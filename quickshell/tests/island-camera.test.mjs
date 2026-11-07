import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandCamera.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const C = ctx;
const cam = (o) => Object.assign({ "cls": "Stream/Input/Video", "camera": true }, o);

test("an app capturing from a camera films; its streams group by process", () => {
    const apps = C.apps([
        cam({ "id": 1, "app": "Firefox", "binary": "firefox", "pid": 10 }),
        cam({ "id": 2, "app": "", "binary": "firefox", "pid": 10 }),
        cam({ "id": 3, "app": "Cheese", "binary": "cheese", "pid": 20, "icon": "org.gnome.Cheese" })
    ]);
    assert.equal(apps.length, 2);
    assert.equal(apps[0].app, "Firefox");
    assert.equal(apps[0].icon, "firefox");
    assert.deepEqual([...apps[0].streams], [1, 2]);
    assert.equal(apps[1].icon, "org.gnome.Cheese");
});

test("screen casts, unlinked streams, playback and nameless streams are not the camera", () => {
    assert.equal(C.apps([
        cam({ "id": 1, "app": "Firefox", "pid": 10, "screen": true }),
        cam({ "id": 2, "app": "Firefox", "pid": 10, "role": "Screen" }),
        cam({ "id": 3, "app": "Firefox", "pid": 10, "camera": false }),
        cam({ "id": 4, "app": "Firefox", "pid": 10, "cls": "Stream/Output/Video" }),
        cam({ "id": 5 }),
        null
    ]).length, 0);
    assert.equal(C.apps(undefined).length, 0);
});

test("a camera is a video source device, not a stream or a screen cast", () => {
    assert.equal(C.isCamera({ "cls": "Video/Source" }), true);
    assert.equal(C.isCamera({ "cls": "Video/Source", "screen": true }), false);
    assert.equal(C.isCamera({ "cls": "Video/Source", "stream": true }), false);
    assert.equal(C.isCamera({ "cls": "Audio/Source" }), false);
    assert.equal(C.isCamera(null), false);
});

test("an app starting to film is new, one whose stream drops and comes back within the grace is not", () => {
    let step = C.arrivals([], ["pid:10"], {}, 1000);
    assert.equal(step.fresh, true);
    // The stream drops (renegotiated) and comes back a second later: same filming.
    step = C.arrivals(["pid:10"], [], step.left, 2000);
    assert.equal(step.fresh, false);
    step = C.arrivals([], ["pid:10"], step.left, 3000);
    assert.equal(step.fresh, false);
    // Gone for longer than the grace: a new start.
    step = C.arrivals(["pid:10"], [], step.left, 4000);
    assert.equal(C.arrivals([], ["pid:10"], step.left, 4000 + C.graceMs).fresh, true);
    // A second app joining is new; the first one staying is not.
    assert.equal(C.arrivals(["pid:10"], ["pid:10", "pid:11"], {}, 5000).fresh, true);
    assert.equal(C.arrivals(["pid:10", "pid:11"], ["pid:10"], {}, 5000).fresh, false);
});
