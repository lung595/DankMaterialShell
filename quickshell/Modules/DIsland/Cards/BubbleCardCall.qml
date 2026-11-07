pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DIsland.Kit

// Call bubble's open card (source "call"), titled by the app (Discord): [microphone][deafen][ go to call ], parts 1 1 2.
// Microphone and deafen cut the app's own streams (IslandCallSource), not the system's; the last one brings the call's
// window forward, or is a real Hang up held 2 s when the app's call notification offers one.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var call: card.bubble?.call ?? null

    BubbleActions {
        BubbleAction {
            toggle: true
            isOn: card.bubble?.muted ?? false
            iconName: "mic"
            iconOn: "mic_off"
            Accessible.name: isOn ? I18n.tr("Unmute", "island call bubble: turn the microphone back on") : I18n.tr("Mute", "island call bubble: cut the microphone")
            onClicked: card.call?.toggleMute()
        }

        BubbleAction {
            toggle: true
            isOn: card.bubble?.deafened ?? false
            iconName: "headset"
            iconOn: "headset_off"
            Accessible.name: isOn ? I18n.tr("Undeafen", "island call bubble: turn the call's sound back on") : I18n.tr("Deafen", "island call bubble: cut the call's sound and microphone")
            onClicked: card.call?.toggleDeafen()
        }

        BubbleAction {
            weight: 2
            role: "primary"
            visible: !(card.call?.canHangUp ?? false)
            enabled: card.call?.canGoTo ?? false
            iconName: "call"
            text: I18n.tr("Go to call", "island call bubble: bring the call's window forward")
            onClicked: card.call?.goTo()
        }

        IslandHoldButton {
            weight: 2
            visible: card.call?.canHangUp ?? false
            iconName: "call_end"
            text: I18n.tr("Hang up", "island call bubble: end the call")
            onConfirmed: card.call?.hangUp()
        }
    }
}
