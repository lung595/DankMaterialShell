pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DIsland.Cards

// A finished download as the island's own face, while the island is free: the file falling into its shape,
// its name on the left, its size on the right, centered and symmetric. Not urgent, so no button on the face: a click
// opens the file, a right-click shows it in its folder. DownloadService moves it to its bubble when something else
// takes the island; the bubble's card keeps both as buttons.
IslandActivityComponent {
    id: root

    compactLength: 300

    compactContent: Item {
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            BubbleDownloadGlyph {
                id: glyph

                anchors.verticalCenter: parent.verticalCenter
                size: Theme.iconSize
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.compactLength - glyph.width - sizeLabel.implicitWidth - Theme.spacingS * 2 - Theme.spacingM * 2)
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                text: DownloadService.file?.name ?? ""
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
            }

            StyledText {
                id: sizeLabel

                anchors.verticalCenter: parent.verticalCenter
                text: DownloadService.sizeText
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("Open", "island download bubble: open the file")
            Accessible.description: I18n.tr("Right-click to show it in its folder", "island download face: screen reader hint")
            onClicked: mouse => mouse.button === Qt.RightButton ? DownloadService.show() : DownloadService.open()
        }
    }
}
