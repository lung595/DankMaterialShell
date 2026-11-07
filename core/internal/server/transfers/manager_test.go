package transfers

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
)

// fakeProc builds /proc/<pid> with comm and one fd pointing at a file of the given size, read up to pos.
func fakeProc(t *testing.T, root, pid, comm string, size, pos int64, flags string) string {
	t.Helper()
	dir := filepath.Join(root, pid)
	for _, d := range []string{"fd", "fdinfo"} {
		if err := os.MkdirAll(filepath.Join(dir, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "comm"), []byte(comm+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	// Started at tick 4242, owned by uid 1000.
	setStart(t, root, pid, comm, 4242)
	setOwner(t, root, pid, 1000)
	file := filepath.Join(t.TempDir(), "ubuntu.iso")
	f, err := os.Create(file)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Truncate(size); err != nil {
		t.Fatal(err)
	}
	f.Close()
	if err := os.Symlink(file, filepath.Join(dir, "fd", "3")); err != nil {
		t.Fatal(err)
	}
	info := "pos:\t" + strconv.FormatInt(pos, 10) + "\nflags:\t" + flags + "\nmnt_id:\t30\n"
	if err := os.WriteFile(filepath.Join(dir, "fdinfo", "3"), []byte(info), 0o644); err != nil {
		t.Fatal(err)
	}
	return file
}

func TestScanProcReadsKnownToolsOnly(t *testing.T) {
	root := t.TempDir()
	file := fakeProc(t, root, "100", "cp", 100<<20, 25<<20, "0100000")
	fakeProc(t, root, "101", "firefox", 100<<20, 25<<20, "0100000")
	// Written, not read: the copy's target, skipped.
	fakeProc(t, root, "102", "cp", 100<<20, 25<<20, "0100001")
	// Too small to show.
	fakeProc(t, root, "103", "tar", 1<<20, 1<<10, "0100000")
	fakeProc(t, root, "104", "qbittorrent", 100<<20, 25<<20, "0100000")

	list, qbt, _ := scanProc(root, nil, 1000)
	if !qbt {
		t.Fatal("qbittorrent process not seen")
	}
	if len(list) != 1 {
		t.Fatalf("want one transfer, got %+v", list)
	}
	got := list[0]
	if got.ID != "proc:100:4242:"+file || got.App != "cp" || got.Category != "copy" || got.Done != 25<<20 || got.Total != 100<<20 || got.Name != "ubuntu.iso" {
		t.Fatalf("unexpected transfer %+v", got)
	}
	if got.CanPause || !got.CanCancel {
		t.Fatal("the user's own copy cancels, never pauses")
	}
}

// setStart writes /proc/<pid>/stat with the given start time (field 22), a comm with a space and a parenthesis.
func setStart(t *testing.T, root, pid, comm string, start uint64) {
	t.Helper()
	fields := make([]string, 20)
	for i := range fields {
		fields[i] = "0"
	}
	fields[0] = "S"
	fields[19] = strconv.FormatUint(start, 10)
	stat := pid + " (" + comm + " (x)) " + strings.Join(fields, " ") + " 0 0\n"
	if err := os.WriteFile(filepath.Join(root, pid, "stat"), []byte(stat), 0o644); err != nil {
		t.Fatal(err)
	}
}

// setOwner writes /proc/<pid>/status with the given real, effective, saved and fs uid.
func setOwner(t *testing.T, root, pid string, uid int) {
	t.Helper()
	u := strconv.Itoa(uid)
	status := "Name:\tx\nUid:\t" + u + "\t" + u + "\t" + u + "\t" + u + "\nGid:\t100\t100\t100\t100\n"
	if err := os.WriteFile(filepath.Join(root, pid, "status"), []byte(status), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestScanProcLetsOnlyTheUsersOwnCopiesAndArchivesCancel(t *testing.T) {
	root := t.TempDir()
	fakeProc(t, root, "400", "cp", 100<<20, 25<<20, "0100000")
	fakeProc(t, root, "401", "tar", 100<<20, 25<<20, "0100000")
	// Someone else's copy, and a file manager (stopping it would close every window).
	fakeProc(t, root, "402", "cp", 100<<20, 25<<20, "0100000")
	setOwner(t, root, "402", 1001)
	fakeProc(t, root, "403", "nautilus", 100<<20, 25<<20, "0100000")
	list, _, _ := scanProc(root, nil, 1000)
	can := map[string]bool{}
	for _, tr := range list {
		can[strings.Split(tr.ID, ":")[1]] = tr.CanCancel
		if tr.CanPause {
			t.Errorf("a copy never pauses: %+v", tr)
		}
	}
	want := map[string]bool{"400": true, "401": true, "402": false, "403": false}
	for pid, c := range want {
		if can[pid] != c {
			t.Errorf("pid %s: canCancel %v, want %v", pid, can[pid], c)
		}
	}
	// Run as root, the shell never stops anything.
	list, _, _ = scanProc(root, nil, 0)
	for _, tr := range list {
		if tr.CanCancel {
			t.Errorf("root must not cancel: %+v", tr)
		}
	}
}

func TestCancelStopsTheSameProcessOnly(t *testing.T) {
	root := t.TempDir()
	file := fakeProc(t, root, "500", "cp", 100<<20, 25<<20, "0100000")
	other := addFd(t, root, "500", "4", "second.iso", 100<<20, 10<<20, "0100000")
	var killed []string
	m := &Manager{procs: root, uid: 1000, wake: make(chan struct{}, 1), kill: func(pid int, start uint64) error {
		killed = append(killed, strconv.Itoa(pid)+"@"+strconv.FormatUint(start, 10))
		return nil
	}}
	// Two files of one cp: one signal.
	if err := m.Cancel([]string{"proc:500:4242:" + file, "proc:500:4242:" + other}); err != nil {
		t.Fatal(err)
	}
	if strings.Join(killed, " ") != "500@4242" {
		t.Fatalf("killed %v", killed)
	}
	killed = nil
	// The pid came back as another process: refused.
	setStart(t, root, "500", "cp", 9999)
	if err := m.Cancel([]string{"proc:500:4242:" + file}); err == nil || killed != nil {
		t.Fatalf("a recycled pid must not be signalled: %v %v", err, killed)
	}
	setStart(t, root, "500", "cp", 4242)
	setOwner(t, root, "500", 1001)
	if err := m.Cancel([]string{"proc:500:4242:" + file}); err == nil || killed != nil {
		t.Fatalf("another user's process must not be signalled: %v %v", err, killed)
	}
	setOwner(t, root, "500", 1000)
	if err := os.WriteFile(filepath.Join(root, "500", "comm"), []byte("bash\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := m.Cancel([]string{"proc:500:4242:" + file}); err == nil || killed != nil {
		t.Fatalf("a process that is no longer a copy must not be signalled: %v %v", err, killed)
	}
	root0 := &Manager{procs: root, uid: 0, wake: make(chan struct{}, 1), kill: m.kill}
	if err := root0.Cancel([]string{"proc:500:4242:" + file}); err == nil || killed != nil {
		t.Fatalf("root must not signal: %v %v", err, killed)
	}
}

func TestTerminateSendsSIGTERMToTheSameProcess(t *testing.T) {
	cmd := exec.Command("sleep", "30")
	if err := cmd.Start(); err != nil {
		t.Skip("no sleep:", err)
	}
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
	pid := cmd.Process.Pid
	start, err := procStart("/proc", strconv.Itoa(pid))
	if err != nil {
		t.Fatal(err)
	}
	if err := terminate("/proc", pid, start+1); err == nil {
		t.Fatal("a different start time must refuse")
	}
	if err := terminate("/proc", pid, start); err != nil {
		t.Fatal(err)
	}
	err = cmd.Wait()
	var exit *exec.ExitError
	if !errors.As(err, &exit) || exit.Sys().(syscall.WaitStatus).Signal() != syscall.SIGTERM {
		t.Fatalf("want SIGTERM, got %v", err)
	}
}

// addFd opens one more file of the given size in a fake /proc/<pid>, at pos with flags.
func addFd(t *testing.T, root, pid, fd, name string, size, pos int64, flags string) string {
	t.Helper()
	file := filepath.Join(t.TempDir(), name)
	f, err := os.Create(file)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Truncate(size); err != nil {
		t.Fatal(err)
	}
	f.Close()
	if err := os.Symlink(file, filepath.Join(root, pid, "fd", fd)); err != nil {
		t.Fatal(err)
	}
	info := "pos:\t" + strconv.FormatInt(pos, 10) + "\nflags:\t" + flags + "\n"
	if err := os.WriteFile(filepath.Join(root, pid, "fdinfo", fd), []byte(info), 0o644); err != nil {
		t.Fatal(err)
	}
	return file
}

func TestScanProcSortsToolsIntoCategories(t *testing.T) {
	root := t.TempDir()
	fakeProc(t, root, "300", "cp", 100<<20, 25<<20, "0100000")
	// The copy's target: the row opens there.
	dest := addFd(t, root, "300", "4", "copy-of.iso", 25<<20, 25<<20, "0100001")
	fakeProc(t, root, "301", "tar", 100<<20, 25<<20, "0100000")
	fakeProc(t, root, "302", "dd", 100<<20, 25<<20, "0100000")
	fakeProc(t, root, "303", "scp", 100<<20, 25<<20, "0100000")
	// A downloader only writes: what came in so far, size unknown.
	fakeProc(t, root, "304", "curl", 1<<10, 0, "0100000")
	got := addFd(t, root, "304", "4", "fedora.iso", 40<<20, 40<<20, "0100001")
	// rsync to a host is a send, rsync between folders a copy.
	fakeProc(t, root, "305", "rsync", 100<<20, 25<<20, "0100000")
	fakeProc(t, root, "306", "rsync", 100<<20, 25<<20, "0100000")
	cmdline := func(pid string, args ...string) {
		if err := os.WriteFile(filepath.Join(root, pid, "cmdline"), []byte(strings.Join(args, "\x00")+"\x00"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	cmdline("305", "rsync", "-a", "--chmod=u+rw", "big.iso", "nas:/backup/")
	cmdline("306", "rsync", "-a", "big.iso", "/mnt/backup/")

	list, _, _ := scanProc(root, nil, 1000)
	cats := map[string]string{}
	for _, tr := range list {
		cats[strings.Split(tr.ID, ":")[1]] = tr.Category
		switch tr.ID[:9] {
		case "proc:300:":
			if tr.Path != dest {
				t.Errorf("a copy opens at its target: %+v", tr)
			}
		case "proc:304:":
			if tr.Name != "fedora.iso" || tr.Done != 40<<20 || tr.Total != 0 || tr.Path != got {
				t.Errorf("download %+v", tr)
			}
		}
	}
	want := map[string]string{"300": "copy", "301": "archive", "302": "disk", "303": "send", "304": "download", "305": "send", "306": "copy"}
	if len(cats) != len(want) {
		t.Fatalf("got %v, want %v", cats, want)
	}
	for pid, c := range want {
		if cats[pid] != c {
			t.Errorf("pid %s: category %q, want %q", pid, cats[pid], c)
		}
	}
}

func TestScanProcNamesEachProcessTwiceThenFromCache(t *testing.T) {
	root := t.TempDir()
	fakeProc(t, root, "200", "bash", 100<<20, 25<<20, "0100000")
	rename := func(comm string) {
		if err := os.WriteFile(filepath.Join(root, "200", "comm"), []byte(comm+"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	list, _, names := scanProc(root, nil, 1000)
	if len(list) != 0 {
		t.Fatalf("a shell is not a copy: %+v", list)
	}
	// The fork was caught before its exec: the second scan names it again.
	rename("cp")
	if list, _, names = scanProc(root, names, 1000); len(list) != 1 {
		t.Fatalf("exec into cp missed: %+v", list)
	}
	// Named twice: an idle scan no longer reads its comm.
	rename("firefox")
	if list, _, names = scanProc(root, names, 1000); len(list) != 1 {
		t.Fatalf("comm read again: %+v", list)
	}
	if err := os.RemoveAll(filepath.Join(root, "200")); err != nil {
		t.Fatal(err)
	}
	if _, _, names = scanProc(root, names, 1000); len(names) != 0 {
		t.Fatalf("a gone process stays cached: %+v", names)
	}
}
