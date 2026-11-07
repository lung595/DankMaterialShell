import QtQuick
import qs.Common
import qs.Services
import "../../../Common/IslandKit.js" as Kit

// Kit category: animation (the weather alert: its bubble's shape, and the whole island while it shows the alert): rain,
// hail, a storm, snow, fog or heat by force (level 0..3), the validated mockup's painters in one shader (weather.frag),
// its particles pure functions of the clock, so a frame only sets uniforms (nothing allocated). The clock runs at DMS's
// animation speed, pushed at the kit's cadence (every few screen refreshes, as its fastest particle needs), only while it
// shows; it eases out to nothing and stops. Reduced motion or speed 0: nothing drawn.
// K6: a decor that picks its own cadence on the kit's clock (K1: nothing runs at rest); C30: its shader.
Item {
    id: fx

    // "rain" | "hail" | "storm" | "snow" | "fog" | "heat", "" for none.
    property string event: ""
    property int level: 0
    // How strongly it shows (0 = gone); it eases there on the theme's effects curve.
    property real strength: 1
    // The mockup's rich painter (the island grown into the card): quieter, more detailed.
    property bool rich: false
    // The plain painter's counts scale with the area (the mockup: one per 4200 px², 1 to 3).
    readonly property real density: Math.max(1, Math.min(3, fx.width * fx.height / 4200))
    // The mask's corner radius; half the size makes a disc.
    property real radius: Math.min(fx.width, fx.height) / 2
    property real topLeftRadius: fx.radius
    property real topRightRadius: fx.radius
    property real bottomRightRadius: fx.radius
    property real bottomLeftRadius: fx.radius
    // Drops (rain, storm); hail, snow and fog; lightning and heat.
    property color color: Theme.primary
    property color color2: Theme.surfaceText
    property color accent: Theme.warning

    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    readonly property real pace: SettingsData.specDefault("animationDuration") / Math.max(1, SettingsData.animationDuration)
    readonly property int kindIndex: ["rain", "hail", "storm", "snow", "fog", "heat"].indexOf(fx.event)
    property real env: fx.kindIndex >= 0 ? fx.strength : 0
    property real clock: 0
    property real since: 0
    // The screen's refresh (its clock steps by it, and keeps the frames' cadence).
    readonly property real refresh: fx.screenHz || Kit.fallbackHz
    readonly property real screenHz: Kit.screenRefresh(NiriService.outputs, fx.Screen.name)
    readonly property real speed: Kit.weatherSpeed(fx.kindIndex, fx.level, fx.width, fx.height) * fx.pace

    visible: fx.kindIndex >= 0 && !fx.still && fx.env > 0.005

    Behavior on env {
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    IslandClock {
        id: fxClock

        refresh: fx.refresh
        running: fx.visible && (fx.Window.window?.visible ?? false)
        onRunningChanged: fx.since = 0
        onTick: dt => {
            fx.since += dt;
            // The particles move every frame: only the cadence, from the fastest one's speed, limits the redraws.
            if (!fxClock.due(fxClock.framesFor(fx.speed), 1))
                return;
            fx.clock = (fx.clock + fx.since * fx.pace) % 3600;
            fx.since = 0;
        }
    }

    ShaderEffect {
        anchors.fill: parent

        readonly property real time: fx.clock
        readonly property real kind: fx.kindIndex
        readonly property real level: fx.level
        readonly property real env: fx.env
        readonly property real density: fx.density
        readonly property real rich: fx.rich ? 1 : 0
        readonly property vector4d radii: Qt.vector4d(fx.topLeftRadius, fx.topRightRadius, fx.bottomRightRadius, fx.bottomLeftRadius)
        readonly property size sizePx: Qt.size(width, height)
        readonly property color fxColor: fx.color
        readonly property color fx2Color: fx.color2
        readonly property color warnColor: fx.accent

        fragmentShader: Qt.resolvedUrl("../../../Shaders/qsb/weather.frag.qsb")
    }
}
