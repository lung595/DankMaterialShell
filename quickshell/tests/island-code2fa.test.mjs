import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandCode2fa.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const C = ctx;

test("a code next to a keyword is found, in English and French", () => {
    assert.equal(C.find("Messages", "Votre code de vérification est 482913."), "482913");
    assert.equal(C.find("Your OTP", "Use 7731 to sign in"), "7731");
    assert.equal(C.find("Google", "G-123456 is your verification code"), "123456");
    assert.equal(C.find("Bank", "Security code: 123 456"), "123456");
    assert.equal(C.find("2FA", "<b>1234-5678</b>"), "12345678");
});

test("no keyword, or no lone 4-8 digits: no code", () => {
    assert.equal(C.find("Mum", "See you at 1830 tomorrow"), "");
    assert.equal(C.find("Code", "Call 0612345678"), "");
    assert.equal(C.find("Code", "Paid 1234,50 € today"), "");
    assert.equal(C.find("Code", "Total 2500 €"), "");
    assert.equal(C.find("Code", "Version 12.3456"), "");
    assert.equal(C.find("Code review", "3 comments"), "");
});

test("a sign-in code relayed by KDE Connect: bracketed, next to « Log in »", () => {
    assert.equal(C.find("Proton Mail", "Recent: [780473] Log in to Recent"), "780473");
    assert.equal(C.find("Proton Mail", "Sign in with 482913"), "482913");
});

test("« log in » alone never makes any number a code", () => {
    assert.equal(C.find("Proton Mail", "Recent: Log in to Recent"), "");
    assert.equal(C.find("Forum", "Log in to read 12 new replies"), "");
    assert.equal(C.find("Shop", "Order 780473 has shipped"), "");
    assert.equal(C.find("Bank", "Log in or call +33 6 12 34 56 78"), "");
});

test("a year, a date or a time is never the code; the number nearest a keyword is", () => {
    assert.equal(C.find("Account", "New sign-in on Oct 31, 2026"), "");
    assert.equal(C.find("Account", "Login detected 2026-10-31 from Paris"), "");
    assert.equal(C.find("Account", "Login at 1830: your code is 482913"), "482913");
    assert.equal(C.find("Account", "Login at 1830, your code is 482913"), "482913");
    assert.equal(C.find("Bank", "Code 482913: do not share it"), "482913");
    assert.equal(C.find("Bank", "Use 482913 as your code. Ref 20261031"), "482913");
    assert.equal(C.find("Mum", "Your code? See you at 18:30"), "");
    assert.equal(C.find("Bank", "Your code: 2026"), "2026");
});

test("grouped and masked keep the code's shape", () => {
    assert.equal(C.grouped("482913"), "482 913");
    assert.equal(C.grouped("12345678"), "1234 5678");
    assert.equal(C.grouped("7731"), "7731");
    assert.equal(C.masked("482913"), "••• •••");
});

test("a screen share keeps the code masked, even hovered", () => {
    assert.equal(C.shown("482913", true, false), "482 913");
    assert.equal(C.shown("482913", true, true), "••• •••");
    assert.equal(C.shown("482913", false, false), "••• •••");
});

test("the code is copied as a secret: to the core, else to wl-copy's standard input for one paste", () => {
    assert.deepEqual(JSON.parse(JSON.stringify(C.copyPlan("482913", true))), { "request": "clipboard.copy", "params": { "text": "482913", "secret": true } });
    const plan = C.copyPlan("482913", false);
    assert.deepEqual(Array.from(plan.command), ["wl-copy", "--paste-once"]);
    assert.equal(plan.stdin, "482913");
    assert.equal(plan.request, undefined);
});

test("hover holds the code; once copied it holds the leave countdown instead; on the island its own timer decides", () => {
    assert.equal(C.heldTimer(true, "", false), "life");
    assert.equal(C.heldTimer(true, "", true), "leave");
    assert.equal(C.heldTimer(true, "dms:code2fa:4", false), "");
    assert.equal(C.heldTimer(false, "", true), "");
});

test("a code pushed out to its bubble goes back to the freed island with the rest of its time (rule 0 ter)", () => {
    const s = { "free": true, "entry": true, "token": "", "copied": false, "hovered": false, "left": 3000 };
    assert.equal(C.backToIsland(s), 3000);
    for (const [k, v] of [["free", false], ["entry", false], ["token", "t"], ["copied", true], ["hovered", true], ["left", 400]])
        assert.equal(C.backToIsland(Object.assign({}, s, { [k]: v })), 0, k);
});
