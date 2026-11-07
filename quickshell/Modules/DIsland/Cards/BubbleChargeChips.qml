pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandKit.js" as Kit
import "../../../Common/IslandCharge.js" as Charge

// The charge face's three chips (his mockup B of 29/10): time left, full at, the session's gain once a minute old, the
// source's texts by key (the model stays, only the texts move); each arrives in turn on the island's growth, pieces
// `from` to `from + 2` of `pieces` (IslandCharge.revealAt); too wide for the row, they wrap, their text never past
// `textWidth` (elided).
Flow {
    id: chips

    required property var charge
    required property real grow
    required property bool still
    required property int from
    required property int pieces
    required property real chipHeight
    required property real chipPad
    required property real textWidth

    spacing: Theme.spacingS

    Repeater {
        model: [
            {
                "icon": "timer",
                "key": "leftText",
                "name": I18n.tr("%1 left", "island charge face: accessible name of the time left chip")
            },
            {
                "icon": "battery_full",
                "key": "fullAtText",
                "name": I18n.tr("Battery %1", "island charge face: accessible name of the full at chip, the chip's own text")
            },
            {
                "icon": "trending_up",
                "key": "gainText",
                "name": I18n.tr("Gained %1", "island charge face: accessible name of the session's gain chip")
            }
        ]

        Rectangle {
            id: chip

            required property int index
            required property var modelData
            readonly property string label: chips.charge?.[chip.modelData.key] ?? ""
            readonly property real r: chips.still ? 1 : Charge.revealAt(chips.grow, chips.from + chip.index, chips.pieces)

            width: Theme.iconSizeSmall + Theme.spacingXS + chipLabel.width + chips.chipPad
            height: chips.chipHeight
            radius: Theme.cornerRadiusS
            color: "transparent"
            border.width: Theme.outlineWidth
            border.color: Theme.outlineVariant
            visible: chip.label !== ""
            opacity: chip.r
            Accessible.role: Accessible.StaticText
            Accessible.name: chip.modelData.name.arg(chip.label)
            transform: Translate {
                y: (1 - chip.r) * Theme.spacingS
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: chip.modelData.icon
                    size: Theme.iconSizeSmall
                    // 3:1 on the island.
                    color: Kit.legible(Theme.primary, Theme.surfaceText, Theme.hostSurface, 1, Kit.legibleMin)
                }
                StyledText {
                    id: chipLabel

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(chipLabel.implicitWidth, chips.textWidth)
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    text: chip.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    font.features: {
                        "tnum": 1
                    }
                    color: Theme.surfaceText
                }
            }
        }
    }
}
