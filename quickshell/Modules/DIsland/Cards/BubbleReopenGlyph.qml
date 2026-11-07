import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DIsland.Kit

// Reopen bubble's pill (source "reopen"): the closed app's icon in the kit's flower outline (never a filled backdrop), the
// kit's live liquid draining under it as the countdown runs out (the undo button's countdown).
Item {
    id: root

    property var bubble: null
    property color accent: Theme.primary
    property bool bare: false
    property real iconSize: Math.round(root.width * 0.7)
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    readonly property string app: root.visible ? root.bubble.app ?? "" : ""

    visible: root.bubble?.source === "reopen"

    // A disc inside the flower's valleys, even sized so it shares the pill's center.
    IslandLiquid {
        readonly property int side: Math.round(root.width * 0.34) * 2

        anchors.centerIn: parent
        width: side
        height: side
        radius: side / 2
        color: Theme.withAlpha(root.accent, 0.32)
        // Reduced motion: full, it simply goes with the bubble.
        level: root.visible ? (root.still ? 1 : root.bubble.reopen?.remaining ?? 1) : 0
    }

    IslandAppIcon {
        anchors.fill: parent
        size: root.width
        bare: root.bare
        iconSize: root.iconSize
        source: root.app ? Paths.getAppIcon(root.app, DesktopEntries.heuristicLookup(root.app)) : ""
    }
}
