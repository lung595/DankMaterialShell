import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const U = loadScript(new URL("../Common/IslandUrgent.js", import.meta.url));

const wins = [
    { "id": 1, "is_urgent": true },
    { "id": 2, "is_urgent": false },
    { "id": 3, "is_urgent": true }
];

test("only urgent windows count", () => {
    assert.deepEqual([...U.urgentIds(wins)], [1, 3]);
    assert.equal(U.urgentIds(undefined).length, 0);
    assert.equal(U.urgentIds([null, 4]).length, 0);
});

test("a window already calling does not call again; the newest new one wins", () => {
    assert.equal(U.fresh(wins, []).id, 3);
    assert.equal(U.fresh(wins, [3]).id, 1);
    assert.equal(U.fresh(wins, [1, 3]), null);
    assert.equal(U.fresh(null, null), null);
});
