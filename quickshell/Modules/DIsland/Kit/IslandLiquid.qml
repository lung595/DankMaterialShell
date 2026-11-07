pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Services
import "../../../Common/IslandKit.js" as Kit

// Kit category: liquid meter (hold to confirm fills it, undo countdown drains it).
// The volume bubble's live liquid, risen from the bottom of a tile: it follows its level on Interior's FILL spring, its front
// is the volume's mirrored wave (IslandKit.wave), raised by the level's speed and carried by its travel, so it slops while it
// fills or drains and lies flat once it settles. Cut to the host's corners. Drawn only while it holds liquid.
Item {
    id: liquid

    // 0..1, where the liquid is heading.
    property real level: 0
    property color color: Theme.primary
    // The host tile's corner radius.
    property real radius: 0
    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    // The mean line of the front, from the top.
    readonly property real line: liquid.height * (1 - Math.max(0, Math.min(1, fill.value)))
    // A live wave (the charge's pill while it charges):{amp: its height in pixels, rate: its pace in
    // radians a second}, set by the host, never higher than a sixth of the liquid; the front then never lies flat, its
    // phase pushed at the kit's cadence once a crest moved half a pixel (IslandWaveProgress). null: only the fill's own
    // slosh, nothing at rest.
    property var wave: null
    readonly property real liveAmp: Math.min(liquid.height / 6, liquid.wave?.amp ?? 0)
    readonly property real liveRate: liquid.wave?.rate ?? 0
    property real _livePhase: 0
    readonly property real amp: liquid.still ? 0 : Math.max(liquid.liveAmp, Math.min(Theme.spacingS, Math.abs(fill.velocity) * Theme.spacingM))
    readonly property real phase: fill.value * Math.PI * 4 + liquid._livePhase
    // The live wave's phase gone by since its last push.
    property real _livePending: 0
    readonly property real screenHz: Kit.screenRefresh(NiriService.outputs, liquid.Screen.name)

    // The live wave runs on the kit's decor clock (K7): pushed once a crest moved half a pixel, at most 60 times a second.
    IslandClock {
        id: liveClock

        refresh: liquid.screenHz || Kit.fallbackHz
        running: !liquid.still && liquid.liveAmp > 0 && liquid.liveRate > 0 && liquid.visible && (liquid.Window.window?.visible ?? false)
        onTick: dt => {
            liquid._livePending += liquid.liveRate * dt;
            if (!liveClock.due(liveClock.framesFor(liquid.liveAmp * liquid.liveRate), liquid.liveAmp * liquid._livePending))
                return;
            liquid._livePhase = (liquid._livePhase + liquid._livePending) % (2 * Math.PI);
            liquid._livePending = 0;
        }
    }

    // Five points across the front (d = 1, 0.5, 0, 0.5, 1) joined by cubics from the wave's slope: numbers only, no array
    // per frame.
    readonly property real quarter: liquid.width / 4
    readonly property real y0: liquid.line - Kit.wave(1, liquid.amp, liquid.phase)
    readonly property real y1: liquid.line - Kit.wave(0.5, liquid.amp, liquid.phase)
    readonly property real y2: liquid.line - Kit.wave(0, liquid.amp, liquid.phase)
    // dy/dx on the left half (d falls as x grows); the right half mirrors it.
    function slope(d) {
        return Kit.waveSlope(d, liquid.amp, liquid.phase) * 2 / Math.max(1, liquid.width);
    }
    readonly property real s0: liquid.slope(1)
    readonly property real s1: liquid.slope(0.5)
    readonly property real s2: liquid.slope(0)

    visible: fill.value > 0.001

    SpringMotion {
        id: fill

        readonly property var spec: Kit.spring("fill", Theme.currentAnimationBaseDuration)
        enabled: !liquid.still
        stiffness: spec.stiffness
        damping: spec.damping
        mass: spec.mass
        // Settles (and its frame loop stops) once the front is within half a pixel and its wave under half a pixel.
        positionEpsilon: 0.5 / Math.max(1, liquid.height)
        velocityEpsilon: 0.5 / Theme.spacingM
    }
    onLevelChanged: fill.retarget(Math.max(0, Math.min(1, liquid.level)))
    // A push from outside (a transfer's burst of speed), in levels per second: the liquid sloshes past and settles back.
    function kick(v) {
        if (liquid.still || !liquid.visible)
            return;
        fill.velocity = Math.max(-Kit.surgeMax, Math.min(Kit.surgeMax, fill.velocity + v));
        // SpringMotion starts only toward a new target (retarget): step off the target and back, so the kick plays out.
        const rest = fill.target;
        fill.target = rest + 1;
        fill.retarget(rest);
    }
    Component.onCompleted: fill.snapTo(Math.max(0, Math.min(1, liquid.level)))

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: liquid.radius
        color: "black"
        visible: false
        layer.enabled: liquid.visible
    }

    Shape {
        id: body

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: liquid.visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            // Soft mask edge instead of a stair-stepped cut.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        ShapePath {
            fillColor: liquid.color
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: liquid.height

            PathLine {
                x: 0
                y: liquid.y0
            }
            PathCubic {
                x: liquid.quarter
                y: liquid.y1
                control1X: liquid.quarter / 3
                control1Y: liquid.y0 + liquid.s0 * liquid.quarter / 3
                control2X: liquid.quarter * 2 / 3
                control2Y: liquid.y1 - liquid.s1 * liquid.quarter / 3
            }
            PathCubic {
                x: liquid.quarter * 2
                y: liquid.y2
                control1X: liquid.quarter * 4 / 3
                control1Y: liquid.y1 + liquid.s1 * liquid.quarter / 3
                control2X: liquid.quarter * 5 / 3
                control2Y: liquid.y2 - liquid.s2 * liquid.quarter / 3
            }
            PathCubic {
                x: liquid.quarter * 3
                y: liquid.y1
                control1X: liquid.quarter * 7 / 3
                control1Y: liquid.y2 - liquid.s2 * liquid.quarter / 3
                control2X: liquid.quarter * 8 / 3
                control2Y: liquid.y1 + liquid.s1 * liquid.quarter / 3
            }
            PathCubic {
                x: liquid.width
                y: liquid.y0
                control1X: liquid.quarter * 10 / 3
                control1Y: liquid.y1 - liquid.s1 * liquid.quarter / 3
                control2X: liquid.quarter * 11 / 3
                control2Y: liquid.y0 + liquid.s0 * liquid.quarter / 3
            }
            PathLine {
                x: liquid.width
                y: liquid.height
            }
        }
    }
}
