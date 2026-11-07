import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandTransfer.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const row = (id, done, total, extra) => Object.assign({ "id": id, "done": done, "total": total }, extra || {});

test("the first sample has no speed nor time left", () => {
    const r = C.step(null, [row("a", 100, 1000)], 0);
    assert.equal(r.rows[0].speed, 0);
    assert.equal(r.rows[0].eta, -1);
    assert.equal(r.total.ratio, 0.1);
    assert.equal(r.surge, 0);
});

test("speed is smoothed, time left follows it", () => {
    let r = C.step(null, [row("a", 0, 10000)], 0);
    r = C.step(r.state, [row("a", 1000, 10000)], 1000);
    assert.equal(r.rows[0].speed, 1000);
    assert.equal(r.rows[0].eta, 9);
    // A one-second burst moves the smoothed speed only part of the way.
    r = C.step(r.state, [row("a", 4000, 10000)], 2000);
    assert.ok(r.rows[0].speed > 1000 && r.rows[0].speed < 3000, String(r.rows[0].speed));
    assert.ok(r.rows[0].eta > 2 && r.rows[0].eta < 8, String(r.rows[0].eta));
});

test("a speed spike surges, a steady flow does not", () => {
    let r = C.step(null, [row("a", 0, 1e9)], 0);
    r = C.step(r.state, [row("a", 1e6, 1e9)], 1000);
    // Starting to flow is one wave.
    assert.equal(r.surge, 1);
    r = C.step(r.state, [row("a", 2e6, 1e9)], 2000);
    assert.equal(r.surge, 0);
    r = C.step(r.state, [row("a", 6e6, 1e9)], 3000);
    assert.equal(r.surge, 2);
    // Capped: a huge jump is still one big wave.
    r = C.step(r.state, [row("a", 1e9 - 1, 1e9)], 4000);
    assert.equal(r.surge, 3);
    // A sudden drop sloshes too.
    r = C.step(r.state, [row("a", 1e9 - 1 + 0, 2e9)], 5000);
    assert.equal(r.surge, 0);
    r = C.step(r.state, [row("a", 1.1e9, 2e9)], 6000);
    r = C.step(r.state, [row("a", 1.125e9, 2e9)], 7000);
    assert.ok(Math.abs(r.surge - 2) < 1e-6, String(r.surge));
});

test("bytes read short, a pair shares the larger one's unit", () => {
    assert.deepEqual({ ...C.bytes(312e6) }, { "value": 312, "decimals": 0, "unit": "MB" });
    assert.deepEqual({ ...C.bytes(12.43e6) }, { "value": 12.4, "decimals": 1, "unit": "MB" });
    assert.deepEqual({ ...C.bytes(312e6, 3.9e9) }, { "value": 0.3, "decimals": 1, "unit": "GB" });
    assert.deepEqual({ ...C.bytes(800) }, { "value": 800, "decimals": 0, "unit": "B" });
    assert.deepEqual({ ...C.bytes(4.2e3) }, { "value": 4.2, "decimals": 1, "unit": "kB" });
});

test("several transfers make one total; paused ones stop, the slowest sets the time left", () => {
    let r = C.step(null, [row("a", 0, 1000), row("b", 0, 3000, { "canPause": true })], 0);
    r = C.step(r.state, [row("a", 100, 1000), row("b", 100, 3000, { "canPause": true })], 1000);
    assert.equal(r.total.done, 200);
    assert.equal(r.total.size, 4000);
    assert.equal(r.total.ratio, 0.05);
    assert.equal(r.total.speed, 200);
    assert.equal(r.total.eta, 29);
    assert.equal(r.total.canPause, true);
    assert.equal(r.total.paused, false);
    r = C.step(r.state, [row("a", 200, 1000, { "paused": true }), row("b", 200, 3000, { "paused": true })], 2000);
    assert.equal(r.total.speed, 0);
    assert.equal(r.total.eta, -1);
    assert.equal(r.total.paused, true);
});

test("finished and failed transfers leave the running total", () => {
    let r = C.step(null, [row("a", 1000, 1000, { "finished": true }), row("b", 10, 100), row("c", 5, 50, { "error": true })], 0);
    assert.equal(r.total.running, 1);
    assert.equal(r.total.size, 100);
    assert.equal(r.total.ratio, 0.1);
    assert.equal(r.total.failed, 1);
    assert.equal(r.total.finished, 1);
});

test("only a transfer that moves makes waves: paused, finished and failed ones lie flat", () => {
    const r = C.step(null, [row("a", 10, 100), row("b", 10, 100, { "paused": true }), row("c", 100, 100, { "finished": true }), row("d", 5, 50, { "error": true })], 0);
    assert.deepEqual(r.rows.map(x => x.flowing), [true, false, false, false]);
    assert.equal(r.total.flowing, true);
    const still = C.step(null, [row("b", 10, 100, { "paused": true }), row("c", 100, 100, { "finished": true })], 0);
    assert.equal(still.total.flowing, false);
    assert.equal(C.step(null, [], 0).total.flowing, false);
});

test("an unknown size has no ratio", () => {
    const r = C.step(null, [row("a", 100, 0)], 0);
    assert.equal(r.rows[0].ratio, -1);
    assert.equal(r.total.ratio, -1);
});

test("time left reads short", () => {
    assert.equal(C.timeLeft(-1), null);
    assert.deepEqual({ ...C.timeLeft(3) }, { "value": 5, "unit": "s" });
    assert.deepEqual({ ...C.timeLeft(42) }, { "value": 45, "unit": "s" });
    assert.deepEqual({ ...C.timeLeft(61) }, { "value": 2, "unit": "min" });
    assert.deepEqual({ ...C.timeLeft(3600 + 25 * 60) }, { "value": 1, "unit": "h", "minutes": 25 });
    assert.deepEqual({ ...C.timeLeft(3590) }, { "value": 1, "unit": "h", "minutes": 0 });
    assert.deepEqual({ ...C.timeLeft(7170) }, { "value": 2, "unit": "h", "minutes": 0 });
});

test("a long name is cut in its stem, its extension always kept", () => {
    const split = n => ({ ...C.splitName(n) });
    assert.deepEqual(split("ubuntu-24.04.1-desktop-amd64.iso"), { "stem": "ubuntu-24.04.1-desktop-amd64", "ext": ".iso" });
    assert.deepEqual(split("backup-2026.tar.gz"), { "stem": "backup-2026", "ext": ".tar.gz" });
    // No extension, a dotfile, a dot that ends a sentence or a version: all stem.
    assert.deepEqual(split("Photos 2024 — vacances en Bretagne"), { "stem": "Photos 2024 — vacances en Bretagne", "ext": "" });
    assert.deepEqual(split(".bashrc"), { "stem": ".bashrc", "ext": "" });
    assert.deepEqual(split("notes."), { "stem": "notes.", "ext": "" });
    assert.deepEqual(split("release 1.2 final.verylongextension"), { "stem": "release 1.2 final.verylongextension", "ext": "" });
    assert.deepEqual(split(""), { "stem": "", "ext": "" });
});

// Rows as step() gives them: flowing, eta, finished, error.
const shown = (id, category, extra) => Object.assign({ "id": id, "category": category, "flowing": true, "eta": -1, "finished": false, "error": false, "paused": false }, extra || {});

test("one section per category, the moving one on top, then waiting ones, finished last", () => {
    const s = C.sections([
        shown("done", "archive", { "flowing": false, "finished": true }),
        shown("held", "copy", { "flowing": false, "paused": true }),
        shown("iso", "download", { "eta": 30 }),
        shown("t", "torrent", { "eta": 600, "canPause": true, "canCancel": true })
    ]);
    // Moving sections in the fixed order, a paused one after them, an all finished one last.
    assert.deepEqual(Array.from(s, x => x.category), ["download", "torrent", "copy", "archive"]);
    assert.equal(s[1].canPause, true);
    assert.equal(s[1].canCancel, true);
    assert.equal(s[0].canPause, false);
    assert.equal(s[2].paused, true);
    assert.equal(s[3].count, 1);
    assert.equal(s[3].finished, 1);
});

test("in a section the closest to finish leads, unknown and paused after, failed then finished last", () => {
    const s = C.sections([
        shown("old", "copy", { "flowing": false, "finished": true, "finishedAt": 1000 }),
        shown("slow", "copy", { "eta": 300 }),
        shown("new", "copy", { "flowing": false, "finished": true, "finishedAt": 2000 }),
        shown("broken", "copy", { "flowing": false, "error": true }),
        shown("held", "copy", { "flowing": false, "paused": true }),
        shown("unknown", "copy"),
        shown("fast", "copy", { "eta": 20 })
    ]);
    assert.equal(s.length, 1);
    assert.deepEqual(Array.from(s[0].rows, r => r.id),["fast", "slow", "unknown", "held", "broken", "new", "old"]);
    // The section's total: finished of all, the slowest running one's time left.
    assert.equal(s[0].count, 7);
    assert.equal(s[0].finished, 2);
    assert.equal(s[0].eta, 300);
});

test("rows in: the core's transfer keeps its numbers, a browser's partial file lands in the downloads folder", () => {
    const t = C.coreRow({ "id": 7, "category": "torrent", "done": "12", "peers": "x", "canPause": true }, "icon");
    assert.equal(t.id, "7");
    assert.equal(t.done, 12);
    assert.equal(t.peers, 0);
    assert.equal(t.canPause, true);
    assert.equal(t.canCancel, false);
    assert.equal(t.image, "icon");
    const p = C.partRow({ "part": "a.iso.part", "name": "a.iso", "size": 5 }, "Browser", "file:///srv/T%C3%A9l%C3%A9chargements");
    assert.equal(p.id, "part:a.iso.part");
    assert.equal(p.done, 5);
    assert.equal(p.path, "/srv/Téléchargements/a.iso");
});

test("a transfer with no category or an unknown one is a copy", () => {
    const s = C.sections([shown("a", undefined), shown("b", "nonsense"), shown("c", "torrent")]);
    assert.deepEqual(Array.from(s, x => x.category), ["torrent", "copy"]);
    assert.equal(s[1].count, 2);
});

test("a finished row stays its time, then leaves; the next one to leave is timed", () => {
    const list = [shown("run", "copy"), shown("a", "copy", { "finished": true, "finishedAt": 0 }), shown("b", "copy", { "finished": true, "finishedAt": 3000 })];
    let r = C.expire(list, 4000, 5000);
    assert.deepEqual(Array.from(r.list, x => x.id), ["run", "a", "b"]);
    assert.equal(r.next, 1000);
    r = C.expire(list, 5000, 5000);
    assert.deepEqual(Array.from(r.list, x => x.id), ["run", "b"]);
    assert.equal(r.next, 3000);
    r = C.expire([shown("run", "copy")], 5000, 5000);
    assert.equal(r.next, -1);
    // Hovered until 4500: every finished row's time starts over from there.
    r = C.expire(list, 5000, 5000, 4500);
    assert.deepEqual(Array.from(r.list, x => x.id), ["run", "a", "b"]);
    assert.equal(r.next, 4500);
});
