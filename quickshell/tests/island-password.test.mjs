import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandPassword.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const P = ctx;

test("password managers are recognised by app id, anything else gets the padlock", () => {
    assert.equal(P.managerOf("proton-pass"), "proton-pass");
    assert.equal(P.managerOf("Proton Pass"), "Proton Pass");
    assert.equal(P.managerOf("me.proton.Pass"), "me.proton.Pass");
    assert.equal(P.managerOf("org.keepassxc.KeePassXC"), "org.keepassxc.KeePassXC");
    assert.equal(P.managerOf("com.bitwarden.desktop"), "com.bitwarden.desktop");
    assert.equal(P.managerOf("firefox"), "");
    assert.equal(P.managerOf(""), "");
    assert.equal(P.managerOf(undefined), "");
});

test("the first state only primes: a password already held is not a new copy", () => {
    const s = P.step({ "secret": 3, "secretActive": true }, -1);
    assert.equal(s.copied, false);
    assert.equal(s.last, 3);
});

test("a new secret count while held is a copy; the same count is not", () => {
    assert.equal(P.step({ "secret": 1, "secretActive": true }, 0).copied, true);
    assert.equal(P.step({ "secret": 1, "secretActive": true }, 1).copied, false);
    // The backend restarted (count back to 1): still a new copy.
    assert.equal(P.step({ "secret": 1, "secretActive": true }, 4).copied, true);
});

test("the clipboard no longer holding it is gone, and history updates without the fields are too", () => {
    const s = P.step({ "secret": 2 }, 2);
    assert.equal(s.copied, false);
    assert.equal(s.gone, true);
    assert.equal(P.step({ "history": [] }, 0).gone, true);
    assert.equal(P.step(null, 0).gone, true);
});
