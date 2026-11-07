.pragma library

// The island's trash bubble: which entries just fell into the trash? The watcher hands every name in Trash/info (one
// "<name>.trashinfo" per trashed item); a name not seen before is a new deletion. The first listing only seeds (what was
// already there is not news). Restores and emptying only remove names, so they never raise the bubble.
// A4: pure logic, tested by island-trash.test.mjs.

function entryName(fileName) {
    const s = String(fileName || "");
    return s.endsWith(".trashinfo") ? s.slice(0, -".trashinfo".length) : "";
}

// known: the names seen so far (null = not seeded yet); batch: the names the shown bubble offers to restore (a name restored meanwhile leaves the batch).
// open: the bubble still shows (its Undo window runs), so a new deletion joins its batch instead of replacing it.
function step(known, names, batch, open) {
    const list = (names || []).filter(n => n !== "");
    if (known === null || known === undefined)
        return {
            "known": list,
            "batch": [],
            "added": 0
        };
    const seen = new Set(known);
    const added = list.filter(n => !seen.has(n));
    if (!added.length)
        return {
            "known": list,
            "batch": (batch || []).filter(n => list.includes(n)),
            "added": 0
        };
    const base = open ? (batch || []).filter(n => list.includes(n) && !added.includes(n)) : [];
    return {
        "known": list,
        "batch": base.concat(added),
        "added": added.length
    };
}

// The bubble's text: the first file's name and how many more went with it.
function label(batch) {
    const b = batch || [];
    return {
        "name": b.length ? b[0] : "",
        "others": Math.max(0, b.length - 1)
    };
}
