import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandDownload.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const names = r => Array.from(r.finished, e => e.name);

test("stat's sizes are matched by file name, a file it could not read leaving no gap", () => {
    const sizes = C.statSizes("120 /dl/a b.part\n4096 /dl/c.part\n", "/dl");
    assert.equal(sizes["a b.part"], 120);
    assert.equal(sizes["c.part"], 4096);
    assert.equal(Object.keys(sizes).length, 2);
    assert.equal(Object.keys(C.statSizes("", "/dl")).length, 0);
    assert.equal(Object.keys(C.statSizes("12 /other/x.part", "/dl")).length, 0);
});

test("a file URL encodes each segment of the path", () => {
    assert.equal(C.fileUrl("/data/My #1?.pdf"), "file:///data/My%20%231%3F.pdf");
    assert.equal(C.fileUrl(""), "");
});

test("the first listing only seeds", () => {
    const r = C.step(null, [{ "name": "a.pdf", "size": 10 }, { "name": "b.part", "size": 3 }]);
    assert.deepEqual(names(r), []);
    assert.deepEqual(names(C.step(r.state, [{ "name": "a.pdf", "size": 10 }])), []);
});

test("firefox: empty placeholder and .part, finished once the .part is gone", () => {
    let r = C.step(null, []);
    r = C.step(r.state, [{ "name": "x.zip", "size": 0 }]);
    assert.deepEqual(names(r), []);
    r = C.step(r.state, [{ "name": "x.zip", "size": 0 }, { "name": "x.zip.part", "size": 500 }]);
    assert.deepEqual(names(r), []);
    // The listing may still carry the placeholder's size: the wait is enough.
    r = C.step(r.state, [{ "name": "x.zip", "size": 0 }]);
    assert.deepEqual(names(r), ["x.zip"]);
    assert.deepEqual(names(C.step(r.state, [{ "name": "x.zip", "size": 900 }])), []);
});

test("chromium: a renamed .crdownload, hidden and temporary files are never announced", () => {
    let r = C.step(null, [{ "name": "Unconfirmed 1.crdownload", "size": 5 }, { "name": ".hidden", "size": 1 }]);
    r = C.step(r.state, [{ "name": "y.iso", "size": 2048 }, { "name": ".hidden2", "size": 1 }, { "name": "z.tmp", "size": 4 }]);
    assert.deepEqual(names(r), ["y.iso"]);
    assert.equal(C.isTemp("A.PART"), true);
});

test("a removed then re-added file is announced again; an empty new file waits for content", () => {
    let r = C.step(null, [{ "name": "a", "size": 1 }]);
    r = C.step(r.state, []);
    r = C.step(r.state, [{ "name": "a", "size": 1 }, { "name": "e", "size": 0 }]);
    assert.deepEqual(names(r), ["a"]);
    assert.deepEqual(names(C.step(r.state, [{ "name": "a", "size": 1 }, { "name": "e", "size": 3 }])), ["e"]);
});

test("running downloads, newest first, named as they will finish", () => {
    const r = C.running([
        { "name": "Fedora-44-1.7.x86_64.iso", "size": 0, "modified": 1 },
        { "name": "Fedora-44-1.2ZOe61wk.7.x86_64.iso.part", "size": 9, "modified": 1 },
        { "name": "b.zip.crdownload", "size": 5, "modified": 2 },
        { "name": "c.pdf", "size": 3, "modified": 3 },
        { "name": ".hidden.part", "size": 1, "modified": 4 },
        { "name": "cache.tmp", "size": 1, "modified": 5 }
    ]);
    assert.deepEqual(Array.from(r, e => e.name), ["b.zip", "Fedora-44-1.7.x86_64.iso"]);
    assert.equal(r[1].part, "Fedora-44-1.2ZOe61wk.7.x86_64.iso.part");
});

test("speed comes from two samples and never goes negative", () => {
    let s = C.sample(null, { "a.part": 100 }, 1000);
    assert.equal(s.speeds["a.part"], 0);
    s = C.sample(s.state, { "a.part": 2100 }, 3000);
    assert.equal(s.speeds["a.part"], 1000);
    assert.equal(C.sample(s.state, { "a.part": 50 }, 4000).speeds["a.part"], 0);
});
