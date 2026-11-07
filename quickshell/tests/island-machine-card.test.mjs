import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const M = loadScript(new URL("../Common/IslandMachineCard.js", import.meta.url));
const host = open => ({ "islandController": { "machineCardOpen": open }, "body": { "bubbleSides": { "machine": {} } } });

test("the machine card's IPC refuses an unknown action, a missing island and a missing machine bubble", () => {
    assert.equal(M.ipc(host(false), "flip"), "ISLAND_CARD_ACTIONS: open close toggle");
    assert.equal(M.ipc(null, "open"), "ISLAND_UNAVAILABLE");
    assert.equal(M.ipc({ "islandController": {}, "body": { "bubbleSides": {} } }, "open"), "ISLAND_CARD_UNAVAILABLE: no machine bubble");
});

test("the machine card's IPC decides open, close and toggle without writing the state", () => {
    const h = host(false);
    assert.equal(M.ipc(h, "open"), true);
    assert.equal(M.ipc(host(true), "close"), false);
    assert.equal(M.ipc(h, "toggle"), true);
    assert.equal(M.ipc(host(true), "toggle"), false);
    assert.equal(h.islandController.machineCardOpen, false);
});
