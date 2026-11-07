package transfers

import (
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Files smaller than this pass too fast to show.
const minFileSize = 8 << 20

type tool struct {
	app   string
	appID string
	// The card's section: download, copy, archive, send or disk.
	category string
	// A downloader or a receiver: the file it writes is the transfer, its size unknown.
	writes bool
}

// Only these programs are read: copies, moves, archives, file managers, downloaders, senders and image writers. Their
// read position in the file they copy from (/proc/<pid>/fdinfo) over its size is the progress; nothing is paused from
// here, only the user's own copy and archive tools stop (stoppable). A tool run with sudo (dd onto a key) keeps its
// fds out of reach and stays unseen.
// shortcut: flushing a drive before its eject has no file to read, show it from /proc/meminfo Dirty if it matters.
var tools = map[string]tool{
	"cp":             {app: "cp", category: "copy"},
	"mv":             {app: "mv", category: "copy"},
	"rsync":          {app: "rsync", category: "copy"},
	"pv":             {app: "pv", category: "copy"},
	"dfiles":         {app: "Files", appID: "dev.duxlabs.files", category: "copy"},
	"nautilus":       {app: "Files", appID: "org.gnome.Nautilus", category: "copy"},
	"nemo":           {app: "Nemo", appID: "nemo", category: "copy"},
	"thunar":         {app: "Thunar", appID: "thunar", category: "copy"},
	"dolphin":        {app: "Dolphin", appID: "org.kde.dolphin", category: "copy"},
	"pcmanfm":        {app: "PCManFM", appID: "pcmanfm", category: "copy"},
	"tar":            {app: "tar", category: "archive"},
	"bsdtar":         {app: "bsdtar", category: "archive"},
	"zip":            {app: "zip", category: "archive"},
	"unzip":          {app: "unzip", category: "archive"},
	"7z":             {app: "7-Zip", category: "archive"},
	"7za":            {app: "7-Zip", category: "archive"},
	"7zz":            {app: "7-Zip", category: "archive"},
	"unrar":          {app: "unrar", category: "archive"},
	"xz":             {app: "xz", category: "archive"},
	"zstd":           {app: "zstd", category: "archive"},
	"lz4":            {app: "lz4", category: "archive"},
	"gzip":           {app: "gzip", category: "archive"},
	"gunzip":         {app: "gzip", category: "archive"},
	"pigz":           {app: "pigz", category: "archive"},
	"bzip2":          {app: "bzip2", category: "archive"},
	"file-roller":    {app: "File Roller", appID: "org.gnome.FileRoller", category: "archive"},
	"ark":            {app: "Ark", appID: "org.kde.ark", category: "archive"},
	"engrampa":       {app: "Engrampa", appID: "engrampa", category: "archive"},
	"xarchiver":      {app: "Xarchiver", appID: "xarchiver", category: "archive"},
	"curl":           {app: "curl", category: "download", writes: true},
	"wget":           {app: "wget", category: "download", writes: true},
	"wget2":          {app: "wget", category: "download", writes: true},
	"aria2c":         {app: "aria2", category: "download", writes: true},
	"yt-dlp":         {app: "yt-dlp", category: "download", writes: true},
	"scp":            {app: "scp", category: "send"},
	"sftp":           {app: "sftp", category: "send"},
	"kdeconnectd":    {app: "KDE Connect", appID: "org.kde.kdeconnect.app", category: "send", writes: true},
	"localsend_app":  {app: "LocalSend", appID: "org.localsend.localsend_app", category: "send", writes: true},
	"localsend":      {app: "LocalSend", appID: "org.localsend.localsend_app", category: "send", writes: true},
	"dd":             {app: "dd", category: "disk"},
	"caligula":       {app: "Caligula", category: "disk"},
	"impression":     {app: "Impression", appID: "io.gitlab.adhami3310.Impression", category: "disk"},
	"isoimagewriter": {app: "ISO Image Writer", appID: "org.kde.isoimagewriter", category: "disk"},
}

// remote says whether an rsync process talks to a host (host:path, host::module, rsync://): a send, not a copy.
func remote(dir string) bool {
	raw, err := os.ReadFile(filepath.Join(dir, "cmdline"))
	if err != nil {
		return false
	}
	args := strings.Split(strings.TrimRight(string(raw), "\x00"), "\x00")
	for _, a := range args[1:] {
		if strings.HasPrefix(a, "-") {
			continue
		}
		if strings.HasPrefix(a, "rsync://") {
			return true
		}
		if i := strings.Index(a, ":"); i > 0 && !strings.Contains(a[:i], "/") {
			return true
		}
	}
	return false
}

// procName is a process's comm as last read, and how many scans read it.
type procName struct {
	comm  string
	reads int
}

// scanProc lists, under root (/proc), each known tool's large regular files open read only and part read, and
// whether a qBittorrent process runs. names carries each process's comm from the previous scan: a process is named
// on its first two scans (a fork caught before its exec gets its real name on the second), then from the cache, so
// with no tool running a scan reads only the /proc directory.
// A copy or an archive the user's own CLI tool runs may be cancelled (stop); uid is the shell's, never root.
// shortcut: a process that execs a tool after its second scan stays unseen, read comm on every scan if that matters.
func scanProc(root string, names map[string]procName, uid int) (list []Transfer, qbt bool, seen map[string]procName) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, false, nil
	}
	seen = make(map[string]procName, len(entries))
	for _, e := range entries {
		if _, err := strconv.Atoi(e.Name()); err != nil {
			continue
		}
		name, ok := names[e.Name()]
		if !ok || name.reads < 2 {
			raw, err := os.ReadFile(filepath.Join(root, e.Name(), "comm"))
			if err != nil {
				continue
			}
			name = procName{comm: strings.TrimSpace(string(raw)), reads: name.reads + 1}
		}
		seen[e.Name()] = name
		comm := name.comm
		if comm == "qbittorrent" || comm == "qbittorrent-nox" {
			qbt = true
			continue
		}
		t, ok := tools[comm]
		if !ok {
			continue
		}
		dir := filepath.Join(root, e.Name())
		if comm == "rsync" && remote(dir) {
			t.category = "send"
		}
		// The start time names the process: a recycled pid gets another id.
		start, err := procStart(root, e.Name())
		if err != nil {
			continue
		}
		rows := readFiles(dir, e.Name()+":"+strconv.FormatUint(start, 10), t)
		if len(rows) > 0 && uid != 0 && stoppable(t) && ownedBy(dir, uid) {
			for i := range rows {
				rows[i].CanCancel = true
			}
		}
		list = append(list, rows...)
	}
	return list, qbt, seen
}

// stoppable: a copy or an archive by a command line tool; a file manager or an archiver app (an app id) would close
// with all its windows, so it is never stopped.
func stoppable(t tool) bool {
	return t.appID == "" && (t.category == "copy" || t.category == "archive")
}

// procStart reads a process's start time (/proc/<pid>/stat field 22, clock ticks since boot), after its comm, which
// may hold spaces and parentheses.
func procStart(root, pid string) (uint64, error) {
	raw, err := os.ReadFile(filepath.Join(root, pid, "stat"))
	if err != nil {
		return 0, err
	}
	i := strings.LastIndexByte(string(raw), ')')
	if i < 0 {
		return 0, errors.New("transfers: bad stat")
	}
	fields := strings.Fields(string(raw[i+1:]))
	if len(fields) < 20 {
		return 0, errors.New("transfers: short stat")
	}
	return strconv.ParseUint(fields[19], 10, 64)
}

// ownedBy: the real, effective, saved and filesystem uids of the process are all uid.
func ownedBy(dir string, uid int) bool {
	raw, err := os.ReadFile(filepath.Join(dir, "status"))
	if err != nil {
		return false
	}
	for line := range strings.SplitSeq(string(raw), "\n") {
		rest, ok := strings.CutPrefix(line, "Uid:")
		if !ok {
			continue
		}
		ids := strings.Fields(rest)
		if len(ids) != 4 {
			return false
		}
		for _, id := range ids {
			if id != strconv.Itoa(uid) {
				return false
			}
		}
		return true
	}
	return false
}

// procTarget reads "proc:<pid>:<start>:<path>".
func procTarget(id string) (pid int, start uint64, ok bool) {
	parts := strings.SplitN(id, ":", 4)
	if len(parts) != 4 || parts[0] != "proc" {
		return 0, 0, false
	}
	pid, err := strconv.Atoi(parts[1])
	if err != nil || pid <= 0 {
		return 0, 0, false
	}
	start, err = strconv.ParseUint(parts[2], 10, 64)
	return pid, start, err == nil
}

var errGone = errors.New("transfers: the process is gone or is another one")

// stoppableNow checks, right before a signal, that pid is still the copy or archive tool it was (same start time),
// owned by uid.
func stoppableNow(root string, pid int, start uint64, uid int) error {
	p := strconv.Itoa(pid)
	dir := filepath.Join(root, p)
	if now, err := procStart(root, p); err != nil || now != start {
		return errGone
	}
	raw, err := os.ReadFile(filepath.Join(dir, "comm"))
	if err != nil {
		return errGone
	}
	comm := strings.TrimSpace(string(raw))
	t, ok := tools[comm]
	if !ok || !stoppable(t) || comm == "rsync" && remote(dir) || !ownedBy(dir, uid) {
		return errUnsupported
	}
	return nil
}
