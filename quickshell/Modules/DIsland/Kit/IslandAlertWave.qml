pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../../Common/IslandKit.js" as Kit

// Kit category: alert. Rings of the alert's colour leaving a shape and fading: an alert bubble's wave (one), an important
// info in the island (two, like a phone ringing), a ringing call (two, again after a pause, until stop()) whose shape
// rocks on each ring (swing, -1..1). Centred on the shape; one clock (IslandKit.ringT / ringSwing) pushed at the kit's
// cadence (every few screen refreshes, as fast as its rings or its swing move) and only while something moves; once
// over or stopped nothing runs. Reduced motion or speed 0: nothing.
Item {
    id: root

    // The shape's diameter the rings leave from, and how many times its size they reach.
    property real base: 0
    property real reach: 2.6
    property int rings: 1
    // 0: rings again after each pause until stop().
    property int cycles: 1
    property bool ringsShown: true
    property color color: Theme.error
    property real stroke: Theme.outlineWidthFocused * 2
    // The spring the shape swings back on, [stiffness, damping ratio, mass]; none: no swing.
    property var spring: null
    // A ring lasts and weighs twice a slow spatial step, so it reads at the default speed.
    readonly property int span: Theme.expressiveDurations.expressiveSlowSpatial * 2
    readonly property int gap: Kit.beat("ringGap", Theme.currentAnimationBaseDuration)
    readonly property int pause: Kit.beat("ringPause", Theme.currentAnimationBaseDuration)
    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    // The pushed clock (bindings read it at the kit's cadence) and the running one under it.
    property real ms: -1
    property real elapsed: -1
    property real since: 0
    property real swing: 0
    // The screen's refresh (its clock steps by it, and keeps the pushes' cadence).
    readonly property real refresh: root.screenHz || Kit.fallbackHz
    readonly property real screenHz: Kit.screenRefresh(NiriService.outputs, root.Screen.name)
    readonly property bool running: root.elapsed >= 0

    function play() {
        if (root.still)
            return;
        root.elapsed = 0;
        root.since = 0;
        ringClock.resetCadence();
        root.ms = 0;
        root.swing = 0;
    }

    function stop() {
        root.elapsed = -1;
        root.ms = -1;
        root.swing = 0;
    }

    width: root.base * root.reach
    height: width

    Repeater {
        model: root.rings

        Rectangle {
            id: ring

            required property int index
            readonly property real t: Kit.ringT(root.ms, root.span, root.gap, root.rings, root.pause, root.cycles, ring.index)
            readonly property var c: Theme.expressiveCurves.expressiveEffects
            readonly property real eased: Kit.bezier(ring.c[0], ring.c[1], ring.c[2], ring.c[3], ring.t)

            anchors.centerIn: parent
            width: root.base + (root.width - root.base) * ring.eased
            height: ring.width
            radius: ring.width / 2
            color: "transparent"
            border.width: root.stroke
            border.color: Theme.withAlpha(root.color, 1 - ring.eased)
            visible: root.ringsShown && ring.t < 1
        }
    }

    IslandClock {
        id: ringClock

        refresh: root.refresh
        running: root.running && root.visible && (root.Window.window?.visible ?? false)
        onTick: dt => {
            root.elapsed += dt * 1000;
            root.since += dt;
            if (Kit.ringsOver(root.elapsed, root.span, root.gap, root.rings, root.pause, root.cycles)) {
                root.stop();
                return;
            }
            const local = root.elapsed % Kit.ringCycle(root.span, root.gap, root.rings, root.pause);
            const swing = root.spring ? Kit.ringSwing(root.elapsed, root.span, root.gap, root.rings, root.pause, root.cycles, root.spring[0], root.spring[1], root.spring[2]) : 0;
            // In the pause, once the last ring is gone and the swing has settled, nothing moves: nothing is pushed.
            const ringing = local < root.span + (root.rings - 1) * root.gap || Kit.ringT(root.ms, root.span, root.gap, root.rings, root.pause, root.cycles, root.rings - 1) < 1;
            const tip = Math.abs(swing - root.swing) * Kit.ringTilt * Math.PI / 180 * root.base / 2;
            const rocking = tip >= 0.5;
            // How fast it moves since the last push: the swing's tip, or a ring's edge.
            const c = Theme.expressiveCurves.expressiveEffects;
            let moved = tip;
            for (let i = 0; i < root.rings; i++) {
                const from = Kit.bezier(c[0], c[1], c[2], c[3], Kit.ringT(root.ms, root.span, root.gap, root.rings, root.pause, root.cycles, i));
                const to = Kit.bezier(c[0], c[1], c[2], c[3], Kit.ringT(root.elapsed, root.span, root.gap, root.rings, root.pause, root.cycles, i));
                moved = Math.max(moved, Math.abs(to - from) * (root.width - root.base) / 2);
            }
            if (!ringClock.due(ringClock.framesFor(moved / root.since), ringing || rocking ? 1 : 0))
                return;
            root.since = 0;
            root.ms = root.elapsed;
            root.swing = swing;
        }
    }
}
