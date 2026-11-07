import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const disk = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/DiskUsage.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), disk);
vm.runInContext(readFileSync(new URL("../Common/DiskChart.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), disk);
const D = disk;

// du -0ab prints each file, then its dir once the dir is done (post-order).
function scan(records) {
    const root = D.node("~", null);
    for (const r of records)
        D.add(root, "/demo", r);
    return root;
}

test("du records build the tree and sizes climb to the root", () => {
    const root = scan(["100\t/demo/a/x", "50\t/demo/a/y", "4096\t/demo/a", "30\t/demo/b", "4246\t/demo"]);
    assert.equal(root.size, 180);
    assert.equal(root.files, 3);
    assert.equal(root.index.a.size, 150);
    assert.equal(root.index.a.children.length, 2);
    assert.equal(root.index.b.children, null);
});

test("a record counted twice, a foreign path or a bad line adds nothing", () => {
    const root = scan(["10\t/demo/a", "10\t/demo/a", "5\t/other/z", "garbage", "x\t/demo/q"]);
    assert.equal(root.size, 10);
});

test("crumbs are grouped, never a group of one", () => {
    const root = scan(["1000\t/demo/big", "5\t/demo/s1", "5\t/demo/s2", "500\t/demo/mid"]);
    const k = D.kids(root, 0.05);
    assert.deepEqual([...k.map(c => c.name)], ["big", "mid", "+2"]);
    assert.equal(k[2].size, 10);
    const one = D.kids(scan(["1000\t/demo/big", "5\t/demo/s1"]), 0.05);
    assert.deepEqual([...one.map(c => c.name)], ["big", "s1"]);
});

test("the treemap tiles its box by area", () => {
    const root = scan(["600\t/demo/a/1", "200\t/demo/a/2", "300\t/demo/b", "100\t/demo/c"]);
    const out = D.layoutTree(root, 0, 0, 200, 100, 0, 0, []);
    const top = out.filter(it => it.depth === 0);
    const area = top.reduce((s, it) => s + it.w * it.h, 0);
    assert.ok(Math.abs(area - 20000) < 1e-6);
    const a = top.find(it => it.node.name === "a");
    assert.ok(Math.abs(a.w * a.h - 20000 * 800 / 1200) < 1e-6);
    assert.deepEqual([...top.map(it => it.col)], [0, 1, 2]);
    assert.ok(out.some(it => it.depth === 1 && it.col === 0));
});

test("rings cover the full turn on the first level", () => {
    const root = scan(["600\t/demo/a/1", "200\t/demo/a/2", "300\t/demo/b", "100\t/demo/c"]);
    const out = D.layoutSun(root, 0, Math.PI * 2, 1, 4, 0, []);
    const first = out.filter(it => it.depth === 1);
    assert.ok(Math.abs(first[first.length - 1].a1 - Math.PI * 2) < 1e-9);
    assert.ok(out.some(it => it.depth === 2));
});

test("sizes read like df -H", () => {
    assert.equal(D.fmt(25.9e9), "25.9 GB");
    assert.equal(D.fmt(640e6), "640 MB");
    assert.equal(D.fmt(5.2e6), "5.2 MB");
    assert.equal(D.fmt(512), "512 B");
});

test("the fullest mount under the threshold raises the bubble, the header and roomy mounts do not", () => {
    const df = "1B-blocks Avail Mounted on\n500000000000 200000000000 /\n500000000000 200000000000 /\n";
    assert.equal(D.lowMount(df, 0.1), null);
    const low = D.lowMount("1B-blocks Avail Mounted on\n100 9 /\n1000 50 /mnt/big disk\n", 0.1);
    assert.equal(low.path, "/mnt/big disk");
    assert.equal(low.avail, 50);
    assert.equal(D.lowMount("100 5 /\n100 5 /srv\n", 0.1).path, "/srv");
    assert.equal(D.lowMount("", 0.1), null);
    assert.equal(D.lowMount("0 0 /\n", 0.1), null);
});

test("the liquid turns to the alert as the disk fills: none with twice the threshold free, all at the threshold", () => {
    assert.equal(D.alertShare(0.5, 0.1), 0);
    assert.equal(D.alertShare(0.2, 0.1), 0);
    assert.equal(D.alertShare(0.1, 0.1), 1);
    assert.equal(D.alertShare(0.02, 0.1), 1);
    assert.ok(Math.abs(D.alertShare(0.15, 0.1) - 0.5) < 1e-9);
    assert.ok(D.alertShare(0.12, 0.1) > D.alertShare(0.18, 0.1));
    assert.equal(D.alertShare(0.3, 0), 0);
});

test("a scan of / keeps to its own file system: entries on another device are left out", () => {
    const records = ["2049 /", "2049 /usr", "4 /proc", "2049 /var", "23 /sys", "2050 /mnt/data"];
    assert.deepEqual(Array.from(D.sameDevice(records)), ["/usr", "/var"]);
    assert.deepEqual(Array.from(D.sameDevice(["2049 /srv/a b", "2049 /srv/a b/c d"])), ["/srv/a b/c d"]);
    assert.deepEqual(Array.from(D.sameDevice([])), []);
});

test("the card's list rows: old downloads biggest first with their node, else the folder's largest files", () => {
    const root = scan(["600\t/demo/a/1", "200\t/demo/a/2", "300\t/demo/b", "4096\t/demo/a"]);
    const old = [{ "path": "/demo/b", "size": 300 }, { "path": "/demo/a", "size": 800 }, { "path": "/elsewhere/z", "size": 5 }];
    const rows = D.oldRows(old, root, "/demo");
    assert.deepEqual([...rows.map(r => r.name)], ["a", "b", "z"]);
    assert.equal(rows[0].dir, true);
    assert.equal(rows[1].node, root.index.b);
    assert.equal(rows[2].node, null);
    const big = D.largestRows(root, "/demo", 2);
    assert.deepEqual([...big.map(r => r.path)], ["/demo/a/1", "/demo/b"]);
    assert.equal(big[0].dir, false);
});

test("the card's arrows: the ring skips grouped crumbs and stops at its ends, the list stays on its rows", () => {
    const a = { "name": "a" };
    const b = { "name": "b" };
    const items = [{ "depth": 1, "node": a }, { "depth": 2, "node": {} }, { "depth": 1, "node": { "other": true } }, { "depth": 1, "node": b }];
    assert.equal(D.ringStep(items, a, 1), b);
    assert.equal(D.ringStep(items, b, 1), b);
    assert.equal(D.ringStep(items, null, -1), a);
    assert.equal(D.ringStep([], a, 1), null);
    assert.equal(D.listStep(3, 2, 1), 2);
    assert.equal(D.listStep(3, -1, 1), 0);
    assert.equal(D.listStep(0, -1, 1), 0);
});

test("branch colors turn from the base hue, greyer and darker deeper; crumbs have none", () => {
    assert.equal(D.branchHsl(-1, 0, 0.72, 0.5), null);
    const top = D.branchHsl(1, 0, 0.72, 0.5);
    assert.ok(Math.abs(top.h - 0.63) < 1e-9);
    assert.equal(top.s, 0.78);
    const deep = D.branchHsl(0, 6, 0.72, -1);
    assert.equal(deep.h, 0.72);
    assert.equal(deep.s, 0.45);
    assert.ok(Math.abs(deep.l - 0.42) < 1e-9);
});

test("a name is cut with an ellipsis to its room, nothing under 12 px", () => {
    const w = s => s.length * 10;
    assert.equal(D.fitText(w, "abc", 30), "abc");
    assert.equal(D.fitText(w, "abcdef", 40), "abc…");
    assert.equal(D.fitText(w, "abcdef", 11), "");
    assert.equal(D.fitText(w, "abcdef", 15), "");
});

test("a cell eases toward its place from where it was born, moving while still far", () => {
    const shown = {};
    const grow = t => ({ "x": 0 });
    const first = D.easeTo(shown, "n", { "x": 100 }, ["x"], 0.5, 0.25, grow);
    assert.equal(first.shown.x, 50);
    assert.equal(first.moved, true);
    assert.equal(shown.n, first.shown);
    const last = D.easeTo(shown, "n", { "x": 50.1 }, ["x"], 1, 0.25, grow);
    assert.equal(last.shown.x, 50.1);
    assert.equal(last.moved, false);
});
