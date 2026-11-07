pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DIsland.Cards

// The eye break as the island's own face, while the island is free: the eye looking off and "Look far away" on the
// left, the countdown on the right, centered and symmetric. Not urgent, so no button on the face: a click skips the
// break. EyeBreakService moves it to the machine bubble (with its Skip button) when something else takes the island.
IslandActivityComponent {
    id: root

    // Room for the eye and the countdown beside it.
    compactLength: 280

    compactContent: Item {
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            EyeBreakGlyph {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.iconSize
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Look far away", "island eye break: the island's short hint during the break")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: EyeBreakService.countdown
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
                font.features: {
                    "tnum": 1
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("Skip", "island eye break: end the break now")
            onClicked: EyeBreakService.skip()
        }
    }
}
