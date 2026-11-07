import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const table = loadScript(new URL("../Common/IslandBubbleTable.js", import.meta.url));
const defaults = loadScript(new URL("../Common/settings/BarWidgetDefaults.js", import.meta.url));
const index = JSON.parse(readFileSync(new URL("../translations/settings_search_index.json", import.meta.url), "utf8"));

test("the bubble table starts empty on both hosts", () => {
    assert.deepEqual({ ...defaults.ISLAND_DEFAULTS.islandBubbleTable }, {});
    assert.deepEqual({ ...defaults.DEFAULTS.island.islandBubbleTable }, {});
});

test("a default value removes its field, then the empty entry; another value adds it", () => {
    let t = table.withField({}, "volume", "side", "apps");
    assert.deepEqual({ ...t.volume }, { side: "apps" });
    t = table.withField(t, "volume", "sound", "normal");
    t = table.withField(t, "volume", "side", "machine");
    assert.deepEqual({ ...t.volume }, { sound: "normal" });
    t = table.withField(t, "volume", "sound", "none");
    assert.equal("volume" in t, false);
    assert.equal(table.withField({}, "copy", "dnd", false).copy, undefined);
});

test("withField and without never touch the table they get", () => {
    const frozen = Object.freeze({ volume: Object.freeze({ side: "apps" }), copy: Object.freeze({ tier: 1 }) });
    assert.notEqual(table.withField(frozen, "volume", "tier", 2), frozen);
    assert.deepEqual({ ...table.withField(frozen, "volume", "tier", 2).volume }, { side: "apps", tier: 2 });
    assert.equal("copy" in table.without(frozen, "copy"), false);
    assert.equal(table.changed(frozen, "volume", "side"), true);
    assert.equal(table.changed(frozen, "volume", "tier"), false);
});

test("the default lifetime follows the importance and the family scale", () => {
    assert.equal(table.defaultLifeMs(table.row("volume"), 0, 1.5), 3000);
    assert.equal(table.defaultLifeMs(table.row("output"), 0, 1), 2000);
    for (const scale of [0.5, 1, 2])
        assert.equal(table.defaultLifeMs(table.row("media"), 1, scale), 0);
    assert.equal(table.defaultLifeMs(table.row("pluginalert"), 2, 2), -1);
});

test("a secret bubble never outlives the secret", () => {
    const password = table.row("password");
    assert.equal(table.defaultLifeMs(password, password.tier, 2), 30000);
    assert.ok(table.lifeChoicesMs(password).every(ms => ms <= 30000));
    assert.ok(table.lifeChoicesMs(table.row("copy")).includes(120000));
});

test("authentication stays shown, through Do Not Disturb, while it waits", () => {
    const state = table.effective({ auth: { enabled: false, dnd: false, lifeMs: 1000, sound: "critical" } }, "auth", 1);
    assert.equal(state.enabled, true);
    assert.equal(state.dnd, true);
    assert.equal(state.lifeMs, 0);
    assert.equal(state.sound, "critical");
});

test("rows are unique, in a known family, and counted as in the plan", () => {
    const ids = table.rows.map(r => r.id);
    assert.equal(new Set(ids).size, ids.length);
    assert.ok(table.rows.every(r => table.families.includes(r.family)));
    assert.deepEqual([...table.families.map(f => table.rowsOf(f).length)], [18, 16, 7]);
    assert.equal(table.countDnd({}), 25);
    assert.equal(table.countDnd({ copy: { dnd: true }, volume: { dnd: false } }), 25);
});

test("search finds each bubble's family card by its id or tag", () => {
    for (const r of table.rows) {
        const section = "islandBubbles" + r.family[0].toUpperCase() + r.family.slice(1);
        const card = index.find(e => e.section === section);
        assert.ok(card, section);
        for (const word of [r.id, ...r.tags])
            assert.ok(card.keywords.includes(word.toLowerCase()), `${r.id}: tag ${word}`);
    }
});
