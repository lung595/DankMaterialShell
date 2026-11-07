import QtQuick
import "../../../Common/IslandKit.js" as Kit
import "../../../Common/IslandClock.js" as Clock

// Kit category: animation. A decor's clock: a Timer ticking 60 times a second on any screen, `every` refreshes apart
// (IslandClock.js clockEvery: 4 at 240 Hz, 1 at 60). A Timer is a pause job: it starts no animation driver, so no other
// window is rendered, and the island draws 60 images a second at most (its decors are spinners and slow motion),
// not the screen's full rate. dt is whole screen periods: `every` of them, or the periods gone
// by when the wall clock says ticks were skipped (IslandClock.js clockStep). The decor's own cadence on top, counted in
// refreshes, is kept here too: framesFor (framesHeld) says how many refreshes apart it draws, due (cadenceDue) whether
// it draws now.
QtObject {
    id: clock

    property bool running: false
    // The screen's refresh: dt and the tick interval are counted in its periods.
    property real refresh: Kit.fallbackHz
    signal tick(real dt)

    readonly property real period: 1 / Math.max(1, clock.refresh)
    readonly property int every: Clock.clockEvery(clock.refresh)
    property real _last: 0
    // The decor's cadence: the refreshes since its last image, how many refreshes apart its images are, how many images
    // that count held, and when the last one was drawn (ms).
    property real _ticks: 0
    property int _frames: 0
    property int _held: 0
    property real _drawnAt: 0

    onRunningChanged: {
        clock._last = Date.now();
        clock.resetCadence();
    }

    // Starts the decor's cadence over: its next image is due as soon as it moved (a decor played again).
    function resetCadence() {
        clock._ticks = 0;
    }

    // How many refreshes apart a decor moving at `speed` px/s draws its images now.
    function framesFor(speed: real): int {
        return Clock.framesHeld(clock.refresh, speed, clock._frames, clock._held, Date.now() - clock._drawnAt);
    }

    // Whether a decor drawn `frames` refreshes apart, `moved` px since its last image, draws one this tick; if it does,
    // its cadence counts that image.
    function due(frames: int, moved: real): bool {
        if (!Kit.cadenceDue(clock._ticks, frames, moved))
            return false;
        clock._held = frames === clock._frames ? clock._held + 1 : 0;
        clock._frames = frames;
        clock._drawnAt = Date.now();
        clock._ticks = Kit.cadenceCarry(clock._ticks, frames);
        return true;
    }

    readonly property Timer timer: Timer {
        running: clock.running
        repeat: true
        interval: Math.round(1000 * clock.every * clock.period)
        onTriggered: {
            const now = Date.now();
            const dt = Clock.clockStep(clock.period, (now - clock._last) / 1000);
            clock._last = now;
            clock._ticks += dt * clock.refresh;
            clock.tick(dt);
        }
    }
}
