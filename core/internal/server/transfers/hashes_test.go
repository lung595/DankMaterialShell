package transfers

import "testing"

func TestTorrentHashesRefuseWhatReachesOtherTorrents(t *testing.T) {
	for _, id := range []string{"qbt:all", "qbt:a|b", "qbt:", "proc:1:2:/x"} {
		if _, err := torrentHashes([]string{id}); err == nil {
			t.Fatalf("%q must be refused", id)
		}
	}
	hashes, err := torrentHashes([]string{"qbt:0123abcdEF"})
	if err != nil || len(hashes) != 1 || hashes[0] != "0123abcdEF" {
		t.Fatalf("a hex hash must pass, got %v %v", hashes, err)
	}
}
