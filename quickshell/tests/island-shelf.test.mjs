import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandShelf.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const plain = v => JSON.parse(JSON.stringify(v));

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
    assert.deepEqual(plain(C.facts("12 81a4 /a\n0 41ed /c d\n").paths), ["/a", "/c d"]);
    assert.deepEqual(plain(C.keep(["/a", "/b", "/c d"], C.facts("12 81a4 /a\n0 41ed /c d\n").paths)), ["/a", "/c d"]);
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
    const f = C.facts("1258291 81a4 /a/b c.png\n4096 41ed /a/Photos\nbad line\n");
    assert.deepEqual(plain(f.dirs), ["/a/Photos"]);
    assert.equal(f.size["/a/b c.png"], 1258291);
    assert.deepEqual(plain(C.facts("1258291 81a4 /a/b c.png\nbad line\n").paths), ["/a/b c.png"]);
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
    assert.deepEqual(plain(C.plan("image", every)), { "buttons": ["copyImage", "annotate", "phone", "wallpaper"], "more": ["open", "ocr", "toPng", "toJpg", "toWebp", "shrinkImage", "rotate"] });
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
