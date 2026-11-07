import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const load = name => {
    const ctx = vm.createContext({});
    vm.runInContext(readFileSync(new URL(`../Common/${name}`, import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
    return ctx;
};
const K = load("IslandKit.js");
const C = load("IslandCharge.js");
const A = load("IslandActivities.js");

const rgb = hex => ({ "r": parseInt(hex.slice(1, 3), 16) / 255, "g": parseInt(hex.slice(3, 5), 16) / 255, "b": parseInt(hex.slice(5, 7), 16) / 255, "a": 1 });
const plain = v => JSON.parse(JSON.stringify(v));
const same = (a, b) => Math.abs(a.r - b.r) < 1e-9 && Math.abs(a.g - b.g) < 1e-9 && Math.abs(a.b - b.b) < 1e-9;
// DMS's stock dark theme: error, warning, success on its surface, the surface's text as the fallback ink.
const dark = { "error": rgb("#f2b8b5"), "warning": rgb("#ff9800"), "success": rgb("#4caf50"), "surface": rgb("#141218"), "ink": rgb("#e6e0e9") };

test("a battery level's steps: to 15 %, to 40 %, to 60 %, above", () => {
    assert.deepEqual([0, 0.05, 0.15, 0.151, 0.4, 0.41, 0.6, 0.61, 1].map(l => K.levelStep(l)), [0, 0, 0, 1, 1, 2, 2, 3, 3]);
});

test("a battery's hue: error, warning, warning and success half and half, success (mouvement.md §6)", () => {
    assert.ok(same(K.batteryHue(0.05, dark), dark.error));
    assert.ok(same(K.batteryHue(0.15, dark), dark.error));
    assert.ok(same(K.batteryHue(0.3, dark), dark.warning));
    const mid = K.batteryHue(0.5, dark);
    assert.ok(same(mid, { "r": (dark.warning.r + dark.success.r) / 2, "g": (dark.warning.g + dark.success.g) / 2, "b": (dark.warning.b + dark.success.b) / 2 }));
    assert.ok(same(K.batteryHue(0.64, dark), dark.success));
    assert.ok(same(K.batteryHue(1, dark), dark.success));
});

test("a battery's hue keeps 3:1 on its surface, else it gives way to the ink", () => {
    const pale = Object.assign({}, dark, { "surface": rgb("#fef7ff"), "ink": rgb("#1d1b20"), "success": rgb("#c8f0cc") });
    assert.ok(K.contrast(pale.success, pale.surface) < 3);
    assert.ok(same(K.batteryHue(0.9, pale), pale.ink));
    for (const l of [0.05, 0.3, 0.5, 0.9])
        assert.ok(K.contrast(K.batteryHue(l, dark), dark.surface) >= 3, `${l}`);
});

test("a battery bubble's shape: the alert's to 5 %, warning to 15 %, its own above", () => {
    assert.deepEqual([0, 0.05, 0.06, 0.15, 0.16, 1].map(l => K.batteryShape(l)), ["alert", "alert", "warning", "warning", "", ""]);
});

test("the ink over the liquid is the more legible of the two", () => {
    const black = rgb("#000000"), white = rgb("#ffffff");
    assert.equal(K.inkOn(rgb("#4caf50"), black, white), black);
    assert.equal(K.inkOn(rgb("#b3261e"), black, white), white);
});



test("a reading's step: plugged, unplugged, full; the first reading stays quiet", () => {
    const r = (plugged, charging, level) => ({ plugged, charging, level });
    assert.equal(C.step(null, r(true, true, 0.5)), "");
    assert.equal(C.step(r(false, false, 0.5), r(true, true, 0.5)), "plugged");
    assert.equal(C.step(r(true, true, 0.5), r(false, false, 0.5)), "unplugged");
    assert.equal(C.step(r(true, true, 0.99), r(true, false, 1)), "full");
    // Plugged in already full: it says so once, never "charging".
    assert.equal(C.step(r(false, false, 1), r(true, false, 1)), "full");
    // A level step while it charges says nothing.
    assert.equal(C.step(r(true, true, 0.5), r(true, true, 0.51)), "");
    assert.equal(C.step(r(false, false, 0.5), r(false, false, 0.4)), "");
});

test("the power history keeps its whole span within its bound, halving its resolution when full", () => {
    let h = [];
    for (let i = 0; i < 1000; i++) {
        h = C.record(h, i * 30000, 20 + (i % 7), A.chargeHistoryMax);
        assert.ok(h.length <= A.chargeHistoryMax, `${h.length}`);
    }
    assert.equal(h[0][0], 0);
    assert.equal(h[h.length - 1][0], 999 * 30000);
    for (let i = 1; i < h.length; i++)
        assert.ok(h[i][0] > h[i - 1][0]);
    // It never edits the history it was given.
    const before = [[0, 10]];
    C.record(before, 1, 12, 240);
    assert.deepEqual(before, [[0, 10]]);
});

test("the history's average power and energy received, over its time", () => {
    const h = [[0, 20], [1800000, 40], [3600000, 40]];
    const s = C.summary(h);
    // 30 W for half an hour then 40 W for half an hour: 35 Wh in one hour.
    assert.equal(s.wh, 35);
    assert.equal(s.avg, 35);
    assert.equal(s.start, 0);
    assert.equal(s.end, 3600000);
    assert.deepEqual(JSON.parse(JSON.stringify(C.summary([]))), { "avg": 0, "wh": 0, "start": 0, "end": 0, "peak": 0 });
    assert.equal(C.summary(h).peak, 40);
});

test("time left and the clock time it is full at", () => {
    assert.deepEqual(JSON.parse(JSON.stringify(C.left(47 * 60))), { "h": 0, "m": 47 });
    assert.deepEqual(JSON.parse(JSON.stringify(C.left(65 * 60 + 1))), { "h": 1, "m": 6 });
    assert.deepEqual(JSON.parse(JSON.stringify(C.left(30))), { "h": 0, "m": 1 });
    assert.equal(C.left(0), null);
    assert.equal(C.left(NaN), null);
    assert.equal(C.left(Infinity), null);
    const at = new Date(2026, 9, 27, 13, 57).getTime();
    assert.equal(C.clock(at + 47 * 60000, true), "14:44");
    assert.equal(C.clock(new Date(2026, 9, 27, 9, 5).getTime(), true), "09:05");
    assert.equal(C.clock(at + 47 * 60000, false), "2:44 PM");
    assert.equal(C.clock(new Date(2026, 9, 27, 0, 5).getTime(), false), "12:05 AM");
});

test("the power's word by the USB PD tiers: slow under 10 W, normal to 30, fast to 65, ultra above, none at 0", () => {
    assert.deepEqual([0, -1, 5, 9.9, 10, 29.9, 30, 64.9, 65, 240].map(w => C.speed(w)), ["", "", "slow", "slow", "normal", "normal", "fast", "fast", "ultra", "ultra"]);
});

test("what the session gave: whole percent and minutes since plugging in; nothing before a plug", () => {
    assert.deepEqual(plain(C.gain(0.61, 0.64, 1000, 1000 + 4 * 60000)), { "pct": 3, "min": 4 });
    assert.deepEqual(plain(C.gain(0.64, 0.64, 1000, 1000 + 30000)), { "pct": 0, "min": 0 });
    assert.deepEqual(plain(C.gain(0.64, 0.64, 1000, 1000 + 59999)), { "pct": 0, "min": 0 });
    assert.equal(C.gain(0.61, 0.64, 0, 5), null);
});

test("the gain chip's percent: signed, a plus even at zero, a minus when the session lost, none before a minute", () => {
    assert.equal(C.gainPct(C.gain(0.61, 0.64, 1000, 1000 + 4 * 60000)), "+3");
    assert.equal(C.gainPct(C.gain(0.64, 0.64, 1000, 1000 + 60000)), "+0");
    assert.equal(C.gainPct(C.gain(0.64, 0.62, 1000, 1000 + 2 * 60000)), "-2");
    assert.equal(C.gainPct(C.gain(0.61, 0.64, 1000, 1000 + 59999)), "");
    assert.equal(C.gainPct(null), "");
});

test("the level said as a whole percent rounds: 99.6 % charging reads 100 %, as on the pill and the bubble", () => {
    assert.deepEqual([0.996, 0.994, 0.29, 0.096, 0.005, 0].map(l => C.percent(l)), [100, 99, 29, 10, 1, 0]);
});

test("a chip's reveal on the island's growth: in order, each over its own slice of the last half, none before", () => {
    // 3 chips over the growth's second half: 0.5-0.667, 0.667-0.833, 0.833-1.
    assert.equal(C.revealAt(0.4, 0, 3), 0);
    assert.equal(C.revealAt(0.5, 0, 3), 0);
    assert.ok(Math.abs(C.revealAt(0.5 + 1 / 12, 0, 3) - 0.5) < 1e-9);
    assert.equal(C.revealAt(0.7, 0, 3), 1);
    assert.ok(Math.abs(C.revealAt(0.7, 1, 3) - 0.2) < 1e-9);
    assert.equal(C.revealAt(1, 2, 3), 1);
    assert.equal(C.revealAt(2, 2, 3), 1);
});

test("the sea at the mockup's 84 px: 0.7 to 5 px of swell, 10 to 50 px a second of rise, 3 to 20 bubbles", () => {
    assert.ok(Math.abs(C.seaAmp(0, 84) - 0.7) < 1e-9 && Math.abs(C.seaAmp(1, 84) - 5) < 1e-9);
    assert.ok(Math.abs(C.bubbleRise(0, 84) - 10) < 1e-9 && Math.abs(C.bubbleRise(1, 84) - 50) < 1e-9);
    assert.equal(C.seaAmp(1, 42) * 2, C.seaAmp(1, 84));
    assert.equal(C.bubbles(0), 3);
    assert.equal(C.bubbles(1), 20);
    assert.equal(C.bubbles(7), 20);
    assert.ok(C.seaPace(1) > C.seaPace(0) && C.seaPace(0) > 0);
});

test("the sea's fastest motion is the quicker of a crest and a bubble, and grows with the power", () => {
    const h = 84;
    for (const s of [0, 0.3, 1])
        assert.equal(C.seaSpeed(s, h), Math.max(C.seaAmp(s, h) * C.seaPace(s) * C.crestGain, C.bubbleRise(s, h) * C.bubbleFastest));
    assert.ok(C.seaSpeed(1, h) > C.seaSpeed(0, h));
    // Under the K7 ceiling at full power: a 120 per second clock moves it under a pixel a step.
    assert.ok(C.seaSpeed(1, h) / 120 < 1);
});

test("the mark: a slower breath at rest, its scale around one, its lobes never past C28's hollow, a faster turn", () => {
    assert.equal(C.breathPeriod(0), C.breathRestS);
    assert.ok(Math.abs(C.breathPeriod(1) - C.breathFastS) < 1e-9);
    assert.equal(C.markScale(0.5, 0), 1);
    assert.ok(C.markScale(1, Math.PI / 2) > C.markScale(0, Math.PI / 2));
    assert.ok(C.markScale(1, Math.PI / 2) < 1 + 0.07);
    for (const s of [-1, 0, 0.5, 1, 4]) {
        const k = C.markDepth(s);
        assert.ok(k > 0 && (1 - k) / (1 + k) >= 0.78, `depth ${k} at ${s}`);
    }
    assert.ok(C.markTurn(1) > C.markTurn(0.5) && C.markTurn(0) > 0);
});

test("the odometer's wheels: the units roll with the fraction, the tens only from 9 to 0, three wheels from 99.5", () => {
    assert.equal(C.rollAt(64, 1), 4);
    assert.equal(C.rollAt(64, 10), 6);
    assert.ok(Math.abs(C.rollAt(64.25, 1) - 4.25) < 1e-9);
    assert.equal(C.rollAt(64.25, 10), 6);
    assert.ok(Math.abs(C.rollAt(69.5, 10) - 6.5) < 1e-9);
    assert.ok(Math.abs(C.rollAt(99.5, 100) - 0.5) < 1e-9);
    assert.ok(Math.abs(C.rollAt(99.5, 10) - 9.5) < 1e-9);
    assert.equal(C.rollAt(100, 100), 1);
    assert.equal(C.rollAt(100, 10), 0);
    assert.equal(C.rollAt(-3, 1), 0);
    assert.equal(C.rollAt(NaN, 1), 0, "an unread level stands at 0");
    assert.equal(C.rollAt(Infinity, 100), 1, "past the top stands at 100");
    assert.equal(C.rollAt(Infinity, 1), 0);
    assert.equal(C.wheels(99.4), 2);
    assert.equal(C.wheels(99.5), 3);
});

test("the slow wave's pace: the base cycles a second at the normal tier, quicker with the power, within bounds", () => {
    const base = 2 * Math.PI * C.waveHz;
    assert.ok(Math.abs(C.waveRate(30) - base) < 1e-9);
    assert.ok(C.waveRate(65) > base && C.waveRate(65) < base * 1.6);
    assert.ok(Math.abs(C.waveRate(240) - base * 1.6) < 1e-9);
    assert.ok(Math.abs(C.waveRate(0) - base * 0.5) < 1e-9);
});

test("the power's share and the live wave's height: square root of the fast tier, half a unit to two", () => {
    assert.equal(C.share(0), 0);
    assert.equal(C.share(-5), 0);
    assert.ok(Math.abs(C.share(C.speedFastMaxW / 4) - 0.5) < 1e-9);
    assert.equal(C.share(C.speedFastMaxW), 1);
    assert.equal(C.share(240), 1);
    assert.equal(C.waveAmp(0, 2), 1);
    assert.equal(C.waveAmp(240, 2), 4);
    assert.ok(C.waveAmp(20, 2) > 1 && C.waveAmp(20, 2) < 4);
});

test("the power chip's text (4.5:1) and bolt (3:1) read on the tonal chip itself, every step and theme", () => {
    const light = { "error": rgb("#b3261e"), "warning": rgb("#ff9800"), "success": rgb("#4caf50"), "surface": rgb("#fef7ff"), "ink": rgb("#1d1b20") };
    const black = Object.assign({}, dark, { "surface": rgb("#000000") });
    for (const roles of [dark, light, black]) {
        for (const l of [0.05, 0.3, 0.5, 0.9]) {
            const hue = K.batteryHue(l, roles), chip = K.laidOver(hue, roles.surface, C.tonalAlpha);
            assert.ok(K.contrast(K.inkOnTonal(hue, roles.ink, roles.surface, C.tonalAlpha, K.textMin), chip) >= K.textMin, `text ${l}`);
            assert.ok(K.contrast(K.inkOnTonal(hue, roles.ink, roles.surface, C.tonalAlpha, K.legibleMin), chip) >= K.legibleMin, `bolt ${l}`);
        }
    }
    // A tone that reads on its chip keeps it.
    assert.ok(same(K.inkOnTonal(dark.success, dark.ink, dark.surface, C.tonalAlpha, K.legibleMin), dark.success));
});

test("the clock times are read again only while the face, the bubble or the card shows them", () => {
    assert.equal(C.clockLive(false, false, false), false);
    assert.equal(C.clockLive(true, false, false), true);
    assert.equal(C.clockLive(false, true, false), true);
    assert.equal(C.clockLive(false, false, true), true);
});
