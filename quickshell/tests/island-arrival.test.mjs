import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const A = loadScript(new URL("../Common/IslandArrival.js", import.meta.url));

const item = (id, tier = 1) => ({ id, tier });

test("a countdown steps once a half pixel of its dot, running or draining, never faster than 60 times a second", () => {
    const cd = A.countdown(4000, 0);
    // A 20 px dot: a quantum is 1/40 of the fill, 100 ms of a 4 s countdown.
    assert.equal(A.stepMs(cd, 20), 100);
    // Frozen at half, it drains over 450 ms: a quantum is 1/20 of what is left, 22.5 ms.
    assert.equal(A.stepMs(A.freeze(cd, 2000), 20), 23);
    assert.equal(A.stepMs(A.countdown(100, 0), 20), 16);
    assert.equal(A.stepMs(A.freezeEmpty(cd, 0), 20), 450);
});

test("M31, M33: a call never takes the alert shape, a critical or important info does", () => {
    assert.equal(A.alertOf({ "call": true, "critical": true }), "");
    assert.equal(A.alertOf({ "critical": true, "important": true }), "critical");
    assert.equal(A.alertOf({ "important": true }), "important");
    assert.equal(A.alertOf({}), "");
    assert.equal(A.alertOf(null), "");
});

test("M20: an info leaving the island for its bubble lives its whole time again, an ended one stays ended", () => {
    assert.equal(A.bubbleClockRestarts(false, true), true);
    assert.equal(A.bubbleClockRestarts(false, false), false);
    assert.equal(A.bubbleClockRestarts(true, true), false);
});

test("tiers follow the lifetime: brief, normal (Undo, notification), important (critical, urgent)", () => {
    assert.equal(A.tierOf({ brief: true }), 0);
    assert.equal(A.tierOf({ brief: true, undo: true }), 1);
    assert.equal(A.tierOf({}), 1);
    assert.equal(A.tierOf({ critical: true }), 2);
    assert.equal(A.tierOf({ urgent: true, brief: true }), 2);
});

test("a notification takes the island when free or already showing one; a critical one (a call) over any open face but the launcher", () => {
    assert.ok(A.takesIsland(false, false, false, "home"));
    assert.ok(A.takesIsland(true, true, false, "launcher"));
    assert.ok(!A.takesIsland(false, true, false, "controlcenter"));
    assert.ok(A.takesIsland(false, true, true, "controlcenter"));
    // Launcher open: it stands as a bubble beside it, like every other info.
    assert.ok(!A.takesIsland(false, true, true, "launcher"));
});

test("an incoming call rings (its freedesktop category), not one that ended or went unanswered", () => {
    assert.ok(A.ringing("call.incoming"));
    assert.ok(A.ringing("call"));
    for (const c of ["call.ended", "call.unanswered", "im.received", "", undefined, null])
        assert.ok(!A.ringing(c), String(c));
});

test("an info goes by itself after its time, a ringing call never (big, folded or in its bubble)", () => {
    assert.equal(A.expires({ tier: 1 }), true);
    assert.equal(A.expires({ tier: 2, critical: true }), true);
    assert.equal(A.expires({ tier: 2, critical: true, call: true }), false);
    assert.equal(A.expires(null), true);
});

test("B + C: a card grows big, 1.4 s normal, 2 s important; a brief one only swells", () => {
    const normal = A.pulse("bc", 1, true);
    assert.equal(normal.big, true);
    assert.equal(normal.holdMs, 1400);
    assert.equal(A.pulse("bc", 2, true).holdMs, 2000);
    const brief = A.pulse("bc", 0, true);
    assert.equal(brief.holdMs, 400);
    assert.equal(brief.big, false);
    assert.ok(brief.swell[0] > 0 && brief.swell[0] < normal.swell[0] + 1);
    // Without a card (a system face, a glance) it swells instead, harder the more it matters.
    const faceN = A.pulse("bc", 1, false), faceI = A.pulse("bc", 2, false);
    assert.equal(faceN.big, false);
    assert.ok(faceI.swell[1] > faceN.swell[1] && faceN.swell[1] > brief.swell[1]);
});

test("C and A never open the card; A has no bounce and no tint", () => {
    for (const tier of [0, 1, 2]) {
        assert.equal(A.pulse("c", tier, true).big, false);
        const a = A.pulse("a", tier, true, ["strong", "strong", "strong"], ["strong", "strong", "strong"]);
        assert.equal(a.big, false);
        assert.equal(a.ratio, 1);
        assert.equal(a.tint, 0);
    }
});

test("bounce and tint are set per tier, defaults light, light, medium and stronger for the important", () => {
    const [b, n, i] = [0, 1, 2].map(t => A.pulse("bc", t, true));
    assert.ok(b.ratio < 1 && b.ratio === n.ratio && i.ratio < n.ratio);
    assert.ok(i.tint > n.tint && n.tint >= b.tint && b.tint > 0);
    const custom = A.pulse("bc", 1, true, ["none", "strong", "none"], ["none", "none", "none"]);
    assert.ok(custom.ratio < i.ratio);
    assert.equal(custom.tint, 0);
    assert.equal(A.pulse("bc", 0, true, ["none", "none", "none"]).ratio, 1);
    // Reduced motion: big at once, never a bounce; the lifetime stays.
    const reduced = A.pulse("bc", 2, true, undefined, undefined, true);
    assert.equal(reduced.ratio, 1);
    assert.equal(reduced.big, true);
    assert.equal(reduced.holdMs, 2000);
});

test("burst: each newcomer rolls in from below; one arriving while held waits as a dot", () => {
    let s = A.arrive(A.emptyBurst(), item("a"), false);
    assert.deepEqual([s.index, s.dir, s.items.length], [0, 0, 1]);
    s = A.arrive(s, item("b"), false);
    assert.deepEqual([s.index, s.dir, s.axis], [1, 1, "y"]);
    const held = A.arrive(s, item("c"), true);
    assert.deepEqual([held.index, held.dir, held.items.length], [1, 0, 3]);
});

test("burst: going back rolls the other way; out of range or the same page goes nowhere", () => {
    const s = ["a", "b", "c"].reduce((b, id) => A.arrive(b, item(id), false), A.emptyBurst());
    const back = A.go(s, 0);
    assert.deepEqual([back.index, back.dir, back.axis], [0, -1, "x"]);
    assert.equal(A.go(s, 2), null);
    assert.equal(A.go(s, 3), null);
    assert.equal(A.go(s, -1), null);
    assert.deepEqual([A.go(back, 1).index, A.go(back, 1).dir], [1, 1]);
});

test("burst: a full countdown moves to the next info left, else folds", () => {
    let s = ["a", "b", "c"].reduce((b, id) => A.arrive(b, item(id), true), A.emptyBurst());
    assert.equal(s.index, 0);
    s = A.afterCountdown(s);
    assert.deepEqual([s.index, s.dir, s.axis], [1, 1, "x"]);
    s = A.afterCountdown(A.afterCountdown(s) ?? s);
    assert.equal(s, null);
});

test("burst: an important info anywhere in the burst sizes the island", () => {
    const s = [item("a", 1), item("call", 2), item("b", 0)].reduce((b, i) => A.arrive(b, i, false), A.emptyBurst());
    assert.equal(A.topTier(s.items), 2);
    assert.equal(A.topTier([]), -1);
});

test("pager: five dots at most, the row slides and the dots at a hidden end shrink", () => {
    assert.deepEqual([...A.pager(1, 0).dots], ["on"]);
    assert.deepEqual([...A.pager(3, 1).dots], ["dot", "on", "dot"]);
    const eight = A.pager(8, 5);
    assert.equal(eight.dots.filter(d => d !== "gone").length, 5);
    assert.equal(eight.dots[5], "on");
    assert.equal(eight.start, 3);
    assert.equal(eight.dots[3], "edge");
    assert.equal(eight.dots[7], "dot");
    const first = A.pager(8, 0);
    assert.equal(first.start, 0);
    assert.equal(first.dots[0], "on");
    assert.equal(first.dots[4], "edge");
    assert.equal(first.dots[5], "gone");
    // The active dot never shrinks, even at the edge.
    assert.equal(A.pager(8, 7).dots[7], "on");
});

test("countdown: the active dot fills over the hold, then it is done", () => {
    const cd = A.countdown(1400, 1000);
    assert.equal(A.fill(cd, 1000), 0);
    assert.equal(A.fill(cd, 1700), 0.5);
    assert.equal(A.done(cd, 2399), false);
    assert.equal(A.done(cd, 2400), true);
    assert.equal(A.remaining(cd, 1700), 700);
});

test("freeze: the dot empties gently, nothing ticks once it is empty, and leaving starts over", () => {
    const frozen = A.freeze(A.countdown(1400, 0), 700, 450);
    assert.equal(A.fill(frozen, 700), 0.5);
    assert.ok(A.fill(frozen, 925) > 0 && A.fill(frozen, 925) < 0.5);
    assert.equal(A.fill(frozen, 1150), 0);
    assert.equal(A.done(frozen, 99999), false);
    assert.equal(A.remaining(frozen, 800), -1);
    assert.equal(A.ticking(frozen, 1000), true);
    assert.equal(A.ticking(frozen, 1150), false);
    // A second hold (focus on top of the pointer) keeps the drain where it is.
    assert.equal(A.freeze(frozen, 900), frozen);
    const thawed = A.thaw(frozen, 5000);
    assert.equal(A.fill(thawed, 5000), 0);
    assert.equal(A.done(thawed, 6400), true);
    // A page turned or a fold reopened while held starts empty, and still.
    const empty = A.freezeEmpty(A.countdown(1400, 0), 300, 450);
    assert.equal(A.fill(empty, 300), 0);
    assert.equal(A.ticking(empty, 300), false);
});

test("fill steps are at least half a pixel of the dot", () => {
    assert.equal(A.quantum(20), 0.025);
    assert.equal(A.shown(0.5, 0.51, 20), 0.5);
    assert.equal(A.shown(0.5, 0.53, 20), 0.53);
    assert.equal(A.shown(0.5, 1, 20), 1);
    assert.equal(A.shown(0.01, 0, 20), 0);
});

test("wheel: notches add up to one page, a pause starts over, a page locks the next notches briefly", () => {
    let w = A.wheel(A.wheelIdle(), 15, 0);
    assert.equal(w.step, 0);
    w = A.wheel(w, 15, 50);
    assert.equal(w.step, 0);
    w = A.wheel(w, 15, 100);
    assert.equal(w.step, 1);
    const locked = A.wheel(w, 120, 150);
    assert.equal(locked.step, 0);
    assert.equal(A.wheel(w, -120, 100 + 400).step, -1);
    // A long pause forgets what was turned.
    const paused = A.wheel(A.wheel(A.wheelIdle(), 30, 0), 30, 1000);
    assert.equal(paused.step, 0);
});

test("wheelDelta: the larger axis wins, pixels before notches (÷3), the wheel turned up goes to the next info", () => {
    assert.equal(A.wheelDelta({ "x": 0, "y": 0 }, { "x": 0, "y": 120 }), 40);
    assert.equal(A.wheelDelta({ "x": 0, "y": 0 }, { "x": 0, "y": -120 }), -40);
    assert.equal(A.wheelDelta({ "x": 0, "y": 9 }, { "x": 0, "y": -120 }), 9);
    assert.equal(A.wheelDelta({ "x": -12, "y": 3 }, { "x": 0, "y": 0 }), -12);
});

test("swipe: sideways turns pages, up tidies away, down opens the full card; short or diagonal does nothing", () => {
    assert.equal(A.swipe(-60, 5, 36), "next");
    assert.equal(A.swipe(60, -5, 36), "prev");
    assert.equal(A.swipe(4, -50, 36), "tidy");
    assert.equal(A.swipe(-3, 50, 36), "open");
    assert.equal(A.swipe(20, 10, 36), "");
    // On a bottom bar the island hangs from below: away from the edge is up.
    assert.equal(A.swipe(4, 50, 36, true), "tidy");
    assert.equal(A.swipe(4, -50, 36, true), "open");
});

test("content stays in the middle of the springing shape: equal room above and below, whole pixels", () => {
    assert.equal(A.centered(40, 40), 0);
    // A swell (40 -> 53): the face moves down half the growth instead of staying pinned to the top.
    assert.equal(A.centered(53, 40), 7);
    // The card bigger than the island early in its growth: centred, cut evenly by both edges.
    assert.equal(A.centered(60, 108), -24);
});

test("grow reads the island's spring between compact and card, unclamped so content rides the bounce", () => {
    assert.equal(A.grow(40, 40, 108), 0);
    assert.equal(A.grow(108, 40, 108), 1);
    assert.equal(A.grow(74, 40, 108), 0.5);
    assert.ok(A.grow(110, 40, 108) > 1);
    // No card to grow into: nothing flies.
    assert.equal(A.grow(60, 40, 40.5), 0);
    // Reduced motion: only the two layouts, nothing in between.
    assert.equal(A.grow(60, 40, 108, true), 0);
    assert.equal(A.grow(80, 40, 108, true), 1);
});

test("fly: a shared element goes from its own place to the other layout's, both centred in the island", () => {
    // Card 300x100, icon centre (30, 30) size 40; compact face 200x40, icon centre (22, 20) size 24.
    const card = { "x": 30, "y": 30, "size": 40, "w": 300, "h": 100 };
    const compact = { "x": 22, "y": 20, "size": 24, "w": 200, "h": 40 };
    assert.deepEqual({ ...A.fly(card, compact, 0) }, { "x": 0, "y": 0, "scale": 1 });
    // At the other end the card's icon sits exactly on the compact one: (22 + 50, 20 + 30) in card coordinates.
    const end = A.fly(card, compact, 1);
    assert.equal(30 + end.x, 72);
    assert.equal(30 + end.y, 50);
    assert.equal(end.scale, 0.6);
    // The compact icon flies the other way and meets it.
    const back = A.fly(compact, card, 1);
    assert.equal(22 + back.x, -20);
    assert.equal(20 + back.y, 0);
    assert.ok(Math.abs(back.scale - 40 / 24) < 1e-9);
    // Halfway, both are at the same spot in the island.
    const a = A.fly(card, compact, 0.5), b = A.fly(compact, card, 0.5);
    assert.equal(30 + a.x - 50, 22 + b.x);
    assert.equal(30 + a.y - 30, 20 + b.y);
});

test("handover: shared elements cross-fade midway (sum 1), the card's own come late, the compact's own leave early", () => {
    for (const t of [-0.1, 0, 0.2, 0.35, 0.5, 0.8, 1, 1.05]) {
        const o = A.handover(t, 0.35);
        assert.ok(o.shared >= 0 && o.shared <= 1);
        assert.ok(o.cardOwn <= o.shared + 1e-9, "the card's own never before the shared ones");
        assert.ok(o.compactOwn <= 1 - o.shared + 1e-9, "the compact's own gone before the shared ones");
    }
    assert.deepEqual({ ...A.handover(0, 0.35) }, { "shared": 0, "cardOwn": 0, "compactOwn": 1 });
    assert.deepEqual({ ...A.handover(1, 0.35) }, { "shared": 1, "cardOwn": 1, "compactOwn": 0 });
    const mid = A.handover(0.35, 0.35);
    assert.ok(mid.shared > 0.5 && mid.cardOwn === 0 && mid.compactOwn === 0);
    // The card's extra lines leave in the first part of the fold, while the icon and title are still near their card place.
    assert.equal(A.handover(0.6, 0.35).cardOwn, 0);
    assert.ok(A.handover(0.85, 0.35).cardOwn > 0.5);
});

test("a click on an info in the island grows it where it is: folded its card opens again, open it opens whole", () => {
    assert.equal(A.click("compact", 2), "reopen");
    assert.equal(A.click("big", 1), "open");
    // Nothing of a burst left: the click keeps the island's own role.
    assert.equal(A.click("rest", 0), "");
    assert.equal(A.click("compact", 0), "");
});

test("a face that swelled on arrival swells again while hovered once folded, never another face, a notification, open or upright", () => {
    const s = { "hovered": true, "owner": "dms:code2fa:1", "face": "dms:code2fa:1", "notification": false, "expanded": false, "vertical": false };
    assert.equal(A.hoverSwell(s), true);
    for (const [k, v] of [["hovered", false], ["owner", ""], ["face", "volume"], ["notification", true], ["expanded", true], ["vertical", true]])
        assert.equal(A.hoverSwell(Object.assign({}, s, { [k]: v })), false, k);
});
