.pragma library

// The island's download bubble: which files of the downloads folder just finished? Browsers write to a temporary file
// (Firefox "name.part" beside an empty "name", Chromium "name.crdownload") and rename it once done, so a file is
// finished when no temporary sibling is left, it is not hidden or temporary itself, and it was not finished in the
// previous listing. An empty new file only counts once it had a temporary sibling (Firefox's placeholder is empty).
// The first listing only seeds: what was already there is never announced.
// A local path as a file URL, each segment encoded ("#" or "?" in a name would otherwise cut the URL).
function fileUrl(path) {
    return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") : "";
}

const TEMP = [".part", ".crdownload", ".download", ".tmp", ".partial"];

function isTemp(name) {
    const n = String(name).toLowerCase();
    return n.startsWith(".") || TEMP.some(t => n.endsWith(t));
}

// Downloads still running: the temporary files, newest first, each with the name it will finish as. Firefox may add a
// random dot segment to its ".part" ("a.1.2ZOe61wk.7.iso.part" for "a.1.7.iso"), so the finished name is the
// placeholder sibling that matches with one segment dropped, else the name without its suffix.
// entries: [{"name", "size", "modified" (ms)}]. Returns [{"part", "name"}].
function running(entries) {
    const list = (entries || []).filter(e => e && e.name);
    const names = {};
    for (const e of list)
        names[e.name] = true;
    const out = [];
    for (const e of list) {
        const n = String(e.name);
        const suffix = TEMP.find(t => n.toLowerCase().endsWith(t));
        if (!suffix || n.startsWith(".") || suffix === ".tmp")
            continue;
        const stripped = n.slice(0, n.length - suffix.length);
        let name = stripped;
        const parts = stripped.split(".");
        for (let i = 1; i < parts.length && !names[name]; i++) {
            const candidate = parts.slice(0, i).concat(parts.slice(i + 1)).join(".");
            if (names[candidate])
                name = candidate;
        }
        out.push({
            "part": n,
            "name": name,
            "modified": Number(e.modified) || 0
        });
    }
    return out.sort((a, b) => b.modified - a.modified).map(r => ({
                "part": r.part,
                "name": r.name
            }));
}

// Speed of each running download from two size samples. prev: null or {"t", "sizes": {part: bytes}}; sizes: {part: bytes}.
// Returns {"state", "speeds": {part: bytes per second}} (0 until a second sample, never negative).
// stat -c "%s %n" output for files of `dir`: { file name: bytes }. A file stat could not read prints no line (its
// error goes to stderr), so a size is matched by its name, never by its line's position.
function statSizes(text, dir) {
    const sizes = {};
    for (const line of String(text ?? "").split("\n")) {
        const at = line.indexOf(" ");
        const n = Number(line.slice(0, at));
        const path = line.slice(at + 1);
        if (at > 0 && isFinite(n) && path.startsWith(dir + "/"))
            sizes[path.slice(dir.length + 1)] = n;
    }
    return sizes;
}

function sample(prev, sizes, now) {
    const speeds = {};
    for (const part in sizes) {
        const before = prev ? prev.sizes[part] : undefined;
        const dt = prev ? (now - prev.t) / 1000 : 0;
        speeds[part] = before !== undefined && dt > 0 ? Math.max(0, (sizes[part] - before) / dt) : 0;
    }
    return {
        "state": {
            "t": now,
            "sizes": sizes
        },
        "speeds": speeds
    };
}

// state: null (not seeded) or {"done": {name: true}, "pending": {name: true}}; entries: [{"name", "size"}].
// Returns {"state", "finished": [entries just finished]}.
function step(state, entries) {
    const list = (entries || []).filter(e => e && e.name);
    const names = {};
    for (const e of list)
        names[e.name] = true;
    const busy = name => TEMP.some(t => names[name + t]);
    const done = {};
    const pending = {};
    const finished = [];
    for (const e of list) {
        if (isTemp(e.name))
            continue;
        if (busy(e.name)) {
            pending[e.name] = true;
            continue;
        }
        const was = state ? state.done[e.name] === true : true;
        const waited = state ? state.pending[e.name] === true : false;
        if (!was && !waited && !(Number(e.size) > 0))
            continue;
        done[e.name] = true;
        if (!was)
            finished.push(e);
    }
    return {
        "state": {
            "done": done,
            "pending": pending
        },
        "finished": finished
    };
}
