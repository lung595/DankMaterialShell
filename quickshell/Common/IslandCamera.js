.pragma library

// Camera bubble (island, apps side, source "camera"): which apps film, read from PipeWire. An app films when one of its
// video capture streams (Stream/Input/Video) is linked to a camera; a stream fed by a screen cast (a browser sharing
// the screen in a call) is not the camera.

// rows: one per PipeWire video capture stream {id, cls, role, screen (looks like a screen cast), camera (linked to a
// camera source), app, binary, icon, pid}. Returns one entry per app, in PipeWire's order:
// {key, app, binary, icon, streams: [stream ids]}.
function apps(rows) {
    const groups = [];
    for (const row of rows || []) {
        if (!row || typeof row !== "object" || row.cls !== "Stream/Input/Video" || row.role === "Screen" || row.screen || !row.camera)
            continue;
        const key = appKey(row);
        if (!key)
            continue;
        let group = groups.find(g => g.key === key);
        if (!group) {
            group = {
                "key": key,
                "app": "",
                "binary": "",
                "icon": "",
                "streams": []
            };
            groups.push(group);
        }
        group.app = group.app || String(row.app || "").trim();
        group.binary = group.binary || String(row.binary || "").trim();
        group.icon = group.icon || String(row.icon || "").trim();
        group.streams.push(row.id);
    }
    return groups.map(g => ({
                "key": g.key,
                "app": g.app || g.binary,
                "binary": g.binary,
                "icon": g.icon || g.binary.toLowerCase(),
                "streams": g.streams
            }));
}

// Streams of one process belong together; without a pid, the binary or the app name.
function appKey(row) {
    if (row.pid)
        return "pid:" + row.pid;
    const name = String(row.binary || row.app || "").trim().toLowerCase();
    return name ? "app:" + name : "";
}

// The camera's rank among the apps side's bubbles (B3): after a call (2e6), ahead of the others.
var rank = 1.9e6;

// How long an app that stopped filming still counts as filming when it starts again (a browser renegotiating its
// stream drops it for a moment): it neither plays its arrival again nor lifts a right-click hide.
var graceMs = 3000;

// One change of the apps filming: before and keys are app keys, left {key: ms it stopped filming}. fresh: an app starts
// filming that was not a moment ago; left: the apps that stopped within the grace, for the next change.
function arrivals(before, keys, left, nowMs) {
    var was = before || [], gone = {}, k;
    for (k in left || {})
        if (nowMs - left[k] < graceMs && keys.indexOf(k) < 0)
            gone[k] = left[k];
    for (var i = 0; i < was.length; i++)
        if (keys.indexOf(was[i]) < 0)
            gone[was[i]] = nowMs;
    var fresh = keys.some(function (key) {
        return was.indexOf(key) < 0 && !(left && key in left && nowMs - left[key] < graceMs);
    });
    return { "fresh": fresh, "left": gone };
}

// A source node is a camera: a video source device, not a screen cast. node: {cls, stream (bool), screen (bool)}.
function isCamera(node) {
    return !!node && node.cls === "Video/Source" && !node.stream && !node.screen;
}
