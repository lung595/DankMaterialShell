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

// stat -c "%s %f %n" prints one line per file still there: its size, its raw mode (hex), its path.
// shortcut: a file name with a newline in it reads as gone and is forgotten; switch to NUL output if that ever matters.
function facts(output) {
    const out = {
        "paths": [],
        "size": {},
        "dirs": []
    };
    for (const line of String(output || "").split("\n")) {
        const m = /^(\d+) ([0-9a-f]+) (\/.*)$/.exec(line);
        if (!m)
            continue;
        out.paths.push(m[3]);
        out.size[m[3]] = Number(m[1]);
        // S_IFDIR in the file type bits.
        if ((parseInt(m[2], 16) & 0o170000) === 0o040000)
            out.dirs.push(m[3]);
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
        "more": ["open", "ocr", "toPng", "toJpg", "toWebp", "shrinkImage", "rotate"]
    },
    "video": {
        "acts": ["open", "frame", "phone", "shrinkVideo"],
        "more": ["gif", "mute", "show"]
    },
    "audio": {
        "acts": ["listen", "phone", "mp3", "show"],
        "more": ["openWith", "copyPaths"]
    },
    "doc": {
        "acts": ["open", "copyText", "phone", "show"],
        "more": ["shrinkPdf", "pdfImages", "print", "copyPaths"]
    },
    "text": {
        "acts": ["open", "copyContent", "copyPaths", "show"],
        "more": ["editor", "phone"]
    },
    "archive": {
        "acts": ["extractHere", "viewArchive", "phone", "show"],
        "more": ["extractTo", "copyPaths"]
    },
    "iso": {
        "acts": ["writeUsb", "verify", "show", "copyPaths"],
        "more": ["open", "mount", "copySha"]
    },
    "folder": {
        "acts": ["open", "zip", "terminal", "copyPaths"],
        "more": ["phone", "folderSize"]
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

// Four buttons (the first is the likeliest), the rest under More; a hidden action leaves its place to the next one.
function plan(kindKey, have) {
    const a = actions[kindKey] || actions.all;
    const all = a.acts.concat(a.more).filter(id => ready(id, have));
    return {
        "buttons": all.slice(0, 4),
        "more": all.slice(4)
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

// A long press, then still held down the list: every row passed over joins what was chosen before.
function sweep(base, list, from, to) {
    const run = list.slice(Math.min(from, to), Math.max(from, to) + 1);
    return (base || []).filter(p => run.indexOf(p) === -1).concat(run);
}

function step(cur, delta, n) {
    return n > 0 ? Math.max(0, Math.min(n - 1, cur + delta)) : 0;
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
    "enter": ["open", "listen", "viewArchive"]
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
