//go:build !linux

package transfers

// terminate: pidfds are Linux's, so elsewhere a transfer is never stopped from here.
func terminate(root string, pid int, start uint64) error {
	return errUnsupported
}
