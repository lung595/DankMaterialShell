pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit

// Incoming SSH bubble's open card (source "ssh"): one line per open session, who on the left and since when on the right,
// then Disconnect held 2 s at the bottom (every open session at once). Read live from the bubble's source
// (IslandSshSource); the address stays hidden while the screen is shared.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var ssh: card.bubble?.ssh ?? null
    readonly property var sessions: card.ssh?.sessions ?? []

    Repeater {
        model: card.sessions

        delegate: Item {
            id: row

            required property var modelData
            readonly property string who: row.modelData.host && !card.ssh?.masked ? I18n.tr("%1 from %2", "island ssh bubble: user from address").arg(row.modelData.user).arg(row.modelData.host) : row.modelData.user
            readonly property string since: row.modelData.since > 0 ? I18n.tr("Since %1", "island ssh bubble: session start time").arg(new Date(row.modelData.since).toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm ap")) : ""

            width: parent?.width ?? 0
            height: Math.max(whoText.implicitHeight, sinceText.implicitHeight)
            Accessible.role: Accessible.ListItem
            Accessible.name: row.who + " " + row.since

            StyledText {
                id: whoText

                anchors.left: parent.left
                anchors.right: sinceText.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                text: row.who
                font.pixelSize: NotificationMetrics.bodySize
                color: Theme.surfaceText
            }

            StyledText {
                id: sinceText

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.NoWrap
                text: row.since
                font.pixelSize: NotificationMetrics.bodySize
                color: Theme.surfaceVariantText
            }
        }
    }

    BubbleActions {
        visible: card.sessions.length > 0

        IslandHoldButton {
            iconName: "link_off"
            text: card.sessions.length > 1 ? I18n.tr("Disconnect all", "island ssh bubble: end every open session") : I18n.tr("Disconnect", "island ssh bubble: end this session")
            busy: card.ssh?.busy ?? false
            enabled: !(card.ssh?.busy ?? true)
            activeFocusOnTab: true
            Accessible.name: card.sessions.length > 1 ? text : I18n.tr("Disconnect %1", "island ssh bubble: disconnect button").arg(card.bubble?.title ?? "")
            onConfirmed: card.ssh?.terminate(card.sessions.map(s => s.id))
        }
    }
}
