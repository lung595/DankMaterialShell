.pragma library

// The island's shelf: links to files dropped on the island, newest first, never copies. A file dropped again comes back
// on top instead of twice; one gone from disk is forgotten (stat lists those still there). The list is saved as plain
// absolute paths in DMS's session state.
// A4: the shelf's pure logic, tested by vm (tests/island-shelf.test.mjs).

// Local paths from a drop: its urls, or a text/uri-list body (CRLF lines, "#" comments). Only file:// on this host.
function paths(uris) {
    const lines = typeof uris === "string" ? uris.split(/\r?\n/) : Array.from(uris || [], u => String(u ?? ""));
    const out = [];
    for (const line of lines) {
        const m = /^file:\/\/(?:localhost)?(\/[^#?]*)$/.exec(line.trim());
        if (!m)
            continue;
        try {
            out.push(decodeURIComponent(m[1]));
        } catch (e) {
            // A malformed escape: not a path we can trust.
        }
    }
    return out;
}

// A drag the shelf takes, by its formats: while it hovers, Wayland announces them but often not the urls themselves
// (they come with the drop), so a count of 0 then means nothing.
var fileFormats = ["text/uri-list", "application/vnd.portal.filetransfer", "application/vnd.portal.files", "application/x-kde4-urilist"];
function takesDrag(formats, hasUrls) {
    return !!hasUrls || Array.from(formats || []).some(f => fileFormats.indexOf(String(f)) !== -1);
}

// What a drop carries its files in: Qt's urls, else its text/uri-list, else file:// lines of its plain text (a source
// may fill only one of them).
function dropUris(urls, uriList, plain) {
    for (const s of [urls, uriList, plain])
        if (paths(s).length)
            return s;
    return "";
}

// The shelf's face shown small in the island (taken back after an interruption, or before its card could load): it
// grows into its card, it never rests there.
function growsOpen(mine, expanded, expandable) {
    return mine && !expanded && expandable;
}

// A launcher just opened (its window, the island's, the bar's button) while the shelf's card shows, in the island or
// in its bubble: the card folds into its bubble beside the island, files kept. A shelf already in its bubble stays.
function foldsForLauncher(launcher, inIsland, inBubble) {
    return launcher === true && (inIsland === true || inBubble === true);
}

// The way back out: a file:// url (each segment escaped, "#" and "?" included), and a drag's text/uri-list.
function url(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}

function uriList(list) {
    return (list || []).map(url).join("\r\n") + "\r\n";
}

// How far the drop target reaches past the island on its screen edge's side (the Fitts strip): a drag thrown against
// the edge ends outside the island, and a drop nothing accepts is cancelled by the compositor.
function dropReach(vertical, farEdge, gap) {
    const g = Math.max(0, gap || 0);
    return {
        "top": !vertical && !farEdge ? g : 0,
        "bottom": !vertical && farEdge ? g : 0,
        "left": vertical && !farEdge ? g : 0,
        "right": vertical && farEdge ? g : 0
    };
}

// The shelf keeps links, not files, but a list past this many is no shelf any more: the oldest ones drop off.
var maxFiles = 100;

function add(list, added) {
    const fresh = [];
    for (const p of added || [])
        if (fresh.indexOf(p) === -1)
            fresh.push(p);
    const old = (list || []).filter(p => fresh.indexOf(p) === -1);
    return {
        "list": fresh.concat(old).slice(0, maxFiles),
        "added": fresh.filter(p => (list || []).indexOf(p) === -1).length
    };
}

function remove(list, path) {
    return (list || []).filter(p => p !== path);
}

// stat -c "%s %f %Y %n" prints one line per file still there: its size, its raw mode (hex), its change time (s), its path.
// shortcut: a file name with a newline in it reads as gone and is forgotten; switch to NUL output if that ever matters.
function facts(output) {
    const out = {
        "paths": [],
        "size": {},
        "mtime": {},
        "dirs": []
    };
    for (const line of String(output || "").split("\n")) {
        const m = /^(\d+) ([0-9a-f]+) (\d+) (\/.*)$/.exec(line);
        if (!m)
            continue;
        out.paths.push(m[4]);
        out.size[m[4]] = Number(m[1]);
        out.mtime[m[4]] = Number(m[3]) * 1000;
        // S_IFDIR in the file type bits.
        if ((parseInt(m[2], 16) & 0o170000) === 0o040000)
            out.dirs.push(m[4]);
    }
    return out;
}

// Only what stat was asked about (all by default) can be found gone.
function keep(list, present, asked) {
    return (list || []).filter(p => present.indexOf(p) !== -1 || (asked && asked.indexOf(p) === -1));
}

// A shelf folder (made by holding a file on another, iOS style) is a group of links, nothing on disk: saved in the list
// as {id, name, items}, shown under the key "group:<id>" (a path always starts with "/").
var groupPrefix = "group:";

function isGroup(key) {
    return String(key).startsWith(groupPrefix);
}

function groupId(key) {
    return String(key).slice(groupPrefix.length);
}

function savedGroup(e) {
    return e !== null && typeof e === "object" && typeof e.id === "string" && e.id !== "" && Array.isArray(e.items);
}

function load(saved) {
    if (!Array.isArray(saved))
        return [];
    return add([], saved.filter(p => typeof p === "string" && p.startsWith("/") || savedGroup(p)).map(p => typeof p === "string" ? p : groupPrefix + p.id)).list;
}

function groups(saved) {
    const out = {};
    for (const e of Array.isArray(saved) ? saved : [])
        if (savedGroup(e))
            out[e.id] = {
                "name": typeof e.name === "string" && e.name !== "" ? e.name : e.id,
                "items": load(e.items).filter(p => !isGroup(p))
            };
    return out;
}

// Back to the saved form; a group key with no group behind it is dropped.
function dump(keys, gs) {
    const out = [];
    for (const k of keys || []) {
        if (!isGroup(k)) {
            out.push(k);
            continue;
        }
        const g = (gs || {})[groupId(k)];
        if (g)
            out.push({
                "id": groupId(k),
                "name": g.name,
                "items": g.items.slice()
            });
    }
    return out;
}

// The files behind keys: a group stands for its files, each file once.
function expand(keys, gs) {
    const out = [];
    for (const k of keys || [])
        for (const p of isGroup(k) ? ((gs || {})[groupId(k)]?.items ?? []) : [k])
            if (out.indexOf(p) === -1)
                out.push(p);
    return out;
}

function copyGroups(gs) {
    const out = {};
    for (const id in gs || {})
        out[id] = {
            "name": gs[id].name,
            "items": gs[id].items.slice()
        };
    return out;
}

// The target file and the files held on it become a folder in the target's place.
function makeGroup(keys, gs, target, moved, gname, id) {
    const key = groupPrefix + id;
    const g = copyGroups(gs);
    g[id] = {
        "name": gname,
        "items": expand([target].concat((moved || []).filter(k => k !== target)), gs)
    };
    for (const k of moved || [])
        if (isGroup(k) && k !== key)
            delete g[groupId(k)];
    const items = [];
    for (const k of keys || [])
        if (k === target)
            items.push(key);
        else if ((moved || []).indexOf(k) === -1)
            items.push(k);
    return {
        "items": items,
        "groups": g,
        "key": key
    };
}

// Files (or another folder's files) dropped on a folder go in it and leave the list.
function intoGroup(keys, gs, id, moved) {
    const key = groupPrefix + id;
    const going = (moved || []).filter(k => k !== key);
    const g = copyGroups(gs);
    if (!g[id])
        return {
            "items": (keys || []).slice(),
            "groups": g
        };
    for (const p of expand(going, gs))
        if (g[id].items.indexOf(p) === -1)
            g[id].items.push(p);
    for (const k of going)
        if (isGroup(k))
            delete g[groupId(k)];
    return {
        "items": (keys || []).filter(k => going.indexOf(k) === -1),
        "groups": g
    };
}

// Keys taken off the list (or off one folder when inside it); a removed group goes with its links.
function withoutKeys(keys, gs, gone, inside) {
    const g = copyGroups(gs);
    if (inside && g[inside]) {
        g[inside].items = g[inside].items.filter(p => (gone || []).indexOf(p) === -1);
        return {
            "items": (keys || []).slice(),
            "groups": g
        };
    }
    for (const k of gone || [])
        if (isGroup(k))
            delete g[groupId(k)];
    return {
        "items": (keys || []).filter(k => (gone || []).indexOf(k) === -1),
        "groups": g
    };
}

// Files gone from disk leave the list and the folders (only those stat was asked about can be found gone).
function prune(keys, gs, present, asked) {
    const g = copyGroups(gs);
    for (const id in g)
        g[id].items = keep(g[id].items, present, asked);
    return {
        "items": (keys || []).filter(k => isGroup(k) || keep([k], present, asked).length > 0),
        "groups": g
    };
}
// What stat was asked about and did not find: gone from disk, said when the shelf forgets them.
function missing(asked, present) {
    return (asked || []).filter(p => (present || []).indexOf(p) === -1);
}

function label(key, gs) {
    return isGroup(key) ? ((gs || {})[groupId(key)]?.name ?? "") : name(key);
}

// One path segment: never empty, never "." or "..", no slash or line break, at most 255 bytes.
function validName(n) {
    const s = String(n ?? "").trim();
    return s !== "" && s !== "." && s !== ".." && !/[\/\n\r\0]/.test(s) && encodeURIComponent(s).replace(/%[0-9A-F]{2}/g, "x").length <= 255;
}

function name(path) {
    const parts = String(path || "").split("/").filter(s => s !== "");
    return parts.length ? parts[parts.length - 1] : "";
}

function extension(path) {
    const n = name(path).toLowerCase();
    const dot = n.lastIndexOf(".");
    return dot > 0 ? n.slice(dot + 1) : "";
}

var images = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "tif", "tiff"];
var kinds = {
    "video": ["mp4", "mkv", "webm", "mov", "avi", "m4v"],
    "audio": ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"],
    "pdf": ["pdf"],
    "text": ["txt", "md", "markdown", "json", "yaml", "yml", "toml", "ini", "conf", "csv", "log", "xml", "html", "css", "js", "mjs", "ts", "qml", "py", "sh", "c", "h", "cpp", "hpp", "rs", "go", "java", "kt", "rb", "lua", "sql"],
    "office": ["odt", "ods", "odp", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "rtf", "epub"],
    "archive": ["zip", "gz", "tgz", "xz", "zst", "bz2", "7z", "rar", "tar"],
    "iso": ["iso", "img"]
};
var kindIcons = {
    "folder": "folder",
    "image": "image",
    "video": "movie",
    "audio": "audio_file",
    "pdf": "picture_as_pdf",
    "text": "description",
    "office": "description",
    "archive": "folder_zip",
    "iso": "album",
    "group": "folder_special",
    "file": "draft"
};

function isImage(path) {
    return images.indexOf(extension(path)) !== -1;
}

// What one file is, by its name; only stat tells a folder (dirs: the folders among the kept paths).
function kind(path, dirs) {
    if (isGroup(path))
        return "group";
    if (dirs && dirs.indexOf(path) !== -1)
        return "folder";
    if (isImage(path))
        return "image";
    const ext = extension(path);
    for (const k in kinds)
        if (kinds[k].indexOf(ext) !== -1)
            return k;
    return "file";
}

// The type's icon, shown while a picture is not decoded and for every other file.
function icon(path, dirs) {
    return kindIcons[kind(path, dirs)];
}

// The card's filters: Images, Documents (PDF, text, office), the rest.
function filterOf(path, dirs) {
    const k = kind(path, dirs);
    return k === "image" ? "image" : k === "pdf" || k === "text" || k === "office" ? "doc" : "other";
}

// Accents and case left out, so "ete" finds "Été".
function fold(s) {
    return String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

// What the list shows: the filter, then the search on names (a folder by its name).
function shown(list, filter, dirs, query, gs) {
    const q = fold(query ?? "").trim();
    return (list || []).filter(p => (filter === "all" || filterOf(p, dirs) === filter) && (q === "" || fold(label(p, gs)).indexOf(q) !== -1));
}

function counts(list, dirs) {
    const out = {
        "all": (list || []).length,
        "image": 0,
        "doc": 0,
        "other": 0
    };
    for (const p of list || [])
        out[filterOf(p, dirs)]++;
    return out;
}

// Which set of actions the choice calls for; nothing chosen is the whole shelf.
function selectionKind(sel, dirs) {
    if (!sel || !sel.length)
        return "all";
    const ks = sel.map(p => kind(p, dirs));
    if (sel.length === 1)
        return ks[0] === "pdf" ? "doc" : ks[0] === "office" ? "file" : ks[0];
    if (ks.every(k => k === "image"))
        return "images";
    if (ks.every(k => k === "pdf"))
        return "pdfs";
    return "mixed";
}

// The card's actions for each choice, the most likely first (the owner's v3 table, 25/10); "file" is one file of no
// known kind, with the several files' set.
var actions = {
    "all": {
        "acts": ["copyFiles", "phone", "zip", "moveTo"],
        "more": ["copyTo", "copyPaths", "renameSeries"]
    },
    "image": {
        "acts": ["copyImage", "annotate", "phone", "wallpaper"],
        "more": ["open", "ocr", "toPng", "toJpg", "toWebp", "shrinkImage", "rotate", "moveTo", "copyTo"]
    },
    "video": {
        "acts": ["open", "frame", "phone", "shrinkVideo"],
        "more": ["gif", "mute", "show", "moveTo", "copyTo"]
    },
    "audio": {
        "acts": ["listen", "phone", "mp3", "show"],
        "more": ["openWith", "copyPaths", "moveTo", "copyTo"]
    },
    "doc": {
        "acts": ["open", "copyText", "phone", "show"],
        "more": ["shrinkPdf", "pdfImages", "print", "copyPaths", "moveTo", "copyTo"]
    },
    "text": {
        "acts": ["open", "copyContent", "copyPaths", "show"],
        "more": ["editor", "phone", "moveTo", "copyTo"]
    },
    "archive": {
        "acts": ["extractHere", "viewArchive", "phone", "show"],
        "more": ["extractTo", "copyPaths", "moveTo", "copyTo"]
    },
    "iso": {
        "acts": ["writeUsb", "verify", "show", "copyPaths"],
        "more": ["open", "mount", "copySha", "moveTo", "copyTo"]
    },
    "folder": {
        "acts": ["open", "zip", "terminal", "copyPaths"],
        "more": ["phone", "folderSize", "moveTo", "copyTo"]
    },
    "images": {
        "acts": ["copyFiles", "pdfFromImages", "shrinkImage", "phone"],
        "more": ["zip", "toPng", "toJpg", "toWebp", "renameSeries", "contactSheet"]
    },
    "pdfs": {
        "acts": ["copyFiles", "mergePdf", "zip", "phone"],
        "more": ["moveTo", "shrinkPdf", "copyPaths"]
    },
    "mixed": {
        "acts": ["copyFiles", "zip", "moveTo", "phone"],
        "more": ["copyPaths", "copyTo", "renameSeries"]
    },
    "file": {
        "acts": ["copyFiles", "zip", "moveTo", "phone"],
        "more": ["copyPaths", "copyTo", "renameSeries", "openWith"]
    }
};

// An action shows only if one of its tools is installed (none listed: DMS does it itself). All local.
var needs = {
    "annotate": ["satty", "swappy"],
    "phone": ["kdeconnect-cli"],
    "zip": ["zip", "7z"],
    "renameSeries": ["thunar", "krename"],
    "ocr": ["tesseract"],
    "toPng": ["magick"],
    "toJpg": ["magick"],
    "toWebp": ["magick"],
    "shrinkImage": ["magick"],
    "rotate": ["magick"],
    "contactSheet": ["magick"],
    "pdfFromImages": ["img2pdf", "magick"],
    "frame": ["ffmpeg"],
    "shrinkVideo": ["ffmpeg"],
    "gif": ["ffmpeg"],
    "mute": ["ffmpeg"],
    "mp3": ["ffmpeg"],
    "listen": ["mpv", "ffplay", "pw-play"],
    "copyText": ["pdftotext"],
    "shrinkPdf": ["gs"],
    "pdfImages": ["pdftoppm"],
    "print": ["lp", "lpr"],
    "mergePdf": ["qpdf", "pdfunite", "gs"],
    "editor": ["code", "codium", "zed", "gnome-text-editor", "kate", "kwrite", "gedit"],
    // shortcut: unzip and tar only read their own formats; the script fails (red flash) on the others.
    "extractHere": ["bsdtar", "7z", "unzip", "tar"],
    "extractTo": ["bsdtar", "7z", "unzip", "tar"],
    "viewArchive": ["file-roller", "ark", "engrampa"],
    // Writing apps that ask before they write; the shelf never writes a disk itself.
    "writeUsb": ["mediawriter", "impression", "gnome-disks", "popsicle"],
    "mount": ["gnome-disk-image-mounter", "udisksctl"],
    // DMS's own terminal setting comes first (SessionData.resolveTerminal); these are its known ones.
    "terminal": ["ghostty", "kitty", "foot", "alacritty", "wezterm", "konsole", "gnome-terminal", "xterm"],
    // The drop zones: Convert with whichever converter fits the type, Share to a device (LocalSend is never an action).
    "convertTo": ["magick", "ffmpeg", "soffice", "pandoc"],
    "sendTo": ["kdeconnect-cli"],
    "localsend": ["localsend", "localsend_app"]
};

// Every tool worth probing once, for the card's actions.
var tools = (() => {
    const all = [];
    for (const k in needs)
        for (const t of needs[k])
            if (all.indexOf(t) === -1)
                all.push(t);
    return all;
})();

function ready(id, have) {
    const n = needs[id];
    return !n || n.some(t => (have || []).indexOf(t) !== -1);
}

// The conversions, by the extensions they make: none is offered on files already in that format.
var madeAs = {
    "mp3": ["mp3"],
    "toPng": ["png"],
    "toJpg": ["jpg", "jpeg"],
    "toWebp": ["webp"]
};

// Four buttons (the first is the likeliest), the rest under More; a hidden action leaves its place to the next one.
function plan(kindKey, have, files) {
    const a = actions[kindKey] || actions.all;
    const same = id => !!madeAs[id] && !!(files && files.length) && files.every(f => madeAs[id].indexOf(extension(f)) !== -1);
    const all = a.acts.concat(a.more).filter(id => ready(id, have) && !same(id));
    return {
        "buttons": all.slice(0, 4),
        "more": all.slice(4)
    };
}

// The explorer's selection, under its facts: Open first when the plan has it (Enter's), the phone last, three shown.
function asidePlan(p) {
    const all = p.buttons.concat(p.more);
    const order = all.filter(id => id === "open").concat(all.filter(id => id !== "open" && id !== "phone"), all.filter(id => id === "phone"));
    return {
        "buttons": order.slice(0, 3),
        "more": order.slice(3)
    };
}

// A click picks one (the same again lets it go), Ctrl adds or takes one, Shift takes the run from the anchor.
function pick(state, list, i, add, range) {
    const sel = (state && state.sel) || [];
    const anchor = state && typeof state.anchor === "number" ? state.anchor : i;
    if (range) {
        const run = list.slice(Math.min(anchor, i), Math.max(anchor, i) + 1);
        const base = add ? sel.filter(p => run.indexOf(p) === -1) : [];
        return {
            "sel": base.concat(run),
            "anchor": anchor
        };
    }
    const p = list[i];
    if (add)
        return {
            "sel": sel.indexOf(p) !== -1 ? sel.filter(q => q !== p) : sel.concat([p]),
            "anchor": i
        };
    return {
        "sel": sel.length === 1 && sel[0] === p ? [] : [p],
        "anchor": i
    };
}

// A plain click that would let the only chosen tile go: the card waits out a double-click first, so the first click
// of a double-click never empties the choice (nor moves the list) before the second opens that tile.
function letsGo(sel, key, add, range) {
    return !add && !range && (sel || []).length === 1 && sel[0] === key;
}

// Listen here failed: an error code, or ffplay finding no sound device (it still exits 0, its errors say so).
function playerFailed(exitCode, errors) {
    return exitCode !== 0 || /audio open failed/.test(errors || "");
}

// A long press, then still held down the list: every row passed over joins what was chosen before.
function sweep(base, list, from, to) {
    const run = list.slice(Math.min(from, to), Math.max(from, to) + 1);
    return (base || []).filter(p => run.indexOf(p) === -1).concat(run);
}

function step(cur, delta, n) {
    return n > 0 ? Math.max(0, Math.min(n - 1, cur + delta)) : 0;
}

// The search never holds an unprintable character (a key's control code, a pasted line break).
function cleanQuery(q) {
    return String(q ?? "").replace(/[\u0000-\u001f\u007f]/g, "");
}
// A key typed on the tiles that goes to the search: a printable letter.
function printable(t) {
    return String(t ?? "").length === 1 && cleanQuery(t).trim() !== "";
}
// The search after a key typed on the tiles: Backspace takes its last letter back, a letter goes on its end.
function typed(q, t) {
    return t === "\b" ? String(q ?? "").slice(0, -1) : cleanQuery((q ?? "") + t);
}
// The keyboard's row once the search changed: the file chosen if it still shows, else the first result while there
// is a search; the search cleared, the file the row stood on, at its place in the whole list.
function rowAfterSearch(q, chosen, ring, list) {
    const l = list || [];
    return Math.max(0, l.indexOf(l.indexOf(chosen) !== -1 ? chosen : q ? null : ring));
}

// A row's slide after one wheel event: a touchpad's pixels move it under the finger; a wheel's notch (120) turns a
// page of the tiles in view (pitch: a tile and its gap).
function rowSlide(offset, room, view, pitch, px, angle) {
    const page = Math.max(1, Math.floor(view / pitch)) * pitch;
    const d = px ? px : angle / 120 * page;
    return Math.max(0, Math.min(room, offset - d));
}
// The row's slide that brings a tile (x, width w) in view with a tile of margin before the faded edge, the least move.
function slideTo(offset, room, view, x, w, pitch) {
    const m = Math.min(pitch, Math.max(0, (view - w) / 2));
    return Math.max(0, Math.min(room, Math.max(Math.min(offset, x - m), x + w + m - view)));
}

// The word of the shelf's count: files, folders, or items when both.
function countKind(paths, dirs) {
    const n = (paths || []).filter(p => (dirs || []).indexOf(p) !== -1).length;
    return n === 0 ? "files" : n === (paths || []).length ? "folders" : "items";
}

// A tile's name; two tiles of one name (a copy and the real folder) each say their parent folder after it.
function tileName(key, list, gs) {
    const n = label(key, gs);
    if (isGroup(key) || !(list || []).some(k => k !== key && !isGroup(k) && name(k) === n))
        return n;
    return n + " · " + (name(parent(key)) || "/");
}

// Home, End and the pages in a list of n: the first, the last, a page up or down.
function leap(cur, n, to, page) {
    return step(cur, to === "first" ? -n : to === "last" ? n : to === "pageUp" ? -page : page, n);
}

// A letter typed in a list: the next name after cur that starts with it (round the end), else -1.
function typeAhead(names, text, cur) {
    const t = fold(text);
    const n = names.length;
    for (let k = 1; k <= n; k++) {
        const i = (cur + k) % n;
        if (fold(names[i]).startsWith(t))
            return i;
    }
    return -1;
}

// A path that wraps at its slashes, never inside a name (a zero-width space after each one).
function wrapPath(path) {
    return String(path || "").replace(/\//g, "/​");
}

// Tab (back: Shift+Tab, or ↑ in a menu) walks a ring of n stops and wraps, never out of the card; from no stop (-1)
// it starts at the first, or the last going back.
function wrap(at, back, n) {
    if (n <= 0)
        return -1;
    if (at < 0 || at >= n)
        return back ? n - 1 : 0;
    return (at + (back ? n - 1 : 1)) % n;
}

// The document portal hands files copied from here back as <runtime dir>/doc/<id>/<name>: the shelf's own last copy
// gives their real paths back by name, so pasting what it copied is not taken for new files.
// shortcut: two copied files of the same name map to the first; match on the portal's host path if that ever matters.
function unportal(paths, copied) {
    return (paths || []).map(p => {
        if (!/\/doc\/[^/]+\/[^/]+$/.test(p))
            return p;
        return (copied || []).find(c => name(c) === name(p)) ?? p;
    });
}

// Direction D's shelves: the family of an entry, from its kind (its extension; stat for a folder); a shelf folder sits
// with the folders, a file of no known kind with the documents.
var families = ["images", "documents", "folders", "archives", "media"];
var familyOf = {
    "image": "images",
    "pdf": "documents",
    "text": "documents",
    "office": "documents",
    "file": "documents",
    "folder": "folders",
    "group": "folders",
    "archive": "archives",
    "iso": "archives",
    "video": "media",
    "audio": "media"
};
function family(entry, dirs) {
    return familyOf[kind(entry, dirs)];
}

// The card's shelves, by family in a fixed order, the empty ones left out; each keeps the list's order, newest first
// (the shelf keeps no date: the order of arrival is its only one). "day" and "app" have nothing to group by yet (N2:
// no date nor source app kept on a drop): one shelf of everything.
function shelves(list, dirs, by) {
    const all = list || [];
    if (by === "day" || by === "app")
        return all.length ? [{
                    "id": "all",
                    "keys": all.slice()
                }] : [];
    return families.map(f => ({
                "id": f,
                "keys": all.filter(k => family(k, dirs) === f)
            })).filter(s => s.keys.length);
}

// The tiles row by row: one row a shelf, every file of it (the row scrolls sideways past the card's edge).
function shelfRows(list) {
    return (list || []).map(s => s.keys.slice());
}

// Up (d = -1) or down a row from key: the same column, or the end of a shorter row; key itself past the ends.
function rowStep(rows, key, d) {
    const r = rows.findIndex(row => row.indexOf(key) !== -1);
    const to = r < 0 ? null : rows[r + d];
    return to ? to[Math.min(rows[r].indexOf(key), to.length - 1)] : key;
}

// A tile's rendered preview (N5): a PDF's or an office document's first page, a video's frame, a sound's cover; a
// picture shows itself.
function previewed(path) {
    const k = kind(path);
    return k === "pdf" || k === "video" || k === "audio" || k === "office";
}

// What the quick look (Space) shows for one key: the picture itself (zoom), a GIF playing, a video playing mute, a
// sound with its cover and a play button, the pages of a PDF or office document, a text (Markdown rendered, code
// coloured), what an archive or a disc image holds, a folder's or a shelf folder's tiles, else the type's icon.
var markdownExts = ["md", "markdown"];
var plainExts = ["txt", "log", "csv", "conf", "ini"];
function peekKind(path, dirs) {
    const k = kind(path, dirs);
    const ext = extension(path);
    if (k === "image")
        return ext === "gif" ? "gif" : "picture";
    if (k === "pdf" || k === "office")
        return "pages";
    if (k === "archive" || k === "iso")
        return "listing";
    if (k === "folder" || k === "group")
        return "mosaic";
    if (k === "text")
        return markdownExts.indexOf(ext) !== -1 ? "markdown" : plainExts.indexOf(ext) !== -1 ? "text" : "code";
    return ["video", "audio"].indexOf(k) !== -1 ? k : "icon";
}

// `island-shelf.sh page`: the page's file, then the page count.
function pageOut(output) {
    const lines = String(output || "").split("\n").filter(l => l !== "");
    return lines.length && lines[0].startsWith("/") ? {
        "path": lines[0],
        "pages": Math.max(1, parseInt(lines[1], 10) || 1)
    } : null;
}

// `island-shelf.sh list`: an archive's paths, listMax lines at most ("more": how many were left out).
var listMax = 400;
function listing(output) {
    const lines = String(output || "").split("\n").filter(l => l !== "");
    return {
        "text": lines.slice(0, listMax).join("\n"),
        "more": Math.max(0, lines.length - listMax),
        "empty": lines.length === 0
    };
}

// `find -mindepth 1 -maxdepth 1 -printf "%y\t%s\t%T@\t%p\n"` on a folder: its entries as paths, folders first, by
// name, with each one's size and change time (ms) for the quick look's browser.
// The tree stops at treeMax entries and treeDepth levels (cut: entries were left out); a folder it may not have read
// whole is read again on its own when it is looked at (unread, merge).
var treeMax = 3000;
var treeDepth = 6;
function entries(output) {
    const lines = String(output || "").split("\n").filter(l => l.indexOf("\t") !== -1);
    const out = pack(lines.slice(0, treeMax).map(l => {
            const c = l.split("\t");
            return {
                "dir": c[0] === "d",
                "size": Number(c[1]) || 0,
                "mtime": Math.round(parseFloat(c[2]) * 1000) || 0,
                "path": c.slice(3).join("\t")
            };
        }));
    if (lines.length > treeMax)
        out.cut = true;
    return out;
}
function pack(rows) {
    // Folded names compared as plain strings: localeCompare costs about 0.1 ms a call in the shell, seconds on a big tree.
    for (const r of rows)
        r.key = fold(name(r.path));
    rows.sort((a, b) => a.dir !== b.dir ? (a.dir ? -1 : 1) : a.key < b.key ? -1 : a.key > b.key ? 1 : 0);
    const out = {
        "paths": rows.map(r => r.path),
        "dirs": rows.filter(r => r.dir).map(r => r.path),
        "size": {},
        "mtime": {}
    };
    for (const r of rows) {
        out.size[r.path] = r.size;
        out.mtime[r.path] = r.mtime;
    }
    return out;
}
// A folder under root whose entries the tree may lack: past its depth, or anywhere once it was cut; read once.
function unread(all, root, dir) {
    if (!root || !dir || (dir !== root && dir.indexOf(root + "/") !== 0) || (all?.read ?? []).indexOf(dir) !== -1)
        return false;
    const depth = dir === root ? 0 : dir.slice(root.length).split("/").length - 1;
    return !!all?.cut || depth >= treeDepth;
}
// The tree with one folder read again (entries' output for it) merged in, that folder marked read.
function merge(all, output, dir) {
    const more = entries(output);
    const seen = {};
    const rows = [];
    for (const src of [all, more]) {
        const ds = new Set(src?.dirs ?? []);
        for (const p of src?.paths ?? [])
            if (!seen[p]) {
                seen[p] = true;
                rows.push({
                    "dir": ds.has(p),
                    "size": src.size[p] ?? 0,
                    "mtime": src.mtime[p] ?? 0,
                    "path": p
                });
            }
    }
    const out = pack(rows);
    if (all?.cut)
        out.cut = true;
    out.read = (all?.read ?? []).concat([dir]);
    return out;
}

// The folder above one path ("/" stays).
function parent(path) {
    const p = String(path || "");
    const cut = p.lastIndexOf("/");
    return cut > 0 ? p.slice(0, cut) : "/";
}

// One folder's entries among all of them (entries' order: folders first, by name).
function children(all, dir) {
    return (all?.paths ?? []).filter(p => parent(p) === dir);
}

// The quick look's tree, as rows: the root folder (depth 0, always open), then each open folder's entries under it
// (folders first), with a folder open by default down to openDepth and along the path to the current item, else as
// toggled (open: {path: bool}). A root "" lists all paths flat (a shelf folder's items). A row: path, depth, dir, open,
// kids (entries in it), current, onPath (an ancestor of the current item, or itself). A whole tree that fits in fit rows
// opens entirely; a folder of more than openMax entries stays folded unless on the path.
var openDepth = 1;
var openMax = 100;
function treeRows(all, root, current, open, fit) {
    const kids = {};
    for (const p of all?.paths ?? []) {
        const d = root === "" ? "" : parent(p);
        (kids[d] = kids[d] || []).push(p);
    }
    const dirs = new Set(all?.dirs ?? []);
    const cur = current || root;
    const onPath = p => cur === p || (p !== "" && cur.indexOf(p + "/") === 0);
    const whole = (fit ?? 0) > (all?.paths?.length ?? 0);
    const rows = [];
    const walk = (dir, depth) => {
        const o = depth === 0 || (open && open[dir] !== undefined ? open[dir] : onPath(dir) || whole || depth <= openDepth && (kids[dir] || []).length <= openMax);
        rows.push({
            "path": dir,
            "depth": depth,
            "dir": true,
            "open": o,
            "kids": (kids[dir] || []).length,
            "current": cur === dir,
            "onPath": onPath(dir)
        });
        if (!o)
            return;
        for (const p of kids[dir] || []) {
            if (dirs.has(p))
                walk(p, depth + 1);
            else
                rows.push({
                    "path": p,
                    "depth": depth + 1,
                    "dir": false,
                    "open": false,
                    "kids": 0,
                    "current": cur === p,
                    "onPath": false
                });
        }
    };
    walk(root, 0);
    return rows;
}

// `island-shelf.sh info` on a picture: "w h", then EXIF's date ("2024:05:03 10:12:33"), make and model.
function imageInfo(output) {
    const l = String(output || "").split("\n");
    const wh = /^(\d+) (\d+)$/.exec(l[0] || "");
    const d = /^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)$/.exec((l[1] || "").trim());
    const make = (l[2] || "").trim();
    const model = (l[3] || "").trim();
    return {
        "width": wh ? Number(wh[1]) : 0,
        "height": wh ? Number(wh[2]) : 0,
        "when": d ? new Date(+d[1], d[2] - 1, +d[3], +d[4], +d[5], +d[6]).getTime() : 0,
        // "Canon" + "Canon EOS R6" reads once.
        "camera": model.toLowerCase().indexOf(make.toLowerCase()) === 0 || !make ? model : (make + " " + model).trim()
    };
}

// `island-shelf.sh tags` on a sound or a video: "duration=123.4", "TAG:title=..." lines, and the first picture stream's
// "width=" and "height=" (a video's frame, a sound's cover).
function audioInfo(output) {
    const out = {
        "seconds": 0,
        "length": "",
        "title": "",
        "artist": "",
        "album": "",
        "width": 0,
        "height": 0
    };
    for (const line of String(output || "").split("\n")) {
        const m = /^(TAG:)?([a-z]+)=(.*)$/i.exec(line.trim());
        if (!m)
            continue;
        const key = m[2].toLowerCase();
        if (key === "duration")
            out.seconds = Math.round(parseFloat(m[3]) || 0);
        else if (key === "width" || key === "height")
            out[key] = parseInt(m[3], 10) || 0;
        else if (key in out)
            out[key] = m[3];
    }
    out.length = clock(out.seconds);
    return out;
}

// What a text's quick look says instead of its body: "empty", "binary" (a NUL byte, or one character in ten that is
// not UTF-8, in its first 4 KiB), else "" (the text shows).
function textWord(text) {
    const s = String(text || "");
    if (s === "")
        return "empty";
    const head = s.slice(0, 4096);
    const bad = head.split("�").length - 1;
    return head.indexOf("\u0000") !== -1 || bad * 10 >= head.length ? "binary" : "";
}

// Qt refuses to decode a picture past 256 MB; a 16-bit RGBA one takes 8 bytes a pixel. A failed picture that big is
// "too large", any other failure has no preview.
var decodeLimit = 256 * 1024 * 1024;
function tooBig(width, height) {
    return width * height * 8 > decodeLimit;
}

// Markdown with its links ([label](url), <url>) as plain text in the given colour: Qt's Markdown reader paints links in
// the application palette's pure blue, unreadable on a dark card, and Text.linkColor does not reach them. Code spans,
// fenced blocks and pictures stay as they are. shortcut: bare URLs (GitHub autolinks) keep Qt's blue; a palette set on
// the application if they ever show up in the previews.
function markdownLinks(text, color) {
    const font = label => "<font color=\"" + color + "\">" + label + "</font>";
    let fenced = false;
    return String(text || "").split("\n").map(line => {
        if (/^\s*(```|~~~)/.test(line)) {
            fenced = !fenced;
            return line;
        }
        if (fenced)
            return line;
        return line.split("`").map((part, i) => i % 2 ? part : part.replace(/(^|[^!])\[([^\]]+)\]\([^)]*\)/g, (m, before, label) => before + font(label)).replace(/<(https?:\/\/[^>\s]+)>/g, (m, url) => font(url))).join("`");
    }).join("\n");
}

// The quick look's zoom after a wheel turn (delta in eighths of a degree, 120 a notch; a touchpad gives a share of
// one): a quarter more a notch up, from 1 (fitted) to 8.
var zoomMax = 8;
function zoomBy(zoom, delta) {
    return Math.max(1, Math.min(zoomMax, zoom * Math.pow(1.25, (delta || 0) / 120)));
}

// Seconds as m:ss, or h:mm:ss past an hour.
function clock(seconds) {
    const s = Math.max(0, Math.round(seconds || 0));
    const two = n => String(n).padStart(2, "0");
    return s >= 3600 ? Math.floor(s / 3600) + ":" + two(Math.floor(s / 60) % 60) + ":" + two(s % 60) : Math.floor(s / 60) + ":" + two(s % 60);
}

// Code as rich text for a Text: comments, strings, numbers and keywords coloured (colors: {comment, string, number,
// keyword}) by the language's family, read from the extension. shortcut: three families and one keyword list each,
// enough to read a file at a glance; a real grammar (tree-sitter) if the colours ever have to be right.
var syntaxes = {
    "c": {
        "exts": ["js", "mjs", "ts", "qml", "c", "h", "cpp", "hpp", "rs", "go", "java", "kt", "css", "json"],
        "comment": "\\/\\/[^\\n]*|\\/\\*[\\s\\S]*?\\*\\/",
        "words": "function|var|let|const|if|else|for|while|do|return|import|export|from|as|class|new|this|true|false|null|undefined|switch|case|break|continue|default|async|await|try|catch|finally|throw|typeof|instanceof|in|of|property|readonly|required|signal|component|pragma|int|string|bool|real|double|void|static|struct|enum|interface|type|fn|pub|mut|impl|use|match|func|package|defer|chan|map|range|go|extends|implements|public|private|protected|final|override|val|fun|when|object"
    },
    "script": {
        "exts": ["py", "rb", "sh", "yaml", "yml", "toml", "ini", "conf", "lua"],
        "comment": "#[^\\n]*|--[^\\n]*",
        "words": "def|class|if|elif|else|for|while|return|import|from|as|with|try|except|finally|lambda|pass|break|continue|and|or|not|in|is|True|False|None|end|do|then|fi|esac|case|local|function|echo|export|exit|module|require|yield|raise|self|nil|global|print|until|elsif|unless|begin|rescue|ensure"
    },
    "sql": {
        "exts": ["sql"],
        "comment": "--[^\\n]*|\\/\\*[\\s\\S]*?\\*\\/",
        "words": "select|from|where|insert|into|update|delete|create|table|drop|alter|join|left|right|inner|outer|on|group|by|order|limit|offset|values|set|and|or|not|null|primary|key|as|distinct|having|union|index|view|begin|commit|rollback|int|integer|text|varchar|boolean|default|references"
    },
    "markup": {
        "exts": ["html", "xml"],
        "comment": "<!--[\\s\\S]*?-->",
        "words": "html|head|body|div|span|p|a|img|ul|ol|li|table|tr|td|th|script|style|link|meta|title|h1|h2|h3|h4|form|input|button|xml"
    }
};
var highlightMax = 200000;
function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function highlight(text, ext, colors) {
    let src = String(text || "");
    const cut = src.length > highlightMax;
    if (cut)
        src = src.slice(0, highlightMax);
    let fam = null;
    for (const f in syntaxes)
        if (syntaxes[f].exts.indexOf(String(ext || "").toLowerCase()) !== -1)
            fam = syntaxes[f];
    if (!fam)
        return "<pre>" + escapeHtml(src) + (cut ? "\n…" : "") + "</pre>";
    const re = new RegExp("(" + fam.comment + ")|(\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'|`[^`]*`)|(\\b\\d+(?:\\.\\d+)?\\b)|(\\b(?:" + fam.words + ")\\b)", "g");
    const tint = (s, c) => "<font color=\"" + c + "\">" + escapeHtml(s) + "</font>";
    let out = "";
    let at = 0;
    let m;
    while ((m = re.exec(src)) !== null) {
        out += escapeHtml(src.slice(at, m.index));
        out += m[1] ? tint(m[1], colors.comment) : m[2] ? tint(m[2], colors.string) : m[3] ? tint(m[3], colors.number) : tint(m[4], colors.keyword);
        at = m.index + m[0].length;
    }
    return "<pre>" + out + escapeHtml(src.slice(at)) + (cut ? "\n…" : "") + "</pre>";
}

// What runs an action: the shelf's helper script for the files (its stdout: the new files, a text to copy, a notice,
// or the moved files' new folder), or an app opened on them. null: the shell does it itself, or no tool for it.
var verbs = {
    "zip": "zip",
    "toPng": ["convert", "png"],
    "toJpg": ["convert", "jpg"],
    "toWebp": ["convert", "webp"],
    "shrinkImage": "shrink-image",
    "rotate": "rotate",
    "contactSheet": "sheet",
    "pdfFromImages": "images-pdf",
    "frame": "frame",
    "shrinkVideo": "shrink-video",
    "gif": "gif",
    "mute": "mute",
    "mp3": "mp3",
    "shrinkPdf": "shrink-pdf",
    "pdfImages": "pdf-images",
    "mergePdf": "merge-pdf",
    "extractHere": "extract",
    "ocr": "ocr",
    "copyText": "pdf-text",
    "copyContent": "content",
    "copySha": "sha",
    "verify": "verify",
    "folderSize": "size",
    "phone": "phone",
    "print": "print",
    "mount": "mount",
    "moveTo": "move",
    "copyTo": "copy",
    "extractTo": "extract",
    "convertTo": "to",
    "sendTo": "phone"
};
var outputs = {
    "ocr": "copy",
    "copyText": "copy",
    "copyContent": "copy",
    "copySha": "copy",
    "verify": "notice",
    "folderSize": "notice",
    "phone": "none",
    "print": "none",
    "mount": "none",
    "moveTo": "moved",
    "copyTo": "none",
    "sendTo": "none"
};

function first(have, among) {
    for (const t of among)
        if ((have || []).indexOf(t) !== -1)
            return t;
    return "";
}

function command(id, paths, have, script, dest) {
    if (!ready(id, have))
        return null;
    const files = (paths || []).slice();
    switch (id) {
    case "annotate":
        return {
            "detach": first(have, needs.annotate) === "satty" ? ["satty", "--filename", files[0]] : ["swappy", "-f", files[0]]
        };
    case "writeUsb":
        {
            const app = first(have, needs.writeUsb);
            return {
                "detach": app === "gnome-disks" ? ["gnome-disks", "--restore-disk-image=" + files[0]] : [app, files[0]]
            };
        }
    case "editor":
    case "viewArchive":
        return {
            "detach": [first(have, needs[id])].concat(files)
        };
    case "renameSeries":
        return {
            "detach": first(have, needs.renameSeries) === "thunar" ? ["thunar", "--bulk-rename"].concat(files) : ["krename"].concat(files)
        };
    }
    const verb = verbs[id];
    if (!verb)
        return null;
    const head = ["sh", script].concat(verb);
    if (dest !== undefined)
        head.push(dest);
    return {
        "run": head.concat(["--"], files),
        "out": outputs[id] || "paths"
    };
}

// Shortcuts shown beside a button (only the first button of each key shows it): Ctrl+C copies, Enter opens.
var keyed = {
    "copy": ["copyFiles", "copyImage", "copyText", "copyContent"],
    // Enter always opens in the default app (decision of 11/01): Listen here and View archive stay buttons.
    "enter": ["open"]
};
var keyDefaults = {
    "copy": "copyFiles",
    "enter": "open"
};

function keysOf(p) {
    const out = {};
    for (const key in keyed) {
        const id = ((p && p.buttons) || []).find(b => keyed[key].indexOf(b) !== -1);
        if (id)
            out[id] = key;
    }
    return out;
}

function shortcut(p, key) {
    const shown = keysOf(p);
    for (const id in shown)
        if (shown[id] === key)
            return id;
    return keyDefaults[key] ?? "";
}

// The drop zones of the card's left column: the owner's order and choice (settings), these three by default.
var zoneIds = ["convert", "share", "cloud"];

function zoneRows(setting) {
    const rows = [];
    for (const r of Array.isArray(setting) ? setting : [])
        if (r && zoneIds.indexOf(r.id) !== -1 && !rows.some(o => o.id === r.id))
            rows.push({
                "id": r.id,
                "enabled": r.enabled !== false
            });
    for (const id of zoneIds)
        if (!rows.some(o => o.id === id))
            rows.push({
                "id": id,
                "enabled": true
            });
    return rows;
}

function zones(setting) {
    return zoneRows(setting).filter(r => r.enabled).map(r => r.id);
}

// What Convert offers for the dropped files, from the tools found here; null when their types differ.
var convertible = {
    "image": [["png", "magick"], ["jpg", "magick"], ["webp", "magick"], ["pdf", "magick"]],
    "video": [["mp4", "ffmpeg"], ["webm", "ffmpeg"], ["gif", "ffmpeg"], ["mp3", "ffmpeg"]],
    "audio": [["mp3", "ffmpeg"], ["ogg", "ffmpeg"], ["wav", "ffmpeg"], ["flac", "ffmpeg"]],
    "pdf": [["png", "magick"]],
    "text": [["html", "pandoc"], ["docx", "pandoc"], ["odt", "pandoc"]]
};
// Office files: PDF, and the other family's format (LibreOffice's or Microsoft's).
var officeTwins = {
    "doc": "odt",
    "docx": "odt",
    "rtf": "odt",
    "odt": "docx",
    "xls": "ods",
    "xlsx": "ods",
    "ods": "xlsx",
    "ppt": "odp",
    "pptx": "odp",
    "odp": "pptx"
};

function formats(paths, have) {
    const ks = (paths || []).map(p => kind(p));
    const exts = (paths || []).map(p => extension(p).replace(/^jpeg$/, "jpg"));
    if (!ks.length || ks.some(k => k !== ks[0]))
        return null;
    let offer = convertible[ks[0]] || [];
    if (ks[0] === "office") {
        const twin = officeTwins[exts[0]];
        offer = [["pdf", "soffice"]].concat(twin && exts.every(e => officeTwins[e] === twin) ? [[twin, "soffice"]] : []);
    }
    return offer.filter(([to, tool]) => (have || []).indexOf(tool) !== -1 && !exts.every(e => e === to)).map(([to, tool]) => ({
                "to": to,
                "tool": tool
            }));
}

// kdeconnect-cli -a --id-name-only: "<id> <name>" per reachable paired device.
function devices(output) {
    const out = [];
    for (const line of String(output || "").split("\n")) {
        const m = /^([A-Za-z0-9_-]+) (.+)$/.exec(line.trim());
        if (m)
            out.push({
                "id": m[1],
                "name": m[2]
            });
    }
    return out;
}

function localsend(have) {
    return first(have, needs.localsend);
}

// The synced folders the owner chose (their sync app talks to the cloud; DMS keeps no account).
// Each path once: "/a/" and "/a" are the same folder, the first one written wins.
function clouds(setting) {
    const out = [];
    for (const c of Array.isArray(setting) ? setting : []) {
        if (!c || typeof c.path !== "string" || !c.path.startsWith("/"))
            continue;
        const path = c.path.length > 1 ? c.path.replace(/\/+$/, "") : c.path;
        if (out.some(o => o.path === path))
            continue;
        out.push({
            "name": typeof c.name === "string" && c.name.trim() !== "" ? c.name.trim() : name(path),
            "icon": typeof c.icon === "string" && c.icon !== "" ? c.icon : "cloud",
            "path": path
        });
    }
    return out;
}

// Undo and redo: each change is one entry the shelf knows how to take back and play again.
var historyCap = 30;

function history() {
    return {
        "undo": [],
        "redo": []
    };
}

function record(h, entry) {
    return {
        "undo": (h?.undo ?? []).concat([entry]).slice(-historyCap),
        "redo": []
    };
}

function back(h) {
    const u = (h?.undo ?? []).slice();
    const entry = u.pop() ?? null;
    return {
        "entry": entry,
        "history": {
            "undo": u,
            "redo": entry ? (h?.redo ?? []).concat([entry]) : (h?.redo ?? [])
        }
    };
}

function forth(h) {
    const r = (h?.redo ?? []).slice();
    const entry = r.pop() ?? null;
    return {
        "entry": entry,
        "history": {
            "undo": entry ? (h?.undo ?? []).concat([entry]) : (h?.undo ?? []),
            "redo": r
        }
    };
}

// Files kept from outside (a drop, a paste, the picker): at the head of the list, or in the open shelf folder, and
// never twice on the shelf (a file kept again leaves wherever it was). kept: the files to choose; fresh: the new ones.
function place(keys, gs, folder, paths) {
    const had = expand(keys, gs);
    const kept = [];
    for (const p of paths || [])
        if (kept.indexOf(p) === -1)
            kept.push(p);
    const g = copyGroups(gs);
    for (const id in g)
        if (id !== folder)
            g[id].items = g[id].items.filter(p => kept.indexOf(p) === -1);
    const base = add(keys, kept).list;
    const s = folder && g[folder] ? intoGroup(base, g, folder, kept) : {
        "items": base,
        "groups": g
    };
    return {
        "items": s.items,
        "groups": s.groups,
        "kept": kept,
        "fresh": kept.filter(p => had.indexOf(p) === -1)
    };
}

// What a drop on a folder on disk can move there: never a folder into itself or below it, never a file already in it.
function movable(paths, dest) {
    const d = String(dest || "");
    return (paths || []).filter((p, i, all) => all.indexOf(p) === i && p !== d && !d.startsWith(p + "/") && parent(p) !== d);
}

// island-shelf.sh move or copy prints "from<TAB>to" for each file it placed (under a free name, never over another).
function moves(output) {
    const out = [];
    for (const line of String(output || "").split("\n")) {
        const [from, to] = line.split("\t");
        if (from && to && from.startsWith("/") && to.startsWith("/"))
            out.push([from, to]);
    }
    return out;
}

// The links follow files moved on disk ([from, to] pairs), on the list and in the shelf folders; a moved folder takes
// the links below it along.
function relink(keys, gs, pairs) {
    const swap = p => {
        for (const [from, to] of pairs || []) {
            if (p === from)
                return to;
            if (p.startsWith(from + "/"))
                return to + p.slice(from.length);
        }
        return p;
    };
    const g = copyGroups(gs);
    for (const id in g)
        g[id].items = g[id].items.map(swap);
    return {
        "items": (keys || []).map(k => isGroup(k) ? k : swap(k)),
        "groups": g
    };
}

// A menu opened at y drops down when it fits under, else rises from y; never past the card's top or bottom.
function menuY(y, height, top, bottom) {
    const at = y + height <= bottom ? y : y - height;
    return Math.max(top, Math.min(at, bottom - height));
}
