package transfers

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestQbtConfNeedsWebUIWithoutLocalAuth(t *testing.T) {
	path := filepath.Join(t.TempDir(), "qBittorrent.conf")
	write := func(s string) {
		if err := os.WriteFile(path, []byte(s), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	c := newQbtClient(path)
	write("[Preferences]\nWebUI\\Enabled=true\nWebUI\\Port=9090\n")
	if _, err := c.baseURL(); err == nil {
		t.Fatal("local auth on (the default) must keep the core out")
	}
	write("[Preferences]\nWebUI\\Enabled=true\nWebUI\\Port=9090\nWebUI\\LocalHostAuth=false\n")
	base, err := c.baseURL()
	if err != nil || base != "http://127.0.0.1:9090" {
		t.Fatalf("got %q %v", base, err)
	}
	write("[Preferences]\nWebUI\\Enabled=false\nWebUI\\LocalHostAuth=false\n")
	if _, err := c.baseURL(); err == nil {
		t.Fatal("web ui off must keep the core out")
	}
	write("[Preferences]\nWebUI\\Enabled=true\nWebUI\\LocalHostAuth=false\nWebUI\\Address=192.168.1.5\n")
	if _, err := c.baseURL(); err == nil {
		t.Fatal("a web ui bound elsewhere than loopback must keep the core out")
	}
}

func TestLoopbackOnly(t *testing.T) {
	for addr, ok := range map[string]bool{"127.0.0.1:8080": true, "[::1]:8080": true, "192.168.1.5:8080": false, "example.com:80": false} {
		if err := loopbackOnly(addr); (err == nil) != ok {
			t.Errorf("%s: %v", addr, err)
		}
	}
	c := newQbtClient("")
	c.base = "http://192.0.2.1:8080"
	if _, err := c.list(); err == nil || !strings.Contains(err.Error(), "not loopback") {
		t.Fatalf("a non loopback address must be refused before dialing: %v", err)
	}
}

// fakeQbt serves a Web UI listing four torrents (one seeding), without the v5 stop action; posted collects the other
// actions, path and form.
func fakeQbt(t *testing.T, posted *[]string) *qbtClient {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v2/torrents/info":
			w.Write([]byte(`[
				{"hash":"a","name":"debian.iso","size":1000,"completed":250,"progress":0.25,"state":"downloading","content_path":"/d/debian.iso","num_seeds":4,"num_leechs":8,"upspeed":2048,"ratio":0.42},
				{"hash":"b","name":"paused","size":1000,"completed":10,"progress":0.01,"state":"stoppedDL"},
				{"hash":"c","name":"seeding","size":1000,"completed":1000,"progress":1,"state":"uploading"},
				{"hash":"d","name":"broken","size":1000,"completed":5,"progress":0.005,"state":"missingFiles"}
			]`))
		case "/api/v2/torrents/stop":
			// A v4 Web UI: no stop, the client falls back to pause.
			http.NotFound(w, r)
		default:
			r.ParseForm()
			*posted = append(*posted, r.URL.Path+"?"+r.PostForm.Encode())
		}
	}))
	t.Cleanup(srv.Close)
	c := newQbtClient("")
	c.base = srv.URL
	return c
}

func TestQbtList(t *testing.T) {
	list, err := fakeQbt(t, new([]string)).list()
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 3 {
		t.Fatalf("seeding torrents must be left out: %+v", list)
	}
	if list[0].ID != "qbt:a" || list[0].Done != 250 || list[0].Path != "/d/debian.iso" || !list[0].CanPause || list[0].Paused {
		t.Fatalf("running torrent %+v", list[0])
	}
	if list[0].Category != "torrent" || list[0].Peers != 12 || list[0].UpSpeed != 2048 || list[0].ShareRatio != 0.42 {
		t.Fatalf("torrent peers, upload and ratio %+v", list[0])
	}
	if !list[1].Paused {
		t.Fatalf("stoppedDL is paused: %+v", list[1])
	}
	if !list[2].Error || list[2].CanPause || list[2].Reason != "missing-files" {
		t.Fatalf("missing files is an error: %+v", list[2])
	}
}

func TestQbtActions(t *testing.T) {
	var posted []string
	m := &Manager{qbt: fakeQbt(t, &posted), wake: make(chan struct{}, 1)}
	if err := m.Pause([]string{"qbt:a", "qbt:b"}); err != nil {
		t.Fatal(err)
	}
	if err := m.Cancel([]string{"qbt:a"}); err != nil {
		t.Fatal(err)
	}
	want := []string{"/api/v2/torrents/pause?hashes=a%7Cb", "/api/v2/torrents/delete?deleteFiles=false&hashes=a"}
	if strings.Join(posted, " ") != strings.Join(want, " ") {
		t.Fatalf("posted %v, want %v", posted, want)
	}
	if err := m.Cancel([]string{"proc:100:/x"}); err == nil {
		t.Fatal("a malformed copy id must not be cancelled")
	}
	if err := m.Pause([]string{"proc:100:4242:/x"}); err == nil {
		t.Fatal("a copy must not be paused")
	}
}
