.pragma library
.import "IslandKit.js" as Kit

// Cadence rule K7 (a spring steps Kit.decorMaxHz, 120, times a second at most, on any screen): a frame shorter than
// minimumStep is folded into the next one with its time, so a spring stays exact. The slack is the kit's rateSlack (5 %),
// the one framesBetween reads: a rate up to 126 Hz still counts as 120 (an off-vsync tick when several windows are
// exposed). The fold steps every k-th frame with k = ceil(hz / 126), framesBetween draws every ceil(hz / 120 - 0.05)
// refreshes: the same count on every panel rate (IslandKit.panelRates: one at 120 Hz and under, two at 144 to 240 Hz,
// three at 280 to 360 Hz, four at 480 Hz); they part only off those rates, between 246 and 252 Hz.
var minimumStep = 1 / (Kit.decorMaxHz * (1 + Kit.rateSlack));

// One frame through the fold, pending seconds folded before it: the time to step with (> 0), or minus the time now
// folded (<= 0). A frame time that is negative or not a finite number is dropped, so the fold never runs backwards nor
// turns into NaN.
function fold(pending, frameTime) {
    if (!(frameTime >= 0 && Number.isFinite(frameTime)))
        return -pending;
    const time = pending + frameTime;
    return time >= minimumStep ? time : -time;
}
