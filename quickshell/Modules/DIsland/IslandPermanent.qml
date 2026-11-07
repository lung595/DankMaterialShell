pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Modules.SurfaceWidgets
import qs.Widgets

// shortcut: horizontal bars only, a vertical bar shows no permanent bubble; add a vertical layout if a plugin needs one.
// A plugin's bubble that always stays (IslandActivityService.setPermanent): small (a mini bubble, just its icon) beside
// the island on its side, floating with no outline. A file dragged over the bar swells it into a normal bubble that takes it, the jellyfish pulsing on that spring
// and drawing a ring in; an event on the same side shrinks it into a dot tucked at the bottom left corner of that event's
// bubble, like a badge, and it grows back in its place when the event leaves. After each move it drifts a few seconds, then
// rests. Its corners are the wings' (DMS's corner setting), scaled to its size.
// Three numbers on the island's own spring (as tuned by DMS) drive it all, so every change starts from what is on screen.
Item {
    id: perm

    required property var bubbles
    // The wing of the side it lives on: its event turns the bubble into a dot on that wing's corner.
    required property var wing

    // The entry this side shows (IslandActivityService.permanentOn), null while it leaves.
    required property var spec
    readonly property int side: perm.wing.side
    readonly property bool on: !!perm.spec && !perm.bubbles.isVertical && perm.bubbles.controller.bubblesEnabled
    readonly property bool receiving: perm.on && perm.spec.receiving === true
    readonly property bool tucked: perm.on && perm.wing.has
    readonly property var tone: perm.bubbles.toneOf("media")
    readonly property color glyphColor: perm.tone[1]

    readonly property real full: perm.bubbles.size
    readonly property real mini: perm.full * 0.72
    readonly property real dotSize: Math.round(perm.full * 0.3)

    // width = presence, height = growth for a drop, offsetCross = how far into the dot, all in springUnit.
    VectorSpringMotion {
        id: spring

        reducedMotion: perm.bubbles.reducedMotion
        mass: perm.bubbles.motion.mass
    }
    // Loaded with its entry: born from nothing on its spring, then it drifts, as when it comes back to rest.
    Component.onCompleted: {
        spring.snapTo(perm.target(false));
        perm.retarget();
        if (perm.resting && !perm.bubbles.reducedMotion)
            driftRun.restart();
    }
    function target(shown) {
        const u = perm.bubbles.springUnit;
        return {
            "width": shown && perm.on ? u : 0,
            "height": shown && perm.receiving && !perm.tucked ? u : 0,
            "offsetAlong": 0,
            "offsetCross": shown && perm.tucked ? u : 0,
            "topLeftRadius": 0,
            "topRightRadius": 0,
            "bottomLeftRadius": 0,
            "bottomRightRadius": 0
        };
    }
    // Same spring as a wing being born (the island's stiffness, softened, with its overshoot); shrinking into the dot is
    // fully damped so the badge lands clean.
    function retarget() {
        const b = perm.bubbles;
        const ratio = perm.tucked ? b.outDampingRatio : b.inDampingRatio;
        spring.stiffness = b.motion.stiffness * b.inStiffness;
        spring.damping = 2 * ratio * Math.sqrt(spring.stiffness * spring.mass);
        spring.setTarget(perm.target(true));
    }
    onOnChanged: perm.retarget()
    onReceivingChanged: perm.retarget()
    onTuckedChanged: perm.retarget()

    readonly property real presence: Math.max(0, spring.currentWidth / perm.bubbles.springUnit)
    readonly property real grow: spring.currentHeight / perm.bubbles.springUnit
    readonly property real dotness: perm.bubbles.clamp01(spring.currentOffsetCross / perm.bubbles.springUnit)
    // How fast it swells, a few units a second at the start of a drop; the jellyfish's pulse rides it.
    readonly property real growSpeed: spring.velocityHeight / perm.bubbles.springUnit

    // Drift (from concept B): one and a half slow loops that fade out, started by whatever brings it back to rest beside
    // the island, then nothing runs.
    property real drift: 1
    readonly property bool resting: perm.on && !perm.receiving && !perm.tucked
    onRestingChanged: {
        if (perm.resting && !perm.bubbles.reducedMotion)
            driftRun.restart();
    }
    NumberAnimation {
        id: driftRun

        target: perm
        property: "drift"
        from: 0
        to: 1
        duration: 5000 / Math.max(0.05, perm.bubbles.breathPace)
    }
    readonly property real driftFade: (1 - perm.drift) * (1 - perm.dotness) * perm.bubbles.clamp01(1 - perm.grow)
    readonly property real driftPhase: perm.drift * 3 * Math.PI
    // A small loop seen from above: away from the island and back (never into it), rising and dipping.
    readonly property real reach: Theme.spacingXS
    readonly property real driftAlong: perm.side * perm.reach * 0.5 * (1 - Math.cos(perm.driftPhase)) * perm.driftFade
    readonly property real driftCross: -perm.reach * 0.6 * Math.sin(perm.driftPhase) * perm.driftFade

    // At rest: beside the island's edge, where a wing of this side would start, one slit away, centered on the island's row.
    readonly property real restH: perm.bubbles.mix(perm.mini, perm.full, perm.grow)
    readonly property real restW: perm.bubbles.mix(perm.mini, perm.full + label.implicitWidth + Theme.spacingM, perm.grow)
    readonly property real leadEdge: Math.min(perm.bubbles.leadEdge, perm.bubbles.surface.currentAlongPos)
    readonly property real trailEdge: Math.max(perm.bubbles.trailEdge, perm.bubbles.surface.currentAlongPos + perm.bubbles.surface.currentVisualAlong)
    readonly property real restCx: (perm.side < 0 ? perm.leadEdge - perm.bubbles.slit - perm.restW / 2 : perm.trailEdge + perm.bubbles.slit + perm.restW / 2) + perm.driftAlong
    readonly property real restCy: perm.bubbles.crossOf(perm.bubbles.nearCross + perm.bubbles.rowOffset, perm.bubbles.size) + perm.bubbles.size / 2 + perm.driftCross

    // Tucked: on the outline of the event bubble's bottom left corner (45 degrees round its radius), following the wing's
    // birth scale (from half its size at the island's edge) so the dot rides the bubble as it grows.
    readonly property real wingScale: perm.bubbles.mix(0.5, 1, perm.bubbles.clamp01(perm.wing.presence))
    // Read only while tucked: at rest the corner has no say, and a wing not laid out yet has no radius.
    readonly property real cornerInset: perm.dotness > 0 ? perm.wing.radius * (1 - Math.SQRT1_2) : 0
    readonly property real cornerX: perm.wing.x + (perm.wing.side < 0 ? perm.wing.width : 0) + (perm.cornerInset - (perm.wing.side < 0 ? perm.wing.width : 0)) * perm.wingScale
    readonly property real cornerY: perm.wing.y + perm.wing.height / 2 + (perm.wing.height / 2 - perm.cornerInset) * perm.wingScale

    readonly property real h: perm.bubbles.mix(perm.restH, perm.dotSize, perm.dotness)
    readonly property real w: perm.bubbles.mix(perm.restW, perm.dotSize, perm.dotness)
    readonly property real cx: perm.bubbles.mix(perm.restCx, perm.cornerX, perm.dotness)
    readonly property real cy: perm.bubbles.mix(perm.restCy, perm.cornerY, perm.dotness)

    // Round when small (rest and dot); the wings' corner comes in as it swells for a file.
    readonly property real wingRadius: Math.min(perm.h / 2, perm.w / 2, perm.bubbles.pillRadius)
    readonly property real radius: perm.bubbles.mix(perm.h / 2, perm.wingRadius, perm.bubbles.clamp01(perm.grow) * (1 - perm.dotness))

    x: perm.cx - perm.w / 2
    y: perm.cy - perm.h / 2
    width: perm.w
    height: perm.h
    visible: perm.presence > 0.01
    opacity: perm.bubbles.clamp01(perm.presence * 1.5)
    scale: perm.bubbles.mix(0.5, 1, perm.bubbles.clamp01(perm.presence))

    // Drawn in: one ring closing on the bubble while it swells for a file, read from the same spring (gone at rest).
    Rectangle {
        readonly property real k: perm.bubbles.mix(1.7, 1, perm.bubbles.clamp01(perm.grow))
        anchors.centerIn: parent
        width: perm.w + perm.h * (k - 1)
        height: perm.h * k
        radius: perm.radius * k
        color: "transparent"
        border.width: 1.5
        border.color: perm.tone[0]
        opacity: (perm.receiving ? 0.5 : 0) * perm.bubbles.clamp01(4 * perm.grow * (1 - perm.grow)) * (1 - perm.dotness)
        visible: opacity > 0.01
    }

    // The capsule in the island's color, floating with no outline; as a dot it turns to the app's accent, ringed by the
    // island's color so it reads clean on the event bubble as on the wallpaper.
    Rectangle {
        anchors.fill: parent
        radius: perm.radius
        // A touch lighter than the island so it still reads on a dark wallpaper with no outline.
        color: Qt.tint(Qt.tint(perm.bubbles.color, Theme.withAlpha(Theme.surfaceText, 0.08)), Theme.withAlpha(perm.tone[0], perm.dotness))
        border.width: 1.5 * perm.bubbles.clamp01(2 * perm.dotness - 1)
        border.color: perm.bubbles.color
    }

    // The icon on its backdrop, as on a wing (corner one rim inside the capsule's); it goes as the bubble becomes a dot.
    Item {
        id: face

        readonly property real d: perm.h - 2 * perm.bubbles.rim
        x: (perm.side < 0 ? 0 : perm.w - perm.h) + perm.bubbles.rim
        y: perm.bubbles.rim
        width: face.d
        height: face.d
        opacity: perm.bubbles.clamp01(1 - 2.5 * perm.dotness)
        visible: opacity > 0.01

        // An app's icon backdrop stays round; only the bubble takes the wings' corners.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: perm.tone[0]
        }

        // The jellyfish: squeezed as the bubble starts to swell, then stretched, its tentacles reaching for the file while it
        // is held open; all from the growth spring, so it settles with it.
        Item {
            id: glyph

            readonly property real pulse: Math.max(-0.14, Math.min(0.14, 0.02 * perm.growSpeed))
            anchors.centerIn: parent
            width: face.d * 0.78
            height: width
            transform: Scale {
                origin.x: glyph.width / 2
                origin.y: 0
                xScale: 1 + glyph.pulse
                yScale: 1 - glyph.pulse + 0.12 * perm.bubbles.clamp01(perm.grow)
            }

            // The app's own icon, one colour, tinted like a wing's glyph.
            Image {
                id: appImage

                anchors.fill: parent
                sourceSize: Qt.size(64, 64)
                source: perm.spec?.image ?? ""
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: appImage
                colorization: 1
                colorizationColor: perm.glyphColor
                visible: appImage.status === Image.Ready
            }

            // Without an icon: the jellyfish drawn in a 24 px box.
            Shape {
                anchors.centerIn: parent
                width: 24
                height: 24
                scale: glyph.width / 24
                visible: appImage.status !== Image.Ready
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: perm.glyphColor
                    strokeColor: "transparent"
                    PathSvg {
                        path: "M3.5 12.5C3.5 7 7.3 3 12 3C16.7 3 20.5 7 20.5 12.5Q18.4 11.2 16.2 12.5Q14.1 11.2 12 12.5Q9.9 11.2 7.8 12.5Q5.6 11.2 3.5 12.5Z"
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: perm.glyphColor
                    strokeWidth: 1.8
                    capStyle: ShapePath.RoundCap
                    PathSvg {
                        path: "M7 14Q5.8 16.5 7 18.5Q8.2 20.5 7 22M12 14.5Q13.2 17 12 19Q10.8 21 12 22.5M17 14Q18.2 16.5 17 18.5Q15.8 20.5 17 22"
                    }
                }
            }
        }
    }

    // Only the swollen bubble says what it does with the file.
    StyledText {
        id: label

        x: perm.side < 0 ? perm.h + Theme.spacingXS : Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        text: perm.spec?.label ?? ""
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
        opacity: perm.bubbles.clamp01((perm.grow - 0.6) / 0.4) * (1 - perm.dotness)
        visible: opacity > 0.01
    }
}
