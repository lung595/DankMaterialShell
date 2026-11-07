package transfers

import (
	"sync"
	"time"

	"github.com/duxlabs-dev/dux-go/syncmap"
)

const (
	// polled while something is moving, slower while nothing is
	busyInterval = time.Second
	idleInterval = 5 * time.Second
)

// Transfer is one file on its way: a copy or an archive a known tool reads, or a qBittorrent torrent.
// Category groups it in the card: download, torrent, copy, archive, send or disk.
type Transfer struct {
	ID        string `json:"id"`
	Category  string `json:"category"`
	Name      string `json:"name"`
	App       string `json:"app"`
	AppID     string `json:"appId,omitempty"`
	Done      int64  `json:"done"`
	Total     int64  `json:"total"`
	Paused    bool   `json:"paused"`
	CanPause  bool   `json:"canPause"`
	CanCancel bool   `json:"canCancel"`
	Error     bool   `json:"error"`
	Reason    string `json:"reason,omitempty"`
	Path      string `json:"path,omitempty"`
	// Torrents only: connected peers, upload speed (bytes/s) and share ratio.
	Peers      int     `json:"peers,omitempty"`
	UpSpeed    int64   `json:"upSpeed,omitempty"`
	ShareRatio float64 `json:"shareRatio,omitempty"`
}

type State struct {
	Transfers []Transfer `json:"transfers"`
}

type Manager struct {
	mu    sync.Mutex
	state State
	procs string
	names map[string]procName // owned by run
	// The shell's own uid: only its processes stop, never when it is root.
	uid int
	// kill sends SIGTERM to pid if it still started at start (terminate; a fake in tests).
	kill func(pid int, start uint64) error
	qbt  *qbtClient
	// The last qBittorrent error logged (noteQbt), owned by run.
	qbtErr string

	// subMu keeps a send from racing the close of the same channel (Unsubscribe, Close).
	subMu       sync.Mutex
	subscribers syncmap.Map[string, chan State]
	wake        chan struct{}
	stopChan    chan struct{}
	wg          sync.WaitGroup
}
