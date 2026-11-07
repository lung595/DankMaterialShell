pragma Singleton

import QtQuick

// The theme values the island's kit pieces read, at DMS's defaults.
QtObject {
    readonly property real spacingXS: 4
    readonly property real spacingS: 8
    readonly property real iconSizeSmall: 16
    readonly property real cornerRadiusS: 8
    readonly property real outlineWidth: 1
    readonly property real fontSizeSmall: 12
    readonly property int fontWeightMedium: Font.Medium
    readonly property color primary: "#d0bcff"
    readonly property color surfaceText: "#e6e0e9"
    readonly property color outlineVariant: "#49454f"
    readonly property color hostSurface: "#141218"
}
