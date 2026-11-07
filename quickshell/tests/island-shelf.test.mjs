import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandShelf.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const plain = v => JSON.parse(JSON.stringify(v));

test("a launcher opening folds the shelf's card into its bubble, wherever the card shows; a bubble alone stays", () => {
    assert.equal(C.foldsForLauncher(true, true, false), true);
    assert.equal(C.foldsForLauncher(true, false, true), true);
    assert.equal(C.foldsForLauncher(true, false, false), false);
    assert.equal(C.foldsForLauncher(false, true, true), false);
    assert.equal(C.foldsForLauncher(undefined, true, false), false);
});

test("a drop's urls become local paths, other schemes and comments are left out", () => {
    assert.deepEqual(plain(C.paths(["file:///data/Photo%20%C3%A9t%C3%A9.jpg", "https://x.org/y", "file:///tmp/b.pdf"])), ["/data/Photo été.jpg", "/tmp/b.pdf"]);
    assert.deepEqual(plain(C.paths("# comment\r\nfile:///tmp/a\r\nfile:///tmp/b\r\n")), ["/tmp/a", "/tmp/b"]);
    assert.deepEqual(plain(C.paths(["file://host/tmp/a", "", null, "file:///tmp/%ZZ"])), []);
    assert.deepEqual(plain(C.paths(undefined)), []);
});

test("a file drag is taken by its formats alone: on Wayland its urls are often unknown until the drop", () => {
    assert.equal(C.takesDrag(["text/uri-list"], false), true);
    assert.equal(C.takesDrag(["application/vnd.portal.filetransfer", "text/uri-list"], false), true);
    assert.equal(C.takesDrag(["application/vnd.portal.files"], false), true);
    assert.equal(C.takesDrag(["application/x-kde4-urilist"], false), true);
    assert.equal(C.takesDrag([], true), true);
    assert.equal(C.takesDrag(["text/plain", "text/html"], false), false);
    assert.equal(C.takesDrag(undefined, false), false);
});

test("a drop's files come from whichever of urls, uri-list or plain text holds them", () => {
    assert.deepEqual(plain(C.paths(C.dropUris([], "file:///tmp/a.png\r\n", ""))), ["/tmp/a.png"]);
    assert.deepEqual(plain(C.paths(C.dropUris(["file:///tmp/b.pdf"], "", ""))), ["/tmp/b.pdf"]);
    assert.deepEqual(plain(C.paths(C.dropUris([], "", "file:///tmp/c.md\n"))), ["/tmp/c.md"]);
    assert.deepEqual(plain(C.paths(C.dropUris(undefined, undefined, "just words"))), []);
    assert.deepEqual(plain(C.paths("file://localhost/tmp/d.txt")), ["/tmp/d.txt"]);
});

test("the shelf's face never rests small in the island: shown compact, it grows into its card", () => {
    assert.equal(C.growsOpen(true, false, true), true);
    assert.equal(C.growsOpen(true, true, true), false);
    assert.equal(C.growsOpen(false, false, true), false);
    assert.equal(C.growsOpen(true, false, false), false);
});

test("adding puts new files on top, newest first", () => {
    const s = C.add(["/a"], ["/b", "/c"]);
    assert.deepEqual(plain(s), { "list": ["/b", "/c", "/a"], "added": 2 });
});

test("a file already kept is not kept twice: it comes back on top", () => {
    let s = C.add(["/a", "/b", "/c"], ["/c"]);
    assert.deepEqual(plain(s), { "list": ["/c", "/a", "/b"], "added": 0 });
    s = C.add([], ["/a", "/a", "/b"]);
    assert.deepEqual(plain(s.list), ["/a", "/b"]);
    assert.equal(s.added, 2);
});

test("the shelf keeps at most maxFiles links, the newest first", () => {
    const many = Array.from({ "length": C.maxFiles + 5 }, (_, i) => "/f" + i);
    const s = C.add(["/old"], many);
    assert.equal(s.list.length, C.maxFiles);
    assert.equal(s.list[0], "/f0");
    assert.equal(s.list.indexOf("/old"), -1);
});

test("removing forgets a link, the others keep their order", () => {
    assert.deepEqual(plain(C.remove(["/a", "/b", "/c"], "/b")), ["/a", "/c"]);
    assert.deepEqual(plain(C.remove(["/a"], "/z")), ["/a"]);
});

test("only files still there are kept, as stat lists them", () => {
    assert.deepEqual(plain(C.facts("12 81a4 1700000000 /a\n0 41ed 1700000000 /c d\n").paths), ["/a", "/c d"]);
    assert.deepEqual(plain(C.keep(["/a", "/b", "/c d"], C.facts("12 81a4 1700000000 /a\n0 41ed 1700000000 /c d\n").paths)), ["/a", "/c d"]);
    assert.deepEqual(plain(C.keep(["/a"], [])), []);
    // A file kept while stat ran was not asked about: it stays.
    assert.deepEqual(plain(C.keep(["/new", "/a", "/b"], ["/a"], ["/a", "/b"])), ["/new", "/a"]);
});

test("the saved list survives a restart, cleaned of what cannot be a kept file", () => {
    const saved = JSON.parse(JSON.stringify(C.add([], ["/x/1.png", "/x/2.pdf"]).list));
    assert.deepEqual(plain(C.load(saved)), ["/x/1.png", "/x/2.pdf"]);
    assert.deepEqual(plain(C.load(["/a", "relative", 3, "/a", "", null])), ["/a"]);
    assert.deepEqual(plain(C.load({ "a": 1 })), []);
    assert.deepEqual(plain(C.load(undefined)), []);
});

test("a kept file goes back out as a url that reads back as its path", () => {
    const odd = "/data/Été 50% #1?.png";
    assert.equal(C.url("/tmp/a b.pdf"), "file:///tmp/a%20b.pdf");
    assert.deepEqual(plain(C.paths([C.url(odd)])), [odd]);
    assert.deepEqual(plain(C.paths(C.uriList(["/tmp/a", odd]))), ["/tmp/a", odd]);
});

test("the drop target reaches the screen edge on the island's side: a file thrown against the edge lands", () => {
    assert.deepEqual(plain(C.dropReach(false, false, 4)), { "top": 4, "bottom": 0, "left": 0, "right": 0 });
    assert.deepEqual(plain(C.dropReach(false, true, 6)), { "top": 0, "bottom": 6, "left": 0, "right": 0 });
    assert.deepEqual(plain(C.dropReach(true, false, 3)), { "top": 0, "bottom": 0, "left": 3, "right": 0 });
    assert.deepEqual(plain(C.dropReach(true, true, 3)), { "top": 0, "bottom": 0, "left": 0, "right": 3 });
    assert.deepEqual(plain(C.dropReach(false, false, -2)), { "top": 0, "bottom": 0, "left": 0, "right": 0 });
});

test("names and what a thumbnail shows", () => {
    assert.equal(C.name("/data/rapport-annuel-2026.pdf"), "rapport-annuel-2026.pdf");
    assert.equal(C.name("/data/dir/"), "dir");
    assert.equal(C.isImage("/a/B.JPG"), true);
    assert.equal(C.isImage("/a/b.webp"), true);
    assert.equal(C.isImage("/a/b.pdf"), false);
    assert.equal(C.isImage("/a/png"), false);
    assert.equal(C.icon("/a/b.pdf"), "picture_as_pdf");
    assert.equal(C.icon("/a/b.mkv"), "movie");
    assert.equal(C.icon("/a/b.flac"), "audio_file");
    assert.equal(C.icon("/a/b.tar.gz"), "folder_zip");
    assert.equal(C.icon("/a/b.png"), "image");
    assert.equal(C.icon("/a/b.txt"), "description");
    assert.equal(C.icon("/a/Makefile"), "draft");
    assert.equal(C.icon("/a/Photos", ["/a/Photos"]), "folder");
    assert.equal(C.icon("/a/f.iso"), "album");
});

test("stat tells each kept file's size and which are folders", () => {
    const f = C.facts("1258291 81a4 1714730400 /a/b c.png\n4096 41ed 1714730400 /a/Photos\nbad line\n");
    assert.deepEqual(plain(f.dirs), ["/a/Photos"]);
    assert.equal(f.size["/a/b c.png"], 1258291);
    assert.deepEqual(plain(C.facts("1258291 81a4 1714730400 /a/b c.png\nbad line\n").paths), ["/a/b c.png"]);
});

test("each file has a kind, and the filters count them", () => {
    const dirs = ["/d/Photos"];
    const list = ["/d/a.png", "/d/r.pdf", "/d/f.iso", "/d/m.jpg", "/d/p.zip", "/d/n.md", "/d/Photos", "/d/c.docx", "/d/v.mkv"];
    assert.deepEqual(list.map(p => C.kind(p, dirs)), ["image", "pdf", "iso", "image", "archive", "text", "folder", "office", "video"]);
    assert.deepEqual(plain(C.counts(list, dirs)), { "all": 9, "image": 2, "doc": 3, "other": 4 });
    assert.deepEqual(plain(C.shown(list, "doc", dirs)), ["/d/r.pdf", "/d/n.md", "/d/c.docx"]);
    assert.deepEqual(plain(C.shown(list, "all", dirs)), list);
});

test("what is chosen picks its set of actions", () => {
    const dirs = ["/d/Photos"];
    const cases = [[[], "all"], [["/d/a.png"], "image"], [["/d/v.mkv"], "video"], [["/d/s.flac"], "audio"], [["/d/r.pdf"], "doc"],
        [["/d/n.md"], "text"], [["/d/p.zip"], "archive"], [["/d/f.iso"], "iso"], [["/d/Photos"], "folder"], [["/d/c.docx"], "file"],
        [["/d/a.png", "/d/m.jpg"], "images"], [["/d/r.pdf", "/d/q.pdf"], "pdfs"], [["/d/a.png", "/d/r.pdf"], "mixed"]];
    for (const [sel, k] of cases)
        assert.equal(C.selectionKind(sel, dirs), k, sel.join(","));
});

test("four buttons, the rest in More, an action whose tool is missing is hidden and the next one moves up", () => {
    const every = C.tools.slice();
    assert.deepEqual(plain(C.plan("image", every)), { "buttons": ["copyImage", "annotate", "phone", "wallpaper"], "more": ["open", "ocr", "toPng", "toJpg", "toWebp", "shrinkImage", "rotate", "moveTo", "copyTo"] });
    // One file is moved or copied into a folder like several (Move to… and Copy to… in More).
    for (const k of ["image", "video", "audio", "doc", "text", "archive", "iso", "folder"])
        assert.ok(C.plan(k, every).more.indexOf("moveTo") !== -1 && C.plan(k, every).more.indexOf("copyTo") !== -1, k);
    // No annotate tool, no phone: Open and OCR move up into the buttons, the first stays the most likely.
    const none = C.plan("image", every.filter(t => ["satty", "swappy", "kdeconnect-cli"].indexOf(t) === -1));
    assert.deepEqual(plain(none.buttons), ["copyImage", "wallpaper", "open", "ocr"]);
    assert.deepEqual(plain(C.plan("iso", []).buttons), ["verify", "show", "copyPaths", "open"]);
    for (const k of Object.keys(C.actions))
        assert.equal(C.plan(k, every).buttons.length, 4, k);
    // The table holds every kind the selection can name.
    for (const k of ["all", "image", "video", "audio", "doc", "text", "archive", "iso", "folder", "images", "pdfs", "mixed", "file"])
        assert.ok(C.actions[k], k);
});

test("a shelf folder is a group of links saved with the list, nothing on disk", () => {
    const saved = ["/a.png", { "id": "g1", "name": "Vacances", "items": ["/b.jpg", "/c.jpg", "rel", 3] }, { "id": "", "name": "x", "items": [] }, { "id": "g2" }];
    assert.deepEqual(plain(C.load(saved)), ["/a.png", "group:g1"]);
    assert.deepEqual(plain(C.groups(saved)), { "g1": { "name": "Vacances", "items": ["/b.jpg", "/c.jpg"] } });
    const back = C.dump(["/a.png", "group:g1"], C.groups(saved));
    assert.deepEqual(plain(back), ["/a.png", { "id": "g1", "name": "Vacances", "items": ["/b.jpg", "/c.jpg"] }]);
    // A group key with no group behind it is dropped.
    assert.deepEqual(plain(C.dump(["group:zz", "/a"], {})), ["/a"]);
    assert.equal(C.isGroup("group:g1"), true);
    assert.equal(C.isGroup("/group:g1"), false);
    assert.equal(C.kind("group:g1"), "group");
    assert.equal(C.icon("group:g1"), "folder_special");
    assert.equal(C.label("group:g1", C.groups(saved)), "Vacances");
    assert.equal(C.label("/x/y.pdf", {}), "y.pdf");
    assert.deepEqual(plain(C.expand(["/a.png", "group:g1", "/b.jpg"], C.groups(saved))), ["/a.png", "/b.jpg", "/c.jpg"]);
});

test("a file held on another makes a folder in its place; a file dropped on a folder goes in", () => {
    let s = C.makeGroup(["/a", "/b", "/c"], {}, "/c", ["/a"], "New folder", "g9");
    assert.deepEqual(plain(s), { "items": ["/b", "group:g9"], "groups": { "g9": { "name": "New folder", "items": ["/c", "/a"] } }, "key": "group:g9" });
    s = C.intoGroup(["/b", "group:g9", "/d"], s.groups, "g9", ["/d", "/b", "group:g9"]);
    assert.deepEqual(plain(s.items), ["group:g9"]);
    assert.deepEqual(plain(s.groups.g9.items), ["/c", "/a", "/d", "/b"]);
    // A folder dropped on a folder brings its files and goes.
    const two = C.intoGroup(["group:a", "group:b"], { "a": { "name": "A", "items": ["/1"] }, "b": { "name": "B", "items": ["/2", "/1"] } }, "a", ["group:b"]);
    assert.deepEqual(plain(two), { "items": ["group:a"], "groups": { "a": { "name": "A", "items": ["/1", "/2"] } } });
});

test("removing a file gone from disk also takes it out of the folders", () => {
    const g = { "g": { "name": "G", "items": ["/x", "/y"] } };
    const s = C.prune(["/a", "group:g", "/b"], g, ["/a", "/y"], ["/a", "/b", "/x", "/y"]);
    assert.deepEqual(plain(s), { "items": ["/a", "group:g"], "groups": { "g": { "name": "G", "items": ["/y"] } } });
    assert.deepEqual(plain(C.withoutKeys(["/a", "group:g"], g, ["group:g"])), { "items": ["/a"], "groups": {} });
    assert.deepEqual(plain(C.withoutKeys(["group:g"], g, ["/x"], "g")), { "items": ["group:g"], "groups": { "g": { "name": "G", "items": ["/y"] } } });
    assert.deepEqual(plain(C.missing(["/a", "/b", "/x", "/y"], ["/a", "/y"])), ["/b", "/x"]);
    assert.deepEqual(plain(C.missing(["/a"], ["/a"])), []);
    assert.deepEqual(plain(C.missing(undefined, undefined)), []);
});

test("search: names, accents and case ignored, folders by their name", () => {
    const g = { "g": { "name": "Été 2026", "items": ["/p/1.jpg"] } };
    const list = ["/d/Rapport Annuel.pdf", "/d/notes.md", "group:g"];
    assert.deepEqual(plain(C.shown(list, "all", [], "RAPP", g)), ["/d/Rapport Annuel.pdf"]);
    assert.deepEqual(plain(C.shown(list, "all", [], "ete", g)), ["group:g"]);
    assert.deepEqual(plain(C.shown(list, "doc", [], "", g)), ["/d/Rapport Annuel.pdf", "/d/notes.md"]);
    assert.deepEqual(plain(C.shown(list, "other", [], " ", g)), ["group:g"]);
});

test("a folder name is one segment, never a path", () => {
    assert.equal(C.validName("Vacances 2026"), true);
    for (const bad of ["", "  ", ".", "..", "a/b", "a\nb", "x".repeat(256)])
        assert.equal(C.validName(bad), false, JSON.stringify(bad));
});

test("drop zones: the default three, the owner's order and choice, unknown ones left out", () => {
    assert.deepEqual(plain(C.zones(undefined)), ["convert", "share", "cloud"]);
    assert.deepEqual(plain(C.zones([{ "id": "cloud", "enabled": true }, { "id": "zzz", "enabled": true }, { "id": "convert", "enabled": false }, { "id": "share", "enabled": true }])), ["cloud", "share"]);
    // The settings rows: every known zone once, the saved order first.
    assert.deepEqual(plain(C.zoneRows([{ "id": "share", "enabled": false }])), [{ "id": "share", "enabled": false }, { "id": "convert", "enabled": true }, { "id": "cloud", "enabled": true }]);
});

test("convert offers only what an installed local tool can make from that type", () => {
    const all = ["magick", "ffmpeg", "soffice", "pandoc"];
    assert.deepEqual(plain(C.formats(["/a.png"], all)), [{ "to": "jpg", "tool": "magick" }, { "to": "webp", "tool": "magick" }, { "to": "pdf", "tool": "magick" }]);
    assert.deepEqual(plain(C.formats(["/a.JPEG", "/b.jpg"], all).map(f => f.to)), ["png", "webp", "pdf"]);
    assert.deepEqual(plain(C.formats(["/a.png"], [])), []);
    assert.deepEqual(plain(C.formats(["/v.mkv"], all).map(f => f.to)), ["mp4", "webm", "gif", "mp3"]);
    assert.deepEqual(plain(C.formats(["/s.mp3"], all).map(f => f.to)), ["ogg", "wav", "flac"]);
    assert.deepEqual(plain(C.formats(["/r.docx"], all)), [{ "to": "pdf", "tool": "soffice" }, { "to": "odt", "tool": "soffice" }]);
    assert.deepEqual(plain(C.formats(["/n.md"], all)), [{ "to": "html", "tool": "pandoc" }, { "to": "docx", "tool": "pandoc" }, { "to": "odt", "tool": "pandoc" }]);
    assert.deepEqual(plain(C.formats(["/n.md"], ["soffice"])), []);
    // Different types: nothing in common to offer.
    assert.equal(C.formats(["/a.png", "/r.pdf"], all), null);
    assert.deepEqual(plain(C.formats(["/r.pdf"], all)), [{ "to": "png", "tool": "magick" }]);
    assert.deepEqual(plain(C.command("convertTo", ["/a b.png"], all, "/s.sh", "magick:webp")), { "run": ["sh", "/s.sh", "to", "magick:webp", "--", "/a b.png"], "out": "paths" });
});

test("share: KDE Connect's reachable paired devices, LocalSend only when installed", () => {
    assert.deepEqual(plain(C.devices("abc_123 Pixel 8\n\nbad\nf00 Tablette salon\n")), [{ "id": "abc_123", "name": "Pixel 8" }, { "id": "f00", "name": "Tablette salon" }]);
    assert.deepEqual(plain(C.devices("")), []);
    assert.deepEqual(plain(C.devices("a;b name\n")), []);
    assert.deepEqual(plain(C.command("sendTo", ["/a"], ["kdeconnect-cli"], "/s.sh", "abc_123")), { "run": ["sh", "/s.sh", "phone", "abc_123", "--", "/a"], "out": "none" });
    assert.equal(C.localsend(["kdeconnect-cli"]), "");
    assert.equal(C.localsend(["localsend_app"]), "localsend_app");
});

test("cloud: the owner's synced folders, a name and an icon each, never an account", () => {
    assert.deepEqual(plain(C.clouds([{ "path": "/h/Proton Drive/Dépôt" }, { "path": "rel" }, { "name": "Nextcloud", "icon": "cloud_sync", "path": "/h/Nextcloud" }, null])), [{ "name": "Dépôt", "icon": "cloud", "path": "/h/Proton Drive/Dépôt" }, { "name": "Nextcloud", "icon": "cloud_sync", "path": "/h/Nextcloud" }]);
    assert.deepEqual(plain(C.clouds(undefined)), []);
    assert.deepEqual(plain(C.clouds([{ "path": "/h/Nextcloud/" }, { "name": "Again", "path": "/h/Nextcloud" }])), [{ "name": "Nextcloud", "icon": "cloud", "path": "/h/Nextcloud" }]);
    assert.deepEqual(plain(C.command("copyTo", ["/a"], [], "/s.sh", "/h/Nextcloud")), { "run": ["sh", "/s.sh", "copy", "/h/Nextcloud", "--", "/a"], "out": "none" });
});

test("undo and redo walk the shelf's changes, a new change forgets what was undone", () => {
    let h = C.history();
    h = C.record(h, { "n": 1 });
    h = C.record(h, { "n": 2 });
    let r = C.back(h);
    assert.equal(r.entry.n, 2);
    r = C.back(r.history);
    assert.equal(r.entry.n, 1);
    assert.equal(C.back(r.history).entry, null);
    r = C.forth(r.history);
    assert.equal(r.entry.n, 1);
    h = C.record(r.history, { "n": 3 });
    assert.equal(C.forth(h).entry, null);
    for (let i = 0; i < 40; i++)
        h = C.record(h, { "n": i });
    assert.equal(h.undo.length, 30);
});

test("an entry's family: by its extension, a folder by stat, a shelf folder among the folders", () => {
    const dirs = ["/d/Projet"];
    assert.equal(C.family("/d/a.JPG", dirs), "images");
    assert.equal(C.family("/d/a.pdf", dirs), "documents");
    assert.equal(C.family("/d/a.md", dirs), "documents");
    assert.equal(C.family("/d/a.odt", dirs), "documents");
    assert.equal(C.family("/d/no-extension", dirs), "documents");
    assert.equal(C.family("/d/Projet", dirs), "folders");
    assert.equal(C.family("group:g1", dirs), "folders");
    assert.equal(C.family("/d/a.tar.gz", dirs), "archives");
    assert.equal(C.family("/d/a.iso", dirs), "archives");
    assert.equal(C.family("/d/a.mp4", dirs), "media");
    assert.equal(C.family("/d/a.flac", dirs), "media");
});

test("the shelves: one per family in a fixed order, none empty, each in the list's order (newest first)", () => {
    const list = ["/d/b.mp4", "/d/new.png", "/d/c.pdf", "/d/old.png", "/d/x.zip", "group:g1"];
    assert.deepEqual(plain(C.shelves(list, [], "kind")), [
        { "id": "images", "keys": ["/d/new.png", "/d/old.png"] },
        { "id": "documents", "keys": ["/d/c.pdf"] },
        { "id": "folders", "keys": ["group:g1"] },
        { "id": "archives", "keys": ["/d/x.zip"] },
        { "id": "media", "keys": ["/d/b.mp4"] }
    ]);
    // No date nor source app is kept yet (N2): day and app fall back on one shelf of everything.
    assert.deepEqual(plain(C.shelves(list, [], "day")), [{ "id": "all", "keys": list }]);
    assert.deepEqual(plain(C.shelves(list, [], "app")), [{ "id": "all", "keys": list }]);
    assert.deepEqual(plain(C.shelves([], [], "day")), []);
    assert.deepEqual(plain(C.shelves([], [], "kind")), []);
    assert.deepEqual(plain(C.shelves(["/d/a.png"], [], undefined)), [{ "id": "images", "keys": ["/d/a.png"] }]);
});

test("up and down go shelf to shelf, one row each, the same column or the end of a shorter row", () => {
    const shelves = [{ "id": "images", "keys": ["a", "b", "c", "d", "e", "f", "g"] }, { "id": "documents", "keys": ["p", "q"] }];
    const rows = C.shelfRows(shelves);
    assert.deepEqual(plain(rows), [["a", "b", "c", "d", "e", "f", "g"], ["p", "q"]]);
    assert.equal(C.rowStep(rows, "b", 1), "q");
    assert.equal(C.rowStep(rows, "g", 1), "q");
    assert.equal(C.rowStep(rows, "q", -1), "b");
    assert.equal(C.rowStep(rows, "q", 1), "q");
    assert.equal(C.rowStep(rows, "zz", 1), "zz");
    assert.deepEqual(plain(C.shelfRows(undefined)), []);
});

test("a folder's entries for the browser: folders first, then by name, each with its size and time", () => {
    const out = "f\t49\t1714730400.5\t/d/notes.md\nd\t4096\t1714730400.0\t/d/src\nf\t12\t1714730401.25\t/d/Abc.js\nd\t4096\t1714730400.0\t/d/empty\n";
    const e = C.entries(out);
    assert.deepEqual(plain(e.paths), ["/d/empty", "/d/src", "/d/Abc.js", "/d/notes.md"]);
    assert.deepEqual(plain(e.dirs), ["/d/empty", "/d/src"]);
    assert.equal(e.size["/d/notes.md"], 49);
    assert.equal(e.mtime["/d/Abc.js"], 1714730401250);
    assert.deepEqual(plain(C.entries("")), { "paths": [], "dirs": [], "size": {}, "mtime": {} });
    assert.equal(C.parent("/d/src/a.js"), "/d/src");
    assert.equal(C.parent("/a"), "/");
});

test("the tree's rows: open folders down to one level and along the current path, toggles win, a flat shelf folder", () => {
    const out = "d\t0\t1\t/r/src\nd\t0\t1\t/r/src/lib\nf\t1\t1\t/r/src/lib/x.js\nf\t1\t1\t/r/src/a.js\nd\t0\t1\t/r/docs\nf\t1\t1\t/r/docs/g.md\nf\t1\t1\t/r/plan.md\n";
    const all = C.entries(out);
    assert.deepEqual(plain(C.children(all, "/r")), ["/r/docs", "/r/src", "/r/plan.md"]);
    const rows = C.treeRows(all, "/r", "", {});
    assert.deepEqual(plain(rows.map(r => r.path)), ["/r", "/r/docs", "/r/docs/g.md", "/r/src", "/r/src/lib", "/r/src/a.js", "/r/plan.md"]);
    assert.deepEqual(plain(rows.map(r => r.depth)), [0, 1, 2, 1, 2, 2, 1]);
    assert.equal(rows[0].current, true);
    assert.equal(rows.find(r => r.path === "/r/src/lib").open, false);
    const deep = C.treeRows(all, "/r", "/r/src/lib/x.js", {});
    assert.deepEqual(plain(deep.filter(r => r.onPath).map(r => r.path)), ["/r", "/r/src", "/r/src/lib"]);
    assert.equal(deep.find(r => r.path === "/r/src/lib/x.js").current, true);
    assert.equal(deep.find(r => r.path === "/r/src").kids, 2);
    const closed = C.treeRows(all, "/r", "", { "/r/src": false });
    assert.deepEqual(plain(closed.map(r => r.path)), ["/r", "/r/docs", "/r/docs/g.md", "/r/src", "/r/plan.md"]);
    const flat = C.treeRows({ "paths": ["/a/p.png", "/b/Photos"], "dirs": ["/b/Photos"] }, "", "", {});
    assert.deepEqual(plain(flat.map(r => [r.path, r.depth])), [["", 0], ["/a/p.png", 1], ["/b/Photos", 1]]);
    assert.equal(flat[2].open, true);
    // A tree that fits opens whole; a huge folder stays folded.
    assert.deepEqual(plain(C.treeRows(all, "/r", "", {}, 20).map(r => r.path)), ["/r", "/r/docs", "/r/docs/g.md", "/r/src", "/r/src/lib", "/r/src/lib/x.js", "/r/src/a.js", "/r/plan.md"]);
    const bulk = C.entries("d\t0\t1\t/r/bulk\n" + Array.from({ "length": C.openMax + 1 }, (_, i) => "f\t0\t1\t/r/bulk/f" + i + "\n").join(""));
    assert.equal(C.treeRows(bulk, "/r", "", {}).length, 2);
});

test("a folder the tree may lack is read again on its own: past six levels, or once the tree was cut", () => {
    const deep = "/r/a/b/c/d/e/f";
    const all = C.entries("d\t0\t1\t/r/a\nd\t0\t1\t" + deep + "\n");
    assert.equal(C.unread(all, "/r", "/r/a"), false);
    assert.equal(C.unread(all, "/r", deep), true);
    assert.equal(C.unread(all, "/r", "/elsewhere/x/y/z/w/v/u"), false);
    const more = C.merge(all, "d\t0\t2\t" + deep + "/ISO\nf\t5\t3\t" + deep + "/a.iso\n", deep);
    assert.deepEqual(plain(C.children(more, deep)), [deep + "/ISO", deep + "/a.iso"]);
    assert.equal(more.dirs.indexOf(deep + "/ISO") !== -1, true);
    assert.equal(more.size[deep + "/a.iso"], 5);
    assert.equal(C.unread(more, "/r", deep), false);
    // Cut at treeMax: every folder is read again once, the root too.
    const cut = C.entries(Array.from({ "length": C.treeMax + 2 }, (_, i) => "f\t0\t1\t/g/f" + i + "\n").join(""));
    assert.equal(cut.cut, true);
    assert.equal(cut.paths.length, C.treeMax);
    assert.equal(C.unread(cut, "/g", "/g"), true);
});

test("the explorer's keys and words: Home, End, pages, a letter, its actions, a path that wraps at slashes", () => {
    assert.equal(C.leap(5, 10, "first", 3), 0);
    assert.equal(C.leap(5, 10, "last", 3), 9);
    assert.equal(C.leap(5, 10, "pageUp", 3), 2);
    assert.equal(C.leap(8, 10, "pageDown", 3), 9);
    const names = ["Docs", "devis.pdf", "foret.jpg", "Été.txt"];
    assert.equal(C.typeAhead(names, "d", 0), 1);
    assert.equal(C.typeAhead(names, "d", 1), 0);
    assert.equal(C.typeAhead(names, "e", -1), 3);
    assert.equal(C.typeAhead(names, "z", 0), -1);
    const have = ["pdftotext", "kdeconnect-cli", "zip", "ghostty"];
    assert.deepEqual(plain(C.asidePlan(C.plan("doc", have)).buttons), ["open", "copyText", "show"]);
    assert.deepEqual(plain(C.asidePlan(C.plan("text", have)).buttons), ["open", "copyContent", "copyPaths"]);
    assert.deepEqual(plain(C.asidePlan(C.plan("folder", have)).buttons), ["open", "zip", "terminal"]);
    assert.equal(C.asidePlan(C.plan("image", have)).buttons[0], "open");
    assert.equal(C.asidePlan(C.plan("doc", have)).more.slice(-1)[0], "phone");
    assert.equal(C.shortcut(C.asidePlan(C.plan("folder", have)), "copy"), "copyFiles");
    assert.equal(C.wrapPath("~/a/b"), "~/​a/​b");
});

test("PDFs, office documents, videos and sounds get a rendered preview, pictures show themselves", () => {
    assert.equal(C.previewed("/d/a.pdf"), true);
    assert.equal(C.previewed("/d/a.webm"), true);
    assert.equal(C.previewed("/d/a.mp3"), true);
    assert.equal(C.previewed("/d/a.odt"), true);
    assert.equal(C.previewed("/d/a.png"), false);
    assert.equal(C.previewed("group:g1"), false);
});

test("the quick look shows each key its own way", () => {
    assert.equal(C.peekKind("/d/a.jpg"), "picture");
    assert.equal(C.peekKind("/d/a.gif"), "gif");
    assert.equal(C.peekKind("/d/a.mp4"), "video");
    assert.equal(C.peekKind("/d/a.flac"), "audio");
    assert.equal(C.peekKind("/d/a.pdf"), "pages");
    assert.equal(C.peekKind("/d/a.docx"), "pages");
    assert.equal(C.peekKind("/d/a.zip"), "listing");
    assert.equal(C.peekKind("/d/a.iso"), "listing");
    assert.equal(C.peekKind("/d/a.md"), "markdown");
    assert.equal(C.peekKind("/d/a.txt"), "text");
    assert.equal(C.peekKind("/d/a.py"), "code");
    assert.equal(C.peekKind("/d/Photos", ["/d/Photos"]), "mosaic");
    assert.equal(C.peekKind("group:g1"), "mosaic");
    assert.equal(C.peekKind("/d/a.bin"), "icon");
});

test("the helper's answers are read: a page and its count, a listing, a picture's facts, a sound's tags", () => {
    assert.deepEqual(plain(C.pageOut("/c/x-3.png\n12\n")), { "path": "/c/x-3.png", "pages": 12 });
    assert.deepEqual(plain(C.pageOut("/c/x-1.png\n")), { "path": "/c/x-1.png", "pages": 1 });
    assert.equal(C.pageOut(""), null);
    assert.equal(C.pageOut("error\n"), null);
    assert.deepEqual(plain(C.listing("a/\na/b.txt\n\n")), { "text": "a/\na/b.txt", "more": 0, "empty": false });
    assert.equal(C.listing("").empty, true);
    const many = Array.from({ length: 450 }, (_, i) => "f" + i).join("\n");
    assert.equal(C.listing(many).more, 50);
    assert.equal(C.listing(many).text.split("\n").length, 400);
    const i = C.imageInfo("4000 3000\n2024:05:03 10:12:33\nCanon\nCanon EOS R6\n");
    assert.equal(i.width, 4000);
    assert.equal(i.height, 3000);
    assert.equal(i.camera, "Canon EOS R6");
    assert.equal(new Date(i.when).getFullYear(), 2024);
    assert.equal(C.imageInfo("800 600\n\nApple\niPhone 13\n").camera, "Apple iPhone 13");
    assert.deepEqual(plain(C.imageInfo("")), { "width": 0, "height": 0, "when": 0, "camera": "" });
    const a = C.audioInfo("duration=245.7\nTAG:title=Song\nTAG:artist=Band\nTAG:album=LP\n");
    assert.equal(a.seconds, 246);
    assert.equal(a.length, "4:06");
    assert.equal(a.title, "Song");
    assert.equal(a.artist, "Band");
    assert.equal(a.album, "LP");
    assert.equal(C.clock(3725), "1:02:05");
    assert.equal(C.audioInfo("").length, "0:00");
});

test("the quick look tells in a word what it cannot show: an empty or binary text, a picture too big to decode", () => {
    assert.equal(C.textWord(""), "empty");
    assert.equal(C.textWord("abc\u0000def"), "binary");
    assert.equal(C.textWord("���ab"), "binary");
    assert.equal(C.textWord("Café 😀 déjà vu\n"), "");
    assert.equal(C.textWord("x".repeat(100) + "�"), "");
    // A 16-bit PNG of 8000 × 6000 is over Qt's 256 MB decode limit; a 4000 × 3000 photo is not.
    assert.equal(C.tooBig(8000, 6000), true);
    assert.equal(C.tooBig(4000, 3000), false);
    assert.equal(C.tooBig(0, 0), false);
    // A video's tags: its first picture stream's size beside the length.
    const v = C.audioInfo("width=640\nheight=360\nduration=3.04\n");
    assert.equal(v.width, 640);
    assert.equal(v.height, 360);
    assert.equal(v.length, "0:03");
    assert.equal(C.audioInfo("duration=1\n").width, 0);
});

test("the wheel zooms a picture by a quarter a notch, a touchpad by its share of a notch, from 1 to 8", () => {
    assert.equal(C.zoomBy(1, 120), 1.25);
    assert.equal(C.zoomBy(1.25, -120), 1);
    assert.equal(C.zoomBy(1, -120), 1);
    assert.equal(C.zoomBy(7, 360), 8);
    assert.ok(Math.abs(C.zoomBy(1, 12) - Math.pow(1.25, 0.1)) < 1e-9);
    assert.equal(C.zoomBy(2, 0), 2);
});

test("a Markdown link takes the theme's colour (Qt draws it pure blue), code and pictures untouched", () => {
    const c = "#ffb4a8";
    assert.equal(C.markdownLinks("a [link](https://example.org) b", c), "a <font color=\"#ffb4a8\">link</font> b");
    assert.equal(C.markdownLinks("see <https://x.org>.", c), "see <font color=\"#ffb4a8\">https://x.org</font>.");
    assert.equal(C.markdownLinks("![logo](a.png) `[x](y)`", c), "![logo](a.png) `[x](y)`");
    assert.equal(C.markdownLinks("```\n[x](y)\n```\n[z](w)", c), "```\n[x](y)\n```\n<font color=\"#ffb4a8\">z</font>");
    assert.equal(C.markdownLinks("", c), "");
});

test("code is coloured by its language's family, escaped, and cut past the cap", () => {
    const colors = { "comment": "#c", "string": "#s", "number": "#n", "keyword": "#k" };
    const js = C.highlight("const a = \"x<y\"; // hi\nreturn 42;", "js", colors);
    assert.ok(js.startsWith("<pre>"));
    assert.ok(js.indexOf("<font color=\"#k\">const</font>") !== -1);
    assert.ok(js.indexOf("<font color=\"#s\">\"x&lt;y\"</font>") !== -1);
    assert.ok(js.indexOf("<font color=\"#c\">// hi</font>") !== -1);
    assert.ok(js.indexOf("<font color=\"#n\">42</font>") !== -1);
    const py = C.highlight("def f(): # c\n  return None", "py", colors);
    assert.ok(py.indexOf("<font color=\"#k\">def</font>") !== -1);
    assert.ok(py.indexOf("<font color=\"#c\"># c</font>") !== -1);
    // A comment never counts as a string: the quote inside it stays grey.
    assert.ok(C.highlight("# it's\n", "sh", colors).indexOf("<font color=\"#c\"># it's</font>") !== -1);
    assert.equal(C.highlight("a < b", "unknown", colors), "<pre>a &lt; b</pre>");
    assert.ok(C.highlight("x".repeat(200001), "txt", colors).endsWith("\n…</pre>"));
});
