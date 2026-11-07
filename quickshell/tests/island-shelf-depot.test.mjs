import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandShelf.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const plain = v => JSON.parse(JSON.stringify(v));

test("kept files go to the head of the list once, new ones counted, a known one moved up", () => {
    const s = C.place(["/a", "/b"], {}, "", ["/c", "/b", "/c"]);
    assert.deepEqual(plain(s.items), ["/c", "/b", "/a"]);
    assert.deepEqual(plain(s.kept), ["/c", "/b"]);
    assert.deepEqual(plain(s.fresh), ["/c"]);
    assert.deepEqual(plain(C.place(["/a", "/b"], {}, "", ["/b"]).fresh), []);
});

test("kept in an open shelf folder, a file leaves the list and any other folder: never twice on the shelf", () => {
    const gs = { "1": { "name": "Trip", "items": ["/p1"] }, "2": { "name": "Old", "items": ["/n"] } };
    const s = C.place(["group:1", "group:2", "/n2", "/x"], gs, "1", ["/x", "/n"]);
    assert.deepEqual(plain(s.items), ["group:1", "group:2", "/n2"]);
    assert.deepEqual(plain(s.groups["1"].items), ["/p1", "/x", "/n"]);
    assert.deepEqual(plain(s.groups["2"].items), []);
    assert.deepEqual(plain(s.fresh), []);
    // Kept again at the top level, it leaves the folder it was in.
    const t = C.place(["group:1"], gs, "", ["/p1"]);
    assert.deepEqual(plain(t.items), ["/p1", "group:1"]);
    assert.deepEqual(plain(t.groups["1"].items), []);
    // A folder gone meanwhile: the files land at the head.
    assert.deepEqual(plain(C.place(["/a"], {}, "9", ["/b"]).items), ["/b", "/a"]);
});

test("a drop on a folder on disk moves neither the folder into itself nor a file already in it", () => {
    assert.deepEqual(plain(C.movable(["/d/a", "/e/b", "/d", "/e/b", "/d/x/c"], "/d/x")), ["/d/a", "/e/b"]);
    assert.deepEqual(plain(C.movable(["/x"], "/")), []);
    assert.deepEqual(plain(C.movable(["/data/a.txt"], "/data/docs")), ["/data/a.txt"]);
    assert.deepEqual(plain(C.movable(undefined, "/d")), []);
});

test("the script's moves are read in order, other lines left out", () => {
    assert.deepEqual(plain(C.moves("/a\t/d/a\n/b\t/d/b (2)\nnoise\n\t/x\n")), [["/a", "/d/a"], ["/b", "/d/b (2)"]]);
    assert.deepEqual(plain(C.moves("")), []);
});

test("links follow the moved files, a moved folder taking the links below it", () => {
    const gs = { "1": { "name": "Trip", "items": ["/f/p", "/z"] } };
    const s = C.relink(["/a", "group:1", "/f"], gs, [["/a", "/d/a"], ["/f", "/d/f"]]);
    assert.deepEqual(plain(s.items), ["/d/a", "group:1", "/d/f"]);
    assert.deepEqual(plain(s.groups["1"].items), ["/d/f/p", "/z"]);
    // A name sharing a prefix is not below it.
    assert.deepEqual(plain(C.relink(["/fa"], {}, [["/f", "/d/f"]]).items), ["/fa"]);
});

test("a menu drops down when it fits, else rises from the click, never out of the card", () => {
    assert.equal(C.menuY(100, 200, 0, 500), 100);
    assert.equal(C.menuY(440, 200, 0, 500), 240);
    assert.equal(C.menuY(150, 200, 0, 300), 0);
    assert.equal(C.menuY(10, 600, 0, 500), 0);
});
