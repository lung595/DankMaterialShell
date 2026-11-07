import QtQuick
import QtQuick.Shapes
import qs.Common
import "../../Common/IslandKit.js" as Kit

// A thin infinity with a soft light running along it: "no known end". The loop is drawn once; the light is three dashes
// of falling width and rising strength sliding on it (dashOffset animations, no JS per frame). Left running it redrew
// every exposed window at 240/s for hours (K1: nothing runs at rest), so it only runs a few turns each time it is shown,
// then brakes from its own speed, lands on the crossing and lights the whole loop from there both ways (M26, stop of a
// continuous light): lit and still, "on, resting", and nothing runs any more. Reduced motion: that rested loop at once.
Item {
    id: root

    property color color: Theme.surfaceText
    // The loop's own line and its lit, rested line (alphas of color and glow).
    readonly property real loopAlpha: 0.35
    readonly property real restAlpha: 0.78
    property color glow: Theme.primary
    // DMS's animation speed, as the island's breath (IslandBubbles.breathPace); 0 = none.
    readonly property real pace: SettingsData.animationDuration > 0 ? SettingsData.specDefault("animationDuration") / SettingsData.animationDuration : 0
    readonly property var play: Kit.infinityRest(Kit.infinityTurns, Kit.infinitySweepMs, root.pace, SettingsData.reduceMotion, [core.dash / root.period, glowLight.dash / root.period, halo.dash / root.period])
    property bool playing: false
    // 0: the light runs; 1: the whole loop is lit, the rested glyph.
    property real spread: 1

    function show() {
        root.playing = false;
        root.spread = root.visible && root.play.turns > 0 ? 0 : 1;
        root.playing = root.visible && root.play.turns > 0;
    }

    onVisibleChanged: root.show()
    Component.onCompleted: root.show()

    // One figure eight in a 24 x 12 box, crossing at its centre so the light keeps going the same way.
    readonly property string loop: "M 12 6 C 9 1.5 3 1.5 3 6 C 3 10.5 9 10.5 12 6 C 15 1.5 21 1.5 21 6 C 21 10.5 15 10.5 12 6 Z"
    readonly property size unit: Qt.size(root.width / 24, root.height / 12)
    readonly property real stroke: Math.max(1, root.height / 8)
    // The loop's length (48.85 box units) in base strokes: a dash pattern of this period loops seamlessly.
    readonly property real period: 48.85 * root.unit.width / root.stroke
    // The lit part of the loop, as a share either side of the crossing: the core's own length, then the whole loop.
    readonly property real reach: core.dash / root.period / 2 + (0.5 - core.dash / root.period / 2) * root.spread

    // The loop lights up from the crossing (where the light has landed) both ways; the light stays dashOffset only,
    // and the lit loop is cut by trim, so no dash pattern is rebuilt per frame.
    SequentialAnimation {
        running: root.playing
        onFinished: root.playing = false

        PauseAnimation {
            duration: root.play.spreadAtMs
        }
        NumberAnimation {
            target: root
            property: "spread"
            from: 0
            to: 1
            duration: root.play.spreadMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Kit.infinityOutCurve
        }
    }

    // One layer of the light; its dash pattern counts in its own stroke widths (k base strokes).
    component Light: ShapePath {
        id: light

        property real k: 1
        property real alpha: 1
        property real dash: 4
        property int layer: 0
        readonly property real period: root.period / light.k
        readonly property var steps: root.play.layers[light.layer] ?? {
            "runMs": 0,
            "brakeMs": 0
        }

        scale: root.unit
        strokeColor: Theme.withAlpha(root.glow, light.alpha)
        strokeWidth: root.stroke * light.k
        strokeStyle: ShapePath.DashLine
        dashPattern: [light.dash / light.k, light.period - light.dash / light.k]
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathSvg {
            path: root.loop
        }

        // Full speed from the start of the loop (turns x period is the sweep's own start), then the brake that lands the
        // dash centred on the crossing.
        SequentialAnimation on dashOffset {
            running: root.playing

            NumberAnimation {
                from: root.play.turns * light.period
                to: light.period * (root.play.turns - light.steps.runMs / Math.max(1, root.play.sweepMs))
                duration: light.steps.runMs
            }
            NumberAnimation {
                to: light.dash / light.k / 2
                duration: light.steps.brakeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Kit.infinityBrakeCurve
            }
        }
    }

    width: 2 * root.height

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            scale: root.unit
            strokeColor: Theme.withAlpha(root.color, root.loopAlpha)
            strokeWidth: root.stroke
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.loop
            }
        }
    }

    // The lit loop: whole once rested, so its ends do not overlap on the crossing.
    Shape {
        anchors.fill: parent
        visible: root.spread > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            scale: root.unit
            strokeColor: Theme.withAlpha(root.glow, root.restAlpha)
            strokeWidth: root.stroke
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            trim.start: 0
            trim.end: root.spread < 1 ? 2 * root.reach : 1
            trim.offset: root.spread < 1 ? -root.reach : 0

            PathSvg {
                path: root.loop
            }
        }
    }

    // The light fades into the lit loop as it spreads; gone at rest.
    Shape {
        anchors.fill: parent
        opacity: 1 - root.spread
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer

        // Halo, glow, core: the light's three dashes, widest and faintest first (alpha, dash length in loop units).
        Light {
            id: halo
            k: 3
            alpha: 0.18
            dash: 9
            layer: 2
        }
        Light {
            id: glowLight
            k: 2
            alpha: 0.4
            dash: 6
            layer: 1
        }
        Light {
            id: core
            k: 1
            alpha: 1
            dash: 4
            layer: 0
        }
    }
}
