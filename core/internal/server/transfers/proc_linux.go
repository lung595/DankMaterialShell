//go:build linux

package transfers

import (
	"strconv"

	"golang.org/x/sys/unix"
)

// terminate sends SIGTERM through a pidfd: once open it pins the process, so the start time read after it is that
// process's own, and the signal cannot reach a pid recycled in between.
func terminate(root string, pid int, start uint64) error {
	fd, err := unix.PidfdOpen(pid, 0)
	if err != nil {
		return errGone
	}
	defer unix.Close(fd)
	if now, err := procStart(root, strconv.Itoa(pid)); err != nil || now != start {
		return errGone
	}
	return unix.PidfdSendSignal(fd, unix.SIGTERM, nil, 0)
}
