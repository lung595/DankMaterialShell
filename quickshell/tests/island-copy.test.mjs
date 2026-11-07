import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandCopy.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);

test("the replayed snapshot only seeds, a higher id is a copy", () => {
    let s = C.step([{ "id": 7 }, { "id": 3 }], -1);
    assert.deepEqual({ ...s }, { "last": 7, "copied": false });
    s = C.step([{ "id": 8 }, { "id": 7 }], s.last);
    assert.deepEqual({ ...s }, { "last": 8, "copied": true });
    assert.equal(C.step([], -1).last, 0);
    assert.equal(C.step([{ "id": 1 }], 0).copied, true);
});

test("pins, deletes and clears are not copies", () => {
    assert.equal(C.step([{ "id": 8, "pinned": true }, { "id": 7 }], 8).copied, false);
    const del = C.step([{ "id": 5 }], 8);
    assert.deepEqual({ ...del }, { "last": 8, "copied": false });
    assert.equal(C.step(undefined, 8).copied, false);
    assert.equal(C.step([{ "id": 9 }], del.last).copied, true);
});

test("the newest entry is the highest id", () => {
    assert.equal(C.newest([{ "id": 3 }, { "id": 9, "preview": "x" }, { "id": 5 }]).preview, "x");
    assert.equal(C.newest([]), null);
    assert.equal(C.newest(undefined), null);
});

test("the peek shows plain text and masks what looks like a secret", () => {
    assert.equal(C.peek("  hello world \nsecond line", 40), "hello world");
    assert.equal(C.peek("une phrase un peu longue", 10), "une phras…");
    assert.equal(C.peek("https://example.org/a?b=C1d2", 40), "https://example.org/a?b=C1d2");
    assert.equal(C.peek("me@example.org", 40), "me@example.org");
    assert.equal(C.peek("Tr0ub4dor&3", 40), "T********3");
    assert.equal(C.peek("482913", 40), "4********3");
    assert.equal(C.peek("ghp_aB3dE5gH7jK9mN1pQ3sT5vX7z", 40), "g********z");
    assert.equal(C.peek("Bonjour", 40), "Bonjour");
    assert.equal(C.peek("2026", 40), "2026");
    assert.equal(C.peek("", 40), "");
});

test("the kind of a copy: image, file, secret, link, else text", () => {
    assert.equal(C.kind({ "isImage": true, "mimeType": "image/png", "preview": "[[ image 2 KiB png 9x9 ]]" }), "image");
    // A copied image file: DMS marks it an image though its data is the file's link.
    assert.equal(C.kind({ "isImage": true, "mimeType": "text/uri-list", "preview": "[[ file a.png png 9x9 ]]" }), "image");
    assert.equal(C.kind({ "mimeType": "text/uri-list", "preview": "[[ file notes.pdf ]]" }), "file");
    assert.equal(C.kind({ "mimeType": "text/uri-list", "preview": "[[ 3 files ]]" }), "file");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "Tr0ub4dor&3" }), "secret");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "482913" }), "secret");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "https://example.org/a?b=C1d2" }), "link");
    assert.equal(C.kind({ "mimeType": "text/uri-list", "preview": "https://example.org" }), "link");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "www.example.org/page" }), "link");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "see https://example.org" }), "text");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "me@example.org" }), "text");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "Bonjour" }), "text");
    // Text that only looks like a file preview is still text.
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "[[ file x ]]" }), "text");
    assert.equal(C.kind(null), "text");
    assert.equal(C.kind({}), "text");
});

test("a www. address with capitals and digits is a link, a secret behind www. stays one", () => {
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "www.Example2024.org/Page1" }), "link");
    assert.equal(C.peek("www.Shop24.Example.com", 40), "www.Shop24.Example.com");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "www.Tr0ub4dor&3" }), "secret");
    assert.equal(C.kind({ "mimeType": "text/plain", "preview": "www.aB3dE5gH7jK9" }), "secret");
});

test("a copied file shows its name, several files their count", () => {
    assert.deepEqual({ ...C.files("[[ file report.pdf ]]", 40) }, { "name": "report.pdf", "count": 1 });
    // A file name is never masked, only cut.
    assert.deepEqual({ ...C.files("[[ file Tr0ub4dor&3.kdbx ]]", 40) }, { "name": "Tr0ub4dor&3.kdbx", "count": 1 });
    assert.equal(C.files("[[ file un rapport assez long.pdf ]]", 10).name, "un rappor…");
    assert.deepEqual({ ...C.files("[[ 3 files ]]", 40) }, { "name": "", "count": 3 });
    assert.deepEqual({ ...C.files("Bonjour", 40) }, { "name": "", "count": 0 });
});

test("each kind has its icon", () => {
    assert.deepEqual(["text", "link", "image", "file", "secret", "other"].map(k => C.kindIcon(k)), ["notes", "link", "image", "description", "key", "notes"]);
});

test("a copy the island makes itself never plays the copied bubble; the user's next copy does", () => {
    assert.equal(C.ownCopy(1000), false);
    C.markOwnCopy(1000);
    // Its clipboard update comes back over DMS's socket a moment later: quiet.
    assert.equal(C.ownCopy(1000 + 300), true);
    assert.equal(C.ownCopy(1000 + C.ownCopyMs), true);
    assert.equal(C.ownCopy(1000 + C.ownCopyMs + 1), false);
});

test("a big image is never carried for a thumbnail, the kind icon stands instead", () => {
    const max = C.THUMB_MAX_CHARS;
    assert.equal(C.thumbOk({ "size": 12e6 }), false);
    assert.equal(C.thumbOk({ "size": 1000 }), true);
    assert.equal(C.thumbOk({ "size": Math.floor(max * 3 / 4) }), true);
    assert.equal(C.thumbOk({ "size": Math.floor(max * 3 / 4) + 10 }), false);
    assert.equal(C.thumbOk({}), false);
    assert.equal(C.thumbOk({ "size": 0 }), false);
    assert.equal(C.thumbOk({}, "x".repeat(max + 1)), false);
    assert.equal(C.thumbOk({ "size": 10 }, "x".repeat(max)), true);
});
