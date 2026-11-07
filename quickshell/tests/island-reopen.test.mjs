import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const R = loadScript(new URL("../Common/IslandReopen.js", import.meta.url));
const apps = R.parseApps(" Signal, discord ,,steam ");

test("the setting parses to lowercase names, blanks dropped", () => {
    assert.deepEqual([...apps], ["signal", "discord", "steam"]);
    assert.equal(R.parseApps("").length, 0);
    assert.equal(R.parseApps(undefined).length, 0);
});

test("app ids match by name or dotted part, not by substring", () => {
    assert.ok(R.watched("signal", apps));
    assert.ok(R.watched("org.signal.Signal", apps));
    assert.ok(R.watched("com.discordapp.Discord", apps));
    assert.ok(R.watched("steam", apps));
    assert.ok(!R.watched("steamwebhelper-x", ["steamweb"]));
    assert.ok(!R.watched("firefox", apps));
    assert.ok(!R.watched("", apps));
});

test("only the last window of a watched app counts as closed", () => {
    const a = { "id": 1, "app_id": "signal" };
    const b = { "id": 2, "app_id": "discord" };
    const b2 = { "id": 3, "app_id": "discord" };
    const f = { "id": 4, "app_id": "firefox" };
    assert.deepEqual([...R.closedApps([a, b, b2, f], [b2], apps)], ["signal"]);
    assert.deepEqual([...R.closedApps([a, b, b2], [], apps)], ["signal", "discord"]);
    assert.equal(R.closedApps([f], [], apps).length, 0);
    assert.equal(R.closedApps([a], [a], apps).length, 0);
    assert.equal(R.closedApps(null, [], apps).length, 0);
});

test("the stack puts the newest first, without duplicates, capped", () => {
    let s = [];
    for (const id of ["a", "b", "c", "b"])
        s = R.push(s, id, 3);
    assert.deepEqual([...s], ["b", "c", "a"]);
    assert.deepEqual([...R.push(s, "d", 3)], ["d", "b", "c"]);
});

test("the wheel walks the stack both ways and wraps", () => {
    const s = ["a", "b", "c"];
    assert.deepEqual([...R.rotate(s, 1)], ["b", "c", "a"]);
    assert.deepEqual([...R.rotate(s, -1)], ["c", "a", "b"]);
    assert.deepEqual([...R.rotate(["a"], 1)], ["a"]);
    assert.deepEqual([...R.rotate(s, 0)], ["a", "b", "c"]);
});
