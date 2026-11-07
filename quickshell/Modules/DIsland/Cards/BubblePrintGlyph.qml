import QtQuick
import qs.Common

// Printing bubble's pill (source "print"): a sheet slides out of the printer's tray on each new page, once, then rests
// hidden (no loop). Reduced motion: no sheet.
Item {
    id: root

    property var bubble: null
    property color sheetColor: Theme.primary

    readonly property bool printing: root.bubble?.source === "print" && root.bubble?.kind === "printing"
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    readonly property int page: root.printing ? (root.bubble.page ?? 0) : -1

    visible: root.printing && sheet.opacity > 0
    onPageChanged: {
        if (root.printing && !root.still)
            slide.restart();
    }
    Component.onCompleted: root.pageChanged()

    Rectangle {
        id: sheet

        width: Math.round(root.width * 0.42)
        height: Math.round(root.height * 0.3)
        x: (root.width - width) / 2
        y: root.height * 0.55
        radius: Math.min(Theme.cornerRadius, height / 4)
        color: root.sheetColor
        opacity: 0
    }

    SequentialAnimation {
        id: slide

        PropertyAction {
            target: sheet
            property: "y"
            value: root.height * 0.55
        }
        PropertyAction {
            target: sheet
            property: "opacity"
            value: 1
        }
        ParallelAnimation {
            NumberAnimation {
                target: sheet
                property: "y"
                to: root.height * 0.95
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
            NumberAnimation {
                target: sheet
                property: "opacity"
                to: 0
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.standardAccel
            }
        }
    }
}
