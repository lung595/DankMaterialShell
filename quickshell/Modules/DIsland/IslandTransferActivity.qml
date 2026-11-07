pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DIsland.Kit

// Transfers as the island's own face, while the island is free: the app's icon on the left (the "more" dot when there
// are several, a badge when paused), the time left on the right, between them the total on DMS's wave progress, waving
// only while something moves. Hovered or clicked, the island grows into the transfers' card (IslandBarHost.faceBubble).
IslandActivityComponent {
    id: root

    readonly property var source: root.activityData.transfer ?? null
    readonly property var lead: root.source?.lead ?? null
    // No total (a browser's partial file): no liquid, only what came in.
    readonly property bool known: root.source?.allDone || (root.source?.total?.ratio ?? -1) >= 0
    readonly property real level: Math.max(0, root.source?.allDone ? 1 : root.source?.total?.ratio ?? 0)
    readonly property color hue: root.source?.hue ?? Theme.primary

    compactLength: 300

    compactContent: Item {
        id: face

        readonly property real iconSize: Theme.iconSize + Theme.spacingS

        IslandAppIcon {
            id: appIcon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            size: face.iconSize
            source: root.lead?.image ?? ""
            iconName: "downloading"

            Rectangle {
                width: Theme.spacingS
                height: width
                radius: width / 2
                x: parent.width - width
                y: parent.height - height
                color: Theme.primary
                visible: (root.source?.running ?? 0) > 1 && !root.source.paused
            }
            IslandStatusBadge {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                size: Math.round(parent.width * 0.6)
                visible: root.source?.paused ?? false
                name: "pause"
                color: Theme.surfaceText
                rimColor: Theme.surfaceContainer
                Accessible.name: I18n.tr("Paused", "island transfers bubble: everything paused")
            }
        }

        StyledText {
            id: value

            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            // As wide as the icon at least, so what sits between them is centered.
            width: Math.max(face.iconSize, implicitWidth)
            horizontalAlignment: Text.AlignRight
            text: root.source?.valueText ?? ""
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            // Tabular digits: a ticking value keeps its width.
            font.features: {
                "tnum": 1
            }
            color: Theme.surfaceText
        }

        // DMS's own wave progress, at the kit's cadence.
        IslandWaveProgress {
            anchors.left: appIcon.right
            anchors.right: value.left
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.spacingL
            visible: root.known
            value: root.level
            moving: root.source?.total?.flowing === true && !root.source.failed
            fillColor: root.hue
            playheadColor: root.hue
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: [root.source?.titleText ?? "", root.source?.valueText ?? ""].filter(t => t).join(", ")
            Accessible.description: I18n.tr("Click to show the transfers", "island transfers face: screen reader hint")
            // Hovered, the island already grows into the transfers' card in place; the bubble only where it cannot.
            onClicked: {
                if (!root.source?.controller.faceCardShown)
                    root.source?.showCard();
            }
        }
    }
}
