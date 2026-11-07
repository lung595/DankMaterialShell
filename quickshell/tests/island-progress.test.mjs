import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const P = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandProgress.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), P);

test("the value hint becomes a ratio, anything else is no progress", () => {
    assert.equal(P.ratio({ "value": 42 }), 0.42);
    assert.equal(P.ratio({ "value": 140 }), 1);
    assert.equal(P.ratio({ "value": -3 }), 0);
    assert.equal(P.ratio({ "value": "42" }), -1);
    assert.equal(P.ratio({}), -1);
    assert.equal(P.ratio(null), -1);
});

test("files and speed are read from the body when the app writes them", () => {
    assert.deepEqual({ ...P.files("Copying 3 of 12 files") }, { "done": 3, "total": 12 });
    assert.deepEqual({ ...P.files("7/9") }, { "done": 7, "total": 9 });
    assert.equal(P.files("12 of 3"), null);
    assert.equal(P.files("Downloading"), null);
    assert.equal(P.speed("3 of 12 · 4.2 MB/s"), "4.2 MB/s");
    assert.equal(P.speed("850 Kio/s"), "850 Kio/s");
    assert.equal(P.speed("no rate"), "");
});

test("time left follows the pace since the job was first seen", () => {
    const start = { "t": 0, "ratio": 0.2 };
    assert.equal(P.remaining(start, 0.4, 10000), 30);
    assert.equal(P.remaining(start, 0.2, 10000), -1);
    assert.equal(P.remaining(start, 1, 10000), -1);
    assert.equal(P.remaining(null, 0.5, 10000), -1);
});

test("the newest live job shows; an old finished one never does", () => {
    let s = P.step(null, [{ "id": "a", "ratio": 1 }, { "id": "b", "ratio": 0.3 }], 0);
    assert.equal(s.current.id, "b");
    assert.equal(s.startTimer, false);
    s = P.step(s, [{ "id": "a", "ratio": 1 }], 10);
    assert.equal(s.current, null);
});

test("a job finishing starts its check once, then hide lets it go", () => {
    let s = P.step(null, [{ "id": "a", "ratio": 0.5 }], 0);
    s = P.step(s, [{ "id": "a", "ratio": 1 }], 10);
    assert.equal(s.startTimer, true);
    s = P.step(s, [{ "id": "a", "ratio": 1 }], 20);
    assert.equal(s.startTimer, false);
    s = P.hide(s, [{ "id": "a", "ratio": 1 }], 30);
    assert.equal(s.current, null);
    s = P.step(s, [{ "id": "a", "ratio": 1 }], 40);
    assert.equal(s.current, null);
});

test("a job closed near its end keeps showing as finished until hidden; one closed midway leaves", () => {
    let s = P.step(null, [{ "id": "a", "ratio": 0.995 }], 0);
    s = P.step(s, [], 10);
    assert.equal(s.current.id, "a");
    assert.equal(s.current.ratio, 1);
    assert.equal(s.startTimer, true);
    s = P.step(s, [], 20);
    assert.equal(s.current.id, "a");
    assert.equal(s.startTimer, false);
    s = P.hide(s, [], 30);
    assert.equal(s.current, null);
    s = P.step(P.step(null, [{ "id": "b", "ratio": 0.5 }], 0), [], 10);
    assert.equal(s.current, null);
});

test("time left never reads 60 minutes", () => {
    assert.deepEqual({ ...P.clock(42) }, { "s": 42, "h": 0, "m": 0 });
    assert.deepEqual({ ...P.clock(3599) }, { "s": -1, "h": 1, "m": 0 });
    assert.deepEqual({ ...P.clock(7170) }, { "s": -1, "h": 2, "m": 0 });
    assert.deepEqual({ ...P.clock(5400) }, { "s": -1, "h": 1, "m": 30 });
});
