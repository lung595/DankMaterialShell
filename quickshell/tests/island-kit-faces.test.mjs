import assert from "node:assert/strict";
import test from "node:test";
import { K } from "./island-kit-load.mjs";

test("a closing bubble fuses only when it merges itself, never as the island's own face or activity closes", () => {
    const own = { "inPlace": true, "reduced": false, "occupantBefore": "plugin|dms:eyes:1", "occupantNow": "plugin|dms:eyes:1" };
    assert.equal(K.closeStyle(own), "fuse");
    // The eye break leaves the island (a click): the media bubble beside it goes back, no fusion.
    assert.equal(K.closeStyle(Object.assign({}, own, { "occupantNow": "home|" })), "shrink");
    // Another bubble's face taking the island does not fuse either.
    assert.equal(K.closeStyle(Object.assign({}, own, { "occupantBefore": "home|", "occupantNow": "copy|", "source": "trash" })), "shrink");
    // The island taking the bubble's own info (the copy's face, the shelf's card) is the bubble going in: it fuses.
    assert.equal(K.closeStyle(Object.assign({}, own, { "occupantBefore": "home|", "occupantNow": "copy|", "source": "copy" })), "fuse");
    assert.equal(K.closeStyle(Object.assign({}, own, { "occupantBefore": "home|", "occupantNow": "plugin|dms:shelf:7", "source": "shelf" })), "fuse");
    assert.equal(K.closeStyle(Object.assign({}, own, { "occupantBefore": "home|", "occupantNow": "plugin|dms:shelfx:7", "source": "shelf" })), "shrink");
    assert.equal(K.closeStyle(Object.assign({}, own, { "reduced": true })), "fade");
    assert.equal(K.closeStyle(Object.assign({}, own, { "inPlace": false })), "shrink");
});

test("a card the bubble opened itself (2FA, Undo) still fuses when it leaves; one the pointer holds open withdraws", () => {
    const own = { "ready": true, "hoverGrow": 1, "selfOpened": true, "hovered": false };
    assert.equal(K.closesInPlace(own), true);
    assert.equal(K.closesInPlace({ ...own, "hovered": true }), false);
    assert.equal(K.closesInPlace({ ...own, "selfOpened": false }), false);
    assert.equal(K.closesInPlace({ ...own, "hoverGrow": 0, "selfOpened": false, "hovered": true }), true, "a shut pill");
    assert.equal(K.closesInPlace({ ...own, "ready": false }), false, "not seen");
});

test("the eye's blink, read off its clock: shuts on its beats, stays shut, reopens, then is over", () => {
    const close = K.beat("blinkClose", 250), shut = K.beat("blinkShut", 250), open = K.beat("blinkOpen", 250);
    const ease = [0.2, 0, 0, 1];
    assert.equal(K.eyeBlinkAt(0, 250, 1, ease, ease), 0);
    assert.equal(K.eyeBlinkAt(close + 1, 250, 1, ease, ease), 1);
    assert.equal(K.eyeBlinkAt(close + shut - 1, 250, 1, ease, ease), 1);
    const mid = K.eyeBlinkAt(close + shut + open / 2, 250, 1, ease, ease);
    assert.ok(mid > 0 && mid < 1);
    assert.equal(K.eyeBlinkAt(close + shut + open, 250, 1, ease, ease), -1);
    // Twice: a gap, then shut again; over after the second.
    const one = close + shut + open + K.beat("blinkTwice", 250);
    assert.equal(K.eyeBlinkAt(one + close + 1, 250, 2, ease, ease), 1);
    assert.equal(K.eyeBlinkAt(2 * one, 250, 2, ease, ease), -1);
    // No animations: no blink at all.
    assert.equal(K.eyeBlinkAt(10, 0, 1, ease, ease), -1);
});

test("a light theme's track is fainter, so the liquid keeps 3:1 against it", () => {
    assert.equal(K.fillAlpha, 0.75);
    assert.equal(K.waveTrackAlpha(false), 0.24);
    assert.equal(K.waveTrackAlpha(true), 0.08);
});

test("the eye blinks every 2 to 6 s at DMS's default speed, shuts fast and opens slower, still at speed 0", () => {
    assert.equal(K.beatIn("blinkGap", 0, 250), 2000);
    assert.equal(K.beatIn("blinkGap", 1, 250), 6000);
    assert.equal(K.beatIn("blinkGap", 0.5, 500), 8000);
    assert.equal(K.beatIn("blinkGap", 0.5, 0), 0);
    assert.equal(K.beatIn("nope", 0.5, 250), 250);
    assert.ok(K.beat("blinkClose", 250) < K.beat("blinkOpen", 250));
    const blink = K.beat("blinkClose", 250) + K.beat("blinkShut", 250) + K.beat("blinkOpen", 250);
    assert.ok(blink >= 250 && blink <= 400, `a blink lasts ${blink} ms`);
    assert.ok(K.beat("saccade", 250) < K.beat("blinkOpen", 250));
    assert.ok(K.eyeTwiceShare > 0 && K.eyeTwiceShare < 0.5);
});

test("the eye mostly glances far off to a side and up, mirrored, and rests longer there", () => {
    let far = 0;
    for (let i = 0; i < 1000; i++) {
        const r = [(i * 0.618) % 1, (i * 0.414) % 1, (i * 0.732) % 1, (i * 0.236) % 1];
        const g = K.eyeGlance(r[0], r[1], r[2], r[3]);
        assert.ok(Math.abs(g.x) <= 1 && Math.abs(g.y) <= 1);
        if (g.far) {
            far++;
            assert.ok(Math.abs(g.x) >= 0.6 && g.y < 0, `far glance ${g.x}, ${g.y}`);
        }
    }
    assert.ok(far > 600 && far < 800, `${far} far glances in 1000`);
    const left = K.eyeGlance(0.1, 0.2, 0.5, 0.5), right = K.eyeGlance(0.1, 0.8, 0.5, 0.5);
    assert.equal(left.x, -right.x);
    assert.equal(left.y, right.y);
    assert.ok(K.beatIn("fixNear", 1, 250) <= K.beatIn("fixFar", 0, 250));
    assert.ok(K.beatIn("fixNear", 0, 250) >= K.beat("saccade", 250) * 2);
});

test("a copy's check draws in 0.3 s and its digits hop 40 ms apart, at DMS's animation speed; none at speed 0", () => {
    assert.equal(K.beat("checkDraw", 250), 300);
    assert.equal(K.beat("hopStep", 250), 40);
    assert.equal(K.beat("hopStep", 500), 80);
    assert.equal(K.beat("checkDraw", 0), 0);
    assert.equal(K.beat("hopStep", 0), 0);
    assert.ok(K.hopLift > 0);
});

// A wing given with carded as a plain value.
const cardOpenOf = w => K.cardOpen({ ...w, "carded": () => w.carded });

test("a hovered pill opens its card beside the launcher on either side, a folded side or the shelf never", () => {
    const pill = { "has": true, "hovered": true, "dwelt": true, "source": "system", "cardness": 1, "carded": true };
    assert.equal(cardOpenOf(pill), true, "machine pill standing beside the launcher");
    assert.equal(cardOpenOf({ ...pill, "source": "transfer" }), true);
    assert.equal(cardOpenOf({ ...pill, "carded": false }), false, "a side folded into the sheet");
    assert.equal(cardOpenOf({ ...pill, "source": "shelf" }), false);
    assert.equal(cardOpenOf({ ...pill, "dwelt": false }), false, "a short pass only breathes");
    assert.equal(cardOpenOf({ ...pill, "cardness": 0, "carded": false }), true, "flat pill");
    assert.equal(cardOpenOf({ ...pill, "vertical": true }), false);
    assert.equal(cardOpenOf({ ...pill, "has": false, "faceOpen": true }), false);
    assert.equal(cardOpenOf({ "has": true, "faceOpen": true }), true);
    assert.equal(cardOpenOf({ "has": true, "tileOpen": true, "tileOpenable": true }), true);
    assert.equal(cardOpenOf({ "has": true, "heldOpen": true, "cardness": 1, "carded": true }), true);
});

test("cardOpen reads carded only when it decides: the binding that opens the card never depends on the spring it moves", () => {
    let reads = 0;
    const open = (w, carded) => K.cardOpen({ ...w, "carded": () => (reads++, carded) });
    const pill = { "has": true, "hovered": true, "dwelt": true, "source": "system", "cardness": 1 };
    for (const w of [{ ...pill, "has": false }, { ...pill, "vertical": true }, { ...pill, "faceOpen": true }, { ...pill, "tileOpen": true, "tileOpenable": true }, { ...pill, "dwelt": false }, { ...pill, "source": "shelf" }, { ...pill, "cardness": 0.2 }])
        open(w, false);
    assert.equal(reads, 0, "no read when the answer does not hang on carded");
    assert.equal(open(pill, true), true);
    assert.equal(open(pill, false), false);
    assert.equal(reads, 2, "read once per decision");
});

test("the alert liquid keeps 3:1 on its pill: a pale error falls back to the dark container tone", () => {
    const white = { "r": 1, "g": 0.97, "b": 1 }, dark = { "r": 0.08, "g": 0.07, "b": 0.09 };
    const pale = { "r": 0.95, "g": 0.72, "b": 0.71 }, deep = { "r": 0.25, "g": 0.05, "b": 0.04 }, red = { "r": 0.73, "g": 0.1, "b": 0.1 };
    assert.equal(K.legible(pale, deep, white, 0.75, 3), deep, "stock error in light mode");
    assert.equal(K.legible(pale, deep, dark, 0.75, 3), pale, "stock error in dark mode");
    assert.equal(K.legible(red, deep, white, 0.75, 3), red, "a theme with a real light error keeps it");
    assert.ok(Math.abs(K.contrast(white, { "r": 0, "g": 0, "b": 0 }) - 20.1) < 0.2);
    assert.equal(K.contrast(red, red), 1);
});

test("an alert's rings, read off their clock: two leave a gap apart, each is gone after its span, then it is over", () => {
    const span = 1300, gap = K.beat("ringGap", 250), pause = K.beat("ringPause", 250);
    assert.ok(gap > 0 && gap < span && pause > gap);
    // One ring: it grows from 0, is gone at its span (1 = not out).
    assert.equal(K.ringT(0, span, gap, 1, pause, 1, 0), 0);
    assert.equal(K.ringT(span / 2, span, gap, 1, pause, 1, 0), 0.5);
    assert.equal(K.ringT(span, span, gap, 1, pause, 1, 0), 1);
    assert.ok(!K.ringsOver(span - 1, span, gap, 1, pause, 1));
    assert.ok(K.ringsOver(span, span, gap, 1, pause, 1));
    // Two rings: the second leaves one gap later, while the first still grows.
    assert.equal(K.ringT(gap / 2, span, gap, 2, pause, 1, 1), 1);
    assert.equal(K.ringT(gap, span, gap, 2, pause, 1, 0), gap / span);
    assert.equal(K.ringT(gap, span, gap, 2, pause, 1, 1), 0);
    assert.equal(K.ringT(span + 1, span, gap, 2, pause, 1, 0), 1);
    assert.ok(K.ringsOver(span + gap, span, gap, 2, pause, 1));
    // No animations: over at once.
    assert.ok(K.ringsOver(0, 0, 0, 2, 0, 1));
    assert.equal(K.ringT(0, 0, 0, 2, 0, 1, 0), 1);
    assert.equal(K.beat("ringGap", 0), 0);
});

test("a critical alert's shape: its container, full error once folded on a light theme (the container is too pale there)", () => {
    const roles = (...a) => Array.from(K.alertRoles(...a));
    assert.deepEqual(roles("critical", false, true), ["errorContainer", "onErrorContainer"]);
    assert.deepEqual(roles("critical", true, false), ["errorContainer", "onErrorContainer"]);
    assert.deepEqual(roles("critical", true, true), ["error", "onError"]);
    assert.equal(K.alertRoles("important", true, true), null);
    assert.equal(K.alertRoles("", true, true), null);
});

test("a ringing call rings again after a pause, forever, and its shape swings on each ring, still in the pause", () => {
    const span = 1300, gap = K.beat("ringGap", 250), pause = K.beat("ringPause", 250);
    const cycle = gap + span + pause;
    // cycles 0: never over; the next cycle's rings leave as the first's did.
    assert.ok(!K.ringsOver(100 * cycle, span, gap, 2, pause, 0));
    assert.equal(K.ringT(cycle + gap, span, gap, 2, pause, 0, 1), 0);
    assert.equal(K.ringT(gap + span + pause / 2, span, gap, 2, pause, 0, 0), 1);
    assert.equal(K.ringT(gap + span + pause / 2, span, gap, 2, pause, 0, 1), 1);
    // The swing (-1..1) on the wing's entry spring: at rest as a ring leaves, kicked right after, settled in the pause.
    const swing = ms => K.ringSwing(ms, span, gap, 2, pause, 0, 220, 0.6, 1);
    assert.equal(swing(0), 0);
    const peak = Math.max(...Array.from({ length: 40 }, (_, i) => Math.abs(swing(i * 10))));
    assert.ok(peak > 0.9 && peak <= 1.2);
    assert.ok(Math.abs(swing(cycle - 1)) < 0.01);
    assert.equal(swing(cycle + 50), swing(50));
    // Over (one cycle done) or no animations: still.
    assert.equal(K.ringSwing(cycle * 2, span, gap, 2, pause, 1, 220, 0.6, 1), 0);
    assert.equal(K.ringSwing(50, 0, 0, 2, 0, 0, 220, 0.6, 1), 0);
});

test("a standing value stays short enough for the upright pill's width", () => {
    // Under ten minutes the clock; then whole minutes, then whole hours, in the caller's translated units.
    const clock = s => K.standClock(s, "%1 min", "%1 h");
    assert.equal(clock(0), "0:00");
    assert.equal(clock(65.4), "1:05");
    assert.equal(clock(599), "9:59");
    assert.equal(clock(754), "12 min");
    assert.equal(clock(3599), "59 min");
    assert.equal(clock(7300), "2 h");
    assert.equal(clock(-3), "0:00");
    assert.equal(clock(NaN), "");
});

test("a track's standing gauge: how far it played and the time left, nothing without a length", () => {
    assert.deepEqual({ ...K.trackStand(50, 200) }, { "level": 0.25, "text": "2:30" });
    assert.deepEqual({ ...K.trackStand(0, 7300, "%1m", "%1h") }, { "level": 0, "text": "2h" });
    assert.deepEqual({ ...K.trackStand(250, 200) }, { "level": 1, "text": "0:00" });
    assert.deepEqual({ ...K.trackStand(10, 0) }, { "level": -1, "text": "" });
    assert.deepEqual({ ...K.trackStand(10, NaN) }, { "level": -1, "text": "" });
});

test("the upright pill's gauge starts under the icon's shape, by the flat track's gap, and leaves the icon alone on top", () => {
    const size = 32, gap = 3, inset = 4;
    // Upright, three pills tall: the icon's shape fills the top pill, the gauge the rest less the gap and the bottom inset.
    assert.equal(K.uprightGaugeTop(size, gap, inset, 1), 35);
    assert.equal(K.uprightGaugeHeight(96, size, gap, inset, 1), 57);
    // The standing value (centred between the gap and the inset) sits in the gauge's middle.
    assert.equal(K.uprightGaugeTop(size, gap, inset, 1) + K.uprightGaugeHeight(96, size, gap, inset, 1) / 2, (size + gap + 96 - inset) / 2);
    // Flat, it is the whole pill inside its inset, never empty (its liquid's spring settles by the pixel).
    assert.equal(K.uprightGaugeTop(size, gap, inset, 0), 4);
    assert.equal(K.uprightGaugeHeight(32, size, gap, inset, 0), 24);
    // Halfway up, halfway under; never negative.
    assert.equal(K.uprightGaugeTop(size, gap, inset, 0.5), 19.5);
    assert.equal(K.uprightGaugeHeight(30, size, gap, inset, 1), 0);
});
