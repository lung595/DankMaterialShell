import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import "../../../Common/IslandKit.js" as Kit

// The eye break's eye, drawn in its icon box: lids that really shut (lashes show and curl as they meet), an iris that
// darts to random points, mostly far off, and rests there a while, the upper lid following it. Blinks every few
// seconds, sometimes twice. Runs only while shown; reduce motion, or no animations, keeps it open, still, centred.
Item {
    id: eye

    property real size: Theme.iconSize
    property color color: Theme.primary

    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    readonly property bool live: eye.visible && !eye.still
    readonly property int base: Theme.currentAnimationBaseDuration

    // 0 open .. 1 shut.
    property real blink: 0
    // Gaze, -1..1 each way, y down.
    property real gazeX: 0
    property real gazeY: 0

    // Lids: two arcs between the corners, peaking at `upper` / `lower` from the middle line (negative up). Shut, both
    // meet on a line that sags a little: the upper lid travels, the lower one barely rises.
    readonly property real stroke: Math.max(1, Math.round(eye.size / 12))
    readonly property real half: eye.size * 0.4
    readonly property real peak: eye.size * 0.28
    readonly property real sag: eye.size * 0.1
    readonly property real mid: eye.size / 2
    readonly property real irisRadius: eye.size * 0.19
    readonly property real irisX: eye.mid + eye.gazeX * (eye.half - eye.irisRadius - eye.stroke)
    // How far the gaze moves the iris up or down, and the pupil's share of the iris.
    readonly property real gazeLift: eye.size * 0.08
    readonly property real pupilShare: 0.42
    readonly property real irisY: eye.mid + eye.gazeY * eye.gazeLift
    readonly property real upper: eye.sag + (0.5 * (eye.irisY - eye.mid) - eye.peak - eye.sag) * (1 - eye.blink)
    readonly property real lower: eye.sag + (eye.peak - eye.sag) * (1 - eye.blink)
    // Lashes come out over the last part of the blink.
    readonly property real lashes: Math.max(0, (eye.blink - 0.5) / 0.5)
    // Three lashes off the upper lid, the middle one and a pair mirrored at a quarter of its width from the corners;
    // the right one hangs along the lid's downward normal there and its tip fans outward as it grows, so it curls.
    readonly property real lashLength: eye.size * 0.16 * eye.lashes
    readonly property real lashSlope: eye.upper / eye.half
    readonly property real lashNorm: Math.sqrt(1 + eye.lashSlope * eye.lashSlope)
    readonly property real lashY: eye.mid + 0.75 * eye.upper
    readonly property real lashBendX: eye.lashSlope / eye.lashNorm * eye.lashLength * 0.6
    readonly property real lashTipX: (eye.lashSlope / eye.lashNorm + 0.4 * eye.lashes) * eye.lashLength
    readonly property real lashDrop: eye.lashLength / eye.lashNorm

    // A lid's height at x (a parabola through both corners).
    function lidAt(p, x) {
        const t = (x - eye.mid + eye.half) / (2 * eye.half);
        return eye.mid + 4 * p * t * (1 - t);
    }

    // A saccade (from → to) and a blink each run on the eye's own clock (ms into them, -1 when none plays).
    property real fromX: 0
    property real fromY: 0
    property real toX: 0
    property real toY: 0
    property real gazeMs: -1
    property real blinkMs: -1
    property int blinkLoops: 1

    function glance() {
        const g = Kit.eyeGlance(Math.random(), Math.random(), Math.random(), Math.random());
        eye.fromX = eye.gazeX;
        eye.fromY = eye.gazeY;
        eye.toX = g.x;
        eye.toY = g.y;
        eye.gazeMs = 0;
        gazeTimer.interval = Kit.beatIn(g.far ? "fixFar" : "fixNear", Math.random(), eye.base);
    }

    function blinkNow() {
        eye.blinkLoops = Math.random() < Kit.eyeTwiceShare ? 2 : 1;
        eye.blinkMs = 0;
        blinkTimer.interval = Kit.beatIn("blinkGap", Math.random(), eye.base);
    }

    width: eye.size
    height: eye.size

    onLiveChanged: {
        eye.gazeMs = -1;
        eye.blinkMs = -1;
        eye.blink = 0;
        eye.gazeX = 0;
        eye.gazeY = 0;
        gazeTimer.interval = Kit.beatIn("fixNear", Math.random(), eye.base);
        blinkTimer.interval = Kit.beatIn("blinkGap", Math.random(), eye.base);
    }

    // One clock for both, running only while one plays (a glance or a blink, a fraction of a second); the eye is redrawn
    // every few screen refreshes, as fast as it moves, once its lids or its iris moved half a pixel.
    FrameAnimation {
        id: pacer

        property real since: 0
        // The screen's refresh as measured, the refreshes since the last frame, and how many apart frames are drawn.
        property real refresh: 60
        readonly property real screenHz: Kit.screenRefresh(NiriService.outputs, eye.Screen.name)
        property real ticks: 0
        property int every: 0

        running: eye.live && (eye.gazeMs >= 0 || eye.blinkMs >= 0) && (eye.Window.window?.visible ?? false)
        onRunningChanged: {
            pacer.since = 0;
            pacer.ticks = 0;
        }
        onTriggered: {
            const ms = pacer.frameTime * 1000;
            pacer.since += pacer.frameTime;
            pacer.refresh = pacer.screenHz || Kit.refreshFrom(pacer.refresh, pacer.frameTime);
            pacer.ticks += pacer.frameTime * pacer.refresh;
            let gx = eye.gazeX, gy = eye.gazeY, b = eye.blink;
            if (eye.gazeMs >= 0) {
                eye.gazeMs += ms;
                const len = Kit.beat("saccade", eye.base);
                const c = Theme.expressiveCurves.emphasizedDecel;
                const p = eye.gazeMs >= len ? 1 : Kit.bezier(c[0], c[1], c[2], c[3], eye.gazeMs / len);
                gx = eye.fromX + (eye.toX - eye.fromX) * p;
                gy = eye.fromY + (eye.toY - eye.fromY) * p;
                if (p >= 1)
                    eye.gazeMs = -1;
            }
            if (eye.blinkMs >= 0) {
                eye.blinkMs += ms;
                const v = Kit.eyeBlinkAt(eye.blinkMs, eye.base, eye.blinkLoops, Theme.expressiveCurves.standardAccel, Theme.expressiveCurves.standard);
                b = Math.max(0, v);
                if (v < 0)
                    eye.blinkMs = -1;
            }
            const moved = Math.max(Math.abs(gx - eye.gazeX) * eye.half, Math.abs(gy - eye.gazeY) * eye.gazeLift, Math.abs(b - eye.blink) * eye.peak);
            const every = Kit.framesBetween(pacer.refresh, moved / pacer.since, pacer.every);
            // The last step always lands, so the eye rests exactly where it went.
            if ((eye.gazeMs >= 0 || eye.blinkMs >= 0) && !Kit.cadenceDue(pacer.ticks, every, moved))
                return;
            pacer.every = every;
            pacer.ticks = Kit.cadenceCarry(pacer.ticks, every);
            pacer.since = 0;
            eye.gazeX = gx;
            eye.gazeY = gy;
            eye.blink = b;
        }
    }

    Timer {
        id: gazeTimer

        running: eye.live
        repeat: true
        onTriggered: eye.glance()
    }

    Timer {
        id: blinkTimer

        running: eye.live
        repeat: true
        onTriggered: eye.blinkNow()
    }

    // The iris (a disc, its pupil a hole), clipped to the opening above and below its centre: the lid strokes, drawn
    // over it, hide what pokes past the curve on its sides.
    Item {
        x: eye.mid - eye.half
        width: 2 * eye.half
        y: eye.lidAt(eye.upper, eye.irisX)
        height: Math.max(0, eye.lidAt(eye.lower, eye.irisX) - y)
        clip: true

        Shape {
            x: eye.irisX - eye.irisRadius - parent.x
            y: eye.irisY - eye.irisRadius - parent.y
            width: 2 * eye.irisRadius
            height: width
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: eye.color
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathAngleArc {
                    centerX: eye.irisRadius
                    centerY: eye.irisRadius
                    radiusX: eye.irisRadius
                    radiusY: eye.irisRadius
                    sweepAngle: 360
                }
                PathAngleArc {
                    moveToStart: true
                    centerX: eye.irisRadius
                    centerY: eye.irisRadius
                    radiusX: eye.irisRadius * eye.pupilShare
                    radiusY: eye.irisRadius * eye.pupilShare
                    sweepAngle: 360
                }
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: eye.color
            strokeWidth: eye.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: eye.mid - eye.half
            startY: eye.mid

            PathQuad {
                x: eye.mid + eye.half
                y: eye.mid
                controlX: eye.mid
                controlY: eye.mid + 2 * eye.upper
            }
            PathQuad {
                x: eye.mid - eye.half
                y: eye.mid
                controlX: eye.mid
                controlY: eye.mid + 2 * eye.lower
            }
        }
    }

    Shape {
        anchors.fill: parent
        visible: eye.lashes > 0
        opacity: eye.lashes
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: eye.color
            strokeWidth: Math.max(1, eye.stroke * 0.75)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: eye.mid - eye.half / 2
            startY: eye.lashY

            PathQuad {
                controlX: eye.mid - eye.half / 2 - eye.lashBendX
                controlY: eye.lashY + eye.lashDrop * 0.6
                x: eye.mid - eye.half / 2 - eye.lashTipX
                y: eye.lashY + eye.lashDrop
            }
            PathMove {
                x: eye.mid
                y: eye.mid + eye.upper
            }
            PathLine {
                x: eye.mid
                y: eye.mid + eye.upper + eye.lashLength
            }
            PathMove {
                x: eye.mid + eye.half / 2
                y: eye.lashY
            }
            PathQuad {
                controlX: eye.mid + eye.half / 2 + eye.lashBendX
                controlY: eye.lashY + eye.lashDrop * 0.6
                x: eye.mid + eye.half / 2 + eye.lashTipX
                y: eye.lashY + eye.lashDrop
            }
        }
    }
}
