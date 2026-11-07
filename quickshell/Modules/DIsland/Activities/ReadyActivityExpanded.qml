pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Cards
import "../../../Common/IslandActivityInput.js" as Input

// A plugin's ready-made face, open: the notification popup's grid: the ring on the left, the title and
// the value stacked beside it, the actions in the kit's full width row at the bottom (the first one primary).
FocusScope {
    id: root

    required property var face

    signal triggered(string actionId)

    readonly property color accent: Theme[root.face.accent] ?? Theme.primary

    function focusFace() {
        root.forceActiveFocus();
        return true;
    }

    // Escape is left to the island, which folds the sheet back to its pill.
    Keys.onReturnPressed: event => root.runPrimary(event)
    Keys.onEnterPressed: event => root.runPrimary(event)

    function runPrimary(event) {
        const id = Input.primaryAction(root.face);
        event.accepted = id !== "";
        if (id)
            root.triggered(id);
    }

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: NotificationMetrics.cardPadding
        height: Math.max(ring.height, texts.implicitHeight)

        ReadyActivityRing {
            id: ring

            iconName: root.face.icon
            image: root.face.image
            progress: root.face.progress
            accent: root.accent
        }

        Column {
            id: texts

            anchors.left: ring.right
            anchors.leftMargin: NotificationMetrics.iconSpacing
            anchors.right: parent.right
            // Centered on the ring; the host makes the sheet as tall as a title line and the text's lines (readyHeaderHeight).
            y: Math.max(0, (ring.height - implicitHeight) / 2)
            spacing: NotificationMetrics.contentSpacing / 2

            StyledText {
                width: parent.width
                text: root.face.title
                color: Theme.surfaceText
                font.pixelSize: NotificationMetrics.summarySize
                font.weight: Theme.fontWeightMedium
                wrapMode: Text.Wrap
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            // One line per line of its text (three at most), so the host knows the sheet's height from the face alone.
            Repeater {
                model: root.face.lines

                StyledText {
                    required property string modelData

                    width: parent.width
                    text: modelData
                    color: Theme.surfaceVariantText
                    font.pixelSize: NotificationMetrics.bodySize
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }

    BubbleActions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: NotificationMetrics.cardPadding
        height: implicitHeight
        visible: root.face.actions.length > 0

        Repeater {
            // Hidden so the row gives it no share; its buttons are the row's own children and stay shown.
            visible: false
            model: root.face.actions

            BubbleAction {
                required property var modelData
                required property int index

                text: modelData.label
                role: index === 0 ? "primary" : "plain"
                onClicked: root.triggered(modelData.id)
            }
        }
    }
}
