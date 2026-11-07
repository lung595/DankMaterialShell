import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandCall.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const C = ctx;

test("an app recording and playing back is a call; a recorder alone is not", () => {
    const calls = C.calls([
        { "id": 1, "input": true, "app": "Discord", "binary": "Discord", "pid": 10 },
        { "id": 2, "input": false, "app": "Discord", "binary": "Discord", "pid": 10 },
        { "id": 3, "input": true, "app": "Audacity", "binary": "audacity", "pid": 20 }
    ]);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].app, "Discord");
    assert.equal(calls[0].icon, "discord");
    assert.deepEqual([...calls[0].inputs], [1]);
    assert.equal(calls[0].muted, false);
});

test("a phone role alone makes a call, and it is muted only when every input is", () => {
    const one = C.calls([
        { "id": 1, "input": true, "app": "Calls", "role": "Communication", "muted": true },
        { "id": 2, "input": true, "app": "Calls", "role": "Communication", "muted": false }
    ]);
    assert.equal(one.length, 1);
    assert.equal(one[0].muted, false);
    const all = C.calls([{ "id": 1, "input": true, "app": "Calls", "role": "phone", "muted": true }]);
    assert.equal(all[0].muted, true);
});

test("bad rows and nameless streams give no call", () => {
    assert.equal(C.calls(undefined).length, 0);
    assert.equal(C.calls([null, 3, { "id": 1, "input": true }]).length, 0);
});

test("the duration fits the pill", () => {
    assert.equal(C.duration(0), "0:00");
    assert.equal(C.duration(65), "1:05");
    assert.equal(C.duration(3599), "59:59");
    assert.equal(C.duration(3720), "1h02");
    assert.equal(C.duration(-4), "0:00");
    assert.ok(C.duration(99 * 3600).length <= 6);
});

test("hang up actions are found by id or label", () => {
    assert.equal(C.hangUpAction([{ "identifier": "answer", "text": "Answer" }, { "identifier": "x", "text": "Hang up" }]), 1);
    assert.equal(C.hangUpAction([{ "identifier": "decline", "text": "" }]), 0);
    assert.equal(C.hangUpAction([{ "identifier": "default", "text": "Open" }]), -1);
    assert.equal(C.hangUpAction(null), -1);
});

test("app names match across case and reverse-domain ids", () => {
    const call = { "app": "Signal", "binary": "signal-desktop", "icon": "signal-desktop" };
    assert.ok(C.sameApp(call, "org.signal.Signal"));
    assert.ok(C.sameApp(call, "signal-desktop"));
    assert.ok(!C.sameApp(call, "firefox"));
    assert.ok(!C.sameApp(call, ""));
    assert.ok(!C.sameApp(null, "signal"));
});

test("Discord's WebRTC streams are named after the binary, with their streams split by direction", () => {
    const [call] = C.calls([
        { "id": 126, "input": true, "app": "WEBRTC VoiceEngine", "binary": "Discord", "pid": "302632", "muted": true },
        { "id": 123, "input": false, "app": "WEBRTC VoiceEngine", "binary": "Discord", "pid": "302632", "muted": true },
        { "id": 9, "input": false, "app": "Firefox", "binary": "firefox", "pid": "77" }
    ]);
    assert.equal(call.app, "Discord");
    assert.equal(call.pid, "302632");
    assert.deepEqual([...call.inputs], [126]);
    assert.deepEqual([...call.outputs], [123]);
    assert.equal(call.muted, true);
    assert.equal(call.deafened, true);
    assert.deepEqual([...C.entryNames(call)], ["Discord"]);
});

test("desktop entry names skip app runtimes and engine names", () => {
    assert.deepEqual([...C.entryNames({ "app": "Vesktop", "binary": "electron" })], ["Vesktop"]);
    assert.deepEqual([...C.entryNames({ "app": "WEBRTC VoiceEngine", "binary": "electron36" })], []);
    assert.deepEqual([...C.entryNames({ "app": "Signal", "binary": "signal-desktop" })], ["signal-desktop", "Signal"]);
    assert.deepEqual([...C.entryNames(null)], []);
});
