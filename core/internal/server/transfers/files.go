package transfers

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

// A process's open files: the transfer rows read from /proc/<pid>/fd and fdinfo.

// readFiles lists one process's transfers; id is "<pid>:<start>".
func readFiles(dir, id string, t tool) []Transfer {
	fds, err := os.ReadDir(filepath.Join(dir, "fd"))
	if err != nil {
		return nil
	}
	var out []Transfer
	// The last file it writes: where a copy or an extraction lands, so the row opens there.
	written := ""
	for _, fd := range fds {
		row, writing, ok := fdTransfer(dir, fd.Name(), id, t)
		if writing {
			written = row.Path
		}
		if ok {
			out = append(out, row)
		}
	}
	if written != "" {
		for i := range out {
			if out[i].Total > 0 {
				out[i].Path = written
			}
		}
	}
	return out
}

// fdTransfer reads one open file of the process: writing says it is open for writing (where the transfer lands), ok
// that it is a row (a file a downloader writes, or a file read part way).
func fdTransfer(dir, fd, id string, t tool) (row Transfer, writing, ok bool) {
	target, err := os.Readlink(filepath.Join(dir, "fd", fd))
	if err != nil || !fileTarget(target) {
		return row, false, false
	}
	pos, flags, read := readFdinfo(filepath.Join(dir, "fdinfo", fd))
	if !read {
		return row, false, false
	}
	info, err := os.Stat(filepath.Join(dir, "fd", fd))
	if err != nil || !info.Mode().IsRegular() {
		return row, false, false
	}
	row = Transfer{
		ID:       "proc:" + id + ":" + target,
		Category: t.category,
		Name:     filepath.Base(target),
		App:      t.app,
		AppID:    t.appID,
		Path:     target,
	}
	if flags&syscall.O_ACCMODE != syscall.O_RDONLY {
		row.Done = info.Size()
		return row, true, t.writes && info.Size() >= minFileSize
	}
	if info.Size() < minFileSize || pos <= 0 || pos >= info.Size() {
		return row, false, false
	}
	row.Done, row.Total = pos, info.Size()
	return row, false, true
}

// fileTarget tells whether an fd's link names a file on disk: anonymous memory (memfd, a deleted file) is never a transfer.
func fileTarget(target string) bool {
	if !strings.HasPrefix(target, "/") || strings.HasSuffix(target, " (deleted)") || strings.HasPrefix(target, "/memfd:") {
		return false
	}
	for _, p := range []string{"/dev/", "/proc/", "/sys/"} {
		if strings.HasPrefix(target, p) {
			return false
		}
	}
	return true
}

// readFdinfo reads "pos:" and the octal "flags:" of one /proc/<pid>/fdinfo/<fd>.
func readFdinfo(path string) (pos int64, flags int, ok bool) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return 0, 0, false
	}
	var gotPos, gotFlags bool
	for line := range strings.SplitSeq(string(raw), "\n") {
		key, value, found := strings.Cut(line, ":")
		if !found {
			continue
		}
		value = strings.TrimSpace(value)
		switch key {
		case "pos":
			n, err := strconv.ParseInt(value, 10, 64)
			pos, gotPos = n, err == nil
		case "flags":
			n, err := strconv.ParseInt(value, 8, 64)
			flags, gotFlags = int(n), err == nil
		}
	}
	return pos, flags, gotPos && gotFlags
}
