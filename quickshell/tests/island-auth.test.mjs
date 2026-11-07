import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const A = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandAuth.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), A);

test("a prompt asking for a response is a password, whatever the info line says", () => {
    assert.equal(A.mode(true, "Place your finger on the fingerprint reader"), "password");
    assert.equal(A.mode(true, ""), "password");
});

test("info lines from fprintd and howdy pick the finger or the face", () => {
    assert.equal(A.mode(false, "Place your finger on the fingerprint reader"), "fingerprint");
    assert.equal(A.mode(false, "Swipe your right index finger across the fingerprint reader"), "fingerprint");
    assert.equal(A.mode(false, "Attempting face detection"), "face");
    assert.equal(A.mode(false, "Identified face as user"), "face");
});

test("no prompt and no known info line waits", () => {
    assert.equal(A.mode(false, ""), "wait");
    assert.equal(A.mode(false, undefined), "wait");
    assert.equal(A.mode(false, "Authenticating"), "wait");
});

test("prompt label drops the trailing colon, icons follow the mode", () => {
    assert.equal(A.promptLabel("Password: "), "Password");
    assert.equal(A.promptLabel(null), "");
    assert.equal(A.modeIcon("fingerprint"), "fingerprint");
    assert.equal(A.modeIcon("face"), "face");
    assert.equal(A.modeIcon("password"), "lock");
});
