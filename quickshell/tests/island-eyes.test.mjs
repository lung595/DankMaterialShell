import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const E = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandEyes.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), E);

test("settings are clamped, bad values fall back to the defaults", () => {
    assert.equal(E.intervalMs(20), 20 * 60000);
    assert.equal(E.intervalMs(1), 5 * 60000);
    assert.equal(E.intervalMs(999), 120 * 60000);
    assert.equal(E.intervalMs("x"), 20 * 60000);
    assert.equal(E.durationSec(undefined), 20);
    assert.equal(E.durationSec(3), 10);
    assert.equal(E.durationSec(45.4), 45);
});

test("fullscreen or a call defers the break", () => {
    assert.equal(E.deferred(false, false, false, false), false);
    assert.equal(E.deferred(true, false, false, false), true);
    assert.equal(E.deferred(false, true, false, false), true);
    assert.equal(E.deferred(false, false, true, false), true);
    assert.equal(E.deferred(false, false, false, true), true);
});

test("a resting island takes the break, a busy one sends it to the bubble", () => {
    const rest = { expanded: false, pluginActive: false, notificationActive: false, systemActivityActive: false };
    assert.equal(E.route([rest]), "island");
    assert.equal(E.route([{ ...rest, expanded: true }]), "bubble");
    assert.equal(E.route([{ ...rest, notificationActive: true }]), "bubble");
    assert.equal(E.route([{ ...rest, systemActivityActive: true }, rest]), "island");
    assert.equal(E.route([]), "bubble");
    assert.equal(E.route(null), "bubble");
});

test("the shelf at rest gives the island up to anything else", () => {
    const rest = { expanded: false, pluginActive: true, notificationActive: false, systemActivityActive: false };
    assert.equal(E.route([{ ...rest, pluginToken: "dms:shelf:4" }]), "island");
    assert.equal(E.route([{ ...rest, pluginToken: "dms:transfer:5" }]), "bubble");
    assert.equal(E.route([{ ...rest, pluginToken: "dms:shelf:4", expanded: true }]), "bubble");
});
