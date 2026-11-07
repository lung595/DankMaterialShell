import QtQuick
import qs.Common
import qs.Modules.DIsland.Kit

// Call bubble's pill (source "call"): only while the call is deafened or its microphone cut, that state's badge (the kit's
// IslandStatusBadge: the small icon alone, rimmed) on the app icon's lower corner.
// B8: its pill, as the bubbles' table says.
Item {
    id: root

    property var bubble: null
    property color ringColor: Theme.surface

    readonly property bool deafened: root.bubble?.deafened ?? false
    readonly property bool muted: root.bubble?.muted ?? false

    visible: root.bubble?.source === "call" && (root.deafened || root.muted)

    IslandStatusBadge {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        size: Math.round(root.width * 0.6)
        name: root.deafened ? "headset_off" : "mic_off"
        color: Theme.error
        rimColor: root.ringColor
        Accessible.name: root.deafened ? I18n.tr("Deafened", "island call bubble: sound and microphone cut") : I18n.tr("Microphone off", "island call bubble: microphone muted")
    }
}
