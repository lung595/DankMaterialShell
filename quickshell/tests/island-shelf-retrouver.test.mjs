import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandShelf.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);

test("the search takes printable letters only; Backspace on the tiles takes its last letter back", () => {
    assert.equal(C.printable("r"), true);
    assert.equal(C.printable("é"), true);
    assert.equal(C.printable("\b"), false);
    assert.equal(C.printable("\u007f"), false);
    assert.equal(C.printable(" "), false);
    assert.equal(C.printable(""), false);
    assert.equal(C.typed("rap", "\b"), "ra");
    assert.equal(C.typed("", "\b"), "");
    assert.equal(C.typed("ra", "p"), "rap");
    assert.equal(C.typed("ra", "\u0001"), "ra");
    assert.equal(C.cleanQuery("ra\bp\n"), "rap");
    assert.equal(C.cleanQuery(undefined), "");
});

test("the keyboard's row: the first result while searching, the chosen file at its place once the search is cleared", () => {
    const all = ["photo-01", "photo-02", "rapport-03", "note-04"];
    const found = ["rapport-03", "rapport-07"];
    // Typing: the first result, whatever row the keyboard stood on before.
    assert.equal(C.rowAfterSearch("rap", undefined, "photo-02", found), 0);
    // Typing with a file chosen that still shows: the ring stays on it.
    assert.equal(C.rowAfterSearch("rap", "rapport-07", "rapport-03", found), 1);
    // Escape: the chosen file, else the ring's, at its place in the whole list.
    assert.equal(C.rowAfterSearch("", "rapport-03", "rapport-03", all), 2);
    assert.equal(C.rowAfterSearch("", undefined, "rapport-03", all), 2);
    assert.equal(C.rowAfterSearch("", undefined, "gone", all), 0);
    assert.equal(C.rowAfterSearch("", undefined, undefined, all), 0);
});

test("a row slides a page of whole tiles per wheel notch, and under the finger on a touchpad", () => {
    // 7 tiles of pitch 100 in a view of 730: a page is 700.
    assert.equal(C.rowSlide(0, 3000, 730, 100, 0, -120), 700);
    assert.equal(C.rowSlide(700, 3000, 730, 100, 0, 120), 0);
    assert.equal(C.rowSlide(0, 3000, 730, 100, 0, -60), 350);
    assert.equal(C.rowSlide(2900, 3000, 730, 100, 0, -120), 3000);
    assert.equal(C.rowSlide(0, 3000, 730, 100, -1, -15), 1);
    assert.equal(C.rowSlide(10, 3000, 730, 100, 3, 0), 7);
    // A view narrower than a tile still turns a tile.
    assert.equal(C.rowSlide(0, 3000, 50, 100, 0, -120), 100);
    // A row of 40 tiles is gone through in a few notches.
    let o = 0;
    let n = 0;
    while (o < 3270) {
        o = C.rowSlide(o, 3270, 730, 100, 0, -120);
        n++;
    }
    assert.ok(n <= 5);
});

test("a tile brought in view keeps a tile of margin before the faded edge, the row moving the least", () => {
    // Tile 23 (x 2300, width 92) in a view of 730: its right side and a pitch fit in.
    assert.equal(C.slideTo(0, 3270, 730, 2300, 92, 100), 2300 + 92 + 100 - 730);
    // Already in the clear: no move.
    assert.equal(C.slideTo(0, 3270, 730, 300, 92, 100), 0);
    // Going back left: a tile of margin on that side too, never before the row's start.
    assert.equal(C.slideTo(2000, 3270, 730, 1500, 92, 100), 1400);
    assert.equal(C.slideTo(500, 3270, 730, 0, 92, 100), 0);
    assert.equal(C.slideTo(0, 3270, 730, 3900, 92, 100), 3270);
});

test("the shelf's count says files, folders, or items when both", () => {
    assert.equal(C.countKind(["/a.png", "/b.pdf"], ["/x"]), "files");
    assert.equal(C.countKind(["/x", "/y"], ["/x", "/y"]), "folders");
    assert.equal(C.countKind(["/x", "/b.pdf"], ["/x"]), "items");
    assert.equal(C.countKind([], []), "files");
    assert.equal(C.countKind(["/a"], undefined), "files");
});

test("two tiles of one name each say their parent folder", () => {
    const list = ["/data/ISO/LIN1", "/data/Kept/LIN1", "/data/a.png", "group:7"];
    const gs = { "7": { "name": "LIN1", "items": [] } };
    assert.equal(C.tileName("/data/ISO/LIN1", list, gs), "LIN1 · ISO");
    assert.equal(C.tileName("/data/Kept/LIN1", list, gs), "LIN1 · Kept");
    assert.equal(C.tileName("/data/a.png", list, gs), "a.png");
    assert.equal(C.tileName("group:7", list, gs), "LIN1");
    assert.equal(C.tileName("/LIN1", ["/LIN1", "/x/LIN1"], {}), "LIN1 · /");
});
