import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const S = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandScreen.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), S);
const plain = v => JSON.parse(JSON.stringify(v));

const laptop = { make: "BOE", model: "NE135", serial: "Unknown", logical: { x: 0, y: 0, width: 1500, height: 1000 } };
const tv = { make: "Acme", model: "TV 55", serial: "42", logical: { x: 1500, y: 0, width: 1920, height: 1080 } };
const outputs = { "eDP-1": laptop, "HDMI-A-1": tv };

test("a plug is a name that was not there; the first fill is the boot", () => {
    assert.deepEqual(plain(S.added(null, outputs)), []);
    assert.deepEqual(plain(S.added(["eDP-1"], outputs)), ["HDMI-A-1"]);
    assert.deepEqual(plain(S.added(["eDP-1", "HDMI-A-1"], { "eDP-1": laptop })), []);
});

test("the key follows the monitor, not the port; the label is its model", () => {
    assert.equal(S.key(tv, "HDMI-A-1"), "Acme TV 55 42");
    assert.equal(S.key(laptop, "eDP-1"), "BOE NE135");
    assert.equal(S.key({}, "DP-3"), "DP-3");
    assert.equal(S.label(tv, "HDMI-A-1"), "TV 55");
    assert.equal(S.label(null, "DP-3"), "DP-3");
});

test("extend turns the output on and lets niri place it", () => {
    assert.deepEqual(plain(S.actions("extend", "HDMI-A-1", outputs)), [
        { output: "HDMI-A-1", action: "On" },
        { output: "HDMI-A-1", action: { Position: { position: "Automatic" } } }]);
});

test("duplicate asks for the reference's place; only turns the others off after the new one is on", () => {
    assert.deepEqual(plain(S.actions("duplicate", "HDMI-A-1", outputs))[1], { output: "HDMI-A-1", action: { Position: { position: { Specific: { x: 0, y: 0 } } } } });
    assert.deepEqual(plain(S.actions("only", "HDMI-A-1", outputs)), [
        { output: "HDMI-A-1", action: "On" },
        { output: "eDP-1", action: "Off" }]);
});

test("an unknown choice or output does nothing", () => {
    assert.deepEqual(plain(S.actions("mirror", "HDMI-A-1", outputs)), []);
    assert.deepEqual(plain(S.actions("only", "DP-9", outputs)), []);
});

test("restore puts every output back, those turned on first", () => {
    const before = { "HDMI-A-1": { logical: null }, "eDP-1": laptop };
    assert.deepEqual(plain(S.restore(before)), [
        { output: "eDP-1", action: "On" },
        { output: "eDP-1", action: { Position: { position: { Specific: { x: 0, y: 0 } } } } },
        { output: "HDMI-A-1", action: "Off" }]);
});

test("each step becomes a niri msg output command, so niri's refusal is read; other actions none", () => {
    const steps = S.actions("duplicate", "HDMI-A-1", outputs).concat(S.actions("extend", "HDMI-A-1", outputs), S.actions("only", "HDMI-A-1", outputs));
    assert.deepEqual(plain(steps.map(s => S.command(s))), [
        ["niri", "msg", "output", "HDMI-A-1", "on"],
        ["niri", "msg", "output", "HDMI-A-1", "position", "set", "0", "0"],
        ["niri", "msg", "output", "HDMI-A-1", "on"],
        ["niri", "msg", "output", "HDMI-A-1", "position", "auto"],
        ["niri", "msg", "output", "HDMI-A-1", "on"],
        ["niri", "msg", "output", "eDP-1", "off"]
    ]);
    assert.equal(S.command({ "output": "eDP-1", "action": { "Scale": { "scale": 2 } } }), null);
    assert.equal(S.command(null), null);
});
