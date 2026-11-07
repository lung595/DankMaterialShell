import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const K = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandKit.js", import.meta.url).pathname, "utf8").replace(/^\.pragma.*$/m, ""), K);

// The light's three layers (core, glow, halo: 4, 6, 9 base strokes) as shares of the loop; at height 12 the loop is
// 48.85 px long and the base stroke 1.5 px.
const shares = [4, 6, 9].map(d => d * 1.5 / 48.85);
const sweep = 2500;

// Rest rule K1: the infinity light ("no known end") is an infinite dashOffset sweep. Shown on an untimed idle inhibit it
// kept every exposed window redrawing at 240/s for hours (27/10, 225 commits/s per surface at rest). It now runs a few
// turns after each showing, then rests; reduced motion never starts it.
test("the infinity light runs a bounded number of turns, none under reduced motion", () => {
    assert.equal(K.infinityRest(3, sweep, 1, false, shares).turns, 3);
    assert.equal(K.infinityRest(3, sweep, 1, true, shares).turns, 0);
    assert.equal(K.infinityRest(3, sweep, 0, false, shares).turns, 0, "animation speed 0 is reduced motion too");
});

// Norm M26, stop of a continuous light (27/10, V3): never a dead stop. The light brakes from its own speed,
// lands on the crossing, then stretches both ways until the whole loop is lit; at most 1.2 s after the last turn.
test("the light settles within 1.2 s of its last turn, then nothing is left to run", () => {
    const r = K.infinityRest(3, sweep, 1, false, shares);
    const lit = 3 * sweep;
    assert.ok(r.restMs > lit && r.restMs - lit <= 1200, `stop takes ${r.restMs - lit} ms`);
    assert.equal(r.spreadAtMs + r.spreadMs, r.restMs, "the spread is the last thing to move");
    assert.equal(r.layers.length, 3);
    for (const l of r.layers) {
        assert.ok(l.runMs >= 0 && l.brakeMs > 0, JSON.stringify(l));
        assert.ok(l.runMs + l.brakeMs <= r.restMs, "every layer has landed before the loop is lit");
    }
    // The halo lands after the glow, the glow after the core (follow-through).
    const ends = r.layers.map(l => l.runMs + l.brakeMs);
    assert.ok(ends[0] < ends[1] && ends[1] < ends[2], ends.join(" "));
});

test("the brake starts at the sweep's own speed and lands each layer centred on the crossing", () => {
    const r = K.infinityRest(3, sweep, 1, false, shares);
    const c = K.infinityBrakeCurve;
    assert.equal(c.length, 6, "one Bezier segment (BezierSpline breaks past ~10)");
    const slope = c[1] / c[0];
    r.layers.forEach((l, i) => {
        // Loops left when the brake starts: the layer's centre ends on the crossing after `turns` loops.
        const left = 3 - shares[i] / 2 - l.runMs / sweep;
        assert.ok(left > 0);
        // Speed at the brake's start (loops per ms) equals the sweep's: no jolt.
        assert.ok(Math.abs(slope * left / l.brakeMs - 1 / sweep) < 1e-9, `layer ${i}`);
    });
});

test("every timing follows DMS's animation speed", () => {
    const a = K.infinityRest(3, sweep, 1, false, shares);
    const b = K.infinityRest(3, sweep, 2, false, shares);
    assert.equal(b.sweepMs, a.sweepMs / 2);
    assert.equal(b.restMs, a.restMs / 2);
    assert.equal(b.spreadMs, a.spreadMs / 2);
});

test("reduced motion shows the rested glyph at once", () => {
    const r = K.infinityRest(3, sweep, 1, true, shares);
    assert.equal(r.restMs, 0);
    assert.equal(r.spreadMs, 0);
    assert.equal(r.layers.length, 0);
});
