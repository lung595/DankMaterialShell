package transfers

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// qBittorrent is asked only through its own Web UI, and only when the user turned it on with "bypass authentication
// for clients on localhost": the core never stores a password and never reaches past 127.0.0.1.

type qbtConf struct {
	enabled   bool
	port      int
	noAuth    bool
	addressOK bool
}

func qbtConfPath() string {
	dir := os.Getenv("XDG_CONFIG_HOME")
	if dir == "" {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, ".config")
	}
	return filepath.Join(dir, "qBittorrent", "qBittorrent.conf")
}

// qBittorrent's own Web UI port when its config names none, and how long the shell waits for it: a local socket answers
// at once, so a few seconds only mean it is not there.
const (
	qbtDefaultPort    = 8080
	qbtDialTimeout    = 2 * time.Second
	qbtRequestTimeout = 3 * time.Second
)

func readQbtConf(path string) qbtConf {
	conf := qbtConf{port: qbtDefaultPort, addressOK: true}
	f, err := os.Open(path)
	if err != nil {
		return conf
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		key, value, ok := strings.Cut(strings.TrimSpace(sc.Text()), "=")
		if !ok {
			continue
		}
		switch key {
		case `WebUI\Enabled`:
			conf.enabled = value == "true"
		case `WebUI\Port`:
			if n, err := strconv.Atoi(value); err == nil && n > 0 && n < 65536 {
				conf.port = n
			}
		case `WebUI\LocalHostAuth`:
			conf.noAuth = value == "false"
		case `WebUI\Address`:
			conf.addressOK = value == "*" || value == "" || value == "127.0.0.1" || value == "localhost"
		}
	}
	return conf
}

type qbtClient struct {
	confPath string
	http     *http.Client
	// base overrides the loopback URL in tests; it must still be loopback.
	base string
}

func newQbtClient(confPath string) *qbtClient {
	dialer := &net.Dialer{Timeout: qbtDialTimeout}
	return &qbtClient{
		confPath: confPath,
		http: &http.Client{
			Timeout: qbtRequestTimeout,
			Transport: &http.Transport{
				Proxy: nil,
				DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
					if err := loopbackOnly(addr); err != nil {
						return nil, err
					}
					return dialer.DialContext(ctx, network, addr)
				},
			},
			CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
		},
	}
}

func loopbackOnly(addr string) error {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return err
	}
	if ip := net.ParseIP(host); ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("qbittorrent: %s is not loopback", host)
	}
	return nil
}

var errQbtOff = errors.New("qbittorrent web ui not usable")

func (c *qbtClient) baseURL() (string, error) {
	if c.base != "" {
		return c.base, nil
	}
	conf := readQbtConf(c.confPath)
	if !conf.enabled || !conf.noAuth || !conf.addressOK {
		return "", errQbtOff
	}
	return "http://127.0.0.1:" + strconv.Itoa(conf.port), nil
}

type qbtTorrent struct {
	Hash        string  `json:"hash"`
	Name        string  `json:"name"`
	Size        int64   `json:"size"`
	Completed   int64   `json:"completed"`
	Progress    float64 `json:"progress"`
	State       string  `json:"state"`
	SavePath    string  `json:"save_path"`
	ContentPath string  `json:"content_path"`
	NumSeeds    int     `json:"num_seeds"`
	NumLeechs   int     `json:"num_leechs"`
	UpSpeed     int64   `json:"upspeed"`
	Ratio       float64 `json:"ratio"`
}

func (c *qbtClient) list() ([]Transfer, error) {
	base, err := c.baseURL()
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Get(base + "/api/v2/torrents/info")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qbittorrent: %s", resp.Status)
	}
	var torrents []qbtTorrent
	if err := json.NewDecoder(resp.Body).Decode(&torrents); err != nil {
		return nil, err
	}
	return qbtTransfers(torrents), nil
}

// Web UI states of a torrent still downloading (v4 and v5 names); seeding ones are left out.
var qbtDownloading = map[string]bool{
	"downloading": true, "forcedDL": true, "metaDL": true, "forcedMetaDL": true, "queuedDL": true, "stalledDL": true,
	"checkingDL": true, "pausedDL": true, "stoppedDL": true, "allocating": true, "checkingResumeData": true,
}

// qbtTransfers keeps the torrents still downloading (running, queued, stalled, paused or failed).
func qbtTransfers(torrents []qbtTorrent) []Transfer {
	var out []Transfer
	for _, t := range torrents {
		failed := t.State == "error" || t.State == "missingFiles"
		if !failed && (t.Progress >= 1 || !qbtDownloading[t.State]) {
			continue
		}
		path := t.ContentPath
		if path == "" {
			path = t.SavePath
		}
		reason := ""
		if t.State == "missingFiles" {
			reason = "missing-files"
		}
		out = append(out, Transfer{
			ID:         "qbt:" + t.Hash,
			Category:   "torrent",
			Peers:      t.NumSeeds + t.NumLeechs,
			UpSpeed:    t.UpSpeed,
			ShareRatio: t.Ratio,
			Name:       t.Name,
			App:        "qBittorrent",
			AppID:      "org.qbittorrent.qBittorrent",
			Done:       t.Completed,
			Total:      t.Size,
			Paused:     t.State == "pausedDL" || t.State == "stoppedDL",
			CanPause:   !failed,
			CanCancel:  true,
			Error:      failed,
			Reason:     reason,
			Path:       path,
		})
	}
	return out
}

// post sends one action to the torrents named by hash; v5 renamed pause/resume to stop/start, so the first name that
// the Web UI does not know falls back to the second.
func (c *qbtClient) post(hashes []string, form url.Values, actions ...string) error {
	base, err := c.baseURL()
	if err != nil {
		return err
	}
	form.Set("hashes", strings.Join(hashes, "|"))
	for _, action := range actions {
		resp, err := c.http.PostForm(base+"/api/v2/torrents/"+action, form)
		if err != nil {
			return err
		}
		resp.Body.Close()
		if resp.StatusCode == http.StatusNotFound {
			continue
		}
		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("qbittorrent %s: %s", action, resp.Status)
		}
		return nil
	}
	return fmt.Errorf("qbittorrent: no %s", strings.Join(actions, "/"))
}
