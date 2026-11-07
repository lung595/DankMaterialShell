.pragma library

// Disk usage tree, fed record by record by `du -0ab` while the scan runs (its charts: DiskChart.js), and the disk
// bubble's figures (df's low mount, its alert share, decimal sizes). A4: pure logic, tested by vm.

function node(name, parent) {
    return {
        "name": name,
        "parent": parent,
        "id": parent ? parent.id + "/" + name : name,
        "size": 0,
        "files": 0,
        "children": null,
        "index": null
    };
}

function child(dir, name) {
    if (!dir.children) {
        dir.children = [];
        dir.index = {};
    }
    let c = dir.index[name];
    if (!c) {
        c = node(name, dir);
        dir.index[name] = c;
        dir.children.push(c);
    }
    return c;
}

// One du record "<bytes>\t<path>": a file (or an empty dir) becomes a leaf whose size climbs to the root. du prints a dir
// after its content, so a path that already has children is a finished dir: nothing to add. Returns the bytes added.
function add(root, base, record) {
    const tab = record.indexOf("\t");
    if (tab < 0)
        return 0;
    const size = Number(record.slice(0, tab));
    const path = record.slice(tab + 1);
    if (!(size >= 0) || path.indexOf(base) !== 0)
        return 0;
    const parts = path.slice(base.length).split("/").filter(p => p.length > 0);
    if (parts.length === 0)
        return 0;
    let n = root;
    for (const p of parts)
        n = child(n, p);
    if (n.children || n.counted)
        return 0;
    n.counted = true;
    for (let a = n; a; a = a.parent) {
        a.size += size;
        a.files += 1;
    }
    return size;
}

// The node's place on disk: the scanned folder joined with its place in the tree ("" for a grouped crumb).
function pathOf(n, base) {
    if (!n || n.other)
        return "";
    const rel = n.id.slice(n.id.indexOf("/") < 0 ? n.id.length : n.id.indexOf("/"));
    return ((base === "/" ? "" : base) + rel) || "/";
}

function find(root, base, path) {
    const b = base === "/" ? "" : base;
    if (path !== base && path.indexOf(b + "/") !== 0)
        return null;
    let n = root;
    for (const p of path.slice(b.length).split("/").filter(s => s.length > 0)) {
        n = n.index ? n.index[p] : null;
        if (!n)
            return null;
    }
    return n;
}

function crumbs(n) {
    const out = [];
    for (let a = n; a; a = a.parent)
        out.unshift(a);
    return out;
}

// The count biggest files under n, biggest first (kept sorted while walking: no sort of the whole tree).
function largest(n, count) {
    const out = [];
    const walk = d => {
        for (const c of d.children || []) {
            if (c.children) {
                walk(c);
                continue;
            }
            if (out.length >= count && c.size <= out[out.length - 1].size)
                continue;
            let i = out.length;
            while (i > 0 && out[i - 1].size < c.size)
                i--;
            out.splice(i, 0, c);
            if (out.length > count)
                out.pop();
        }
    };
    walk(n);
    return out;
}

// Trashed: the node leaves its folder and its size leaves every folder above; attach() puts it back for Undo.
function detach(n) {
    const p = n.parent;
    if (!p || !p.index || p.index[n.name] !== n)
        return;
    delete p.index[n.name];
    p.children.splice(p.children.indexOf(n), 1);
    for (let a = p; a; a = a.parent) {
        a.size -= n.size;
        a.files -= n.files;
    }
}

function attach(n) {
    const p = n.parent;
    if (!p || (p.index && p.index[n.name]))
        return;
    if (!p.children) {
        p.children = [];
        p.index = {};
    }
    p.index[n.name] = n;
    p.children.push(n);
    for (let a = p; a; a = a.parent) {
        a.size += n.size;
        a.files += n.files;
    }
}

// Decimal units, as df -H and the file managers: "25.9 GB", "640 MB".
function fmt(bytes) {
    const units = ["B", "kB", "MB", "GB", "TB"];
    let v = bytes;
    let u = 0;
    while (v >= 1000 && u < units.length - 1) {
        v /= 1000;
        u++;
    }
    return (u >= 3 || (v < 10 && u > 0) ? v.toFixed(1) : Math.round(v)) + " " + units[u];
}

// `df -B1 --output=size,avail,target / /home`: the mount with the smallest free share under `threshold` (0..1), or null.
// A tie goes to the later line: / and /home sharing one btrfs pool report the same free space, the files sit in /home.
function lowMount(text, threshold) {
    let low = null;
    for (const line of String(text || "").split("\n")) {
        const m = /^\s*(\d+)\s+(\d+)\s+(\/.*)$/.exec(line);
        if (!m || Number(m[1]) <= 0)
            continue;
        const mount = {
            "path": m[3],
            "size": Number(m[1]),
            "avail": Number(m[2])
        };
        if (mount.avail / mount.size < threshold && (!low || mount.avail / mount.size <= low.avail / low.size))
            low = mount;
    }
    return low;
}

// How far the disk bubble's liquid has turned to the alert, 0..1 from its free share: none with twice the threshold free,
// all of it at the threshold (DiskSpaceService.lowThreshold), smooth between.
function alertShare(free, threshold) {
    if (!(threshold > 0))
        return 0;
    const t = Math.max(0, Math.min(1, (2 * threshold - free) / threshold));
    return t * t * (3 - 2 * t);
}

// A measure or a scan this young is reused: the card's cleanup figures, its folder's scan.
var freshMs = 10 * 60 * 1000;

// `find <folder> -maxdepth 1 -printf "%D %p\0"` records (the folder first, each "<device> <path>"): the folder's own
// entries on its file system, so du never reads /proc, /sys or another mount when the folder is /.
function sameDevice(records) {
    const list = records || [];
    const dev = r => String(r).slice(0, String(r).indexOf(" "));
    const own = list.length ? dev(list[0]) : "";
    return list.slice(1).filter(r => dev(r) === own).map(r => String(r).slice(String(r).indexOf(" ") + 1));
}

// The disk card's list rows {path, name, size, dir, node}: the cleanup's old downloads ({path, size}), biggest first, each
// with its node when the tree scanned from base holds it.
function oldRows(old, tree, base) {
    return old.slice().sort((a, b) => b.size - a.size).map(o => {
        const n = find(tree, base, o.path);
        return {
            "path": o.path,
            "name": o.path.slice(o.path.lastIndexOf("/") + 1),
            "size": o.size,
            "dir": !!(n && n.children),
            "node": n
        };
    });
}

// The count largest files under folder, as list rows (the tree scanned from base).
function largestRows(folder, base, count) {
    return largest(folder, count).map(n => ({
                "path": pathOf(n, base),
                "name": n.name,
                "size": n.size,
                "dir": false,
                "node": n
            }));
}
