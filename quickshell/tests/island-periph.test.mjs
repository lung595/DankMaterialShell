import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandPeriph.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);

function run(readings) {
    let s = null;
    return readings.map(([p, c]) => (s = C.step(s, p, c)).alert + (s.step ? s.step : ""));
}

test("a discharge warns once at 15 % then once at 5 %", () => {
    assert.deepEqual(run([[40, false], [15, false], [14, false], [9, false], [5, false], [3, false]]), ["", "low15", "", "", "low5", ""]);
});

test("a first reading already under 5 % warns once, at 5 %", () => {
    assert.deepEqual(run([[4, false], [3, false]]), ["low5", ""]);
});

test("15/16 % jitter does not repeat; 20 % rearms", () => {
    assert.deepEqual(run([[15, false], [16, false], [15, false], [20, false], [15, false]]), ["low15", "", "", "", "low15"]);
});

test("plugging in raises charging and rearms; already charging at start stays quiet", () => {
    assert.deepEqual(run([[10, false], [10, true], [11, true], [12, false], [11, false]]), ["low15", "charging", "", "low15", ""]);
    assert.deepEqual(run([[50, true], [50, true]]), ["", ""]);
});

test("an unset level (0) keeps the marks and never warns", () => {
    assert.deepEqual(run([[14, false], [0, false], [13, false], [4, false]]), ["low15", "", "", "low5"]);
});

test("icons per device type", () => {
    assert.equal(C.icon("mouse"), "mouse");
    assert.equal(C.icon("gamepad"), "sports_esports");
    assert.equal(C.icon("printer"), "");
});

test("a device that appears after the shell settled and is already charging raises charging; at startup it only seeds", () => {
    assert.equal(C.step(C.first(true), 31, true).alert, "charging");
    assert.equal(C.step(C.first(false), 31, true).alert, "");
    assert.equal(C.step(C.first(true), 4, false).alert, "low");
    assert.equal(C.step(C.first(true), 50, false).alert, "");
});

test("a device that left charging and comes back charging under the same path raises charging again", () => {
    const marks = {};
    const read = () => (marks.pad = C.step(marks.pad ?? C.first(true), 60, true)).alert;
    assert.equal(read(), "charging");
    assert.equal(read(), "");
    delete marks.pad; // what IslandPeriphSource does as UPower drops the device
    assert.equal(read(), "charging");
});

test("a model's type is remembered once, unchanged maps are not rewritten", () => {
    const types = C.remember({}, "G502", "mouse");
    assert.equal(types.G502, "mouse");
    assert.equal(C.remember(types, "G502", "mouse"), null);
    assert.equal(C.remember(types, "", "mouse"), null);
    assert.equal(C.remember(types, "G502", "headset").G502, "headset");
});

test("the remembered types stay bounded: past the bound the oldest model leaves", () => {
    let types = {};
    for (let i = 0; i < 20; i++)
        types = C.remember(types, `model ${i}`, "mouse");
    assert.equal(Object.keys(types).length, 16);
    assert.equal(types["model 3"], undefined);
    assert.equal(types["model 4"], "mouse");
    types = C.remember(types, "model 4", "headset");
    types = C.remember(types, "model 20", "mouse");
    assert.equal(types["model 4"], "headset");
    assert.equal(types["model 5"], undefined);
});

test("a model named in digits is not written: an object lists those keys first, out of write order", () => {
    let types = {};
    for (let i = 0; i < 16; i++)
        types = C.remember(types, `model ${i}`, "mouse");
    assert.equal(C.remember(types, "502", "mouse"), null);
    types = C.remember(types, "model 16", "mouse");
    assert.deepEqual(Object.keys(types), Array.from({ length: 16 }, (_, i) => `model ${i + 1}`));
});

test("UPower's keyboard guess yields to the type the same model reported another time", () => {
    const types = { "G502": "mouse", "Pad": "keyboard" };
    assert.equal(C.kind("keyboard", types, "G502"), "mouse");
    assert.equal(C.kind("keyboard", types, "MX Keys"), "keyboard");
    assert.equal(C.kind("keyboard", undefined, "G502"), "keyboard");
    assert.equal(C.kind("mouse", types, "Pad"), "mouse");
    assert.equal(C.kind("headset", types, "G502"), "headset");
});

test("hostile session data or model names: no inherited value, no type outside the set, no unsafe or huge key", () => {
    const types = JSON.parse('{"__proto__": "mouse", "Odd": "printer", "Toy": {"x": 1}}');
    assert.equal(C.kind("keyboard", types, "constructor"), "keyboard");
    assert.equal(C.kind("keyboard", types, "toString"), "keyboard");
    assert.equal(C.kind("keyboard", types, "Odd"), "keyboard");
    assert.equal(C.kind("keyboard", types, "Toy"), "keyboard");
    assert.equal(C.remember({}, "__proto__", "mouse"), null);
    assert.equal(C.remember({}, "constructor", "mouse"), null);
    assert.equal(C.remember({}, "hasOwnProperty", "mouse"), null);
    assert.equal(C.remember({}, "x".repeat(10000), "mouse"), null);
    assert.equal(C.remember({}, "x".repeat(128), "mouse")["x".repeat(128)], "mouse");
});

test("remembered types that are not an object in session.json (null, a string, a list) start over, never throw", () => {
    for (const bad of [null, undefined, "mouse", 3, ["mouse"]]) {
        assert.deepEqual({ ...C.remember(bad, "G502", "mouse") }, { "G502": "mouse" }, String(bad));
        assert.equal(C.kind("keyboard", bad, "G502"), "keyboard", String(bad));
    }
});

test("a keyboard reading, or a type outside the set, is never remembered: a cable's guess cannot overwrite the receiver's", () => {
    const types = { "G502": "mouse" };
    assert.equal(C.remember(types, "G502", "keyboard"), null);
    assert.equal(C.remember({}, "MX Keys", "keyboard"), null);
    assert.equal(C.remember({}, "Toaster", "toaster"), null);
    assert.equal(C.remember({}, "Pad", "gamepad").Pad, "gamepad");
});

// B12: a mouse can be "Acme Glide X 2" by its receiver and "Glide X 2" on its cable (same serial in UPower's history):
// the cable's keyboard guess must find the receiver's mouse.
test("a plug on the cable: the keyboard guess yields to the mouse the receiver reported under its vendor-prefixed name", () => {
    const types = C.remember({}, "Acme Glide X 2", "mouse");
    assert.equal(C.kind("keyboard", types, "Glide X 2"), "mouse");
    assert.equal(C.kind("keyboard", { "Glide X 2": "mouse" }, "Acme Glide X 2"), "mouse");
    assert.equal(C.kind("keyboard", {}, "Glide X 2"), "keyboard", "never seen: still the guess");
    assert.equal(C.kind("keyboard", types, "X 2"), "keyboard", "only one leading word may differ");
    assert.equal(C.kind("keyboard", types, ""), "keyboard");
});
