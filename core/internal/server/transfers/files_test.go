package transfers

import "testing"

func TestFileTargetSkipsAnonymousMemory(t *testing.T) {
	cases := map[string]bool{
		"/srv/files/fedora.iso": true,
		// KDE Connect's PulseAudio shared memory: 64 MiB open for writing, never a transfer.
		"/memfd:pulseaudio (deleted)":   false,
		"/tmp/kdeconnect.abc (deleted)": false,
		"/dev/shm/x":                    false,
		"/proc/1/maps":                  false,
		"/sys/x":                        false,
		"socket:[1234]":                 false,
	}
	for target, want := range cases {
		if got := fileTarget(target); got != want {
			t.Errorf("fileTarget(%q) = %v, want %v", target, got, want)
		}
	}
}
