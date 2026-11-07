pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/AppCrash.js" as AppCrash

// The last desktop app of this user that crashed, from systemd-coredump's entries in the user journal.
// journalctl -f blocks on the journal's inotify: no polling, nothing runs while no app crashes. It runs only while a
// reader holds a reference (IslandBarHost: its screen shows bubbles on a visible bar), and comes back if it ends.
Singleton {
    id: root

    property int refCount: 0
    onRefCountChanged: root.journal.running = root.refCount > 0
    // A journalctl that ended by itself is started again after this, while someone still reads.
    readonly property int respawnMs: 5000
    readonly property Timer respawn: Timer {
        interval: root.respawnMs
        onTriggered: root.journal.running = root.refCount > 0
    }

    // {name, image, signal, log, entry} or null; only crashes that map to a desktop entry (no CLI tools, no daemons).
    property var crash: null

    function dismiss() {
        root.crash = null;
    }

    function relaunch() {
        const entry = root.crash?.entry;
        root.crash = null;
        if (entry)
            SessionService.launchDesktopEntry(entry);
    }

    function handle(line) {
        const c = AppCrash.parse(line);
        if (!c)
            return;
        let entry = null;
        for (const n of c.names) {
            entry = DesktopEntries.heuristicLookup(n);
            if (entry)
                break;
        }
        if (!entry || entry.noDisplay)
            return;
        root.crash = {
            "name": entry.name || c.comm,
            "image": Quickshell.iconPath(entry.icon, true),
            "signal": c.signal,
            "log": c.log,
            "entry": entry
        };
    }

    // systemd-coredump's MESSAGE_ID for "process dumped core" (SD_MESSAGE_COREDUMP in systemd's sd-messages.h).
    readonly property string coredumpMessageId: "fc2e22bc6ee647b6b90729ab34a250b1"

    readonly property Process journal: Process {
        // -n0: only crashes from now on; the field list keeps each line small (a coredump entry also carries the environ and maps).
        command: ["journalctl", "--user", "-f", "-q", "-n0", "-o", "json", "MESSAGE_ID=" + root.coredumpMessageId, "--output-fields=COREDUMP_PID,COREDUMP_COMM,COREDUMP_EXE,COREDUMP_USER_UNIT,COREDUMP_SIGNAL,COREDUMP_SIGNAL_NAME,MESSAGE"]
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        onExited: if (root.refCount > 0)
            root.respawn.restart()
    }
}
