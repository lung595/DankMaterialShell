import QtQuick
import qs.Common
import qs.Modules.DIsland.Kit

// Transfers bubble's pill (source "transfer"): a state the liquid's tone alone must not carry gets its badge (the kit's
// IslandStatusBadge) on the app icon's lower corner: failed, paused, done.
Item {
    id: root

    property var bubble: null
    property color ringColor: Theme.surface

    readonly property bool failed: root.bubble?.failed ?? false
    readonly property bool paused: root.bubble?.paused ?? false
    readonly property bool done: root.bubble?.done ?? false

    visible: root.bubble?.source === "transfer" && (root.failed || root.paused || root.done)

    IslandStatusBadge {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        size: Math.round(root.width * 0.6)
        name: root.failed ? "priority_high" : root.paused ? "pause" : "check"
        color: root.failed ? Theme.error : root.paused ? Theme.surfaceText : Theme.primary
        rimColor: root.ringColor
        Accessible.name: root.failed ? I18n.tr("Failed", "island transfers bubble: a transfer failed") : root.paused ? I18n.tr("Paused", "island transfers bubble: everything paused") : I18n.tr("Done", "island transfers bubble: everything finished")
    }
}
