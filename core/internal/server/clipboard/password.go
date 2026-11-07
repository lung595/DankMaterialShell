package clipboard

import (
	"github.com/duxlabs-dev/dux-go/wayland/ext_data_control"
	"github.com/duxlabs-dev/dux-shell/core/internal/log"
)

// A password manager's copy (its x-kde-passwordManagerHint): never stored, counted in the state so the shell can show
// it, and cleared on request only while the clipboard still holds it.

// setSecret records the password manager copy the clipboard now holds (nil: none), so the shell can show and clear it.
func (m *Manager) setSecret(offer any) {
	m.secretMutex.Lock()
	changed := offer != m.secretOffer
	if changed && offer != nil {
		m.secretSeq++
	}
	m.secretOffer = offer
	m.secretMutex.Unlock()
	if changed {
		m.updateState()
		m.notifySubscribers()
	}
}

// ClearSecret empties the clipboard only while it still holds the password manager copy, never a later copy.
func (m *Manager) ClearSecret() {
	m.post(func() {
		m.secretMutex.Lock()
		held := m.secretOffer != nil && m.secretOffer == m.currentOffer
		m.secretMutex.Unlock()
		device, ok := m.dataDevice.(*ext_data_control.ExtDataControlDeviceV1)
		if !held || !ok {
			return
		}
		if err := device.SetSelection(nil); err != nil {
			log.Errorf("Failed to clear selection: %v", err)
		}
	})
}
