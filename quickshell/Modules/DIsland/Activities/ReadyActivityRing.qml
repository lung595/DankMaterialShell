import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.DCommon.Widgets

// Icon inside a progress ring; without progress it is the bare icon.
Item {
    id: root

    property string iconName: ""
    property real progress: -1
    property color accent: Theme.primary
    property color iconColor: root.accent
    // The ring's stroke; the item is the icon plus two strokes of margin on each side.
    property real ringWidth: 3
    property real iconSize: root.progress >= 0 ? Theme.iconSizeSmall : Theme.iconSize
    // The track under the level, faint enough to read as empty.
    readonly property real trackAlpha: 0.25

    implicitWidth: Theme.iconSize + root.ringWidth * 4
    implicitHeight: implicitWidth

    Shape {
        anchors.fill: parent
        visible: root.progress >= 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(root.accent, root.trackAlpha)
            strokeWidth: root.ringWidth

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.ringWidth) / 2
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.accent
            strokeWidth: root.ringWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.ringWidth) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * Math.max(0, root.progress)
            }
        }
    }

    DIcon {
        anchors.centerIn: parent
        visible: root.iconName !== ""
        name: root.iconName
        size: root.iconSize
        color: root.iconColor
    }
}
