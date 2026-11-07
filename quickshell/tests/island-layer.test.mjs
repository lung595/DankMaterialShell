import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const layer = loadScript(new URL("../Common/IslandLayer.js", import.meta.url));
const defaults = loadScript(new URL("../Common/settings/BarWidgetDefaults.js", import.meta.url));

test("an island bar rides the overlay layer for fullscreen requests by default", () => {
    assert.equal(defaults.ISLAND_DEFAULTS.islandOverlayOnRequest, true);
    assert.equal(defaults.DEFAULTS.island.islandOverlayOnRequest, true);
    assert.equal(defaults.ISLAND_DEFAULTS.islandUseOverlayLayer, false);
});

test("the island wants the overlay layer for the setting, or for a fullscreen request when allowed", () => {
    const polkit = { "pluginId": "dms:auth", "showInFullscreen": true };
    const plain = { "pluginId": "demo", "showInFullscreen": false };
    const rows = [
        // [islandUseOverlayLayer, islandOverlayOnRequest, shown entry, expected]
        [false, false, null, false],
        [false, true, null, false],
        [false, true, plain, false],
        [false, true, polkit, true],
        [false, false, polkit, false],
        [true, false, null, true],
        [true, true, plain, true],
        [true, false, polkit, true],
        [false, true, undefined, false],
        [false, true, { "showInFullscreen": "yes" }, false]
    ];
    for (const [always, onRequest, entry, expected] of rows)
        assert.equal(layer.wantsOverlay(always, onRequest, entry), expected, JSON.stringify([always, onRequest, entry]));
});
