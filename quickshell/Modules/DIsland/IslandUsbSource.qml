pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "../../Common/IslandUsb.js" as Usb

// The USB stick / plugged disk bubble (apps side, source "usb"): a removable filesystem that appears plays in the free
// island first (arrived()), then stays as a bubble with Open / Eject until it is ejected, unplugged or dismissed.
// UDisks2 signals through DMS's D-Bus bridge, else udisksctl monitor, re-read lsblk; no polling. Its row in B8's apps
// table, coded as B9 says; its arrival plays as M1 says.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    property var drives: []
    // The drive the bubble shows, kept after it leaves the list so "You can unplug it" can still name it.
    property var drive: null
    property bool ejected: false
    property bool busy: false
    property bool dismissed: false
    property bool cardOpen: false
    property bool primed: false
    property var _last: []
    readonly property var current: root.drive ? root.drives.find(d => d.dev === root.drive.dev) ?? null : null
    readonly property bool shown: root.enabled && !!root.drive && !root.dismissed

    signal arrived

    readonly property string freeText: {
        const d = root.current ?? root.drive;
        if (!d)
            return "";
        if (d.free >= 0)
            return I18n.tr("%1 free", "island usb bubble: free space on the stick").arg(Usb.size(d.free));
        return Usb.size(d.size);
    }
    readonly property var face: ({
            "id": "usb",
            "source": "usb",
            "kind": "usb",
            "seq": 1e5,
            "icon": root.ejected ? "check_circle" : "usb",
            "progress": -1,
            "text": "",
            "title": root.drive?.name ?? "",
            "detail": root.ejected ? I18n.tr("You can unplug it", "island usb bubble: the stick was ejected") : root.freeText,
            "accent": "primary",
            "open": root.cardOpen,
            "usb": root
        })

    onDrivesChanged: {
        const now = root.drives;
        const before = root._last;
        root._last = now;
        if (!root.primed) {
            root.primed = true;
            return;
        }
        const fresh = Usb.arrived(before, now);
        if (fresh) {
            root.drive = fresh;
            root.ejected = false;
            root.dismissed = false;
            if (root.enabled)
                root.arrived();
        } else if (root.drive && !root.current && !root.ejected) {
            // Pulled out without ejecting: nothing left to act on.
            root.clear();
        }
    }

    function clear() {
        root.drive = null;
        root.cardOpen = false;
        root.ejected = false;
    }

    function dismiss() {
        root.dismissed = true;
        root.cardOpen = false;
    }

    function open() {
        const d = root.current;
        if (!d || root.busy)
            return;
        if (d.mount) {
            Qt.openUrlExternally(root.fileUrl(d.mount));
            return;
        }
        root.run(["udisksctl", "mount", "--no-user-interaction", "-b", d.dev], out => {
            const path = Usb.mountedAt(out);
            if (path)
                Qt.openUrlExternally(root.fileUrl(path));
        });
    }

    function eject() {
        const d = root.current;
        if (!d || root.busy)
            return;
        // Every mounted filesystem of the drive first (a key may hold several), one after the other, then its power.
        const mounted = root.drives.filter(o => o.disk === d.disk && o.mount).map(o => o.dev);
        const next = () => {
            const dev = mounted.shift();
            if (dev)
                root.run(["udisksctl", "unmount", "--no-user-interaction", "-b", dev], next);
            else
                root.run(["udisksctl", "power-off", "--no-user-interaction", "-b", d.disk], () => {}, true);
        };
        next();
    }

    // One udisksctl call at a time; done(stdout) on success. quiet: a failed power-off still leaves it safe to pull.
    property var _done: null
    property bool _quiet: false
    function run(command, done, quiet) {
        root.busy = true;
        root._done = done;
        root._quiet = quiet === true;
        action.command = command;
        action.running = true;
    }

    readonly property Process action: Process {
        stdout: StdioCollector {
            id: actionOut
        }
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: code => {
            // done() may start the next call (unmount, then power-off): reset first.
            const done = root._done;
            const isPowerOff = root._quiet;
            root.busy = false;
            root._done = null;
            root._quiet = false;
            // A stick pulled out mid-action has nothing left to name: no message then.
            if (code !== 0 && !isPowerOff) {
                if (!root.drive)
                    return;
                ToastService.showError(I18n.tr("Could not open or eject %1", "island usb bubble: udisksctl failed").arg(root.drive?.name ?? ""), actionErr.text.trim());
                return;
            }
            if (isPowerOff) {
                root.ejected = true;
                root.ejectedTimer.restart();
            }
            done?.(actionOut.text);
        }
    }

    // "You can unplug it" says so for a moment, then leaves.
    readonly property Timer ejectedTimer: Timer {
        interval: root.controller.transientTimeout
        onTriggered: {
            if (root.ejected)
                root.clear();
        }
    }

    // Hovering the bubble holds "you can unplug it".
    function hold(inside) {
        if (!root.ejected)
            return;
        if (inside)
            root.ejectedTimer.stop();
        else
            root.ejectedTimer.restart();
    }

    // Signals come in bursts (a stick adds a disk, a partition, a mount): one lsblk after the last of them, the time
    // UDisks2 takes to send a whole burst. One that comes while lsblk runs reads again once it ends.
    readonly property int settleMs: 300
    property bool _again: false
    readonly property Timer settle: Timer {
        interval: root.settleMs
        onTriggered: {
            if (root.lsblk.running)
                root._again = true;
            else
                root.lsblk.running = true;
        }
    }

    readonly property Process lsblk: Process {
        command: ["lsblk", "-J", "-l", "-b", "-o", "PATH,PKNAME,TYPE,FSTYPE,LABEL,MODEL,FSAVAIL,SIZE,MOUNTPOINT,HOTPLUG,RM,TRAN"]
        stdout: StdioCollector {
            onStreamFinished: root.drives = Usb.drives(text)
        }
        onExited: {
            if (!root._again)
                return;
            root._again = false;
            root.lsblk.running = true;
        }
    }

    // A file URL whose path keeps a label's "#" or "?" as part of the name.
    function fileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
    }

    // A mount or unmount from a file manager changes Filesystem.MountPoints, hence PropertiesChanged.
    readonly property IslandDbusSignals udisks: IslandDbusSignals {
        enabled: root.enabled
        service: "org.freedesktop.UDisks2"
        matches: [["org.freedesktop.DBus.ObjectManager", "InterfacesAdded", ""], ["org.freedesktop.DBus.ObjectManager", "InterfacesRemoved", ""], ["org.freedesktop.DBus.Properties", "PropertiesChanged", ""]]
        onReceived: root.settle.restart()
    }
    onEnabledChanged: if (root.enabled)
        root.lsblk.running = true
    Component.onCompleted: if (root.enabled)
        root.lsblk.running = true

    // Without the D-Bus bridge (no backend, or one without the dbus capability): udisksctl's own event stream (blocks on
    // its pipe, no CPU at rest).
    readonly property Process monitor: Process {
        command: ["udisksctl", "monitor"]
        running: root.enabled && !root.udisks.bridge
        stdout: SplitParser {
            onRead: root.settle.restart()
        }
    }
}
