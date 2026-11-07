import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const load = f => {
    const c = vm.createContext({});
    vm.runInContext(readFileSync(new URL("../Common/" + f, import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), c);
    return c;
};
const D = load("DiskUsage.js");
vm.runInContext(readFileSync(new URL("../Common/DiskChart.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), D);
const K = load("DiskCleanup.js");
const plain = v => JSON.parse(JSON.stringify(v));

function scan(base, records) {
    const root = D.node("~", null);
    for (const r of records)
        D.add(root, base, r);
    return root;
}
const home = () => scan("/users/me", ["600\t/users/me/Videos/a.mkv", "200\t/users/me/Videos/b.mkv", "300\t/users/me/Dev/x", "100\t/users/me/notes.txt"]);

test("a node's path is the scanned folder joined with its place, / included", () => {
    const t = home();
    assert.equal(D.pathOf(t, "/users/me"), "/users/me");
    assert.equal(D.pathOf(t.index.Videos.index["a.mkv"], "/users/me"), "/users/me/Videos/a.mkv");
    const r = scan("/", ["5\t/etc/x"]);
    assert.equal(D.pathOf(r.index.etc.index.x, "/"), "/etc/x");
    assert.equal(D.pathOf(r, "/"), "/");
    // A grouped crumb is not a place on disk.
    assert.equal(D.pathOf({ "id": "~/Videos/…", "other": true }, "/users/me"), "");
});

test("find walks a path back to its node, crumbs climb to the root", () => {
    const t = home();
    assert.equal(D.find(t, "/users/me", "/users/me/Videos/b.mkv"), t.index.Videos.index["b.mkv"]);
    assert.equal(D.find(t, "/users/me", "/users/me"), t);
    assert.equal(D.find(t, "/users/me", "/users/me/nope"), null);
    assert.equal(D.find(t, "/users/me", "/users/other/Videos"), null);
    assert.deepEqual([...D.crumbs(t.index.Videos.index["a.mkv"]).map(n => n.name)], ["~", "Videos", "a.mkv"]);
});

test("the pointer hits the deepest cell under it", () => {
    const items = [{ "node": "A", "x": 0, "y": 0, "w": 100, "h": 100, "depth": 0 }, { "node": "A1", "x": 10, "y": 20, "w": 30, "h": 30, "depth": 1 }, { "node": "B", "x": 100, "y": 0, "w": 50, "h": 100, "depth": 0 }];
    assert.equal(D.hit(items, 15, 25).node, "A1");
    assert.equal(D.hit(items, 80, 80).node, "A");
    assert.equal(D.hit(items, 120, 10).node, "B");
    assert.equal(D.hit(items, 300, 10), null);
});

test("a point on the rings finds its arc by ring and angle, the hub none", () => {
    const items = [{ "node": "A", "a0": 0, "a1": 3, "depth": 1 }, { "node": "A1", "a0": 0, "a1": 1, "depth": 2 }, { "node": "B", "a0": 3, "a1": 2 * Math.PI, "depth": 1 }];
    // Center 100,100, hub radius 20, rings 10 wide; angle 0 points up, clockwise.
    const at = (r, a) => D.hitRing(items, 100, 100, 20, 10, 100 + r * Math.sin(a), 100 - r * Math.cos(a));
    assert.equal(at(25, 0.5).node, "A");
    assert.equal(at(35, 0.5).node, "A1");
    assert.equal(at(35, 2), null);
    assert.equal(at(25, 4).node, "B");
    assert.equal(at(10, 1), null);
});

test("arrows step to the nearest cell of the shown folder that way, and stay at the edge", () => {
    // [A][B]
    // [C][D]   plus a nested cell, never a target.
    const cell = (node, x, y, depth) => ({ node, x, y, "w": 50, "h": 50, "depth": depth || 0 });
    const items = [cell("A", 0, 0), cell("A1", 5, 5, 1), cell("B", 50, 0), cell("C", 0, 50), cell("D", 50, 50)];
    assert.equal(D.step(items, null, 1, 0), "A");
    assert.equal(D.step(items, "A", 1, 0), "B");
    assert.equal(D.step(items, "A", 0, 1), "C");
    assert.equal(D.step(items, "D", -1, 0), "C");
    assert.equal(D.step(items, "D", 0, -1), "B");
    assert.equal(D.step(items, "B", 1, 0), "B");
    assert.equal(D.step(items, "A1", 1, 0), "A");
    assert.equal(D.step([], null, 1, 0), null);
});

test("the list shows the biggest files under the folder, biggest first, capped", () => {
    const t = home();
    assert.deepEqual([...D.largest(t, 2).map(n => n.name)], ["a.mkv", "x"]);
    assert.deepEqual([...D.largest(t.index.Videos, 10).map(n => n.name)], ["a.mkv", "b.mkv"]);
    assert.equal(D.largest(D.node("~", null), 5).length, 0);
});

test("a trashed node leaves the tree with its size, Undo puts it back", () => {
    const t = home();
    const v = t.index.Videos;
    const a = v.index["a.mkv"];
    D.detach(a);
    assert.equal(v.size, 200);
    assert.equal(t.size, 600);
    assert.equal(t.files, 3);
    assert.equal(D.find(t, "/users/me", "/users/me/Videos/a.mkv"), null);
    D.detach(a);
    assert.equal(t.size, 600);
    D.attach(a);
    assert.equal(v.size, 800);
    assert.equal(t.size, 1200);
    assert.equal(t.files, 4);
    assert.equal(D.find(t, "/users/me", "/users/me/Videos/a.mkv"), a);
});

test("only a place inside home can go to the trash, never home itself, the trash or an escape", () => {
    assert.equal(K.canTrash("/users/me/Videos/a.mkv", "/users/me"), true);
    assert.equal(K.canTrash("/users/me", "/users/me"), false);
    assert.equal(K.canTrash("/users/me/", "/users/me"), false);
    assert.equal(K.canTrash("/users/other/x", "/users/me"), false);
    assert.equal(K.canTrash("/users/me/../v/x", "/users/me"), false);
    assert.equal(K.canTrash("/etc/passwd", "/users/me"), false);
    assert.equal(K.canTrash("/users/me/.local/share/Trash/files/x", "/users/me"), false);
    assert.equal(K.canTrash("/users/me/.local/share/Trash", "/users/me"), false);
    assert.equal(K.canTrash("", "/users/me"), false);
    assert.equal(K.canTrash("/x", ""), false);
});

test("safe caches all sit in the home cache folder", () => {
    const c = K.safeCaches("/users/me");
    assert.ok(c.length >= 3);
    for (const p of c)
        assert.ok(p.startsWith("/users/me/.cache/") && K.canTrash(p, "/users/me"), p);
});

test("du summaries read as sizes by path, NUL or newline separated", () => {
    assert.deepEqual(plain(K.sizes("12\t/users/me/a\u000034\t/users/me/b c\n\nbad\n")), [{ "path": "/users/me/a", "size": 12 }, { "path": "/users/me/b c", "size": 34 }]);
    assert.deepEqual(plain(K.sizes("")), []);
});

test("flatpak sizes read like GLib prints them", () => {
    assert.equal(K.bytes("670.7 MB"), 670.7e6);
    assert.equal(K.bytes("1.7 GB"), 1.7e9);
    assert.equal(K.bytes("163.8 kB"), 163800);
    assert.equal(K.bytes("512 bytes"), 512);
    assert.equal(K.bytes("1.2GB"), 1.2e9);
    assert.equal(K.bytes("?"), 0);
});

test("a base runtime no app uses is unused, with its extensions of that branch; used ones and others stay", () => {
    const runtimes = ["org.freedesktop.Platform\t25.08\tsystem\t670.7 MB", "org.freedesktop.Platform\t24.08\tuser\t600 MB", "org.freedesktop.Platform.GL.default\t24.08\tuser\t400 MB", "org.freedesktop.Platform.GL.default\t24.08-extra\tuser\t100 MB", "org.freedesktop.Platform.GL.default\t25.08\tsystem\t462.3 MB", "org.freedesktop.Platform.GL.nvidia-1-2\t1.4\tsystem\t957.7 MB", "org.freedesktop.Sdk\t24.08\tuser\t1.7 GB"].join("\n");
    const apps = "io.example.App\torg.freedesktop.Platform/x86_64/25.08\n";
    const u = K.flatpakUnused(runtimes, apps);
    assert.deepEqual([...u.refs], ["org.freedesktop.Platform//24.08", "org.freedesktop.Platform.GL.default//24.08", "org.freedesktop.Platform.GL.default//24.08-extra"]);
    assert.equal(u.size, 1100e6);
    assert.equal(K.flatpakUnused("", "").size, 0);
});

test("dangling images add up from podman's JSON or docker's lines", () => {
    const pod = JSON.stringify([{ "Size": 2705917958, "Dangling": true }, { "Size": 100, "Dangling": true }]);
    assert.deepEqual(plain(K.images(pod)), { "count": 2, "size": 2705918058 });
    assert.deepEqual(plain(K.images("{\"Size\":\"1.2GB\"}\n{\"Size\":\"300MB\"}\n")), { "count": 2, "size": 1.5e9 });
    assert.deepEqual(plain(K.images("not json")), { "count": 0, "size": 0 });
});

test("the trashed item is the newest entry from its place", () => {
    const list = JSON.stringify([{ "name": "a.mkv", "originalPath": "/users/me/a.mkv", "deletionDate": "2026-10-01T10:00:00", "trashDir": "/users/me/.local/share/Trash" }, { "name": "a.2.mkv", "originalPath": "/users/me/a.mkv", "deletionDate": "2026-10-25T10:00:00", "trashDir": "/users/me/.local/share/Trash" }, { "name": "b", "originalPath": "/users/me/b", "deletionDate": "2026-10-26T10:00:00", "trashDir": "/t" }]);
    assert.deepEqual(plain(K.trashed(list, "/users/me/a.mkv")), { "name": "a.2.mkv", "dir": "/users/me/.local/share/Trash" });
    assert.equal(K.trashed(list, "/users/me/zzz"), null);
    assert.equal(K.trashed("oops", "/users/me/a.mkv"), null);
});

test("the cleanup rows add up what can be freed", () => {
    const f = { "trash": 3e9, "caches": [{ "path": "/users/me/.cache/pip", "size": 1e9 }], "old": [{ "path": "/users/me/Downloads/x.iso", "size": 4e9 }], "flatpak": { "refs": ["r"], "size": 2e9 }, "images": { "count": 1, "size": 5e8 } };
    const rows = K.rows(f);
    assert.deepEqual([...rows.map(r => r.id)], ["trash", "old", "caches", "packages"]);
    assert.deepEqual([...rows.map(r => r.size)], [3e9, 4e9, 1e9, 2.5e9]);
    assert.equal(K.total(rows), 10.5e9);
    assert.equal(K.total(K.rows({})), 0);
});
