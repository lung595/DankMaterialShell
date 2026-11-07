.pragma library

// Reopen bubble (island, source "reopen"): the last window of an app that keeps running in the background (chat,
// game launcher, music) was closed; the bubble offers to show it again for a few seconds.
// A4: pure logic, tested by island-reopen.test.mjs.

// The setting is a comma-separated list of app names ("signal, discord"); case and blanks do not matter.
function parseApps(text) {
    return String(text || "").split(",").map(s => s.trim().toLowerCase()).filter(s => s !== "");
}

// An app id matches a name when it is that name or one of its dotted parts (org.signal.Signal, com.discordapp.Discord).
function watched(appId, apps) {
    const id = String(appId || "").toLowerCase();
    if (!id)
        return false;
    const parts = id.split(/[.\-_]/);
    return (apps || []).some(name => id === name || parts.indexOf(name) !== -1 || parts.indexOf(name + "app") !== -1);
}

// App ids whose last window just went away between two niri window lists, watched apps only, in list order.
function closedApps(before, after, apps) {
    const left = new Set((after || []).map(w => w && w.app_id).filter(Boolean));
    const seen = new Set((after || []).map(w => w && w.id));
    const out = [];
    for (const w of before || []) {
        if (!w || seen.has(w.id) || !w.app_id || left.has(w.app_id) || out.indexOf(w.app_id) !== -1)
            continue;
        if (watched(w.app_id, apps))
            out.push(w.app_id);
    }
    return out;
}

// The newest close goes first; the same app again moves to the front instead of showing twice.
// How many closed apps the bubble remembers.
var depth = 5;

function push(stack, appId, max) {
    const next = [appId].concat((stack || []).filter(id => id !== appId));
    return next.slice(0, max > 0 ? max : depth);
}

// The wheel walks through older closes and wraps around: dir > 0 brings the next older one to the front.
function rotate(stack, dir) {
    const s = (stack || []).slice();
    if (s.length < 2 || !dir)
        return s;
    if (dir > 0)
        s.push(s.shift());
    else
        s.unshift(s.pop());
    return s;
}
