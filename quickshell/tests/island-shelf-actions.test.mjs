import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandShelf.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);
const plain = v => JSON.parse(JSON.stringify(v));

test("choosing: a click, Ctrl or Shift click, a long press swept down, all, the arrows", () => {
    const list = ["/a", "/b", "/c", "/d"];
    let s = C.pick({ "sel": [], "anchor": 0 }, list, 1, false, false);
    assert.deepEqual(plain(s), { "sel": ["/b"], "anchor": 1 });
    // The same click again lets it go; another one takes its place.
    assert.deepEqual(plain(C.pick(s, list, 1, false, false).sel), []);
    assert.deepEqual(plain(C.pick(s, list, 2, false, false).sel), ["/c"]);
    s = C.pick(s, list, 3, true, false);
    assert.deepEqual(plain(s.sel), ["/b", "/d"]);
    assert.deepEqual(plain(C.pick(s, list, 1, true, false).sel), ["/d"]);
    // Shift: from the anchor to here; with Ctrl it adds to what was chosen.
    assert.deepEqual(plain(C.pick({ "sel": ["/a"], "anchor": 1 }, list, 3, false, true).sel), ["/b", "/c", "/d"]);
    assert.deepEqual(plain(C.pick({ "sel": ["/a"], "anchor": 1 }, list, 2, true, true).sel), ["/a", "/b", "/c"]);
    // Long press on /b then down to /d (and back up to /c): what was chosen before stays.
    assert.deepEqual(plain(C.sweep(["/a"], list, 1, 3)), ["/a", "/b", "/c", "/d"]);
    assert.deepEqual(plain(C.sweep([], list, 1, 2)), ["/b", "/c"]);
    assert.deepEqual(plain(C.sweep([], list, 2, 0)), ["/a", "/b", "/c"]);
    assert.equal(C.step(0, -1, 4), 0);
    assert.equal(C.step(2, 1, 4), 3);
    assert.equal(C.step(3, 1, 4), 3);
    assert.equal(C.step(0, 1, 0), 0);
});

test("an action's command: the helper script for files, the app for what opens a window", () => {
    const t = ["zip", "tesseract", "magick", "satty", "kdeconnect-cli", "mediawriter", "gnome-disks", "code", "gnome-text-editor", "file-roller"];
    assert.deepEqual(plain(C.command("toWebp", ["/d/a b.png"], t, "/s.sh")), { "run": ["sh", "/s.sh", "convert", "webp", "--", "/d/a b.png"], "out": "paths" });
    assert.deepEqual(plain(C.command("zip", ["/d/a", "/e/b"], t, "/s.sh")), { "run": ["sh", "/s.sh", "zip", "--", "/d/a", "/e/b"], "out": "paths" });
    assert.deepEqual(plain(C.command("ocr", ["/d/a.png"], t, "/s.sh")), { "run": ["sh", "/s.sh", "ocr", "--", "/d/a.png"], "out": "copy" });
    assert.deepEqual(plain(C.command("verify", ["/d/f.iso"], t, "/s.sh")), { "run": ["sh", "/s.sh", "verify", "--", "/d/f.iso"], "out": "notice" });
    assert.deepEqual(plain(C.command("annotate", ["/d/a.png"], t, "/s.sh")), { "detach": ["satty", "--filename", "/d/a.png"] });
    // The USB stick is never written by the shelf: the installed writing app opens with the image, it asks first.
    assert.deepEqual(plain(C.command("writeUsb", ["/d/f.iso"], t, "/s.sh")), { "detach": ["mediawriter", "/d/f.iso"] });
    assert.deepEqual(plain(C.command("writeUsb", ["/d/f.iso"], ["gnome-disks"], "/s.sh")), { "detach": ["gnome-disks", "--restore-disk-image=/d/f.iso"] });
    assert.deepEqual(plain(C.command("editor", ["/d/n.md"], t, "/s.sh")), { "detach": ["code", "/d/n.md"] });
    assert.deepEqual(plain(C.command("moveTo", ["/d/a"], t, "/s.sh", "/dest")), { "run": ["sh", "/s.sh", "move", "/dest", "--", "/d/a"], "out": "moved" });
    // Done in the shell itself (clipboard, wallpaper, picker), not by a command.
    assert.equal(C.command("copyFiles", ["/d/a"], t, "/s.sh"), null);
    assert.equal(C.command("annotate", ["/d/a.png"], [], "/s.sh"), null);
});

test("several chosen files can always be copied first (the v3 table), the single kinds keep their order", () => {
    const every = C.tools.slice();
    for (const k of ["images", "pdfs", "mixed"])
        assert.equal(C.plan(k, every).buttons[0], "copyFiles", k);
    assert.deepEqual(plain(C.plan("text", every).buttons), ["open", "copyContent", "copyPaths", "show"]);
    assert.deepEqual(plain(C.plan("images", every).buttons), ["copyFiles", "pdfFromImages", "shrinkImage", "phone"]);
});

test("each action's shortcut shows on one button only, and the key runs that button (else its default)", () => {
    const doc = C.plan("doc", C.tools.slice());
    assert.deepEqual(plain(C.keysOf(doc)), { "open": "enter", "copyText": "copy" });
    assert.equal(C.shortcut(doc, "copy"), "copyText");
    assert.equal(C.shortcut(doc, "enter"), "open");
    const iso = C.plan("iso", []);
    assert.deepEqual(plain(C.keysOf(iso)), { "open": "enter" });
    // No button shows Ctrl+C: it copies the files.
    assert.equal(C.shortcut(iso, "copy"), "copyFiles");
    assert.equal(C.shortcut(iso, "enter"), "open");
    assert.deepEqual(plain(C.keysOf(C.plan("image", C.tools.slice()))), { "copyImage": "copy" });
});

test("Enter opens in the default app whatever the type or the tools: Listen here and View archive stay buttons", () => {
    const every = C.tools.slice();
    for (const k of ["audio", "archive", "image", "iso", "video", "folder"]) {
        assert.equal(C.shortcut(C.plan(k, every), "enter"), "open", k);
        assert.equal(C.shortcut(C.plan(k, []), "enter"), "open", k);
    }
    assert.equal(plain(C.keysOf(C.plan("audio", every))).listen, undefined);
    assert.equal(plain(C.keysOf(C.plan("archive", every))).viewArchive, undefined);
});

test("no conversion to the format the files already have", () => {
    const every = C.tools.slice();
    assert.equal(C.plan("audio", every, ["/m/song.mp3"]).buttons.indexOf("mp3"), -1);
    assert.notEqual(C.plan("audio", every, ["/m/song.flac"]).buttons.indexOf("mp3"), -1);
    assert.notEqual(C.plan("audio", every).buttons.indexOf("mp3"), -1);
    const png = C.plan("image", every, ["/p/a.PNG"]);
    assert.equal(png.buttons.concat(png.more).indexOf("toPng"), -1);
    assert.notEqual(png.more.indexOf("toJpg"), -1);
    const jpgs = C.plan("images", every, ["/p/a.jpg", "/p/b.jpeg"]);
    assert.equal(jpgs.buttons.concat(jpgs.more).indexOf("toJpg"), -1);
    // A mix keeps it: some files are not in that format yet.
    const mix = C.plan("images", every, ["/p/a.jpg", "/p/b.png"]);
    assert.notEqual(mix.buttons.concat(mix.more).indexOf("toJpg"), -1);
});

test("a plain click on the only chosen tile waits out a double-click before letting it go", () => {
    assert.equal(C.letsGo(["/a"], "/a", false, false), true);
    assert.equal(C.letsGo(["/a"], "/b", false, false), false);
    assert.equal(C.letsGo(["/a", "/b"], "/a", false, false), false);
    assert.equal(C.letsGo(["/a"], "/a", true, false), false);
    assert.equal(C.letsGo(["/a"], "/a", false, true), false);
    assert.equal(C.letsGo([], "/a", false, false), false);
});

test("Listen here fails on an error code, or when ffplay finds no sound device yet exits 0", () => {
    assert.equal(C.playerFailed(0, ""), false);
    assert.equal(C.playerFailed(1, ""), true);
    assert.equal(C.playerFailed(0, "SDL_OpenAudio (2 channels, 44100 Hz): No available audio device\nNo more combinations to try, audio open failed\n"), true);
    assert.equal(C.playerFailed(0, undefined), false);
});

test("Move to…: the shelf follows the files, Ctrl+Z moves them back; a read-only folder or a folder into itself is refused first", () => {
    const moves = C.moves("/d/a.txt\t/t/a.txt\n/d/b\t/t/b (2)\n");
    assert.deepEqual(plain(moves), [["/d/a.txt", "/t/a.txt"], ["/d/b", "/t/b (2)"]]);
    const s = C.relink(["/d/a.txt", "/x", "group:g"], { "g": { "name": "G", "items": ["/d/b"] } }, moves);
    assert.deepEqual(plain(s), { "items": ["/t/a.txt", "/x", "group:g"], "groups": { "g": { "name": "G", "items": ["/t/b (2)"] } } });
    // The script itself, in a scratch folder.
    const script = new URL("../scripts/island-shelf.sh", import.meta.url).pathname;
    const d = mkdtempSync(join(tmpdir(), "shelf-move-"));
    try {
        const run = (...args) => spawnSync("sh", [script, ...args], { "encoding": "utf8" });
        mkdirSync(join(d, "Cible/Sous"), { "recursive": true });
        mkdirSync(join(d, "Lecture"));
        writeFileSync(join(d, "notes.md"), "n");
        chmodSync(join(d, "Lecture"), 0o555);
        assert.equal(run("move", join(d, "Lecture"), "--", join(d, "notes.md")).status, 7);
        assert.equal(run("move", join(d, "Cible/Sous"), "--", join(d, "notes.md"), join(d, "Cible")).status, 6);
        assert.ok(existsSync(join(d, "notes.md")), "nothing moved before a refusal");
        const ok = run("move", join(d, "Cible"), "--", join(d, "notes.md"));
        assert.equal(ok.status, 0);
        const back = run("unmove", "--", ...C.moves(ok.stdout).reduce((a, p) => a.concat([p[1], p[0]]), []));
        assert.equal(back.status, 0);
        assert.ok(existsSync(join(d, "notes.md")) && !existsSync(join(d, "Cible/notes.md")));
    } finally {
        chmodSync(join(d, "Lecture"), 0o755);
        rmSync(d, { "recursive": true, "force": true });
    }
});
