.pragma library
.import "IslandKit.js" as Kit

// Kit category: animation. The decor clock's arithmetic, read by IslandClock.qml.

// The screen arbiters' hysteresis (Android's): frames a decor keeps its count before it may slow down, and the ms
// without a frame after which its vote (its last count) is forgotten.
var holdFrames = 5;
var voteForgetMs = 750;
// Periods after which the wall clock counts images skipped: a late image within half a period still counts one.
var skippedAfter = 1.5;

// framesBetween with the hysteresis of the screen arbiters: a decor keeps its count `held` frames (holdFrames) before
// it may slow down, and a vote older than voteForgetMs is forgotten, so a decor that paused restarts from its measured
// speed. `idleMs`: the time since its last frame.
function framesHeld(refresh, speed, prev, held, idleMs) {
    const last = idleMs >= voteForgetMs ? 0 : prev;
    const k = Kit.framesBetween(refresh, speed, last);
    return last > 0 && k > last && held < holdFrames ? last : k;
}

// A decor clock's step: the screen's period, or the whole periods gone by when the wall clock says images were skipped
// (beyond skippedAfter periods, so the steps keep to the screen's grid). `elapsed` in seconds. A period that is not
// positive has no grid: the step is then the elapsed time itself (0 if that is not positive either), never NaN.
function clockStep(period, elapsed) {
    if (!(period > 0))
        return elapsed > 0 ? elapsed : 0;
    return elapsed > period * skippedAfter ? Math.round(elapsed / period) * period : period;
}

// How many times a second a decor's clock ticks on any screen: the island's decors are spinners and slow motion (60 is
// enough), never the screen's full rate.
var clockHz = 60;

// How many refreshes apart a decor's clock ticks, so it ticks clockHz times a second (240 Hz: 4, 60 Hz: 1).
function clockEvery(refresh) {
    return Math.max(1, Math.round(refresh / clockHz));
}
