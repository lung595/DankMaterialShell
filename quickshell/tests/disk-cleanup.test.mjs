import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const C = loadScript(new URL("../Common/DiskCleanup.js", import.meta.url));

test("only a path inside home goes to the trash, never home, the trash or a dot segment", () => {
    assert.equal(C.canTrash("/h/Videos/old.mkv", "/h"), true);
    assert.equal(C.canTrash("/h", "/h"), false);
    assert.equal(C.canTrash("/h/", "/h"), false);
    assert.equal(C.canTrash("/h/.", "/h"), false);
    assert.equal(C.canTrash("/h/a/../../etc", "/h"), false);
    assert.equal(C.canTrash("/h/a/./b", "/h"), false);
    assert.equal(C.canTrash("/h2/x", "/h"), false);
    assert.equal(C.canTrash("/h/.local/share/Trash/files/x", "/h"), false);
    // The trash in use, under XDG_DATA_HOME, is kept too; the default place is then an ordinary folder.
    assert.equal(C.canTrash("/h/data/Trash", "/h", "/h/data/Trash"), false);
    assert.equal(C.canTrash("/h/data/Trash/files/x", "/h", "/h/data/Trash/"), false);
    assert.equal(C.canTrash("/h/.local/share/Trash/x", "/h", "/h/data/Trash"), true);
    assert.equal(C.canTrash("", "/h"), false);
});
