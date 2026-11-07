pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../../Common/IslandKit.js" as Kit
import "../../../Common/IslandCharge.js" as Charge

// Kit category: liquid meter. The charge well's sea (the open island's charge face, his mockup B "Expressive" of 29/10):
// the level's colour risen from the floor as far as the island has grown into the face (`grow`), an organic surface of
// three swells and a paler back wave, bubbles that burst into rings at the surface, and over it the bolt's Material
// cookie (`markSize` wide), its lobes dug deeper with the power and turning, round at the plug (it morphs in on `grow`).
// One shader (charge_sea.frag, K15) drawn from numbers: no Shape to rebuild, no layer, nothing allocated by frame (K9).
// One clock for the whole face, pushed at the kit's cadence once something moved half a pixel (K2, K6), at most
// seaMaxHz (K3, under K7), for its first seaLiveMs once shown, zero at rest and once hidden (K1); it also beats the
// mark's breath (`markScale`, read by the face for the bolt). Reduced motion: a flat sea, no bubble, nothing runs (A5).
Item {
    id: sea

    property real level: 0
    property real grow: 1
    property real watts: 0
    property color color: Theme.success
    property color markColor: Theme.surfaceContainerHighest
    property real markSize: 0
    property real radius: 0

    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    readonly property real share: Charge.share(sea.watts)
    readonly property real shown: sea.still ? 1 : Math.max(0, Math.min(1, sea.grow))
    // The mean line of the surface, from the top.
    readonly property real line: sea.height * (1 - Math.max(0, Math.min(1, sea.level)) * sea.shown)
    readonly property real markScale: sea.still ? 1 : Charge.markScale(sea.share, sea.breath)

    // The clock: the surface's phase, the breath, the bubbles' rise (px of the slowest lane), the mark's turn.
    property real phase: 0
    property real breath: 0
    property real rise: 0
    property real turn: 0
    property real pending: 0
    // The screen's refresh (the clock steps by it, and keeps the pushes' cadence).
    readonly property real refresh: sea.screenHz || Kit.fallbackHz
    readonly property real screenHz: Kit.screenRefresh(NiriService.outputs, sea.Screen.name)

    // The clock runs its first seaLiveMs once shown, then the sea holds still (held open under the pointer too).
    property bool awake: true
    onVisibleChanged: {
        if (sea.visible)
            sea.awake = true;
    }
    Timer {
        interval: Charge.seaLiveMs
        running: sea.visible && sea.awake && !sea.still
        onTriggered: sea.awake = false
    }

    IslandClock {
        id: seaClock

        refresh: sea.refresh
        running: sea.awake && !sea.still && sea.visible && (sea.Window.window?.visible ?? false)
        onTick: dt => {
            sea.pending += dt;
            const speed = Charge.seaSpeed(sea.share, sea.height);
            const fewest = Math.max(1, Math.ceil(Kit.panelRate(sea.refresh) / Charge.seaMaxHz - 0.05));
            if (!seaClock.due(Math.max(fewest, seaClock.framesFor(speed)), speed * sea.pending))
                return;
            const step = sea.pending;
            sea.phase = (sea.phase + step * Charge.seaPace(sea.share)) % (2 * Math.PI * 100);
            sea.breath = (sea.breath + step * 2 * Math.PI / Charge.breathPeriod(sea.share)) % (2 * Math.PI);
            sea.rise = (sea.rise + step * Charge.bubbleRise(sea.share, sea.height)) % 1e6;
            sea.turn = (sea.turn + step * Charge.markTurn(sea.share)) % (2 * Math.PI);
            sea.pending = 0;
        }
    }

    ShaderEffect {
        anchors.fill: parent

        readonly property size sizePx: Qt.size(width, height)
        readonly property real radius: sea.radius
        readonly property real line: sea.line
        readonly property real amp: sea.still ? 0 : Charge.seaAmp(sea.share, sea.height)
        readonly property real phase: sea.phase
        readonly property real breath: sea.breath
        readonly property real rise: sea.rise
        readonly property real bubbles: sea.still ? 0 : Charge.bubbles(sea.share)
        readonly property real markR: sea.markSize / 2 * sea.markScale
        // Round at the plug, dug into its cookie as the island grows into the face; C28: the bolt fits at every step.
        readonly property real markDepth: Charge.markDepth(sea.still ? Charge.markStillShare : sea.share) * sea.shown
        readonly property real markTurn: sea.turn
        readonly property color liqColor: sea.color
        readonly property color deepColor: Qt.darker(sea.color, Charge.seaDeep)
        readonly property color bubColor: Theme.withAlpha(Qt.lighter(sea.color, 1.5), Charge.bubbleAlpha)
        readonly property color markColor: sea.markColor

        fragmentShader: Qt.resolvedUrl("../../../Shaders/qsb/charge_sea.frag.qsb")
    }
}
