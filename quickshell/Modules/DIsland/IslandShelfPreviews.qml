pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "../../Common/IslandShelf.js" as Shelf

// Rich previews for the shelf's tiles (N5, direction D): a PDF's or office document's first page (pdftoppm, LibreOffice),
// a video's frame (ffmpeg), a sound's cover, and the quick look's pages, rendered by the shelf's helper (island-shelf.sh
// thumb | page) one at a time, off the UI thread, into ~/.cache/dms/shelf-thumbs/<md5 of the path>[-<page>].png. A tile
// shows its type's icon until its preview is ready, and for good when the tool is missing or fails.
QtObject {
    id: root

    required property string script
    // The previews ready, by path: a file URL.
    property var ready: ({})
    // The quick look's pages ready, by "<path>\n<page>": {url, pages}; "" while rendering, false when failed.
    property var pages: ({})
    readonly property string dir: Paths.strip(Paths.cache) + "/shelf-thumbs"
    // shortcut: asked once per session; a file changed meanwhile keeps its old preview until the next start (the helper
    // renders again a preview older than its file). Ask again on facts' change if that matters.
    property var asked: ({})
    property var queue: []
    property bool busy: false

    function want(path) {
        if (!path || root.asked[path] || !Shelf.previewed(path))
            return;
        root.asked[path] = true;
        root.queue.push({
            "verb": "thumb",
            "path": path,
            "file": root.dir + "/" + Qt.md5(path) + ".png"
        });
        root.next();
    }

    // The quick look's page n (from 1) of a PDF or office document; answered in pages.
    function page(path, n) {
        const key = path + "\n" + n;
        if (!path || root.pages[key] !== undefined)
            return;
        root.pages = Object.assign({}, root.pages, {
            [key]: ""
        });
        root.queue.push({
            "verb": "page",
            "path": path,
            "key": key,
            "file": root.dir + "/" + Qt.md5(path) + "-" + n + ".png"
        });
        root.next();
    }

    function next() {
        if (root.busy || !root.queue.length)
            return;
        root.busy = true;
        const job = root.queue.shift();
        Proc.runCommand(null, ["sh", root.script, job.verb, job.file, "--", job.path], (output, code) => {
            if (job.verb === "thumb") {
                const out = String(output || "").trim();
                if (code === 0 && out.startsWith("/"))
                    root.ready = Object.assign({}, root.ready, {
                        [job.path]: Shelf.url(out)
                    });
            } else {
                const p = code === 0 ? Shelf.pageOut(output) : null;
                root.pages = Object.assign({}, root.pages, {
                    [job.key]: p ? {
                        "url": Shelf.url(p.path),
                        "pages": p.pages
                    } : false
                });
            }
            root.busy = false;
            root.next();
        }, 0, job.verb === "page" ? 120000 : 20000);
    }
}
