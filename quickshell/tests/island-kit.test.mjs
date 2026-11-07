import assert from "node:assert/strict";
import test from "node:test";
import { K } from "./island-kit-load.mjs";

test("a row's edge alone (no array per frame) lands where the whole row puts it", () => {
    for (const [total, weights, gap] of [[368, [1, 1, 2, 2], 8], [300, [1.37, 1, 1.63], 8], [251, [1, 2, 1], 8]]) {
        const cells = K.rowLayout(total, weights, gap);
        const sum = weights.reduce((a, w) => a + w, 0);
        let acc = 0;
        cells.forEach((c, i) => {
            assert.equal(K.rowEdge(total, weights.length, gap, acc, sum) + i * gap, c.x, `${weights} cell ${i}`);
            acc += weights[i];
            assert.equal(K.rowEdge(total, weights.length, gap, acc, sum) + i * gap, c.x + c.width, `${weights} end ${i}`);
        });
    }
});

test("the button row fills the width exactly, by weight, whole pixels", () => {
    for (const [total, weights, gap] of [[368, [1, 1, 2, 2], 8], [400, [1], 8], [401, [1, 1, 1], 4], [333, [2, 1], 8]]) {
        const cells = K.rowLayout(total, weights, gap);
        const last = cells[cells.length - 1];
        assert.equal(last.x + last.width, total, `${weights} in ${total}`);
        cells.forEach(c => assert.ok(Number.isInteger(c.width) && Number.isInteger(c.x)));
    }
    const call = K.rowLayout(368, [1, 1, 2, 2], 8);
    assert.ok(Math.abs(call[2].width - 2 * call[0].width) <= 1);
    assert.ok(Math.abs(call[0].width - call[1].width) <= 1);
});

test("no weight or a bad weight still gives equal parts, never a negative width", () => {
    const cells = K.rowLayout(300, [0, 0, 0], 0);
    assert.deepEqual(cells.map(c => c.width), [100, 100, 100]);
    assert.equal(K.rowLayout(0, [1, 1], 8).length, 0);
    assert.ok(K.rowLayout(10, [1, 1, 1, 1], 8).every(c => c.width >= 0));
});

test("the hold drains 2.5 times faster than it fills, from where it was let go", () => {
    assert.equal(K.holdRemaining(0.25, 2000), 1500);
    assert.equal(K.drainTime(0.5, 2000), 400);
    assert.equal(K.drainTime(2, 2000), 800);
    assert.equal(K.holdRemaining(-1, 2000), 2000);
});

test("the liquid front is mirrored, flat without amplitude, and its slope matches it", () => {
    assert.equal(K.wave(0.3, 0, 1.2), 0);
    assert.ok(Math.abs(K.wave(0, 5, 0)) < 1e-9);
    assert.ok(Math.abs(K.wave(0.5, 5, 0) - 5) < 1e-9);
    const h = 1e-6;
    for (const d of [0, 0.25, 0.5, 0.9]) {
        const num = (K.wave(d + h, 4, 0.7) - K.wave(d - h, 4, 0.7)) / (2 * h);
        assert.ok(Math.abs(num - K.waveSlope(d, 4, 0.7)) < 1e-4, `slope at ${d}`);
    }
});

test("springs slow down with DMS's animation speed and keep their damping ratio", () => {
    const ratio = s => s.damping / (2 * Math.sqrt(s.stiffness * s.mass));
    const normal = K.spring("cell", 250);
    const slow = K.spring("cell", 1000);
    assert.ok(Math.abs(ratio(normal) - ratio(slow)) < 1e-9);
    assert.ok(Math.abs(Math.sqrt(normal.stiffness / slow.stiffness) - 4) < 1e-9);
    assert.deepEqual(K.spring("nope", 250), K.spring("cell", 250));
});

test("content beats follow DMS's animation speed and stop at speed 0", () => {
    assert.equal(K.beat("ringPause", 250), 1000);
    assert.equal(K.beat("ringPause", 500), 2000);
    assert.equal(K.beat("ringPause", 0), 0);
    assert.equal(K.beat("nope", 250), 250);
});

test("the copy and hold buttons' outcome is a lifetime, not a motion: it stays at speed 0", () => {
    assert.equal(K.feedbackMs, 1600);
});

test("a face row is centred on its ink, not on its glyph boxes, to the whole pixel", () => {
    // A 16 px icon box holding a 12 px-advance glyph whose ink starts 1 px in: 3 px of air before the ink.
    assert.equal(K.boxBearing(16, 12, 1), 3);
    assert.equal(K.boxBearing(16, 16, 0), 0);
    // 3 px of air before, 1 px after in a 100 px row of a 120 px face: x 9 so both sides show 12 px of air.
    assert.equal(K.inkCentredX(120, 100, 3, 1), 9);
    assert.equal(K.inkCentredX(120, 100, 1, 5), 12);
    assert.equal(K.inkCentredX(120, 100, 2, 2), 10);
    // The row's own fractional width counts too: one rounding, on the final x.
    assert.equal(K.inkCentredX(282, 199.53, 1.5, 0.37), 41);
    for (const [w, row, lead, trail] of [[120, 100, 3, 0], [120, 100, 0, 3], [282, 199.53, 4.6, 1.2], [281, 124.58, 3.37, 0.37]]) {
        const x = K.inkCentredX(w, row, lead, trail);
        assert.ok(Number.isInteger(x) && Math.abs((x + lead) - (w - x - row + trail)) <= 1, `${w}/${row}/${lead}/${trail}`);
    }
});

test("mixing two outlines lands on each end and ignores a mismatched one", () => {
    assert.deepEqual(K.mixRadii([1, 2], [3, 4], 0.5), [2, 3]);
    assert.deepEqual(K.mixRadii([1, 2], [3, 4], 2), [3, 4]);
    assert.deepEqual(K.mixRadii([1, 2], [3], 0.5), [1, 2]);
});

test("a burst of speed pushes the liquid by its size, capped, scaled by the motion setting, never backwards", () => {
    assert.equal(K.surgeKick(0, 1), 0);
    assert.equal(K.surgeKick(-2, 1), 0);
    assert.ok(K.surgeKick(2, 1) > K.surgeKick(1, 1));
    assert.equal(K.surgeKick(100, 1), K.surgeMax);
    assert.equal(K.surgeKick(1, 0.5), K.surgeKick(1, 1) / 2);
    assert.equal(K.surgeKick(1, 0), 0);
});

test("the spring's closed form follows the wing's own integration, for every damping", () => {
    for (const ratio of [0.4, 1, 1.6]) {
        const k = 420, m = 0.9, c = 2 * ratio * Math.sqrt(k * m), h = 1 / 48000;
        let x = 0, v = 0;
        for (let i = 1; i <= 24000; i++) {
            v += (k * (1 - x) - c * v) / m * h;
            x += v * h;
            if (i % 200 === 0)
                assert.ok(Math.abs(K.springStep(i * h, k, c, m) - x) < 0.005, `ratio ${ratio} at ${i}`);
        }
    }
    assert.equal(K.springStep(0, 420, 40, 0.9), 0);
    assert.ok(Math.abs(K.springStep(5, 420, 2 * Math.sqrt(420 * 0.9), 0.9) - 1) < 1e-6);
    assert.equal(K.springStep(1, 0, 0, 1), 1);
});

test("a cubic bezier easing matches the CSS curve: ends pinned, monotone, known midpoints", () => {
    assert.equal(K.bezier(0.2, 0, 0, 1, 0), 0);
    assert.equal(K.bezier(0.2, 0, 0, 1, 1), 1);
    // ease-in-out (.42,0,.58,1) is symmetric about the middle.
    assert.ok(Math.abs(K.bezier(0.42, 0, 0.58, 1, 0.5) - 0.5) < 1e-4);
    assert.ok(Math.abs(K.bezier(0.42, 0, 0.58, 1, 0.25) + K.bezier(0.42, 0, 0.58, 1, 0.75) - 1) < 1e-4);
    // Accelerate starts slow, emphasized starts fast.
    assert.ok(K.bezier(0.5, 0, 0.75, 0, 0.5) < 0.2);
    assert.ok(K.bezier(0.2, 0, 0, 1, 0.3) > 0.6);
    let last = 0;
    for (let x = 0.02; x <= 1; x += 0.02) {
        const y = K.bezier(0.5, 0, 0.75, 0, x);
        assert.ok(y >= last - 1e-9);
        last = y;
    }
});

test("a spring settles when it last strays further than eps from its target", () => {
    const k = 84, m = 1, c = 2 * 0.6 * Math.sqrt(k * m), eps = 0.005;
    const t = K.springSettle(k, c, m, eps);
    assert.ok(Math.abs(1 - K.springStep(t - 0.01, k, c, m)) > eps * 0.5);
    for (let s = t + 0.005; s < t + 2; s += 0.005)
        assert.ok(Math.abs(1 - K.springStep(s, k, c, m)) <= eps, `at ${s}`);
    // Stiffer settles sooner; the island's default entry settles in about a second.
    assert.ok(K.springSettle(4 * k, 2 * 0.6 * Math.sqrt(4 * k * m), m, eps) < t);
    assert.ok(t > 0.8 && t < 1.2);
    assert.equal(K.springSettle(0, 0, 1, eps), 0);
});

test("the fusion runs on one spring: gathered, then one continuous flow that stretches, thins and lands softly", () => {
    // wt = ω·t of the wing's exit spring (critically damped); the shape touches the island halfway along its way.
    const at = wt => K.fusionPhases(wt, 0.5);
    const p0 = at(0);
    assert.deepEqual([p0.text, p0.gather, p0.along, p0.glow, p0.swell, p0.flowing, p0.done], [1, 0, 0, 0, 0, false, false]);
    assert.ok(at(1.2).text === 0 && at(1.2).gather > 0.99);
    // Its speed never jumps: no step between two frames is far from the one before (gather, flow, melt alike).
    const dt = 0.05;
    let prev = 0, last = at(0);
    for (let wt = dt; wt < 12; wt += dt) {
        const p = at(wt);
        const step = p.along - last.along;
        assert.ok(step >= 0 && Math.abs(step - prev) < 0.01, `speed jumps at ${wt.toFixed(2)}`);
        assert.ok(p.gather >= last.gather && p.text <= last.text);
        // Moving, it stretches along its way and thins across, more the faster it goes; at rest it is round.
        assert.ok(p.scaleAlong >= p.scaleCross - 1e-9);
        prev = step;
        last = p;
    }
    // It lands with no jolt: barely moving at the end.
    assert.ok(at(9).along - at(8.95).along < 1e-3);
    assert.ok(at(12).done);
});

test("the fusion's glow: a halo born at the contact, spreading like a wave on the island's spring, fading out", () => {
    const at = wt => K.fusionPhases(wt, 0.5);
    let contact = -1;
    for (let wt = 0; wt < 12 && contact < 0; wt += 0.01)
        if (at(wt).along >= 0.5)
            contact = wt;
    assert.ok(contact > 0);
    // Nothing lights before the shape touches the island.
    assert.equal(at(contact - 0.05).glow, 0);
    assert.equal(at(contact - 0.05).wave, 0);
    // Then a halo from the contact point, its front moving out while it pales, and gone at the end.
    let last = at(contact);
    for (let t = 0.1; t < 8; t += 0.1) {
        const p = at(contact + t);
        assert.ok(p.wave >= last.wave && p.glow <= last.glow + 1e-9, `at ${t.toFixed(1)}`);
        last = p;
    }
    assert.ok(at(contact + 1).wave > 0.2 && at(contact + 1).glow > 0.2);
    assert.ok(at(contact + 8).glow < 0.01 && at(contact + 8).swell < 0.02);
});

test("the fusion lights the island's edge with the launcher closed too: flat pill or tile, both sides", () => {
    // The shape flows from where the wing gathered (beside the island, one gap away), never from where its icon sat on the
    // long open pill: measured from there, a flat pill's shape never reached the island and its edge never lit.
    const size = 32, reach = 1.5;
    for (const gap of [4, 12]) {
        const contact = K.fuseContact(gap, size, reach);
        assert.ok(contact > 0 && contact < 1, `gap ${gap}: contact ${contact}`);
        let lit = 0;
        for (let wt = 0; wt < 12; wt += 0.05)
            lit = Math.max(lit, K.fusionPhases(wt, contact).glow);
        assert.ok(lit > 0.5, `gap ${gap}: glow ${lit}`);
    }
    // A flat pill on a quiet island (the clock) fuses.
    assert.equal(K.closeStyle({ "inPlace": true, "reduced": false, "occupantBefore": "home|", "occupantNow": "home|" }), "fuse");
});

test("the shape under a logo is the tone that contrasts with it; unknown keeps the dark one", () => {
    const dark = { "r": 0.05, "g": 0.06, "b": 0.07 }, light = { "r": 0.93, "g": 0.92, "b": 0.92 };
    assert.equal(K.logoShapeTone(1, dark, light), dark, "white silhouette");
    assert.equal(K.logoShapeTone(0, dark, light), light, "black glyph");
    assert.equal(K.logoShapeTone(-1, dark, light), dark, "unknown");
    // A mid photo (luminance 0.35) reads better on the dark tone than on the light one.
    assert.equal(K.logoShapeTone(0.35, dark, light), dark, "photo");
});

test("a logo's luminance counts only where it is drawn, weighted by alpha", () => {
    assert.equal(K.logoLuminance([255, 255, 255, 255, 0, 0, 0, 0]), 1, "white over a clear pixel");
    assert.equal(K.logoLuminance([0, 0, 0, 255, 255, 255, 255, 0]), 0, "black over a clear pixel");
    assert.equal(K.logoLuminance([0, 0, 0, 0]), -1, "nothing drawn");
    assert.ok(Math.abs(K.logoLuminance([255, 255, 255, 255, 0, 0, 0, 255]) - 0.5) < 1e-9, "half white, half black");
    assert.ok(Math.abs(K.logoLuminance([255, 255, 255, 255, 0, 0, 0, 85]) - 0.75) < 1e-9, "a third of a black pixel");
});
