pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskUsage.js" as DiskUsage

// The disk card's crumbs (BubbleCardDisk): back, then the folders down to the shown one, the end kept in sight.
Item {
    id: crumbs

    required property BubbleCardDisk card
    required property DiskChartView chartView

    width: parent.width
    visible: !card.cleanupOpen
    height: Theme.iconSize + Theme.spacingXS

    BubbleAction {
        focusPolicy: Qt.TabFocus
        id: backButton

        anchors.verticalCenter: parent.verticalCenter
        role: "quiet"
        iconName: "arrow_back"
        buttonHeight: parent.height
        enabled: card.oldOnly || !!card.folder.parent
        Accessible.name: I18n.tr("Up", "island disk card: back to the parent folder")
        onClicked: {
            if (card.oldOnly)
                card.oldOnly = false;
            else
                card.up();
        }
    }
    Item {
        anchors.left: backButton.right
        anchors.leftMargin: Theme.spacingXS
        anchors.right: parent.right
        height: parent.height
        clip: true

        Row {
            x: Math.min(0, parent.width - implicitWidth)
            height: parent.height
            spacing: Theme.spacingXXS

            Repeater {
                model: card.oldOnly ? [] : DiskUsage.crumbs(card.folder)

                Row {
                    id: crumb

                    required property var modelData
                    required property int index
                    readonly property bool last: crumb.modelData === card.folder

                    height: parent.height
                    spacing: Theme.spacingXXS

                    DIcon {
                        visible: crumb.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        size: Theme.iconSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: crumb.index === 0 ? card.place : crumb.modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: crumb.last ? Theme.fontWeightMedium : Font.Normal
                        color: crumb.last ? Theme.surfaceText : crumbMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText

                        MouseArea {
                            id: crumbMouse

                            anchors.fill: parent
                            anchors.margins: -Theme.spacingXXS
                            enabled: !crumb.last
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: parent.text
                            onClicked: {
                                card.cur = crumb.modelData;
                                card.sel = null;
                                crumbs.chartView.requestPaint();
                            }
                        }
                    }
                }
            }
            StyledText {
                visible: card.oldOnly
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Old downloads · not opened in 6 months", "island disk card: the largest list filtered by Review")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
        }
    }
}
