import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const C = loadScript(new URL("../Common/IslandTrash.js", import.meta.url));
const plain = v => JSON.parse(JSON.stringify(v));

test("entry names come from .trashinfo files only", () => {
    assert.equal(C.entryName("report.pdf.trashinfo"), "report.pdf");
    assert.equal(C.entryName(".hidden.trashinfo"), ".hidden");
    assert.equal(C.entryName("report.pdf"), "");
    assert.equal(C.entryName(undefined), "");
});

test("the first listing only seeds", () => {
    const s = C.step(null, ["a", "b"], [], false);
    assert.deepEqual(plain(s), { "known": ["a", "b"], "batch": [], "added": 0 });
});

test("a new name is a deletion, a removed one is not", () => {
    let s = C.step(["a"], ["a", "b"], [], false);
    assert.deepEqual(plain(s), { "known": ["a", "b"], "batch": ["b"], "added": 1 });
    s = C.step(s.known, ["b"], s.batch, true);
    assert.equal(s.added, 0);
    assert.deepEqual(plain(s.batch), ["b"]);
    assert.equal(C.step(["a", "b"], [], [], false).added, 0);
    // Restored elsewhere while the bubble shows: Undo must not try it again.
    assert.deepEqual(plain(C.step(["a", "b", "c"], ["a"], ["b", "c"], true).batch), []);
    assert.deepEqual(plain(C.step(["a", "b"], ["a", "c"], ["b"], true).batch), ["c"]);
});

test("deletions while the bubble shows join its batch, later ones replace it", () => {
    let s = C.step(["a"], ["a", "b", "c"], [], false);
    assert.deepEqual(plain(s.batch), ["b", "c"]);
    s = C.step(s.known, ["a", "b", "c", "d"], s.batch, true);
    assert.deepEqual(plain(s.batch), ["b", "c", "d"]);
    s = C.step(s.known, ["a", "b", "c", "d", "e"], s.batch, false);
    assert.deepEqual(plain(s.batch), ["e"]);
});

test("the label names the first file and counts the others", () => {
    assert.deepEqual(plain(C.label(["x", "y", "z"])), { "name": "x", "others": 2 });
    assert.deepEqual(plain(C.label(["x"])), { "name": "x", "others": 0 });
    assert.deepEqual(plain(C.label([])), { "name": "", "others": 0 });
});
