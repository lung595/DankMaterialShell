pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/DiskUsage.js" as DiskUsage

// The island's low space watch: a single df reads the free space of / and the home folder at start, when the mount list
// changes and every 30 min; under lowThreshold free, lowFolder is what the disk bubble scans (DiskUsageService).
Singleton {
    id: root

    // Free space of / and the home folder: under lowThreshold free, lowFolder is what the island's disk bubble scans
    // ("" = enough room). Read by df at start, when DgopService's mount list changes, and at most every 30 min. Once
    // low, a disk stays low until its free share is clearRatio times the threshold, so it never flaps at the edge.
    readonly property real lowThreshold: 0.1
    readonly property real clearRatio: 1.2
    // The mount points last seen, so a DgopService refresh with the same mounts reads nothing.
    property string _mountsKey: ""
    property string lowFolder: ""
    property real lowFree: 1
    property real lowAvail: 0

    function checkFree() {
        freeDf.running = true;
    }

    function _setLow(folder, free, avail) {
        root.lowFree = free;
        root.lowAvail = avail;
        root.lowFolder = folder;
    }

    Component.onCompleted: checkFree()

    Connections {
        target: DgopService

        function onDiskMountsChanged() {
            const key = (DgopService.diskMounts ?? []).map(m => m?.mount ?? "").join("\n");
            if (key === root._mountsKey)
                return;
            root._mountsKey = key;
            root.checkFree();
        }
    }

    // shortcut: a 30 min one-shot, re-armed after each read, catches a disk filling with no event; drop if a mount
    // watcher (inotify on /proc/self/mountinfo does not see free space) or a dgop push appears.
    Timer {
        id: freeLater

        interval: 30 * 60 * 1000
        onTriggered: root.checkFree()
    }

    Process {
        id: freeDf

        command: ["df", "-B1", "--output=size,avail,target", "/", Quickshell.env("HOME") || "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const low = DiskUsage.lowMount(text, root.lowFolder ? root.lowThreshold * root.clearRatio : root.lowThreshold);
                // / full scans / (its own file system only: DiskUsageService), a full home mount scans the home folder.
                root._setLow(!low ? "" : low.path === "/" ? "/" : Quickshell.env("HOME"), low ? low.avail / low.size : 1, low ? low.avail : 0);
                freeLater.restart();
            }
        }
    }
}
