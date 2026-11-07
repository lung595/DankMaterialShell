pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Kit category: state badge (a pill's corner: microphone cut, deafened).
// The small icon alone, never on a filled dot: a thin rim of the surface under it (four hairline-offset copies) keeps it
// readable on any app icon.
Item {
    id: root

    property string name: "mic_off"
    property color color: Theme.error
    // The surface under the badge, for its rim.
    property color rimColor: Theme.surfaceContainer
    property real size: Theme.iconSizeSmall

    implicitWidth: root.size
    implicitHeight: root.size
    // The caller names the state through I18n.tr() (Accessible.name): an icon's ligature is no name.
    Accessible.role: Accessible.Indicator

    Repeater {
        model: [[-1, 0], [1, 0], [0, -1], [0, 1]]

        DIcon {
            id: rim

            required property var modelData

            x: rim.modelData[0] * Theme.spacingXXS / 2
            y: rim.modelData[1] * Theme.spacingXXS / 2
            name: root.name
            size: root.size
            filled: true
            color: root.rimColor
        }
    }

    DIcon {
        name: root.name
        size: root.size
        filled: true
        color: root.color
        Accessible.ignored: true
    }
}
