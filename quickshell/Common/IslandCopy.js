.pragma library

// The island's "copied" bubble: is this clipboard state a new copy? Entry ids only grow (dedupe re-inserts with a new
// id), so a copy is a top id above the last one seen; pins, deletes and clears never raise it. The first state seen
// (the snapshot DMS replays on subscribe) only seeds. Of the entry, only its one-line peek is kept, masked when it looks
// like a secret. Returns the new last id; -1 = not seeded yet.
// A copy the island makes itself (a 2FA code's Copy, a file taken off the shelf) never plays the "copied" bubble: the one
// making it calls markOwnCopy() just before, and every island's copy source keeps quiet for the clipboard update that
// comes back over DMS's socket within ownCopyMs. Shared by every importer (.pragma library).
// A4: this bubble's pure logic, tested by vm (tests/island-copy.test.mjs).
var ownCopyMs = 1500;
var ownCopyAt = -Infinity;
function markOwnCopy(now) {
    ownCopyAt = now ?? Date.now();
}
function ownCopy(now) {
    return (now ?? Date.now()) - ownCopyAt <= ownCopyMs;
}

function lastId(history) {
    let top = 0;
    for (const e of history || [])
        top = Math.max(top, Number(e?.id) || 0);
    return top;
}

function step(history, last) {
    const top = lastId(history);
    return {
        "last": Math.max(last, top),
        "copied": last >= 0 && top > last
    };
}

// The newest entry of a clipboard state (the highest id), or null.
function newest(history) {
    let top = null;
    for (const e of history || [])
        if (!top || (Number(e?.id) || 0) > (Number(top.id) || 0))
            top = e;
    return top;
}

// A secret: one word with no space that a password manager, a token or a code would give: a one-time code (6 to 8
// digits), a long hex or base64 run, or 8+ characters mixing three of lower, upper, digit, symbol. Links (with a scheme,
// or "www." then host labels and an optional path) and mails are not.
function secretLike(text) {
    if (/\s/.test(text) || /^[a-z][a-z0-9+.-]*:\/\//i.test(text) || /^www(\.[a-z0-9-]+)+\.[a-z]{2,}(\/\S*)?$/i.test(text) || /^[^@]+@[^@]+\.[a-z]{2,}$/i.test(text))
        return false;
    if (/^\d{6,8}$/.test(text) || /^[A-Za-z0-9+\/=_-]{24,}$/.test(text))
        return true;
    const kinds = [/[a-z]/, /[A-Z]/, /\d/, /[^A-Za-z0-9]/].filter(r => r.test(text)).length;
    return text.length >= 8 && kinds >= 3;
}

// What a clipboard entry is, from its metadata only (never its data): "image", "file" (DMS's "[[ file … ]]" or
// "[[ N files ]]" preview of a uri-list), "secret", "link" (one web address), else "text".
function kind(entry) {
    if (entry?.isImage === true)
        return "image";
    const line = String(entry?.preview ?? "").trim().split("\n")[0].trim();
    if (entry?.mimeType === "text/uri-list" && /^\[\[ (file |\d+ files ]]$)/.test(line))
        return "file";
    if (secretLike(line))
        return "secret";
    if (/^([a-z][a-z0-9+.-]*:\/\/|www\.)\S+$/i.test(line))
        return "link";
    return "text";
}

// The Material symbol standing for a kind: lines, chain, picture, file, key.
function kindIcon(kind) {
    return ({
            "link": "link",
            "image": "image",
            "file": "description",
            "secret": "key"
        })[kind] ?? "notes";
}

function cut(line, max) {
    return line.length > max ? line.slice(0, max - 1) + "…" : line;
}

// What the hover card shows of a copied text: its first line, cut at max characters; a secret keeps only its first and
// last characters around always 8 "*", so its length does not show.
function peek(text, max) {
    const line = String(text ?? "").trim().split("\n")[0].trim();
    if (secretLike(line))
        return line[0] + "********" + line[line.length - 1];
    return cut(line, max);
}

// A copied file's name (cut at max, never masked) from DMS's "[[ file name ]]" preview, or the count of "[[ N files ]]".
function files(preview, max) {
    const line = String(preview ?? "").trim().split("\n")[0].trim();
    const one = /^\[\[ file (.+) \]\]$/.exec(line);
    if (one)
        return {
            "name": cut(one[1], max),
            "count": 1
        };
    const many = /^\[\[ (\d+) files \]\]$/.exec(line);
    return {
        "name": "",
        "count": many ? Number(many[1]) : 0
    };
}

// An image bigger than this (base64 characters) is never carried over the socket for a round thumbnail: parsing and
// decoding such a string on the main thread froze the shell after a screenshot. The kind icon stands instead.
var THUMB_MAX_CHARS = 300000;

// Worth asking DMS for the image's data? Before asking, from the entry's byte size: a size of 0 or none could be any
// size, so it is not asked. Once got, from the data itself.
function thumbOk(entry, data) {
    if (data !== undefined)
        return String(data).length <= THUMB_MAX_CHARS;
    const size = Number(entry?.size);
    return size > 0 && Math.ceil(size * 4 / 3) <= THUMB_MAX_CHARS;
}
