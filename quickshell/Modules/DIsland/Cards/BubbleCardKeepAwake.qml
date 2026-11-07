pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Notifications
import qs.DCommon.Widgets
// Sleep blocked bubble's open card (kind "keepawake", the cards' rules C): one row per app keeping the session
// awake, its icon in the header icon's column, its name and reason in the title's; Release (all of them) in the bottom
// row. Read live from the bubble's source (IslandKeepAwakeSource).
// source (IslandKeepAwakeSource).
BubbleCardBase {
    id: card

    readonly property var keepAwake: card.bubble?.keepAwake ?? null
    readonly property var blockers: card.keepAwake?.blockers ?? []

    Repeater {
        model: card.blockers

        Item {
            id: row

            required property var modelData

            width: parent?.width ?? 0
            height: Theme.buttonHeightS
            Accessible.role: Accessible.ListItem
            Accessible.name: card.keepAwake ? card.keepAwake.nameOf(row.modelData) : ""

            Item {
                id: iconBox

                width: NotificationMetrics.appIconSize
                height: parent.height

                CcAppIcon {
                    anchors.centerIn: parent
                    visible: !row.modelData.own
                    appId: row.modelData.app
                    iconSize: Theme.iconSize
                }

                DIcon {
                    anchors.centerIn: parent
                    visible: row.modelData.own
                    name: "coffee"
                    size: Theme.iconSize
                    color: Theme.primary
                }
            }

            Column {
                anchors.left: iconBox.right
                anchors.leftMargin: NotificationMetrics.iconSpacing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: card.keepAwake ? card.keepAwake.nameOf(row.modelData) : ""
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: row.modelData.reason
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    actions: [
        BubbleAction {
            visible: card.blockers.length > 0
            iconName: "bedtime"
            text: card.blockers.length > 1 ? I18n.tr("Release all", "island sleep blocked bubble: stop every app keeping the session awake") : I18n.tr("Release", "island sleep blocked bubble: stop an app keeping the session awake")
            activeFocusOnTab: true
            // A copy: each release drops its row from the source's list.
            onClicked: card.blockers.slice().forEach(blocker => card.keepAwake?.release(blocker))
        }
    ]
}
