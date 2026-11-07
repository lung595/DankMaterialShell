pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/DiskUsage.js" as DiskUsage

// Live disk usage of one folder, like gdu or dust: statfs (df) gives the used space at once, then four `du -0abx` readers
// share the folder's top entries and stream every file as they reach it; the tree (and its charts) fills while they run.
// Hard links count once (du's own rule) and other file systems are skipped, as ncdu -x: the folder's own entries on
// another file system (/proc, /sys, a mount under /) are left out (DiskUsage.sameDevice), du -x keeps to each entry's.
// du runs only on scan(). The low space watch is DiskSpaceService, the card's cleanup DiskCleanupService.
Singleton {
    id: root

    readonly property int readers: 4
    property string path: ""
    property var tree: DiskUsage.node("~", null)
    // Bumped whenever the tree changed, for the charts to redraw.
    property int revision: 0
    property bool scanning: false
    property real elapsed: 0
    // statfs of the folder's file system (bytes).
    property real fsSize: 0
    property real fsUsed: 0
    // The card's chart: "tree" (treemap) or "sun" (rings).
    property string mode: "tree"

    property var _queues: []
    property var _groups: []
    property int _running: 0
    property real _started: 0
    // When the last scan started (ms since the epoch), for a reader judging how fresh it is.
    readonly property real scannedAt: root._started
    property int _ticks: 0

    function scan(folder) {
        // Stopped first, while scanning is false, so the old listing does not start readers.
        root.scanning = false;
        lister.running = false;
        df.running = false;
        applier.stop();
        root.path = folder.replace(/\/+$/, "") || "/";
        root.tree = DiskUsage.node("~", null);
        root._queues = [];
        root._groups = [];
        root._running = 0;
        root._ticks = 0;
        root.elapsed = 0;
        root.scanning = true;
        root._started = Date.now();
        root.revision++;
        df.command = ["df", "-B1", "--output=size,used", root.path];
        df.running = true;
        lister.entries = [];
        // The folder itself first, then its entries, each with its device (find's %D).
        lister.command = ["find", root.path, "-maxdepth", "1", "-printf", "%D %p\\0"];
        lister.running = true;
    }

    function _startReaders(entries) {
        const groups = [];
        for (let i = 0; i < Math.min(root.readers, entries.length); i++)
            groups.push([]);
        entries.forEach((e, i) => groups[i % groups.length].push(e));
        root._queues = groups.map(() => []);
        root._running = groups.length;
        root._groups = groups;
        applier.start();
    }

    function _received(reader, record) {
        root._queues[reader].push(record);
    }

    function _readerDone() {
        root._running = Math.max(0, root._running - 1);
    }

    // Applies what the readers found, round robin so they grow side by side; reduced motion takes it in steps.
    function _apply() {
        let changed = false;
        root._queues.forEach(q => {
            while (q.length) {
                DiskUsage.add(root.tree, root.path, q.shift());
                changed = true;
            }
        });
        if (changed)
            root.revision++;
        // A reader can exit before its last records are read: stop after two quiet ticks.
        root._ticks = changed || root._running > 0 ? 0 : root._ticks + 1;
        if (root._ticks >= 2) {
            applier.stop();
            root.scanning = false;
            root.elapsed = Date.now() - root._started;
            root.revision++;
        }
    }

    Timer {
        id: applier

        interval: SettingsData.reduceMotion || SettingsData.animationDuration <= 0 ? 500 : 50
        repeat: true
        onTriggered: root._apply()
    }

    Process {
        id: df

        stdout: StdioCollector {
            onStreamFinished: {
                const nums = (text || "").trim().split(/\s+/).map(Number).filter(n => n >= 0);
                root.fsSize = nums[nums.length - 2] || 0;
                root.fsUsed = nums[nums.length - 1] || 0;
            }
        }
    }

    Process {
        id: lister

        property var entries: []
        stdout: SplitParser {
            splitMarker: "\0"
            onRead: data => lister.entries.push(data)
        }
        // running drops when it exits (onExited needs QProcess types qmllint cannot see).
        onRunningChanged: if (!running && root.scanning && root._groups.length === 0) root._startReaders(DiskUsage.sameDevice(lister.entries))
    }

    Instantiator {
        model: root._groups

        delegate: Process {
            id: reader

            required property var modelData
            required property int index

            command: ["du", "-0abx", "--"].concat(reader.modelData)
            running: true
            stdout: SplitParser {
                splitMarker: "\0"
                onRead: data => root._received(reader.index, data)
            }
            onRunningChanged: if (!running) root._readerDone()
        }
    }
}
