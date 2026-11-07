package clipboard

import (
	"crypto/sha256"
	"encoding/binary"
	"time"

	bolt "go.etcd.io/bbolt"

	"github.com/duxlabs-dev/dux-go/wayland/ext_data_control"
	"github.com/duxlabs-dev/dux-shell/core/internal/log"
)

// Secrets the shell copies for the user (one-time codes, passwords, keys, sign-in links) leave the clipboard and its
// history secretWipeAfter later. Only a SHA-256 fingerprint and the deadline are kept, in the db, so a restart still
// wipes the history; the clipboard is emptied only while it still holds exactly that copy.
const secretWipeAfter = 30 * time.Second

var secretBucket = []byte("secretWipes")

// CopySecret copies text like CopyText, then wipes it secretWipeAfter later.
func (m *Manager) CopySecret(text string) error {
	if err := m.CopyText(text); err != nil {
		return err
	}
	return m.armWipe([]byte(text), time.Now().Add(secretWipeAfter))
}

// armWipe records the fingerprint and deadline of data, then schedules its wipe. A second copy pushes the deadline.
func (m *Manager) armWipe(data []byte, due time.Time) error {
	sum := sha256.Sum256(data)
	err := m.dbUpdate(func(tx *bolt.Tx) error {
		b, err := tx.CreateBucketIfNotExists(secretBucket)
		if err != nil {
			return err
		}
		return b.Put(sum[:], binary.BigEndian.AppendUint64(nil, uint64(due.UnixNano())))
	})
	if err != nil {
		return err
	}
	time.AfterFunc(time.Until(due), func() { m.wipeSecret(sum) })
	return nil
}

// pendingWipes reads the recorded wipes: fingerprint to deadline.
func (m *Manager) pendingWipes() map[[sha256.Size]byte]time.Time {
	out := map[[sha256.Size]byte]time.Time{}
	err := m.dbView(func(tx *bolt.Tx) error {
		b := tx.Bucket(secretBucket)
		if b == nil {
			return nil
		}
		return b.ForEach(func(k, v []byte) error {
			if len(k) == sha256.Size && len(v) == 8 {
				out[[sha256.Size]byte(k)] = time.Unix(0, int64(binary.BigEndian.Uint64(v)))
			}
			return nil
		})
	})
	if err != nil {
		log.Errorf("Failed to read secret wipes: %v", err)
	}
	return out
}

// resumeWipes schedules the wipes a previous run left; overdue ones run at once.
func (m *Manager) resumeWipes() {
	for sum, due := range m.pendingWipes() {
		time.AfterFunc(time.Until(due), func() { m.wipeSecret(sum) })
	}
}

// forgetSecret drops the wipe of a value the user copied again from another app: their copy is never wiped.
func (m *Manager) forgetSecret(data []byte) {
	if len(m.pendingWipes()) == 0 {
		return
	}
	sum := sha256.Sum256(data)
	err := m.dbUpdate(func(tx *bolt.Tx) error {
		if b := tx.Bucket(secretBucket); b != nil {
			return b.Delete(sum[:])
		}
		return nil
	})
	if err != nil {
		log.Errorf("Failed to drop secret wipe: %v", err)
	}
}

// wipeSecret removes the secret's unpinned history entries and empties the clipboard if it still holds the copy.
// Nothing happens when the record is gone (the user copied it again) or was pushed later (a newer copy's timer runs).
func (m *Manager) wipeSecret(sum [sha256.Size]byte) {
	due := false
	removed := 0
	err := m.dbUpdate(func(tx *bolt.Tx) error {
		w := tx.Bucket(secretBucket)
		if w == nil {
			return nil
		}
		v := w.Get(sum[:])
		if len(v) != 8 || time.Now().Before(time.Unix(0, int64(binary.BigEndian.Uint64(v)))) {
			return nil
		}
		due = true
		if err := w.Delete(sum[:]); err != nil {
			return err
		}
		h := tx.Bucket([]byte("clipboard"))
		if h == nil {
			return nil
		}
		keys, err := secretEntries(h, sum)
		if err != nil {
			return err
		}
		for _, k := range keys {
			if err := h.Delete(k); err != nil {
				return err
			}
		}
		removed = len(keys)
		return nil
	})
	if err != nil {
		log.Errorf("Failed to wipe secret: %v", err)
		return
	}
	if removed > 0 {
		m.updateState()
		m.notifySubscribers()
	}
	if due && m.ownsSecret(sum) {
		m.post(func() { m.dropOwnedSecret(sum) })
	}
}

// secretEntries lists the history keys holding that secret (pinned entries and images are never wiped).
func secretEntries(h *bolt.Bucket, sum [sha256.Size]byte) ([][]byte, error) {
	var keys [][]byte
	err := h.ForEach(func(k, v []byte) error {
		meta, err := decodeEntryMeta(v)
		if err != nil || meta.Pinned || meta.IsImage {
			return nil
		}
		if e, err := decodeEntry(v); err == nil && sha256.Sum256(e.Data) == sum {
			keys = append(keys, k)
		}
		return nil
	})
	return keys, err
}

// dropOwnedSecret empties the clipboard while the daemon still serves that secret, on the Wayland loop.
func (m *Manager) dropOwnedSecret(sum [sha256.Size]byte) {
	device, ok := m.dataDevice.(*ext_data_control.ExtDataControlDeviceV1)
	if !ok || !m.ownsSecret(sum) {
		return
	}
	if err := device.SetSelection(nil); err != nil {
		log.Errorf("Failed to clear selection: %v", err)
	}
	// Drop the source too: it held the secret to serve pastes. A destroyed source gets no cancel event.
	m.releaseCurrentSource()
	m.ownerLock.Lock()
	m.isOwner = false
	m.ownedSum = [sha256.Size]byte{}
	m.ownerLock.Unlock()
}

// setOwned marks the daemon as the clipboard owner of data, kept as a fingerprint only.
func (m *Manager) setOwned(data []byte) {
	sum := sha256.Sum256(data)
	m.ownerLock.Lock()
	m.isOwner = true
	m.ownedSum = sum
	m.ownerLock.Unlock()
}

// ownsSecret is true while the clipboard is still the daemon's copy of the value with that fingerprint.
func (m *Manager) ownsSecret(sum [sha256.Size]byte) bool {
	m.ownerLock.Lock()
	defer m.ownerLock.Unlock()
	return m.isOwner && m.ownedSum == sum
}
