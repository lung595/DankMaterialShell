.pragma library

// How many islands' sources are alive (one per screen and the free island): the last one gone clears the shell's
// permanent entry. Shared by every importer of this library.
var sources = 0;

function join() {
    return ++sources;
}

function leave() {
    sources = Math.max(0, sources - 1);
    return sources;
}

// Sleep blocked bubble (island, kind "keepawake"): who keeps the session awake, from the freedesktop ScreenSaver
// inhibitors DMS serves (browsers, players: DMSService.screensaverInhibitors) plus DMS's own idle inhibitor toggle.

// One row per app, in arrival order: an app holding several cookies (a browser with two videos) is one row with all of
// them, so releasing it lets go of every one. DMS's own toggle comes last, flagged own.
function blockers(inhibitors, own) {
    const rows = [];
    for (const inhibitor of inhibitors || []) {
        if (!inhibitor || typeof inhibitor !== "object")
            continue;
        const app = String(inhibitor.appName || "").trim();
        let row = rows.find(r => r.app === app);
        if (!row) {
            row = {
                "app": app,
                "reason": String(inhibitor.reason || "").trim(),
                "cookies": [],
                "own": false
            };
            rows.push(row);
        }
        if (typeof inhibitor.cookie === "number")
            row.cookies.push(inhibitor.cookie);
    }
    if (own === true)
        rows.push({
            "app": "",
            "reason": "",
            "cookies": [],
            "own": true
        });
    return rows;
}

function rowKey(row) {
    return row.own ? "\u0001own" : row.app;
}

// What the rows say, to skip the service's repeated identical states.
function key(rows) {
    return (rows || []).map(rowKey).join("\u001f");
}

// True when an app not in the previous rows starts holding sleep off: the moment the island shows it.
function arrived(previousKey, rows) {
    const before = previousKey ? previousKey.split("\u001f") : [];
    return (rows || []).some(row => before.indexOf(rowKey(row)) === -1);
}

// The app the bubble names and shows: the newest arrival, DMS's own toggle only when it is alone.
function lead(rows) {
    const apps = (rows || []).filter(row => !row.own);
    return apps.length > 0 ? apps[apps.length - 1] : (rows && rows.length > 0 ? rows[0] : null);
}
