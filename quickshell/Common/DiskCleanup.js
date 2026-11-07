.pragma library

// The disk card's cleanup: what it may send to the trash, and what each suggestion would free, read from the tools'
// own output (du, flatpak list, podman / docker images, dms trash list). Nothing here deletes anything.
// A4: pure logic, tested by vm (tests/disk-cleanup.test.mjs).

// Inside home only, never home itself, the trash in use (trashDir: under XDG_DATA_HOME, else ~/.local/share/Trash), or a
// path with a "." or ".." segment (one that names home again or climbs out).
function canTrash(path, home, trashDir) {
    if (!path || !home || String(path).split("/").some(s => s === "." || s === ".."))
        return false;
    const h = home.replace(/\/+$/, "");
    const p = path.replace(/\/+$/, "");
    if (p.indexOf(h + "/") !== 0)
        return false;
    const trash = (trashDir || h + "/.local/share/Trash").replace(/\/+$/, "");
    return p !== trash && p.indexOf(trash + "/") !== 0;
}

// Caches their programs rebuild on their own; nothing that holds settings, logins or downloads in progress.
function safeCaches(home) {
    return ["thumbnails", "pip", "mesa_shader_cache", "mesa_shader_cache_db", "radv_builtin_shaders", "nvidia/GLCache", "mozilla", "chromium", "google-chrome", "BraveSoftware", "go-build", "yarn", "pnpm", "fontconfig"].map(c => home + "/.cache/" + c);
}

// `du -0sb` records: "<bytes>\t<path>", NUL (or newline) separated.
function sizes(text) {
    const out = [];
    for (const r of String(text || "").split(/[\u0000\n]/)) {
        const tab = r.indexOf("\t");
        const size = Number(r.slice(0, tab));
        if (tab > 0 && size >= 0)
            out.push({
                "path": r.slice(tab + 1),
                "size": size
            });
    }
    return out;
}

// GLib's g_format_size ("670.7 MB", "512 bytes") and docker's ("1.2GB"): decimal units.
function bytes(s) {
    const m = /^\s*([\d.]+)\s*(bytes|B|kB|KB|MB|GB|TB)?\s*$/.exec(String(s || ""));
    if (!m)
        return 0;
    const mult = {
        "kB": 1e3,
        "KB": 1e3,
        "MB": 1e6,
        "GB": 1e9,
        "TB": 1e12
    }[m[2]] || 1;
    return Math.round(Number(m[1]) * mult);
}

// `flatpak list --runtime --columns=application,branch,installation,size` against `flatpak list --app
// --columns=application,runtime`: a base runtime (*.Platform) no app runs on, and its extensions of that branch.
// shortcut: under-counts what `flatpak uninstall --unused` frees (SDKs, other orphans); exact needs a flatpak dry run.
function flatpakUnused(runtimes, apps) {
    const used = new Set();
    for (const line of String(apps || "").split("\n")) {
        const r = (line.split("\t")[1] || "").split("/");
        if (r.length === 3)
            used.add(r[0] + "//" + r[2]);
    }
    const rows = String(runtimes || "").split("\n").map(l => l.split("\t")).filter(c => c.length >= 4);
    const bases = rows.filter(c => /\.Platform$/.test(c[0]) && !used.has(c[0] + "//" + c[1]));
    const refs = [];
    let size = 0;
    for (const c of rows) {
        const own = bases.some(b => (c[0] === b[0] || c[0].indexOf(b[0] + ".") === 0) && (c[1] === b[1] || c[1].indexOf(b[1] + "-") === 0) && c[2] === b[2]);
        if (!own)
            continue;
        refs.push(c[0] + "//" + c[1]);
        size += bytes(c[3]);
    }
    return {
        "refs": refs,
        "size": size
    };
}

// `podman images --filter dangling=true --format json` (an array, Size in bytes) or docker's one JSON per line
// (`--format '{{json .}}'`, Size as "1.2GB").
function images(text) {
    let list = [];
    try {
        const t = String(text || "").trim();
        list = t.charAt(0) === "[" ? JSON.parse(t) : t.split("\n").filter(l => l.trim()).map(l => JSON.parse(l));
    } catch (e) {
        list = [];
    }
    return {
        "count": list.length,
        "size": list.reduce((s, i) => s + (typeof i.Size === "number" ? i.Size : bytes(i.Size)), 0)
    };
}

// `dms trash list --json`: the newest entry that came from path, what `dms trash restore` needs.
function trashed(text, path) {
    let list = [];
    try {
        list = JSON.parse(text) || [];
    } catch (e) {
        return null;
    }
    let best = null;
    for (const e of list)
        if (e.originalPath === path && (!best || e.deletionDate > best.deletionDate))
            best = e;
    return best ? {
        "name": best.name,
        "dir": best.trashDir
    } : null;
}

// The suggestion rows, in the card's order, from what was measured (missing facts count as nothing).
function rows(f) {
    const sum = list => (list || []).reduce((s, i) => s + i.size, 0);
    return [{
            "id": "trash",
            "size": f.trash || 0
        }, {
            "id": "old",
            "size": sum(f.old),
            "count": (f.old || []).length
        }, {
            "id": "caches",
            "size": sum(f.caches)
        }, {
            "id": "packages",
            "size": (f.flatpak ? f.flatpak.size : 0) + (f.images ? f.images.size : 0)
        }];
}

function total(rows) {
    return rows.reduce((s, r) => s + r.size, 0);
}
