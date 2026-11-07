import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandShelf.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const plain = v => JSON.parse(JSON.stringify(v));

test("Tab and Shift+Tab walk the card's stops and wrap, never out of it", () => {
    assert.equal(C.wrap(0, false, 3), 1);
    assert.equal(C.wrap(2, false, 3), 0);
    assert.equal(C.wrap(0, true, 3), 2);
    assert.equal(C.wrap(1, true, 3), 0);
    // From nothing focused in the ring: the first stop, or the last going back.
    assert.equal(C.wrap(-1, false, 4), 0);
    assert.equal(C.wrap(-1, true, 4), 3);
    assert.equal(C.wrap(9, false, 4), 0);
    assert.equal(C.wrap(0, false, 1), 0);
    assert.equal(C.wrap(0, false, 0), -1);
});

test("files the shelf copied come back through the document portal as their real paths", () => {
    const copied = ["/data/Documents/a.png", "/data/b c.txt"];
    assert.deepEqual(plain(C.unportal(["/run/user/1000/doc/6hHy/a.png", "/run/user/1000/doc/yh0/b c.txt"], copied)), copied);
    // Under any runtime dir (a bench's own).
    assert.deepEqual(plain(C.unportal(["/srv/bench/run/doc/6hHy/a.png"], copied)), [copied[0]]);
    // Not copied from here, or not the portal's: left as they are.
    assert.deepEqual(plain(C.unportal(["/run/user/1000/doc/zz/other.pdf", "/tmp/a.png"], copied)), ["/run/user/1000/doc/zz/other.pdf", "/tmp/a.png"]);
    assert.deepEqual(plain(C.unportal(["/run/user/1000/doc/zz/sub/a.png"], copied)), ["/run/user/1000/doc/zz/sub/a.png"]);
    assert.deepEqual(plain(C.unportal(undefined, copied)), []);
});
