package transfers

import (
	"errors"
	"net/url"
	"os"
	"reflect"
	"strings"
	"time"

	"github.com/duxlabs-dev/dux-shell/core/internal/log"
)

func NewManager() *Manager {
	return newManager("/proc", newQbtClient(qbtConfPath()))
}

func newManager(procs string, qbt *qbtClient) *Manager {
	m := &Manager{
		procs:    procs,
		qbt:      qbt,
		uid:      os.Getuid(),
		wake:     make(chan struct{}, 1),
		stopChan: make(chan struct{}),
	}
	m.kill = func(pid int, start uint64) error { return terminate(procs, pid, start) }
	m.wg.Go(m.run)
	return m
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.wg.Wait()
	m.subMu.Lock()
	defer m.subMu.Unlock()
	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 64)
	m.subscribers.Store(id, ch)
	m.poke()
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	m.subMu.Lock()
	defer m.subMu.Unlock()
	if ch, ok := m.subscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

func (m *Manager) GetState() State {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.state
}

func (m *Manager) poke() {
	select {
	case m.wake <- struct{}{}:
	default:
	}
}

func (m *Manager) watched() bool {
	found := false
	m.subscribers.Range(func(string, chan State) bool {
		found = true
		return false
	})
	return found
}

// run scans only while the shell listens: every second while something moves, every five otherwise. A user process
// gets no event when another one starts (the proc connector and fanotify need privileges, /proc has no inotify), so
// the idle scan stays, kept to one read of the /proc directory while no known tool runs.
func (m *Manager) run() {
	for {
		if !m.watched() {
			select {
			case <-m.stopChan:
				return
			case <-m.wake:
				continue
			}
		}
		busy := m.refresh()
		wait := idleInterval
		if busy {
			wait = busyInterval
		}
		select {
		case <-m.stopChan:
			return
		case <-m.wake:
		case <-time.After(wait):
		}
	}
}

// noteQbt logs once that qBittorrent's Web UI refuses (or fails otherwise), not at every scan; a new error logs again.
func (m *Manager) noteQbt(err error) {
	msg := ""
	if err != nil {
		msg = err.Error()
	}
	if msg == m.qbtErr {
		return
	}
	m.qbtErr = msg
	if err != nil {
		log.Warnf("transfers: no qBittorrent torrents: %v", err)
	}
}

func (m *Manager) refresh() bool {
	list, qbt, names := scanProc(m.procs, m.names, m.uid)
	m.names = names
	if qbt && m.qbt != nil {
		torrents, err := m.qbt.list()
		m.noteQbt(err)
		list = append(list, torrents...)
	}
	if list == nil {
		list = []Transfer{}
	}
	m.mu.Lock()
	changed := !reflect.DeepEqual(m.state.Transfers, list)
	m.state = State{Transfers: list}
	state := m.state
	m.mu.Unlock()
	if changed {
		m.subMu.Lock()
		m.subscribers.Range(func(_ string, ch chan State) bool {
			select {
			case ch <- state:
			default:
			}
			return true
		})
		m.subMu.Unlock()
	}
	return len(list) > 0
}

var errUnsupported = errors.New("transfer cannot be paused or cancelled from here")

func torrentHashes(ids []string) ([]string, error) {
	var hashes []string
	for _, id := range ids {
		hash, ok := strings.CutPrefix(id, "qbt:")
		if !ok || hash == "" || strings.Trim(hash, "0123456789abcdefABCDEF") != "" {
			// Hex digits only: the Web UI reads "all" or hashes joined by "|" as more torrents than the one named.
			return nil, errUnsupported
		}
		hashes = append(hashes, hash)
	}
	if len(hashes) == 0 {
		return nil, errNoTransfer
	}
	return hashes, nil
}

// Pause and Resume act on torrents only (no SIGSTOP); Cancel removes torrents and stops the user's own copies and
// archives with SIGTERM.
func (m *Manager) Pause(ids []string) error {
	return m.act(ids, url.Values{}, "stop", "pause")
}

func (m *Manager) Resume(ids []string) error {
	return m.act(ids, url.Values{}, "start", "resume")
}

// Cancel removes a torrent (its files kept) or stops a copy or an archive; every process is checked before any signal.
func (m *Manager) Cancel(ids []string) error {
	if len(ids) == 0 {
		return errNoTransfer
	}
	var torrents, procs []string
	for _, id := range ids {
		if strings.HasPrefix(id, "proc:") {
			procs = append(procs, id)
		} else {
			torrents = append(torrents, id)
		}
	}
	if len(procs) > 0 {
		if err := m.stop(procs); err != nil {
			return err
		}
	}
	if len(torrents) > 0 {
		return m.act(torrents, url.Values{"deleteFiles": {"false"}}, "delete")
	}
	return nil
}

var errNoTransfer = errors.New("no transfer given")

// stop sends SIGTERM once to each process behind the given ids, only if each is still the same copy or archive tool,
// started at the same time (a recycled pid is another process) and owned by the shell's user, who is not root.
func (m *Manager) stop(ids []string) error {
	if m.uid == 0 {
		return errUnsupported
	}
	type target struct {
		pid   int
		start uint64
	}
	var targets []target
	seen := map[target]bool{}
	for _, id := range ids {
		pid, start, ok := procTarget(id)
		if !ok {
			return errUnsupported
		}
		if err := stoppableNow(m.procs, pid, start, m.uid); err != nil {
			return err
		}
		if t := (target{pid, start}); !seen[t] {
			seen[t] = true
			targets = append(targets, t)
		}
	}
	for _, t := range targets {
		if err := m.kill(t.pid, t.start); err != nil {
			return err
		}
	}
	m.poke()
	return nil
}

func (m *Manager) act(ids []string, form url.Values, actions ...string) error {
	hashes, err := torrentHashes(ids)
	if err != nil {
		return err
	}
	if err := m.qbt.post(hashes, form, actions...); err != nil {
		return err
	}
	m.poke()
	return nil
}
