pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit

// The disk card's key hints (BubbleCardDisk), always in sight: what the arrows, Enter, Backspace / Escape and Del do
// in the shown tab.
Flow {
    id: hints

    required property BubbleCardDisk card

    width: parent.width
    visible: !card.cleanupOpen
    spacing: Theme.spacingS

    Repeater {
        model: [{
                "keys": ["←", "↑", "↓", "→"],
                "text": I18n.tr("Move", "island disk card: arrow keys")
            }, {
                "keys": ["↵"],
                "text": I18n.tr("Open", "island disk card: Enter goes into the folder")
            }, {
                "keys": ["⌫"],
                "text": I18n.tr("Up", "island disk card: Backspace goes to the parent folder")
            }]

        Row {
            id: hint

            required property var modelData

            spacing: Theme.spacingXXS

            Repeater {
                model: hint.modelData.keys

                DKeycap {
                    required property string modelData

                    text: modelData
                }
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Theme.spacingXXS
                text: hint.modelData.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
