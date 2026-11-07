pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "../../../Common/IslandArrival.js" as Arrival
import "../../../Common/IslandKit.js" as Kit

// Kit category: page dots (a burst in the island, the infos waiting behind a bubble). Five at most, the row slides and the
// dots at a hidden end shrink; the shown page's dot is long and, with a countdown, fills (UIPageControlTimerProgress).
Item {
    id: root

    property int count: 0
    property int index: 0
    // IslandArrival countdown state, or null for plain dots.
    property var countdown: null
    property bool reducedMotion: false
    signal picked(int index)

    readonly property real dot: Theme.spacingXS + Theme.spacingXXS
    readonly property real gap: Theme.spacingXS
    readonly property real longDot: root.countdown ? Theme.spacingL + Theme.spacingXS : Theme.spacingM + Theme.spacingXXS
    readonly property var layout: Arrival.pager(root.count, root.index)
    readonly property int beat: root.reducedMotion ? 0 : Kit.beat("pop", Theme.currentAnimationBaseDuration)
    property real fill: 0

    implicitHeight: root.dot
    implicitWidth: row.implicitWidth

    // Steps of half a pixel of the dot at most, and nothing ticks once it is full, or empty and frozen.
    function sample() {
        if (!root.countdown) {
            root.fill = 0;
            return false;
        }
        const now = Date.now();
        root.fill = Arrival.shown(root.fill, Arrival.fill(root.countdown, now), root.longDot);
        return Arrival.ticking(root.countdown, now) && root.fill < 1;
    }
    onCountdownChanged: ticker.running = root.visible && root.sample()
    onVisibleChanged: ticker.running = root.visible && root.sample()

    // One step a quantum (half a pixel of the dot), timed from the countdown (IslandArrival.stepMs): no image is asked
    // between two steps.
    Timer {
        id: ticker

        repeat: true
        interval: root.countdown ? Arrival.stepMs(root.countdown, root.longDot) : 1000
        onTriggered: {
            if (!root.sample())
                ticker.stop();
        }
    }

    property int lastCount: 0
    onCountChanged: {
        if (root.count > root.lastCount && root.lastCount > 0 && root.beat > 0)
            popIn.restart();
        root.lastCount = root.count;
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: root.count

            Item {
                id: cell

                required property int index
                readonly property string kind: root.layout.dots[cell.index] ?? "gone"
                readonly property bool on: cell.kind === "on"
                readonly property bool gone: cell.kind === "gone"
                readonly property real size: cell.kind === "edge" ? root.dot - Theme.spacingXXS : root.dot

                width: cell.gone ? 0 : (cell.on ? root.longDot : cell.size) + root.gap
                height: root.dot
                opacity: cell.gone ? 0 : 1
                scale: cell.index === root.count - 1 ? popIn.scale : 1

                Behavior on width {
                    NumberAnimation {
                        duration: root.beat
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: track

                    anchors.centerIn: parent
                    width: parent.width - root.gap
                    height: cell.size
                    radius: height / 2
                    color: cell.on && !root.countdown ? Theme.primary : Theme.withAlpha(Theme.surfaceText, cell.on ? 0.25 : 0.4)

                    Rectangle {
                        visible: cell.on && !!root.countdown
                        width: track.width * root.fill
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -root.gap
                    enabled: !cell.gone && !cell.on
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(cell.index)
                }
            }
        }
    }

    QtObject {
        id: popIn

        property real scale: 1

        function restart() {
            anim.restart();
        }

        property NumberAnimation anim: NumberAnimation {
            target: popIn
            property: "scale"
            from: 0.4
            to: 1
            duration: root.beat
            easing.type: Easing.OutBack
        }
    }
}
