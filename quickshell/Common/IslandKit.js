.pragma library

// The island kit's shared rules, plain arithmetic with no QML: motion and layout (springs of interior.dev, MIT; row
// split, hold, wave, outlines), frame cadence, and what several faces read alike (an alert's rings and tones).

// [stiffness, damping, mass] at DMS's default animation speed.
var springs = {
    "cell": [520, 34, 0.45],
    "pop": [640, 22, 0.7],
    "surface": [420, 36, 0.9],
    "fill": [210, 34, 0.9]
};

// Interior's hold-to-confirm: released early, the sweep drains this much faster than it filled.
var drainSpeed = 2.5;
// Interior's error shake, in units of the theme's smallest spacing.
var shake = [0, -1.25, 1, -0.75, 0];

// Content micro-motions, in multiples of DMS's animation speed.
var beats = {
    // A busy halo breathing (the shelf taking files in).
    "breath": 4,
    // The eye break's eye: its saccade is quick; its blink shuts fast and reopens slower, with a short gap before a
    // second one.
    "saccade": 0.36,
    "blinkClose": 0.32,
    "blinkShut": 0.16,
    "blinkOpen": 1,
    "blinkTwice": 0.6,
    // An arriving info's tint fading.
    "tint": 2.08,
    // An arriving info: the page rolling in and out, a new page dot popping, a frozen dot emptying.
    "roll": 1.36,
    "rollOut": 0.88,
    "pop": 1.28,
    "drain": 1.8,
    // A copy's check drawing itself.
    "checkDraw": 1.2,
    // The pause between two digits of a copied code jumping (a wave).
    "hopStep": 0.16,
    // An important info rings like a phone: its second ring leaves this long after the first.
    "ringGap": 1.6,
    // A ringing call rings again after this pause, like a phone.
    "ringPause": 4
};
// How far a ringing call's shape swings each ring, in degrees at the spring's peak.
var ringTilt = 12;
// Beats drawn at random within [min, max]: the eye's rest on a near or a far point, the gap between its blinks.
var spans = {
    "fixNear": [1, 2.4],
    "fixFar": [2.4, 9],
    "blinkGap": [8, 24]
};
// Share of the eye's blinks that come twice, and of its glances that go far off (the break is about looking far away).
var eyeTwiceShare = 0.2;
var eyeFarShare = 0.7;
// The copy and hold buttons go back to rest this long after their outcome (Interior): a lifetime, not a motion.
var feedbackMs = 1600;
// How high a copied code's digit jumps, in units of the theme's smallest spacing.
var hopLift = 1;
// A file held this long on another in the shelf makes a folder of them (iOS): a lifetime too.
var folderHoldMs = 600;
// A place lit under a drag (the shelf's room, its bubble): its fill is the primary container at this share.
var dropLitAlpha = 0.28;
// A shape moving on to its next one beats out by this much (the app icon's poke, a replaced face on the wing).
var morphPulse = 0.15;

// A gauge's liquid and its track, as alphas of one hue (trackAlpha alone: behind an opaque liquid). On a light theme a
// 0.24 track leaves the liquid at 2.5:1; lightTrackAlpha keeps it at 3:1, and the dark value on it at 4.5:1.
var fillAlpha = 0.75;
var trackAlpha = 0.24;
var lightTrackAlpha = 0.08;
function waveTrackAlpha(light) {
    return light ? lightTrackAlpha : trackAlpha;
}

// DMS's default animation duration: the speed the tables above are tuned at.
var baseMs = 250;

// A beat at DMS's animation speed (250 ms by default); 0 at speed 0, where content shows its final state.
function beat(name, baseDuration) {
    return baseDuration > 0 ? Math.round(baseDuration * (beats[name] ?? 1)) : 0;
}

// A beat of the spans table at the random draw r (0..1).
function beatIn(name, r, baseDuration) {
    const s = spans[name] ?? [1, 1];
    return baseDuration > 0 ? Math.round(baseDuration * (s[0] + (s[1] - s[0]) * r)) : 0;
}

// The eye's blink ms into it (0 open .. 1 shut) on the beats above, closing and opening on the given bezier curves
// ([x1, y1, x2, y2]); twice, a gap and again. -1 once over, so the eye's clock can stop.
function eyeBlinkAt(ms, baseDuration, loops, closeCurve, openCurve) {
    const close = beat("blinkClose", baseDuration), shut = beat("blinkShut", baseDuration), open = beat("blinkOpen", baseDuration);
    const one = close + shut + open + (loops > 1 ? beat("blinkTwice", baseDuration) : 0);
    if (one <= 0 || ms >= one * Math.max(1, loops))
        return -1;
    const t = ms % one;
    if (t < close)
        return bezier(closeCurve[0], closeCurve[1], closeCurve[2], closeCurve[3], t / close);
    if (t < close + shut)
        return 1;
    if (t < close + shut + open)
        return 1 - bezier(openCurve[0], openCurve[1], openCurve[2], openCurve[3], (t - close - shut) / open);
    return 0;
}

// A critical alert's [shape, icon] Theme roles: its container; folded on a light theme, full error (the container is too
// pale there to say it). null for other alerts, which keep their own tone.
function alertRoles(alert, folded, light) {
    if (alert !== "critical")
        return null;
    return folded && light ? ["error", "onError"] : ["errorContainer", "onErrorContainer"];
}

// An alert's rings, ms into them: a cycle sends one ring every gap, each lasting span, then pauses; cycles 0 rings until
// stopped (a ringing call). Plain numbers, no allocation: read once per pushed frame.
function ringCycle(span, gap, rings, pause) {
    return (rings - 1) * gap + span + pause;
}

function ringsOver(ms, span, gap, rings, pause, cycles) {
    return span <= 0 || (cycles > 0 && ms >= (cycles - 1) * ringCycle(span, gap, rings, pause) + (rings - 1) * gap + span);
}

// Ring i's progress: 0 just left .. 1 gone (or not out).
function ringT(ms, span, gap, rings, pause, cycles, i) {
    if (ms < 0 || ringsOver(ms, span, gap, rings, pause, cycles))
        return 1;
    const t = (ms % ringCycle(span, gap, rings, pause) - i * gap) / span;
    return t >= 0 && t < 1 ? t : 1;
}

// The shape's swing (-1..1 at the peak): each ring leaving kicks it, one way then the other, and it swings back on the
// spring (stiffness, damping ratio, mass), as a ringing phone rocks. Kept under swingMaxRatio damping so it has a peak.
var swingMaxRatio = 0.95;
function ringSwing(ms, span, gap, rings, pause, cycles, stiffness, ratio, mass) {
    if (ms <= 0 || !(stiffness > 0) || !(mass > 0) || ringsOver(ms, span, gap, rings, pause, cycles))
        return 0;
    const w = Math.sqrt(stiffness / mass), z = Math.min(swingMaxRatio, ratio), wd = w * Math.sqrt(1 - z * z);
    const tp = Math.atan(wd / (z * w)) / wd;
    const peak = Math.exp(-z * w * tp) * Math.sin(wd * tp);
    const local = ms % ringCycle(span, gap, rings, pause);
    let x = 0;
    for (let i = 0; i < rings; i++) {
        const s = (local - i * gap) / 1000;
        if (s > 0)
            x += (i % 2 ? -1 : 1) * Math.exp(-z * w * s) * Math.sin(wd * s);
    }
    return x / peak;
}

// Where the eye looks next, x and y in -1..1 (y down), from four random draws: mostly far off to a side and a little
// up, sometimes back near the middle. A far glance goes eyeFarX[0] out plus up to eyeFarX[1] more, eyeFarY[0] up plus
// up to eyeFarY[1] more; a near one stays within eyeNearReach of the middle.
var eyeFarX = [0.6, 0.4];
var eyeFarY = [-0.2, -0.6];
var eyeNearReach = 0.4;
function eyeGlance(a, b, c, d) {
    if (a < eyeFarShare)
        return {
            "x": (b < 0.5 ? -1 : 1) * (eyeFarX[0] + eyeFarX[1] * c),
            "y": eyeFarY[0] + eyeFarY[1] * d,
            "far": true
        };
    return {
        "x": (2 * b - 1) * eyeNearReach,
        "y": (2 * d - 1) * eyeNearReach,
        "far": false
    };
}

// Air between a glyph's box edge and its ink, for a glyph centred in its box (icons).
function boxBearing(box, advance, inkX) {
    return (box - advance) / 2 + inkX;
}

// Whole-pixel x that centres a row on its ink in a face, given the air before its first ink and after its last.
function inkCentredX(width, rowWidth, lead, trail) {
    return Math.round((width - rowWidth + trail - lead) / 2);
}

// The upright pill's gauge (track and liquid), t = 0 flat to 1 upright: the whole pill inside its inset while flat (never
// empty: its liquid's spring settles by the pixel), under the icon's shape by the flat track's gap once upright.
function uprightGaugeTop(iconSide, gap, inset, t) {
    return inset + (iconSide + gap - inset) * t;
}

function uprightGaugeHeight(height, iconSide, gap, inset, t) {
    return Math.max(0, height - uprightGaugeTop(iconSide, gap, inset, t) - inset);
}

// DMS's animation speed (250 ms by default) stretches time: k / f² and c / f keep the spring's shape, f times slower,
// never more than 1 / minStretch times faster.
var minStretch = 0.05;
function spring(name, baseDuration) {
    const s = springs[name] ?? springs.cell;
    const f = Math.max(minStretch, (baseDuration > 0 ? baseDuration : baseMs) / baseMs);
    return {
        "stiffness": s[0] / (f * f),
        "damping": s[1] / f,
        "mass": s[2]
    };
}

// A full-width row split by weights (1 1 2 2 for the call card), whole pixels, ending exactly at the edge.
function rowLayout(total, weights, gap) {
    const n = weights.length;
    if (n === 0 || total <= 0)
        return [];
    const clean = weights.map(w => w > 0 ? w : 0);
    const sum = clean.reduce((a, w) => a + w, 0);
    const parts = sum > 0 ? clean : clean.map(() => 1);
    const partsSum = sum > 0 ? sum : n;
    let acc = 0;
    let edge = 0;
    return parts.map((w, i) => {
        acc += w;
        const next = rowEdge(total, n, gap, acc, partsSum);
        const cell = {
            "x": edge + i * gap,
            "width": next - edge
        };
        edge = next;
        return cell;
    });
}

// One edge of that row, gaps left out (add i * gap for part i), after the weights before it (acc) out of all (sum): a
// part that springs every frame places itself with it, without an array. Rounding the running edge, not each width,
// keeps every part within a pixel of its share.
function rowEdge(total, n, gap, acc, sum) {
    const free = Math.max(0, Math.floor(total - gap * (n - 1)));
    return sum > 0 ? Math.round(free * acc / sum) : 0;
}

// Time left to fill from progress, and to drain back to zero after an early release.
function holdRemaining(progress, holdMs) {
    return Math.max(0, 1 - Math.max(0, Math.min(1, progress))) * holdMs;
}

function drainTime(progress, holdMs) {
    return Math.max(0, Math.min(1, progress)) * holdMs / drainSpeed;
}

// Two polar outlines (same sample count) mixed at t; a missing one stands for the other.
function mixRadii(a, b, t) {
    if (!a || a.length === 0)
        return b ?? [];
    if (!b || b.length !== a.length)
        return a;
    const k = Math.max(0, Math.min(1, t));
    return a.map((r, i) => r + (b[i] - r) * k);
}

// The liquid front of every island liquid (the volume wing's level, the hold and undo meters): how far it reaches
// past its mean line at d (0 mid-front, 1 at its walls, mirrored); amp follows the level's speed, phase its travel.
function wave(d, amp, phase) {
    return amp * Math.sin(phase + Math.PI * d);
}

// Its slope along d, for a front drawn as cubic curves (no point array per frame).
function waveSlope(d, amp, phase) {
    return amp * Math.PI * Math.cos(phase + Math.PI * d);
}

// A live level's burst of speed never pushes its liquid more than this many levels a second, so a jumpy source can't
// whip it.
var surgeMax = 0.75;

// A burst of speed (a transfer whose rate jumps): each doubling of the rate pushes the liquid this many levels a second,
// up to surgeMax; gain is the user's motion intensity (0..1).
var surgePush = 0.25;
function surgeKick(surge, gain) {
    return Math.min(surgeMax, Math.max(0, surge) * surgePush) * Math.max(0, gain);
}

// A critically damped spring released at 0 toward 1, at x = ω·t (x <= 0: not yet released).
function criticalStep(x) {
    return x <= 0 ? 0 : 1 - (1 + x) * Math.exp(-x);
}

// Where a spring (stiffness k, damping c, mass m) released at 0 toward 1 is after t seconds: the wing's own spring in
// closed form, so a clock can drive it without integrating every frame.
function springStep(t, k, c, m) {
    if (t <= 0)
        return 0;
    if (!(k > 0) || !(m > 0))
        return 1;
    const w = Math.sqrt(k / m);
    const z = c / (2 * Math.sqrt(k * m));
    if (Math.abs(z - 1) < 1e-4)
        return criticalStep(w * t);
    if (z < 1) {
        const wd = w * Math.sqrt(1 - z * z);
        return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + z * w / wd * Math.sin(wd * t));
    }
    const s = Math.sqrt(z * z - 1);
    const r1 = -w * (z - s), r2 = -w * (z + s);
    return 1 + (r2 * Math.exp(r1 * t) - r1 * Math.exp(r2 * t)) / (r1 - r2);
}

// Where in [0, hi] a rising f reaches y, by bisection: bisectSteps halvings land within a billionth of the range.
var bisectSteps = 30;
function solveRising(f, y, hi) {
    let lo = 0;
    for (let i = 0; i < bisectSteps; i++) {
        const mid = (lo + hi) / 2;
        if (f(mid) < y)
            lo = mid;
        else
            hi = mid;
    }
    return (lo + hi) / 2;
}

// A CSS cubic-bezier(x1, y1, x2, y2) easing at x (0..1), solved on its x.
function bezier(x1, y1, x2, y2, x) {
    if (x <= 0)
        return 0;
    if (x >= 1)
        return 1;
    const at = (a, b, t) => 3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t;
    return at(y1, y2, solveRising(t => at(x1, x2, t), x, 1));
}

// How long a spring released at 0 toward 1 takes to stay within eps of it: the wing's entry length, so its exit can last
// as long. Sampled at SpringMotion's integration step, over settleMaxS seconds at most.
var settleStep = 1 / 240;
var settleMaxS = 10;
function springSettle(k, c, m, eps) {
    if (!(k > 0) || !(m > 0))
        return 0;
    const dt = settleStep;
    let last = 0;
    for (let t = dt; t < settleMaxS; t += dt)
        if (Math.abs(1 - springStep(t, k, c, m)) > eps)
            last = t;
    return last + dt;
}

// Whether a leaving bubble closes where it stands: its card shut, or a card it opened itself (a 2FA code, the trash's Undo)
// that nobody is reading, which folds back onto its shape as it fuses. A card the pointer still holds open withdraws.
function closesInPlace(w) {
    return w.ready && (w.hoverGrow < 0.01 || w.selfOpened && !w.hovered);
}

// How a bubble closing where it stands leaves: "fuse" (into the island), "fade" (reduced motion) or "shrink" (back along
// its spring). It fuses when it goes on its own, or when the island takes its own info in the same turn (the copy's
// face, the shelf's card): it goes in. Any other change of the island's occupant (a face or activity closing, another
// one opening) makes it just withdraw.
function closeStyle(s) {
    if (!s.inPlace || s.occupantBefore !== s.occupantNow && !tookIn(s.occupantNow, s.source))
        return "shrink";
    return s.reduced ? "fade" : "fuse";
}

// Whether the island's occupant ("activity|plugin token") is the bubble's own source: its activity, or its token "dms:<source>:<n>".
function tookIn(occupant, source) {
    if (!source)
        return false;
    const parts = String(occupant).split("|");
    return parts[0] === source || (parts[1] ?? "").startsWith("dms:" + source + ":");
}

// A bubble merging into the island, read off one critically damped spring (the wing's exit spring: the island's
// stiffness, damping ratio 1) at wt = ω·t. Its position P eases from 0 to 1 with no jump in speed: the text fades over
// fuseTextShare of the hand-off and the wing gathers onto its shape until P reaches the hand-off, then the shape flows on
// along its way (along, 0..1, still on P, so the speed carries over), stretched along and thinned across by its own
// speed, losing fuseShrink of its size as it goes in, landing softly as the spring settles. contact: the share of its way
// where it touches the island; from there a halo spreads from that point like a wave on the same spring (wave 0..1 of its
// reach) while it pales (glow), and the island's edge swells there and back (swell, 1 at its height).
var fuseHandoff = 0.2;
// Flow speed (along per unit of wt) at which the shape is stretched the most, and that stretch.
var fuseFastest = 0.33;
var fuseStretch = 0.6;
var fuseTextShare = 0.6;
var fuseShrink = 0.8;
// Inside the island the shader hides it; it fades from this share of its way so nothing is left to draw.
var fuseBlobFade = 0.85;
// The spring and the halo count as landed this close to rest.
var fuseLanded = 0.995;
function fusionPhases(wt, contact) {
    const smooth = (a, b, x) => {
        const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
        return t * t * (3 - 2 * t);
    };
    const h = fuseHandoff;
    const flowAt = x => {
        const q = Math.max(0, (criticalStep(x) - h) / (1 - h));
        return q * q;
    };
    const P = criticalStep(wt);
    const along = flowAt(wt);
    const q = Math.max(0, (P - h) / (1 - h));
    const speed = P > h ? 2 * q / (1 - h) * Math.max(0, wt) * Math.exp(-wt) : 0;
    const stretch = fuseStretch * Math.min(1, speed / fuseFastest);
    const size = 1 - fuseShrink * along;
    // The moment of contact (the flow rises with wt).
    const touch = contact >= 0 && along >= contact ? solveRising(flowAt, contact, Math.max(0, wt)) : -1;
    const wave = touch < 0 ? 0 : criticalStep(wt - touch);
    return {
        "text": 1 - smooth(0, fuseTextShare * h, P),
        "gather": smooth(0, h, P),
        "flowing": P >= h,
        "along": along,
        "scaleAlong": size * (1 + stretch),
        "scaleCross": size / (1 + stretch),
        "blob": 1 - smooth(fuseBlobFade, 1, along),
        "wave": wave,
        "glow": touch < 0 ? 0 : 1 - wave,
        "swell": 4 * wave * (1 - wave),
        "done": P > fuseLanded && (touch < 0 || wave > fuseLanded)
    };
}

// Where along its way the fusing shape touches the island: it flows from where the wing gathered (one pill of size, gap
// away from the island's edge), the same flat or upright, whatever the open pill's length was.
function fuseContact(gap, size, reach) {
    return Math.max(0, Math.min(1, (gap + size / 2) / (size * reach)));
}

// A costly frame (a shader pass) is redrawn once `every` screen refreshes went by (IslandKit.framesBetween), and only once
// something moved half a pixel. `refreshes`: the time since the last frame in refreshes; within half of one, so frames
// keep to the screen's grid even when DMS's animation timer ticks off its vsync.
function cadenceDue(refreshes, every, movedPx) {
    return refreshes >= every - 0.5 && movedPx >= 0.5;
}

// What is left of the refreshes once a frame is drawn: carried to the next one (within half a refresh either way), so the
// frames keep to the screen's grid on average instead of drifting a tick late each time.
function cadenceCarry(refreshes, every) {
    return Math.max(-0.5, Math.min(0.5, refreshes - every));
}

// The refresh the kit's clocks count in while the screen's own is unknown (screenRefresh gives 0).
var fallbackHz = 60;
// The refresh of the screen named `name`, from niri's outputs (its current mode, mHz), 0 when unknown.
function screenRefresh(outputs, name) {
    const output = outputs?.[name];
    const mode = output?.modes?.[output?.current_mode];
    return mode?.refresh_rate > 0 ? mode.refresh_rate / 1000 : 0;
}

// The screen's refresh rate, followed from the frame times a running animation sees: their mean (not the mean of their
// inverse, which reads high) with each one counting for refreshWeight and within refreshBand times either way, so a
// missed frame or a wake from pause barely moves it, a real change settles in a few tenths of a second. A frame under
// minFrameS reads as one (a zero frame time is no rate); without a rate yet, the frame alone gives it.
var refreshWeight = 0.1;
var refreshBand = 1.5;
var minFrameS = 1e-4;
function refreshFrom(hz, frameTime) {
    const ft = Math.max(frameTime, minFrameS);
    if (!(hz > 0))
        return 1 / ft;
    const period = 1 / hz;
    return 1 / (period + refreshWeight * (Math.max(period / refreshBand, Math.min(period * refreshBand, ft)) - period));
}

// Screens refresh at a known rate: the nearest one to a measured refresh, so a little jitter never shifts the range.
var panelRates = [24, 30, 48, 50, 60, 72, 75, 85, 90, 100, 120, 144, 165, 170, 175, 180, 200, 240, 280, 300, 360, 480];
function panelRate(refresh) {
    let best = panelRates[0];
    for (let i = 1; i < panelRates.length; i++) {
        if (Math.abs(panelRates[i] - refresh) < Math.abs(best - refresh))
            best = panelRates[i];
    }
    return best;
}

// How many refreshes apart a step of `px` at `speed` px/s fits, within [fewest, most].
function stepsFit(px, hz, speed, fewest, most) {
    return Math.max(fewest, Math.min(most, Math.floor(px * hz / (speed > 1e-3 ? speed : 1e-3))));
}

// A decor is drawn decorMinHz to decorMaxHz times a second; a measured refresh off by up to rateSlack of a step (121,
// 239) keeps the same range; it slows down only once a step would stay under slowStepPx.
var decorMaxHz = 120;
var decorMinHz = 24;
var rateSlack = 0.05;
var slowStepPx = 0.8;

// How many screen refreshes apart a decor moving at `speed` px/s is drawn, so its rate always divides the screen's
// (240 Hz: 120, 80, 60, 48, 40, 30, 24; 60 Hz: 60, 30) and never judders: as far apart as keeps each step within a pixel,
// within the range above (never more than the screen). It speeds up at once; it slows one refresh at a time, and only
// once a step would stay well under the pixel, so it does not flap on the edge. `prev`: the count of its last frame.
function framesBetween(refresh, speed, prev) {
    const hz = panelRate(refresh);
    const fewest = Math.max(1, Math.ceil(hz / decorMaxHz - rateSlack));
    const most = Math.max(fewest, Math.floor(hz / decorMinHz + rateSlack));
    // No speed to read (0/0 on a first frame) counts as still.
    const k = stepsFit(1, hz, speed, fewest, most);
    if (!(prev > 0) || k < prev)
        return k;
    return Math.max(fewest, Math.min(most, stepsFit(slowStepPx, hz, speed, fewest, most) > prev ? prev + 1 : prev));
}

// The weather sky's tables by level, as weather.frag's: SS (skyScale), RAIN_LEAN, RAIN_SP and RAIN_LEN (the drops' lean,
// fall speed and length). skyGust: the fastest gust() changes, per second (the bound written above gust()).
var skyScale = [0.6, 0.85, 1.1, 1.4];
var dropLean = [0.1, 0.2, 0.3, 0.7];
var dropFall = [0.3, 0.75, 1.4, 1.9];
var dropSize = [3, 4, 7, 9];
var skyGust = 1.5 * (0.65 * 0.23 + 0.35 * 0.61);
// weatherSpeed's bounds, each the largest value of a weather.frag term (its function named). vnoise changes at most
// noiseSlope per unit of its argument.
var noiseSlope = 1.5;
// drops(): speed jitter 0.85 + 0.35, fall over s.y + 14, lean widened 1.5 times by the margin, range s.y + 6 plus a
// length up to 1.4 times RAIN_LEN.
var dropJitter = 1.2;
var dropRun = 14;
var dropLeanWiden = 1.5;
var dropRange = 6;
var dropLenMax = 1.4;
// hail(): rate 0.9 + 0.4; a stone lands four times faster than it falls (hailY), its impact ring grows 60 px a phase,
// floored at it, and it bounces sideways up to 14 * 0.5 px.
var hailRate = 1.3;
var hailLand = 4;
var hailRing = 60;
var hailBounce = 7;
// snow(): rate 0.18 + 0.12 over s.y + 10; sway 2.5 + 3.5 px at 0.7 + 0.6 rad/s, a second sway of 1.5 px at 1.9 + 0.8
// rad/s plus 0.12 rad per px of fall; wind 8 px per unit of gust; a rich flake's arm (0.9 + 3) * 1.4 px turning 0.4 rad/s.
var snowRate = 0.3;
var snowRun = 10;
var snowSway = [6, 1.3];
var snowSway2 = [1.5, 2.7, 0.12];
var snowWind = 8;
var snowSpin = [0.4, 5.5];
// fog bank(): bands drift 0.045 * (1 + 2 * 0.35) of 1.8 widths per second; a band up to half the height undulates by
// 0.9 at noise speed 0.25 and swells by 0.25 at 0.18; its edge pattern moves 0.25 over a 0.04 spatial frequency.
var fogDrift = 0.045 * 1.7 * 1.8;
var fogBand = 0.5;
var fogWobble = 0.9 * 0.25 + 0.25 * 0.18;
var fogEdge = 0.25 / 0.04;
// heat(): sparks rise s.y at 0.2 + 0.15 and sway 2 px at 1.5 + 1.5 rad/s; a ripple up to (2 + 4 * 0.4) * 1.3 px high runs
// at 1.1 + 4 * 0.17 rad/s, drifts and swells (3 * 0.3 + 3.6 * 0.6 * 0.4) * 1.5 px/s, breaks 0.2 over a 0.04 frequency.
var heatRise = 0.35;
var heatSway = 6;
var heatRipple = 4.68 * 1.78;
var heatDrift = 2.65;
var heatBreak = 0.2 / 0.04;

// The weather sky's fastest particle in px/s (weather.frag's own speeds, kind and level as its uniforms, w x h its size).
// The rich painter is quieter, so this bounds it too.
function weatherSpeed(kind, level, w, h) {
    const lv = Math.max(0, Math.min(3, Math.floor(level))), ss = skyScale[lv];
    if (kind === 0 || kind === 2) {
        // Rain and the storm's drops along their gust-swayed lean, plus the gust swaying their whole fall.
        const l = kind === 2 ? Math.max(1, lv) : lv, lean = dropLean[l];
        const fall = dropFall[l] * dropJitter * (h + dropRun) * Math.hypot(1, lean * dropLeanWiden);
        return fall + lean * skyGust * (h + dropRange + dropSize[l] * dropLenMax);
    }
    if (kind === 1)
        return hailRate * ss * (Math.max(hailLand * h, hailRing) + hailBounce);
    if (kind === 3) {
        const fall = snowRate * ss * (h + snowRun);
        return fall + snowSway[0] * snowSway[1] + snowSway2[0] * (snowSway2[1] + snowSway2[2] * fall) + snowWind * skyGust
            + snowSpin[0] * snowSpin[1];
    }
    if (kind === 4)
        return ss * (fogDrift * w + fogBand * noiseSlope * fogWobble * h + fogEdge);
    return heatRise * ss * h + heatSway + heatRipple * ss + heatDrift + heatBreak * ss;
}

// Whether a wing's card is open, from the wing w: its face asks (faceOpen), a click toggled its list (tileOpen, if
// tileOpenable), the pointer dwelt on it (hovered and dwelt; never on the shelf, which grows in the island), or it is held
// open pointerless (heldOpen: island card over IPC). Beside the launcher a lone pill opens, either side; a side folded
// into the sheet (vertical) never. w.carded, a function, is read only when it decides (cardness past half): opening the
// card moves the wing's spring, which sets carded in the same turn (else a loop).
function cardOpen(w) {
    if (!w.has || w.vertical)
        return false;
    if (w.faceOpen || w.tileOpen && w.tileOpenable)
        return true;
    const asked = w.hovered && w.dwelt && w.source !== "shelf" || w.heldOpen;
    return !!asked && (!(w.cardness >= 0.5) || !!w.carded());
}

// Relative luminance (WCAG, 0..1) of a colour ({r, g, b} in 0..1, as a QML color).
function luminanceOf(c) {
    return [c.r, c.g, c.b].map(v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)).reduce((s, v, i) => s + v * [0.2126, 0.7152, 0.0722][i], 0);
}
function contrastOfLuminances(la, lb) {
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}
// WCAG contrast of two colours.
function contrast(a, b) {
    return contrastOfLuminances(luminanceOf(a), luminanceOf(b));
}

// The mean luminance of a logo, from its RGBA pixels (a canvas's getImageData, 0..255), each weighted by its alpha so a
// silhouette on a clear ground counts only where it is drawn; -1 when nothing is drawn.
function logoLuminance(pixels) {
    let sum = 0, weight = 0;
    for (let i = 0; i + 3 < pixels.length; i += 4) {
        const a = pixels[i + 3] / 255;
        if (a === 0)
            continue;
        sum += luminanceOf({ "r": pixels[i] / 255, "g": pixels[i + 1] / 255, "b": pixels[i + 2] / 255 }) * a;
        weight += a;
    }
    return weight > 0 ? sum / weight : -1;
}

// The shape under an app's logo (IslandAppIcon): of two tones, the one that contrasts most with the logo's mean luminance
// (logoLuminance): a white Android silhouette sits on the dark one, a black glyph on the light one, a photo on whichever
// reads. Unknown (-1) keeps the first.
function logoShapeTone(logoLum, first, second) {
    if (logoLum < 0)
        return first;
    return contrastOfLuminances(logoLum, luminanceOf(second)) > contrastOfLuminances(logoLum, luminanceOf(first)) ? second : first;
}

// A liquid tone that reads on its pill: `tone`, laid at `alpha` over `surface`, if it keeps `min` contrast with it, else
// `fallback` (a stock theme's error is pale in light mode; its container's text tone is not).
var legibleMin = 3;
function laidOver(tone, surface, alpha) {
    return {
        "r": surface.r + (tone.r - surface.r) * alpha,
        "g": surface.g + (tone.g - surface.g) * alpha,
        "b": surface.b + (tone.b - surface.b) * alpha
    };
}
function legible(tone, fallback, surface, alpha, min) {
    return contrast(laidOver(tone, surface, alpha), surface) >= min ? tone : fallback;
}

// The A1 battery glyph's geometry (BubbleChargeGlyph): its pile is 10 of the 19 units of its box, so the flat pill's
// value sits closer to it than to a full-width icon.
var batteryPileUnits = 10;
var batteryBoxUnits = 19;

// A tone's ink on its own tonal chip (`tone` laid at `alpha` over `surface`): the tone if it keeps `min` contrast with the
// chip (4.5:1 a text, 3:1 an icon), else `fallback`.
var textMin = 4.5;
function inkOnTonal(tone, fallback, surface, alpha, min) {
    return contrast(tone, laidOver(tone, surface, alpha)) >= min ? tone : fallback;
}

// A time under the icon of an upright pill, one pill wide: the clock (m:ss) under clockUntilS, then minutes, then hours.
// The units come translated from the caller (I18n.tr("%1m"), I18n.tr("%1h", ...)): the kit has no I18n, so without
// them it falls back to the bare "%1m" and "%1h".
var clockUntilS = 600;
var minuteS = 60;
var hourS = 3600;
function standClock(seconds, minutes, hours) {
    if (!isFinite(seconds))
        return "";
    const s = Math.max(0, Math.floor(seconds));
    if (s < clockUntilS)
        return Math.floor(s / minuteS) + ":" + String(s % minuteS).padStart(2, "0");
    return s < hourS ? (minutes ?? "%1m").replace("%1", Math.floor(s / minuteS)) : (hours ?? "%1h").replace("%1", Math.floor(s / hourS));
}

// A playing track standing beside the launcher: its liquid is how far it played, its value the time left.
function trackStand(position, length, minutes, hours) {
    if (!(length > 0))
        return {
            "level": -1,
            "text": ""
        };
    const p = Math.max(0, Math.min(length, position));
    return {
        "level": p / length,
        "text": standClock(length - p, minutes, hours)
    };
}

// The infinity glyph's light (no permanent sweep: a continuous light stops). A few turns of
// its sweep after each showing, then it brakes from its own speed (the brake curve starts at slope 3, so braking over T
// covers what the sweep would in T / 3: no jolt), lands centred on the crossing, core first, glow and halo just after
// (follow-through), and the whole loop lights up from there both ways (Interior's out). Not M3's emphasized decelerate:
// it starts at slope 14, a jolt for a light already moving. Times at DMS's default speed, divided by pace.
var infinityTurns = 3;
var infinitySweepMs = 2500;
var infinityBrakeCurve = [0.25, 0.75, 0.1, 1, 1, 1];
var infinityOutCurve = [0.23, 1, 0.32, 1, 1, 1];
// After the last turn: when the core, glow and halo have landed; when the loop starts lighting up, and for how long.
var infinityLands = [400, 450, 500];
var infinitySpread = [450, 700];

// The play of one showing. shares: each layer's dash as a share of the loop. Reduced motion or speed 0 (pace 0): no
// turn, the rested glyph at once.
function infinityRest(turns, sweepMs, pace, reduced, shares) {
    if (reduced || !(pace > 0) || !(turns > 0))
        return {
            "turns": 0,
            "sweepMs": 0,
            "layers": [],
            "spreadAtMs": 0,
            "spreadMs": 0,
            "restMs": 0
        };
    const sweep = sweepMs / pace;
    const lit = turns * sweep;
    const slope = infinityBrakeCurve[1] / infinityBrakeCurve[0];
    const layers = shares.map((share, i) => {
        const end = lit + infinityLands[Math.min(i, infinityLands.length - 1)] / pace;
        // When the layer's centre would reach the crossing at full speed; braking over T lands it T (1 - 1 / slope) later.
        const arrive = sweep * (turns - share / 2);
        const brakeMs = (end - arrive) * slope / (slope - 1);
        return {
            "runMs": end - brakeMs,
            "brakeMs": brakeMs
        };
    });
    const spreadAtMs = lit + infinitySpread[0] / pace;
    const spreadMs = infinitySpread[1] / pace;
    return {
        "turns": turns,
        "sweepMs": sweep,
        "layers": layers,
        "spreadAtMs": spreadAtMs,
        "spreadMs": spreadMs,
        "restMs": spreadAtMs + spreadMs
    };
}

// A battery level's steps: 0 up to batterySteps[0] (low), 1 up to [1], 2 up to [2], 3 above.
var batterySteps = [0.15, 0.4, 0.6];
function levelStep(level) {
    return level <= batterySteps[0] ? 0 : level <= batterySteps[1] ? 1 : level <= batterySteps[2] ? 2 : 3;
}

// A battery level's colour, the one source: error, warning, warning and success half and half,
// success; each kept 3:1 on `surface` (legible), else `ink`. roles: {error, warning, success, surface, ink}.
function batteryHue(level, roles) {
    const mix = (a, b) => ({
            "r": (a.r + b.r) / 2,
            "g": (a.g + b.g) / 2,
            "b": (a.b + b.b) / 2
        });
    const tone = [roles.error, roles.warning, mix(roles.warning, roles.success), roles.success][levelStep(level)];
    return legible(tone, roles.ink, roles.surface, 1, legibleMin);
}

// The more legible of two inks over a tone (a bolt or a value on the liquid).
function inkOn(tone, a, b) {
    return contrast(tone, a) >= contrast(tone, b) ? a : b;
}

// A battery bubble's shape by its level: the alert's to batteryAlertLevel, warning while low, else its own ("").
var batteryAlertLevel = 0.05;
function batteryShape(level) {
    return level <= batteryAlertLevel ? "alert" : level <= batterySteps[0] ? "warning" : "";
}
