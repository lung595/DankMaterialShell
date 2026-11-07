import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandKeepAwake.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const V = ctx;

test("inhibitors group by app with all their cookies, DMS's own toggle last", () => {
    const rows = V.blockers([
        { "appName": "Firefox", "reason": "video", "cookie": 1 },
        { "appName": "mpv", "reason": "", "cookie": 2 },
        { "appName": "Firefox", "reason": "audio", "cookie": 3 }
    ], true);
    assert.equal(rows.length, 3);
    assert.deepEqual([...rows[0].cookies], [1, 3]);
    assert.equal(rows[0].reason, "video");
    assert.equal(rows[2].own, true);
});

test("bad entries are skipped and nothing blocking gives no rows", () => {
    assert.equal(V.blockers([null, 4, "x"], false).length, 0);
    assert.equal(V.blockers(undefined, false).length, 0);
    assert.equal(V.blockers([{ "appName": "", "cookie": 9 }], false)[0].app, "");
});

test("only a new app counts as an arrival; the same state again or a release does not", () => {
    const one = V.blockers([{ "appName": "Firefox", "cookie": 1 }], false);
    const two = V.blockers([{ "appName": "Firefox", "cookie": 1 }, { "appName": "mpv", "cookie": 2 }], false);
    assert.equal(V.arrived("", one), true);
    assert.equal(V.arrived(V.key(one), one), false);
    assert.equal(V.arrived(V.key(one), two), true);
    assert.equal(V.arrived(V.key(two), one), false);
    assert.equal(V.arrived(V.key(one), V.blockers([{ "appName": "Firefox", "cookie": 1 }], true)), true);
});

test("the bubble names the newest app, DMS's own toggle only alone", () => {
    assert.equal(V.lead(V.blockers([{ "appName": "Firefox" }, { "appName": "mpv" }], true)).app, "mpv");
    assert.equal(V.lead(V.blockers([], true)).own, true);
    assert.equal(V.lead([]), null);
});
