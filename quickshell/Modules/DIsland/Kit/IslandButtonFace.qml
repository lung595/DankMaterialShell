pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Kit category: every button. IslandButton's face, its icon (or spinner, or drawn check) and label: drawn once above the
// liquid's mean line and once, inverted, under it.
Row {
    id: faceRow

    // The button it draws for, and its icon's pop (the button's spring).
    required property var button
    property real iconScale: 1

    property color ink: faceRow.button.inkColor
    readonly property real labelWidth: label.implicitWidth
    // What an icon (or the spinner) takes beside the label.
    readonly property real iconRoom: Theme.iconSizeMedium + faceRow.spacing
    // Icon and label at full size: the button's own width when no row sizes it (the label's width follows the button's).
    readonly property real naturalWidth: faceRow.labelWidth + (faceRow.button.shownIcon !== "" || faceRow.button.busy ? faceRow.iconRoom : 0)
    // The width the button leaves its face, inside its padding and its key hints.
    readonly property real room: faceRow.button.width - faceRow.button.keyRoom - Theme.spacingS * 2
    // Too narrow for icon and label (Hang up in its 2 parts): the label wins, the icon goes.
    readonly property bool cramped: !faceRow.button.iconOnly && faceRow.labelWidth + faceRow.iconRoom > faceRow.room

    // Right to left, StyledButton's inherited LayoutMirroring flips the row (setting layoutDirection too undid it).
    spacing: Theme.spacingS

    // The success check is drawn left to right: a clip that sweeps open over the glyph.
    Item {
        visible: faceRow.button.shownIcon !== "" && !faceRow.button.busy && !faceRow.cramped
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSizeMedium
        height: Theme.iconSizeMedium
        scale: faceRow.iconScale

        Item {
            width: parent.width * (faceRow.button.feedback === "success" ? faceRow.button._checkProgress : 1)
            height: parent.height
            clip: width < parent.width

            DIcon {
                name: faceRow.button.shownIcon
                size: Theme.iconSizeMedium
                color: faceRow.ink
            }
        }
    }

    Loader {
        active: faceRow.button.busy
        visible: active
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSizeMedium
        height: Theme.iconSizeMedium
        sourceComponent: DSpinner {
            size: Theme.iconSizeMedium
            strokeWidth: Theme.outlineWidthFocused
            color: faceRow.ink
            running: faceRow.button.busy && faceRow.button.visible
            Accessible.ignored: true
        }
    }

    StyledText {
        id: label

        visible: !faceRow.button.iconOnly
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Math.max(0, faceRow.room - ((faceRow.button.shownIcon !== "" && !faceRow.cramped) || faceRow.button.busy ? faceRow.iconRoom : 0)))
        text: faceRow.button.shownText
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: faceRow.ink
    }
}
