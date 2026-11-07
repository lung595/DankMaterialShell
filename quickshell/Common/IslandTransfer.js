.pragma library

// The island's transfers bubble (downloads, torrents, copies, archives): one sample per second of each transfer's bytes
// gives its speed (smoothed, so the figure does not flicker), its time left (smoothed too, counting down between
// samples) and one total for the bubble. A spike of the raw total speed is a surge: the bubble's liquid takes it as a
// kick, so a burst makes waves and a steady flow lies still.
// Rows in: [{"id", "done", "total" (0 = unknown), "paused", "canPause", "finished", "error"}].

// Weight of a new sample in the smoothed speed and time left.
const ALPHA = 0.3;
// A surge is the doubling count of the raw total speed (log2), under the dead zone none, capped.
const SURGE_DEAD = 0.5;
const SURGE_MAX = 3;

function smooth(prev, value) {
    return prev === undefined || prev < 0 ? value : prev + ALPHA * (value - prev);
}

function step(state, list, now) {
    const was = state ? state.rows : {};
    const next = {};
    let rawTotal = 0;
    const rows = (list || []).map(t => {
        const p = was[t.id];
        const done = Number(t.done) || 0, total = Number(t.total) || 0;
        const dt = p ? (now - p.at) / 1000 : 0;
        const live = !t.paused && !t.finished && !t.error;
        const raw = live && p && dt > 0 ? Math.max(0, (done - p.done) / dt) : 0;
        rawTotal += raw;
        // The first speed is a sample's own; a pause starts it over.
        const sampled = live && p && dt > 0;
        const speed = sampled ? smooth(p.speed, raw) : 0;
        const fresh = speed > 0 && total > 0 ? Math.max(0, (total - done) / speed) : -1;
        // Between samples the time left counts down; a new sample only pulls it part of the way.
        const eta = fresh < 0 ? -1 : p && p.eta >= 0 ? smooth(Math.max(0, p.eta - dt), fresh) : fresh;
        next[t.id] = {
            "done": done,
            "speed": sampled ? speed : -1,
            "eta": eta,
            "at": now
        };
        return Object.assign({}, t, {
            "done": done,
            "total": total,
            "ratio": total > 0 ? Math.min(1, done / total) : -1,
            // Its bar waves only while it moves.
            "flowing": live,
            "speed": speed,
            "eta": eta
        });
    });
    const running = rows.filter(r => !r.finished && !r.error);
    const size = running.reduce((s, r) => s + r.total, 0);
    const done = running.reduce((s, r) => s + r.done, 0);
    const prevRaw = state ? state.raw : 0;
    let surge = 0;
    if (rawTotal > 0)
        surge = prevRaw > 0 ? Math.abs(Math.log2(rawTotal / prevRaw)) : 1;
    surge = surge < SURGE_DEAD ? 0 : Math.min(SURGE_MAX, surge);
    return {
        "state": {
            "rows": next,
            "raw": rawTotal
        },
        "rows": rows,
        "surge": surge,
        "total": {
            "running": running.length,
            "finished": rows.filter(r => r.finished && !r.error).length,
            "failed": rows.filter(r => r.error).length,
            "done": done,
            "size": size,
            "ratio": size > 0 && running.every(r => r.total > 0) ? Math.min(1, done / size) : -1,
            "speed": running.reduce((s, r) => s + r.speed, 0),
            // Each transfer ends on its own: everything is done when the slowest is.
            "eta": running.reduce((m, r) => Math.max(m, r.eta), -1),
            "paused": running.length > 0 && running.every(r => r.paused),
            "flowing": running.some(r => !r.paused),
            "canPause": running.some(r => r.canPause === true)
        }
    };
}

// The card's sections, in this order when equal. A row without a known category is a copy.
const categories = ["download", "torrent", "copy", "archive", "send", "disk"];

function categoryOf(r) {
    return categories.indexOf(r.category) !== -1 ? r.category : "copy";
}

// Running rows first, the closest to finish leading (unknown time left, then paused, after), then failed ones, then
// finished ones, the latest first.
function rowKey(r) {
    if (r.finished && !r.error)
        return [2, 0, -(r.finishedAt || 0)];
    if (r.error)
        return [1, 0, 0];
    return [0, r.paused ? 1 : 0, r.eta >= 0 ? r.eta : Infinity];
}

function byKey(a, b) {
    const ka = rowKey(a), kb = rowKey(b);
    for (let i = 0; i < ka.length; i++)
        if (ka[i] !== kb[i])
            return ka[i] < kb[i] ? -1 : 1;
    return String(a.id) < String(b.id) ? -1 : String(a.id) > String(b.id) ? 1 : 0;
}

// Rows (step's) grouped by category: [{"category", "rows", "count", "finished", "eta", "flowing", "paused",
// "canPause", "canCancel"}]. The section that moves leads, then those still waiting, all finished ones last.
function sections(rows) {
    const groups = {};
    for (const r of rows || []) {
        const c = categoryOf(r);
        (groups[c] = groups[c] || []).push(r);
    }
    const out = Object.keys(groups).map(c => {
        const list = groups[c].slice().sort(byKey);
        const running = list.filter(r => !r.finished && !r.error);
        return {
            "category": c,
            "rows": list,
            "count": list.length,
            "finished": list.filter(r => r.finished && !r.error).length,
            "eta": running.reduce((m, r) => Math.max(m, r.eta), -1),
            "flowing": running.some(r => r.flowing),
            "paused": running.length > 0 && running.every(r => r.paused),
            "canPause": running.some(r => r.canPause === true),
            "canCancel": running.some(r => r.canCancel === true),
            "rank": running.some(r => r.flowing) ? 0 : list.some(r => !r.finished || r.error) ? 1 : 2
        };
    });
    return out.sort((a, b) => a.rank - b.rank || categories.indexOf(a.category) - categories.indexOf(b.category));
}

// A finished row stays ms after finishedAt, then leaves: {"list" (kept), "next" (ms until the next one leaves, -1)}.
// since, the end of a hover: every finished row's time starts over from there.
function expire(list, now, ms, since) {
    let next = -1;
    const kept = (list || []).filter(r => {
        if (!r.finished || r.error)
            return true;
        const left = Math.max(r.finishedAt || 0, since || 0) + ms - now;
        if (left <= 0)
            return false;
        next = next < 0 ? left : Math.min(next, left);
        return true;
    });
    return {
        "list": kept,
        "next": next
    };
}

// Under secondsUpTo seconds the time left counts seconds, in steps of secondStep (never under one step); under
// minutesUpTo, whole minutes (3570 s, so 59 min 30 s and up already reads "1 h"); then hours.
var secondsUpTo = 50;
var secondStep = 5;
var minutesUpTo = 3570;

// Time left, short: {"value", "unit": "s" | "min" | "h", "minutes" (with h)}, or null when unknown.
function timeLeft(seconds) {
    if (!(seconds >= 0))
        return null;
    if (seconds < secondsUpTo)
        return {
            "value": Math.max(secondStep, Math.ceil(seconds / secondStep) * secondStep),
            "unit": "s"
        };
    if (seconds < minutesUpTo)
        return {
            "value": Math.max(1, Math.ceil(seconds / 60)),
            "unit": "min"
        };
    const m = Math.round(seconds / 60);
    return {
        "value": Math.floor(m / 60),
        "unit": "h",
        "minutes": m % 60
    };
}

// A byte count, short and decimal (as file managers show it): {"value", "decimals", "unit": "B" | "kB" | "MB" | "GB"}.
// ref picks the unit, so "312 / 850 MB" and "0.3 / 3.9 GB" share theirs.
function bytes(n, ref) {
    const units = ["B", "kB", "MB", "GB", "TB"];
    let i = 0;
    for (let r = Math.max(0, ref === undefined ? n : ref); r >= 1000 && i < units.length - 1; r /= 1000)
        i++;
    const v = Math.max(0, n) / Math.pow(1000, i);
    const decimals = i > 0 && v < 100 ? 1 : 0;
    return {
        "value": Number(v.toFixed(decimals)),
        "decimals": decimals,
        "unit": units[i]
    };
}

// A file name as {"stem", "ext"}: a long name is cut in its stem, its extension (".iso", ".tar.gz") always shows.
function splitName(name) {
    const m = /^(.+?)((?:\.tar)?\.[A-Za-z0-9]{1,5})$/.exec(String(name || ""));
    return m ? {
        "stem": m[1],
        "ext": m[2]
    } : {
        "stem": String(name || ""),
        "ext": ""
    };
}

// A row in from the core's TransferService (t; image: its app's icon, "" for none).
function coreRow(t, image) {
    return {
        "id": String(t.id),
        "category": t.category ?? "",
        "peers": Number(t.peers) || 0,
        "upSpeed": Number(t.upSpeed) || 0,
        "shareRatio": Number(t.shareRatio) || 0,
        "name": t.name ?? "",
        "app": t.app ?? "",
        "image": image,
        "done": Number(t.done) || 0,
        "total": Number(t.total) || 0,
        "paused": t.paused === true,
        "canPause": t.canPause === true,
        "canCancel": t.canCancel === true,
        "finished": false,
        "error": t.error === true,
        "reason": t.reason ?? "",
        "path": t.path ?? ""
    };
}

// A browser's partial file (DownloadService.live: d), named by the app it comes from; its path is where it lands once
// renamed, in the downloads folder (a file: URL or a path).
function partRow(d, app, folder) {
    return {
        "id": "part:" + d.part,
        "category": "download",
        "name": d.name,
        "app": app,
        "image": "",
        "done": Number(d.size) || 0,
        "total": 0,
        "paused": false,
        "canPause": false,
        "canCancel": false,
        "finished": false,
        "error": false,
        "path": decodeURIComponent(String(folder).replace(/^file:\/\//, "")) + "/" + d.name
    };
}
