import QtQuick
import qs.Common
import qs.DCommon.Widgets

// A finished download: the file falls into a Material shape (DMS's slow spatial motion, landing past and back), and the shape
// morphs from round to cookie as it lands. "Reduce motion" shows it landed at once. Plays once, at creation.
Item {
    id: glyph

    property real size: Theme.iconSize * 2.6
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    // 0: the file above, 1: landed.
    property real fall: glyph.still ? 1 : 0

    implicitWidth: glyph.size
    implicitHeight: glyph.size
    clip: true

    Accessible.role: Accessible.Graphic
    Accessible.name: I18n.tr("Download finished", "island download bubble: the falling file glyph")

    NumberAnimation on fall {
        running: !glyph.still
        to: 1
        duration: Theme.expressiveDurations.expressiveSlowSpatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveSlowSpatial
    }

    DMaterialShape {
        anchors.fill: parent
        shape: glyph.fall > 0.85 ? "cookie9" : "circle"
        color: Theme.primaryContainer
        scale: 0.86 + 0.14 * Math.min(1, glyph.fall * 1.2)
    }

    DIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 - (1 - glyph.fall) * parent.height
        name: "draft"
        size: glyph.size * 0.5
        color: Theme.onPrimaryContainer
        opacity: Math.min(1, glyph.fall * 3)
    }
}
