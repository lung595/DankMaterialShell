package clipboard

import (
	"crypto/sha256"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/duxlabs-dev/dux-go/ipc"
)

func historyHas(m *Manager, text string) bool {
	for _, e := range m.GetHistory() {
		if e.Preview == text {
			return true
		}
	}
	return false
}

func TestSecret_ClipboardClearedOnlyWhileItStillHoldsTheSecret(t *testing.T) {
	m := newTestManagerWithDB(t)
	sum := sha256.Sum256([]byte("482913"))

	m.setOwned([]byte("482913"))
	assert.True(t, m.ownsSecret(sum), "unchanged: the island's copy is still the clipboard")

	m.setOwned([]byte("hello"))
	assert.False(t, m.ownsSecret(sum), "the island copied something else since")

	m.setOwned([]byte("482913"))
	m.ownerLock.Lock()
	m.isOwner = false // another client took the clipboard
	m.ownerLock.Unlock()
	assert.False(t, m.ownsSecret(sum), "something else was copied since")
}

func TestSecret_HistoryEntryRemovedAtTheEnd(t *testing.T) {
	m := newTestManagerWithDB(t)
	storeTestEntry(t, m, "before")
	storeTestEntry(t, m, "482913")

	require.NoError(t, m.armWipe([]byte("482913"), time.Now()))
	m.wipeSecret(sha256.Sum256([]byte("482913")))

	assert.False(t, historyHas(m, "482913"))
	assert.True(t, historyHas(m, "before"))
	assert.Empty(t, m.pendingWipes(), "the record goes with it")
}

func TestSecret_PinnedEntryAndEarlyTimerKeepTheEntry(t *testing.T) {
	m := newTestManagerWithDB(t)
	id := storeTestEntry(t, m, "482913")

	require.NoError(t, m.armWipe([]byte("482913"), time.Now().Add(time.Hour)))
	m.wipeSecret(sha256.Sum256([]byte("482913")))
	assert.True(t, historyHas(m, "482913"), "re-armed later: an older timer leaves it")

	require.NoError(t, m.PinEntry(id))
	require.NoError(t, m.armWipe([]byte("482913"), time.Now()))
	m.wipeSecret(sha256.Sum256([]byte("482913")))
	assert.Len(t, m.GetPinnedEntries(), 1, "the user saved it: kept")
}

func TestSecret_SurvivesARestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "clipboard.db")
	db, err := openDB(path)
	require.NoError(t, err)
	m := newTestManagerWithDB(t)
	m.db = db
	storeTestEntry(t, m, "482913")
	require.NoError(t, m.armWipe([]byte("482913"), time.Now().Add(50*time.Millisecond)))
	db.Close()

	db, err = openDB(path)
	require.NoError(t, err)
	t.Cleanup(func() { db.Close() })
	next := newTestManagerWithDB(t)
	next.db = db
	require.True(t, historyHas(next, "482913"))

	next.resumeWipes()
	assert.Eventually(t, func() bool { return !historyHas(next, "482913") }, 2*time.Second, 20*time.Millisecond)
}

func TestSecret_NeverForTheUsersOwnCopy(t *testing.T) {
	m := newTestManagerWithDB(t)

	require.NoError(t, m.CopyText("my own text"))
	assert.Empty(t, m.pendingWipes(), "a plain copy never arms a wipe")

	storeTestEntry(t, m, "482913")
	// Armed a little ahead: a timer due now could fire before the user's copy comes in.
	require.NoError(t, m.armWipe([]byte("482913"), time.Now().Add(50*time.Millisecond)))
	m.forgetSecret([]byte("482913")) // the user copied the same value from another app
	assert.Never(t, func() bool { return !historyHas(m, "482913") }, 200*time.Millisecond, 10*time.Millisecond)
	assert.True(t, historyHas(m, "my own text"))
}

func TestSecret_CopySecretStoresAndArms(t *testing.T) {
	m := newTestManagerWithDB(t)

	require.NoError(t, m.CopySecret("482913"))
	assert.True(t, historyHas(m, "482913"), "it enters the history")
	pending := m.pendingWipes()
	require.Len(t, pending, 1)
	assert.WithinDuration(t, time.Now().Add(secretWipeAfter), pending[sha256.Sum256([]byte("482913"))], time.Second)
}

func copyRequest(t *testing.T, m *Manager, params map[string]any) {
	t.Helper()
	mc := newClipboardTestConn()
	HandleRequest(ipc.NewConnWriter(mc), ipc.Request{ID: 1, Method: "clipboard.copy", Params: params}, m)
	var resp ipc.Response[map[string]any]
	require.NoError(t, json.NewDecoder(mc.writeBuf).Decode(&resp))
	require.Empty(t, resp.Error)
}

func TestSecret_OnlyACopyMarkedSecretIsWiped(t *testing.T) {
	m := newTestManagerWithDB(t)

	copyRequest(t, m, map[string]any{"text": "hello"})
	assert.Empty(t, m.pendingWipes(), "clipboard.copy alone stays")

	copyRequest(t, m, map[string]any{"text": "482913", "secret": true})
	assert.Contains(t, m.pendingWipes(), sha256.Sum256([]byte("482913")))
	assert.Len(t, m.pendingWipes(), 1)
}

func TestSecret_UsersCopyFromAnotherAppCancelsTheWipe(t *testing.T) {
	m := newTestManagerWithDB(t)
	require.NoError(t, m.armWipe([]byte("482913"), time.Now().Add(time.Hour)))

	r, w, err := os.Pipe()
	require.NoError(t, err)
	_, err = w.WriteString("482913")
	require.NoError(t, err)
	w.Close()
	m.readAndStore(r, "text/plain;charset=utf-8", nil, "")

	assert.Empty(t, m.pendingWipes())
	assert.True(t, historyHas(m, "482913"))
}
