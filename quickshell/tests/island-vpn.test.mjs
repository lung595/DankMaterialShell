import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandVpn.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const V = ctx;

const up = [{ "name": "Work", "uuid": "u1", "state": "activated" }];

test("a drop is when the last VPN goes, named by name then uuid", () => {
    assert.equal(V.dropped(up, []), "Work");
    assert.equal(V.dropped([{ "uuid": "u2", "state": "activated" }], []), "u2");
    // A connection that never came up (activating, then gone) did not drop.
    assert.equal(V.dropped([{ "name": "Work", "state": "activating" }], []), "");
    assert.equal(V.dropped([], []), "");
    assert.equal(V.dropped(up, up), "");
    assert.equal(V.dropped(null, null), "");
    assert.equal(V.dropped(up.concat([{ "name": "B", "state": "activated" }]), [{ "name": "B" }]), "");
});

test("a VPN going down through deactivating still drops, judged by the list last seen up", () => {
    let last = V.lastUp([], up);
    const going = [{ "name": "Work", "uuid": "u1", "state": "deactivating" }];
    assert.equal(V.dropped(last, going), "");
    last = V.lastUp(last, going);
    assert.equal(V.dropped(last, []), "Work");
    last = V.lastUp(last, []);
    assert.equal(last.length, 0);
    // A reconnect that fails (activating, then gone) is no second drop, and the bubble stays until one is up.
    const trying = [{ "name": "Work", "state": "activating" }];
    last = V.lastUp(last, trying);
    assert.equal(V.backUp(trying), false);
    assert.equal(V.dropped(last, []), "");
    assert.equal(V.backUp(up), true);
});

test("reconnect goes back to the dropped VPN, else DMS's last one", () => {
    assert.equal(V.reconnectUuid(up, "u9"), "u1");
    assert.equal(V.reconnectUuid([{ "name": "x" }], "u9"), "u9");
    assert.equal(V.reconnectUuid([], ""), "");
});

test("wanted when DMS was disconnecting or the user disconnected close to the drop", () => {
    assert.equal(V.wanted(true, 0, 1000), true);
    assert.equal(V.wanted(false, 0, 1000), false);
    assert.equal(V.wanted(false, 10000, 12000), true);
    assert.equal(V.wanted(false, 13000, 12000), true);
    assert.equal(V.wanted(false, 1000, 12000), false);
});

test("only NetworkManager's deactivated by the user counts", () => {
    assert.equal(V.userDown([4, 2]), true);
    assert.equal(V.userDown([4, 1]), false);
    assert.equal(V.userDown([2, 2]), false);
    assert.equal(V.userDown(null), false);
});
