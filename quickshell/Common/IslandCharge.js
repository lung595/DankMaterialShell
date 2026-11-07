.pragma library

// The laptop battery's charge (IslandChargeSource.qml): what a new reading says, the power history taken while it
// charges, and the times its card and face show. Pure functions, no Qt.

// prev, next: {plugged, charging, level (0..1)}; prev null for the first reading, which only seeds (quiet at start).
// Returns "" | "plugged" | "unplugged" | "full".
function step(prev, next) {
    if (!prev || !next)
        return "";
    if (prev.plugged && !next.plugged)
        return "unplugged";
    if (!prev.plugged && next.plugged)
        return next.charging ? "plugged" : (next.level >= 1 ? "full" : "plugged");
    if (next.plugged && prev.charging && !next.charging)
        return "full";
    return "";
}

// A new [time ms, watts] point; once over `max`, neighbours merge two by two so the whole span stays, at half the
// resolution. Never edits `history`.
function record(history, t, watts, max) {
    let next = (history || []).concat([[t, watts]]);
    if (next.length <= max)
        return next;
    const merged = [next[0]];
    for (let i = 1; i + 1 < next.length - 1; i += 2)
        merged.push([(next[i][0] + next[i + 1][0]) / 2, (next[i][1] + next[i + 1][1]) / 2]);
    merged.push(next[next.length - 1]);
    return merged;
}

// Average power, energy received (Wh, trapezoids), peak and span of a history.
function summary(history) {
    const h = history || [];
    if (h.length < 2)
        return {
            "avg": h.length ? h[0][1] : 0,
            "wh": 0,
            "start": h.length ? h[0][0] : 0,
            "end": h.length ? h[0][0] : 0,
            "peak": h.length ? h[0][1] : 0
        };
    let wms = 0, peak = 0;
    for (let i = 0; i < h.length; i++) {
        peak = Math.max(peak, h[i][1]);
        if (i > 0)
            wms += (h[i][0] - h[i - 1][0]) * (h[i][1] + h[i - 1][1]) / 2;
    }
    const span = h[h.length - 1][0] - h[0][0];
    return {
        "avg": span > 0 ? wms / span : h[0][1],
        "wh": wms / 3600000,
        "start": h[0][0],
        "end": h[h.length - 1][0],
        "peak": peak
    };
}

// Time left as whole hours and minutes, rounded up to the minute; null when unknown.
function left(seconds) {
    if (!(seconds > 0 && seconds < Infinity))
        return null;
    const m = Math.ceil(seconds / 60);
    return {
        "h": Math.floor(m / 60),
        "m": m % 60
    };
}

// A clock time, "14:44" or "2:44 PM", as DMS's 24-hour setting says.
function clock(ms, h24) {
    const d = new Date(ms);
    const mm = String(d.getMinutes()).padStart(2, "0");
    if (h24)
        return String(d.getHours()).padStart(2, "0") + ":" + mm;
    const h = d.getHours() % 12 || 12;
    return h + ":" + mm + (d.getHours() < 12 ? " AM" : " PM");
}

// The power's word, a convention cut on the USB Power Delivery tiers (no standard names them): under 10 W a USB-A port
// (5 V 2 A), to 30 W a phone charger, to 65 W a laptop charger, above the 100 W and extended-range bricks. "" at rest.
var speedSlowMaxW = 10;
var speedNormalMaxW = 30;
var speedFastMaxW = 65;
function speed(watts) {
    if (!(watts > 0))
        return "";
    if (watts < speedSlowMaxW)
        return "slow";
    if (watts < speedNormalMaxW)
        return "normal";
    if (watts < speedFastMaxW)
        return "fast";
    return "ultra";
}

// The power's share of the fast tier's top, on a square root (a phone's 20 W already moves), 0..1.
function share(watts) {
    return Math.sqrt(Math.max(0, Math.min(1, watts / speedFastMaxW)));
}

// A live wave's height in `unit`s (the kit's spacingXXS): half a unit at rest to two at the fast tier's top.
var waveAmpRest = 0.5;
var waveAmpGain = 1.5;
function waveAmp(watts, unit) {
    return unit * (waveAmpRest + waveAmpGain * share(watts));
}

// The slow wave's pace in radians a second: `waveHz` cycles a second at the normal tier's top, scaled by the square
// root of the power, half to 1.6 times (the open face's sea, the bolt's pill).
var waveHz = 0.4;
function waveRate(watts) {
    const s = Math.sqrt(Math.max(0, watts) / speedNormalMaxW);
    return 2 * Math.PI * waveHz * Math.max(0.5, Math.min(1.6, s));
}

// The sea and its mark (mockup B "Expressive" of 29/10), all on the power's share s (0..1). The breath: its period in
// seconds (slow at rest, quick at the fast tier), the mark's scale on it (a little deeper with the power).
var breathRestS = 4.2;
var breathFastS = 1.6;
function breathPeriod(s) {
    return breathRestS - (breathRestS - breathFastS) * s;
}
var markBreathRest = 0.025;
var markBreathGain = 0.035;
function markScale(s, breath) {
    return 1 + (markBreathRest + markBreathGain * s) * Math.sin(breath);
}
// The mark's Material cookie (nine lobes): how deep they dig, a share of its radius (C28: at most 0.12, its hollow stays
// over 0.78 of its radius for the bolt), deeper with the power; reduced motion keeps the depth of `markStillShare`.
// Its turn in radians a second.
var markDepthRest = 0.045;
var markDepthGain = 0.075;
var markStillShare = 0.3;
function markDepth(s) {
    return markDepthRest + markDepthGain * Math.max(0, Math.min(1, s));
}
var markTurnRest = 0.15;
var markTurnGain = 0.75;
function markTurn(s) {
    return markTurnRest + markTurnGain * s;
}
// The surface's phase pace in radians a second, its swell's height as a share of the sea's height h (the mockup's 0.7 to
// 5 px of 84), the bubbles' count and their lanes' rise as a share of h a second (10 to 50 px of 84).
var seaPaceRest = 0.7;
var seaPaceGain = 3.1;
function seaPace(s) {
    return seaPaceRest + seaPaceGain * s;
}
var seaAmpRest = 0.7 / 84;
var seaAmpGain = 4.3 / 84;
function seaAmp(s, h) {
    return h * (seaAmpRest + seaAmpGain * s);
}
var bubblesRest = 3;
var bubblesGain = 17;
function bubbles(s) {
    return Math.round(bubblesRest + bubblesGain * Math.max(0, Math.min(1, s)));
}
var riseRest = 10 / 84;
var riseGain = 40 / 84;
function bubbleRise(s, h) {
    return h * (riseRest + riseGain * s);
}
// The fastest thing on the sea in px a second, for the clock's cadence (K2, K6): a crest (its three swells move at most
// `crestGain` times its height by radian) or the quickest bubble (`bubbleFastest` times its lane's rise).
var crestGain = 1.5;
var bubbleFastest = 1.9;
function seaSpeed(s, h) {
    return Math.max(seaAmp(s, h) * seaPace(s) * crestGain, bubbleRise(s, h) * bubbleFastest);
}

// The odometer: where the wheel of `place` (1, 10, 100) stands for the value v, 0..10 (a fraction is a roll to the next
// digit); a higher wheel rolls only while every wheel under it passes from 9 to 0. Two wheels to 99.5, three above.
// The level is read from the battery: anything but a number in 0..100 (NaN, infinite) stands at the nearest bound or 0.
function rollAt(v, place) {
    const x = v > 0 ? Math.min(100, v) : 0;
    if (place <= 1)
        return x % 10;
    return Math.floor(x / place) % 10 + Math.max(0, Math.min(1, x % place - (place - 1)));
}
function wheels(v) {
    return v >= 99.5 ? 3 : 2;
}

// A chip's reveal (0..1) on the island's growth: chip i of n takes its own slice of the growth's second half, in order,
// so the chips cascade on the island's spring instead of a timer.
function revealAt(grow, i, n) {
    const slice = 0.5 / Math.max(1, n);
    const from = 0.5 + slice * i;
    return Math.max(0, Math.min(1, (grow - from) / slice));
}

// What the session gave since the plug: whole percent points and whole minutes gone; null before any plug.
function gain(startLevel, level, startedAt, now) {
    if (!(startedAt > 0))
        return null;
    return {
        "pct": Math.round((level - startLevel) * 100),
        "min": Math.floor((now - startedAt) / 60000)
    };
}

// The gain chip's signed percent ("+3", "+0", "-2"), none before the session is a minute old: "+0% in 0 min" says nothing.
function gainPct(g) {
    return g && g.min >= 1 ? (g.pct >= 0 ? "+" : "") + g.pct : "";
}

// The level as the island says it, a whole percent: 99.6 % charging reads 100 %, as the pill, the bubble and the face do.
function percent(level) {
    return Math.round(level * 100);
}

// The face's opacities: the tonal chip and the wave's track (the level's colour over the island), the bubbles over the
// sea. The sea's deep is its colour darkened this much.
var tonalAlpha = 0.22;
var trackAlpha = 0.4;
var bubbleAlpha = 0.6;
var seaDeep = 1.9;
// The sea's clock runs this long once shown (the bubble's 5 s, M18 to M22), then the sea holds still, even held open
// under the pointer; and never past this rate (K3: the lowest that stays fluid, under K7; 60 cost the bench half again
// the base's CPU, 29/10).
var seaLiveMs = 5000;
var seaMaxHz = 30;

// The clock times are read again once a minute, and at once, only while something shows them.
function clockLive(shown, lasting, cardOpen) {
    return !!(shown || lasting || cardOpen);
}
