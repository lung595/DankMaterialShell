import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandWifi.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const W = ctx;

test("an open network warns, unless secured, unknown, VPN already on, or no SSID", () => {
    assert.equal(W.decide("Cafe", false, [], true, false), "bubble");
    assert.equal(W.decide("Cafe", false, [], false, false), "bubble");
    assert.equal(W.decide("Cafe", true, [], true, false), "");
    assert.equal(W.decide("Cafe", null, [], true, false), "");
    assert.equal(W.decide("Cafe", false, [], true, true), "");
    assert.equal(W.decide("", false, ["" ], true, false), "");
});

test("a network marked always connects the VPN, only when a VPN can connect", () => {
    assert.equal(W.decide("Cafe", false, ["Cafe"], true, false), "vpn");
    assert.equal(W.decide("Cafe", false, ["Cafe"], false, false), "bubble");
    assert.equal(W.decide("Gare", false, ["Cafe"], true, false), "bubble");
});

test("security of the connected band, null when not found", () => {
    assert.equal(W.securedFromInfo({ bands: [{ connected: false, secured: true }, { connected: true, secured: false }] }), false);
    assert.equal(W.securedFromInfo({ bands: [{ secured: true }] }), true);
    assert.equal(W.securedFromInfo({ bands: [] }), null);
    assert.equal(W.securedFromInfo(null), null);
});

test("remember adds a network once", () => {
    assert.deepEqual([...W.remember([], "Cafe")], ["Cafe"]);
    assert.deepEqual([...W.remember(["Cafe"], "Cafe")], ["Cafe"]);
    assert.deepEqual([...W.remember(undefined, "Cafe")], ["Cafe"]);
    assert.deepEqual([...W.remember(["Cafe"], "")], ["Cafe"]);
});
