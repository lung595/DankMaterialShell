pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../Common/IslandDownload.js" as Download
import "../Common/IslandEyes.js" as Eyes
import "../Common/IslandActivities.js" as Activities
import "../Common/Format.js" as Format

// Finished downloads: the user's downloads folder (XDG, e.g. ~/Téléchargements), watched by Qt's folder model (inotify,
// no polling). Browsers rename their temporary file once done (IslandDownload.js tells which files just finished).
// A free island takes the file whole for a brief info's lifetime (activity "dms:download"), unless brief info always
// goes in a bubble; a busy one, or one that gets busy meanwhile, leaves it to a brief bubble on the apps side (source "download"), held while hovered.
Singleton {
    id: root

    readonly property string sourceId: "dms:download"
    // The file just finished: {"name", "size", "path", "seq"}, or null.
    property var file: null
    // "island" or "bubble" while a file shows.
    property string shownIn: ""
    property string token: ""
    property var state: null
    property int seq: 0
    readonly property url folder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    readonly property string sizeText: root.file ? Format.formatBytes(Number(root.file.size) || 0) : ""
    // The apps-side face while the island is busy.
    readonly property var face: root.shownIn !== "bubble" || !root.file ? null : ({
            "id": "download:" + root.file.seq,
            "source": "download",
            "kind": "download",
            "seq": 1e5 + root.file.seq,
            "icon": "download_done",
            "progress": -1,
            "text": root.sizeText.length <= 6 ? root.sizeText : "",
            "title": root.file.name,
            "detail": root.sizeText,
            "accent": "primary",
            "file": root.file,
            "open": true
        })

    // Each finished file, for the shelf to come (it will keep the files to put away).
    signal toShelve(string path)

    function announce(entry) {
        root.clear();
        const name = String(entry?.name ?? "");
        if (!name)
            return "";
        const path = entry.path || (decodeURIComponent(root.folder.toString().replace(/^file:\/\//, "")) + "/" + name);
        root.file = {
            "name": name,
            "size": Number(entry.size) || 0,
            "path": path,
            "seq": ++root.seq
        };
        root.toShelve(path);
        const screen = CompositorService.getFocusedScreenName();
        if (!SettingsData.islandBriefBubbles && Eyes.route(IslandActivityService.islandsFor(screen)) === "island")
            root.token = IslandActivityService.add(root.sourceId, {
                "kind": "glance",
                "timeoutMs": Activities.briefTimeoutMs,
                "screen": screen,
                "data": {
                    "icon": "download_done",
                    "title": name
                }
            });
        root.toBubble(!root.token);
        return root.shownIn;
    }

    function toBubble(yes) {
        root.shownIn = yes ? "bubble" : "island";
        if (yes)
            brief.restart();
    }

    function clear() {
        const token = root.token;
        root.token = "";
        brief.stop();
        root.file = null;
        root.shownIn = "";
        if (token)
            IslandActivityService.remove(token, "released");
    }

    // The bubble stays while hovered, then its whole lifetime again.
    // A drag out of the card holds it too: the pointer leaves the bubble while it carries the file.
    property bool dragging: false
    function hold(inside) {
        if (root.shownIn !== "bubble")
            return;
        if (inside || root.dragging)
            brief.stop();
        else
            brief.restart();
    }

    function open() {
        if (root.file)
            Qt.openUrlExternally(Download.fileUrl(root.file.path));
        root.clear();
    }

    // The file manager selects the file (FileManager1, as browsers do); "Show" falls back to the folder without one.
    function show() {
        if (!root.file)
            return;
        const url = Download.fileUrl(root.file.path);
        if (!showItems.running) {
            showItems.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1", "--object-path", "/org/freedesktop/FileManager1", "--method", "org.freedesktop.FileManager1.ShowItems", "['" + url.replace(/'/g, "\\'") + "']", "''"];
            showItems.running = true;
        }
        root.clear();
    }

    Process {
        id: showItems

    }
    Connections {
        target: showItems

        function onExited(code) {
            if (code !== 0)
                Qt.openUrlExternally(root.folder);
        }
    }

    Timer {
        id: brief

        interval: Activities.briefTimeoutMs
        onTriggered: root.clear()
    }

    // Downloads still running (IslandDownload.running) with their received bytes and speed: [{"part", "name", "size",
    // "speed"}], newest first. The browser never says the total, so there is no percentage.
    property var live: []
    // The names the last listing found finished, set before live so a running row that leaves can tell.
    property var justFinished: []
    property var liveSample: null
    // How often a running download's size is read (its speed is the change over this step).
    readonly property int liveTickMs: 1000

    // shortcut: sizes come from one `stat` per second, only while a download runs; a parts-only inotify watcher would
    // need a native helper.
    Timer {
        id: liveTick

        interval: root.liveTickMs
        repeat: true
        triggeredOnStart: true
        running: root.live.length > 0
        onTriggered: {
            if (sizer.running)
                return;
            const dir = decodeURIComponent(root.folder.toString().replace(/^file:\/\//, ""));
            sizer.dir = dir;
            sizer.command = ["stat", "-c", "%s %n", "--"].concat(root.live.map(d => dir + "/" + d.part));
            sizer.running = true;
        }
    }

    Process {
        id: sizer

        // The folder the sizes were asked in.
        property string dir: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const sizes = Download.statSizes(text, sizer.dir);
                const s = Download.sample(root.liveSample, sizes, Date.now());
                root.liveSample = s.state;
                root.live = root.live.map(d => Object.assign({}, d, {
                        "size": sizes[d.part] ?? d.size,
                        "speed": s.speeds[d.part] ?? 0
                    }));
            }
        }
    }

    function rescan() {
        if (model.status !== FolderListModel.Ready)
            return;
        const entries = [];
        for (let i = 0; i < model.count; i++)
            entries.push({
                "name": model.get(i, "fileName"),
                "size": model.get(i, "fileSize"),
                "modified": model.get(i, "fileModified")?.getTime?.() ?? 0
            });
        const r = Download.step(root.state, entries);
        root.justFinished = r.finished.map(e => e.name);
        const running = Download.running(entries);
        const known = {};
        for (const d of root.live)
            known[d.part] = d;
        root.live = running.map(d => known[d.part] ?? Object.assign({}, d, {
                "size": Number(entries.find(e => e.name === d.part)?.size) || 0,
                "speed": 0
            }));
        if (!root.live.length) {
            root.liveSample = null;
        }
        root.state = r.state;
        // Several at once (an archive's parts): the last one shows, each one goes to the shelf.
        for (const e of r.finished)
            root.announce(e);
    }

    FolderListModel {
        id: model

        folder: root.folder
        showDirs: false
        showHidden: true
        showDotAndDotDot: false
        nameFilters: ["*"]
        onStatusChanged: root.rescan()
        onCountChanged: root.rescan()
        // A rename (name.crdownload to name) keeps the count.
        onDataChanged: root.rescan()
    }

    Connections {
        target: IslandActivityService

        // Something else took the island: the file goes on in the bubble.
        function onInterrupted(token) {
            if (token !== root.token)
                return;
            root.token = "";
            IslandActivityService.remove(token, "released");
            root.toBubble(true);
        }

        function onDropped(token, reason) {
            if (token === root.token && reason !== "released") {
                root.token = "";
                root.clear();
            }
        }
    }
}
