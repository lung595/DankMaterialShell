pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Common
import qs.Services
import "../../Common/IslandTrash.js" as Trash
import "../../Common/IslandArrival.js" as Arrival

// The trash bubble (apps side, source "trash"): a file just went to the home trash; its card names it and offers Undo for
// an Undo's lifetime, a ring draining around it. The home trash's info folder is watched by the file system (no polling): one
// .trashinfo per trashed item, whoever trashed it (DMS, a file manager, gio trash).
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    readonly property string infoDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Trash/info"
    readonly property int undoMs: root.controller.undoTimeout

    property var known: null
    // How many of DiskCleanupService.quietTrash this screen has let pass already (each screen counts its own).
    property int quietSeen: 0
    Component.onCompleted: root.quietSeen = DiskCleanupService.quietTrash
    // Off, it stops looking: back on, what was trashed meanwhile is known already, never a late bubble.
    onEnabledChanged: if (!root.enabled)
        root.known = null
    property var batch: []
    property bool shown: false
    // 1 → 0 over the Undo window; the card's ring shows it.
    property real left: 0

    readonly property var label: Trash.label(root.batch)
    readonly property var face: ({
            "id": "trash",
            "source": "trash",
            "kind": "trash",
            "seq": 1e6 + 1,
            "icon": "delete",
            "progress": -1,
            "text": "",
            "title": root.label.name,
            "detail": root.label.others > 0 ? I18n.tr("and %1 more", "island trash bubble: other files deleted with the first").arg(root.label.others) : "",
            "accent": "primary",
            // The card (name, Undo) opens at once, like the power profile's.
            "open": true,
            "count": root.batch.length,
            "trash": root
        })

    // shortcut: no watch while ~/.local/share/Trash/info does not exist yet (fresh account), until DMS restarts.
    readonly property FolderListModel watch: FolderListModel {
        folder: root.enabled ? "file://" + root.infoDir : ""
        showDirs: false
        showHidden: true
        showDotAndDotDot: false
        nameFilters: ["*.trashinfo"]
        onCountChanged: root.scan()
        onStatusChanged: root.scan()
    }

    function scan() {
        if (!root.enabled || root.watch.status !== FolderListModel.Ready)
            return;
        const names = [];
        for (let i = 0; i < root.watch.count; i++)
            names.push(Trash.entryName(root.watch.get(i, "fileName")));
        const s = Trash.step(root.known, names, root.batch, root.shown);
        root.known = s.known;
        // The disk card's own deletions: its Undo is already on screen, never a second one here.
        const quiet = Math.max(0, DiskCleanupService.quietTrash - root.quietSeen);
        if (s.added && quiet > 0) {
            root.quietSeen += Math.min(quiet, s.added);
            return;
        }
        if (s.added) {
            root.batch = s.batch;
            root.play();
            return;
        }
        root.batch = s.batch;
        if (root.shown && !root.batch.length)
            root.close();
    }

    readonly property NumberAnimation countdown: NumberAnimation {
        target: root
        property: "left"
        from: 1
        to: 0
        duration: root.undoMs
        onFinished: root.close()
    }

    // The island's own "trash" face first, its value an Undo (IslandBarHost asks for it); a bubble only when the island
    // cannot or will not. Either way the Undo lives for the whole window, wherever the info goes meanwhile.
    signal arrived
    readonly property bool onIsland: root.controller.activeActivity === "trash"
    // Hovering the island's face holds the window, as hovering the bubble does.
    readonly property bool islandHeld: root.onIsland && root.controller.timeoutSuspended
    onIslandHeldChanged: root.hold(root.islandHeld)
    // Its island face was put back after an alert, but the window closed meanwhile. A face that left early (Escape,
    // another face, an alert, the launcher) hands the info to the bubble with a whole window again (M20).
    onOnIslandChanged: {
        if (Arrival.bubbleClockRestarts(root.onIsland, root.shown))
            root.countdown.restart();
        Qt.callLater(root.leave);
    }
    readonly property Connections ending: Connections {
        target: root.controller

        function onSystemActivityEnding(activityId) {
            // The island's clock and the window end together, give or take a frame: no bubble for that frame.
            if (activityId === "trash" && root.left < 0.05)
                root.hide();
        }
    }

    function play() {
        if (!root.enabled || !root.controller.bubblesEnabled)
            return;
        root.shown = true;
        root.countdown.restart();
        root.arrived();
    }
    function hide() {
        root.countdown.stop();
        root.shown = false;
    }
    function close() {
        root.hide();
        root.leave();
    }
    function leave() {
        if (root.onIsland && !root.shown)
            root.controller.finishTransient();
    }
    // Hovering the bubble holds the Undo window.
    function hold(inside) {
        if (!root.shown)
            return;
        if (inside)
            root.countdown.pause();
        else
            root.countdown.resume();
    }
    function undo() {
        const names = root.batch;
        root.close();
        for (const name of names)
            Proc.runCommand(null, [Proc.dmsBin, "trash", "restore", "--", name], (output, exitCode) => {
                if (exitCode !== 0)
                    ToastService.showError(I18n.tr("Failed to restore from trash", "island trash bubble undo error"), name);
            });
    }
}
