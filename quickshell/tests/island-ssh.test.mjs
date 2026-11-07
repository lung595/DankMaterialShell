import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandSsh.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const S = ctx;

test("ids keeps the session ids and drops anything that is not one", () => {
    const json = JSON.stringify([{ "session": "4" }, { "session": "c12" }, { "session": "4; rm" }, {}]);
    assert.deepEqual([...S.ids(json)], ["4", "c12"]);
    assert.deepEqual([...S.ids("not json")], []);
    assert.deepEqual([...S.ids("{}")], []);
});

const show = [
    "Id=4", "Name=me", "Timestamp=Fri 2026-10-23 14:02:36 CEST", "Remote=no", "RemoteHost=", "Service=greetd", "",
    "Id=31", "Name=guest", "Timestamp=Fri 2026-10-23 15:10:00 CEST", "Remote=yes", "RemoteHost=192.0.2.7", "Service=sshd", "",
    "Id=30", "Name=me", "Timestamp=Fri 2026-10-23 15:00:00 CEST", "Remote=yes", "RemoteHost=", "Service=sshd", "",
    "Id=32", "Name=x", "Remote=yes", "RemoteHost=192.0.2.8", "Service=login"
].join("\n");

test("sessions keeps remote sshd sessions only, oldest first, with their local time", () => {
    const s = S.sessions(show);
    assert.equal(s.length, 2);
    assert.equal(s[0].id, "30");
    assert.equal(s[0].host, "");
    assert.equal(s[1].user, "guest");
    assert.equal(s[1].host, "192.0.2.7");
    assert.equal(s[1].since, new Date(2026, 9, 23, 15, 10, 0).getTime());
    assert.equal(S.sessions("").length, 0);
});

test("arrived names the first new session", () => {
    const a = [{ "id": "30" }];
    const b = [{ "id": "30" }, { "id": "31" }];
    assert.equal(S.arrived(a, b).id, "31");
    assert.equal(S.arrived(b, a), null);
    assert.equal(S.arrived(null, a).id, "30");
});
