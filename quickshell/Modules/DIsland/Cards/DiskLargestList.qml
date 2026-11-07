pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskUsage.js" as DiskUsage

// The disk card's list tab (BubbleCardDisk): the folder's largest files, or the old downloads under Review; a row picks
// its item, a double click shows it in its folder on the chart.
DListView {
    id: largestList

    required property BubbleCardDisk card

    // The list tab: the old downloads (Review), else the folder's largest files; redone at most every second while du runs.
    property int slowRev: 0
    Timer {
        interval: 1000
        repeat: true
        running: card.visible && card.svc.scanning && card.svc.mode === "list"
        onTriggered: largestList.slowRev++
    }
    readonly property var rows: {
        card.svc.scanning ? largestList.slowRev : card.svc.revision;
        if (card.svc.mode !== "list")
            return [];
        if (card.oldOnly)
            return DiskUsage.oldRows(card.clean.facts.old || [], card.svc.tree, card.svc.path);
        return DiskUsage.largestRows(card.folder, card.svc.path, 30);
    }
    readonly property int chosenIndex: {
        const s = card.sel;
        return s ? largestList.rows.findIndex(i => i.path === s.path) : -1;
    }

    anchors.fill: parent
    anchors.margins: Theme.spacingXS
    visible: card.svc.mode === "list"
    clip: true
    model: largestList.rows
    currentIndex: largestList.chosenIndex

    delegate: Item {
        id: line

        required property var modelData
        required property int index
        readonly property bool chosen: line.index === largestList.chosenIndex

        width: ListView.view.width
        height: lineText.implicitHeight + Theme.spacingS

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: line.chosen ? Theme.withAlpha(Theme.primary, 0.2) : lineMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"
        }
        DIcon {
            id: lineIcon

            x: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter
            name: line.modelData.dir ? "folder" : "description"
            size: Theme.iconSizeSmall
            color: Theme.surfaceVariantText
        }
        Column {
            id: lineText

            anchors.left: lineIcon.right
            anchors.leftMargin: Theme.spacingS
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: parent.width
                height: lineName.implicitHeight

                StyledText {
                    id: lineName

                    anchors.left: parent.left
                    anchors.right: lineSize.left
                    anchors.rightMargin: Theme.spacingS
                    text: line.modelData.name
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                    elide: Text.ElideMiddle
                }
                StyledText {
                    id: lineSize

                    anchors.right: parent.right
                    text: DiskUsage.fmt(line.modelData.size)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
            StyledText {
                width: parent.width
                text: card.shortPath(line.modelData.path.slice(0, line.modelData.path.lastIndexOf("/")) || "/")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideMiddle
            }
            Rectangle {
                width: parent.width
                height: Theme.spacingXS / 2
                radius: height / 2
                color: Theme.surfaceContainerHigh

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * line.modelData.size / Math.max(1, largestList.rows[0]?.size ?? 1)
                    color: card.oldOnly ? Theme.error : Theme.primary
                }
            }
        }
        MouseArea {
            id: lineMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                card.takeKeys();
                card.sel = line.modelData;
            }
            onDoubleClicked: card.reveal(line.modelData)
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !largestList.rows.length
        text: I18n.tr("Nothing here", "island disk card: empty list")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
}
