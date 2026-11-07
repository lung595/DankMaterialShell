import QtQuick
import qs.Common
import qs.Services
import "../../../Common/IslandKit.js" as Kit

// Kit category: progress, lying down (a transfer's row, its island face and its bubble): DMS's wave progress (the shader
// of DCommon's M3WaveProgress, its amplitude, wavelength, drift and swell), drawn here without M3WaveProgress's own
// FrameAnimation, which runs at the screen's full rate while the swell is up: its phase moves at DMS's speed but is
// pushed at the kit's cadence (every few screen refreshes, once the wave moved half a pixel). It waves only while
// moving; at rest nothing runs. mirrored: it fills from the right.
Item {
    id: wave

    property real value: 0
    property real lineWidth: 2
    property real wavelength: 20
    property real amp: 1.6
    property real phase: 0
    property color trackColor: Theme.withAlpha(Theme.surfaceVariant, 0.40)
    property color fillColor: Theme.primary
    property color playheadColor: Theme.primary
    property bool moving: false
    property bool mirrored: false
    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    // M3WaveProgress's swell: the wave rises and lies down instead of switching.
    property real currentAmp: wave.moving ? wave.amp : 0
    // M3WaveProgress's swell time (DCommon), kept the same so both waves rise alike.
    readonly property int swellMs: 300
    // DMS's drift: 0.03 rad a frame at 60 frames a second.
    readonly property real drift: 0.03 * 60
    property real pending: 0
    // The screen's refresh (its clock steps by it, and keeps the pushes' cadence).
    readonly property real refresh: wave.screenHz || Kit.fallbackHz
    readonly property real screenHz: Kit.screenRefresh(NiriService.outputs, wave.Screen.name)

    transform: Scale {
        origin.x: wave.width / 2
        xScale: wave.mirrored ? -1 : 1
    }

    Behavior on currentAmp {
        enabled: !wave.still
        NumberAnimation {
            duration: wave.swellMs
            easing.type: Easing.OutCubic
        }
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true

        readonly property real widthPx: width
        readonly property real heightPx: height
        readonly property real value: wave.value
        readonly property real actualValue: wave.value
        readonly property real phase: wave.phase
        readonly property real ampPx: wave.currentAmp
        readonly property real wavelengthPx: wave.wavelength
        readonly property real lineWidthPx: wave.lineWidth
        readonly property real showActual: 0
        readonly property color fillColor: wave.fillColor
        readonly property color trackColor: wave.trackColor
        readonly property color playheadColor: wave.playheadColor
        readonly property color actualColor: Theme.onSurface_38

        fragmentShader: Qt.resolvedUrl("../../../DCommon/Shaders/qsb/wave_progress.frag.qsb")
    }

    IslandClock {
        id: waveClock

        refresh: wave.refresh
        running: wave.moving && !wave.still && wave.visible && (wave.Window.window?.visible ?? false)
        onTick: dt => {
            wave.pending += wave.drift * dt;
            if (!waveClock.due(waveClock.framesFor(wave.drift / (2 * Math.PI) * wave.wavelength), wave.pending / (2 * Math.PI) * wave.wavelength))
                return;
            wave.phase = (wave.phase + wave.pending) % (2 * Math.PI);
            wave.pending = 0;
        }
    }
}
