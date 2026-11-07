pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.FileBrowser
import qs.Modules.Notifications
import qs.Services
import "../../Common/IslandShelf.js" as Shelf
import "../../Common/IslandCopy.js" as Copy
import "../../Common/IslandKit.js" as Kit

// The shelf: files dragged onto the island wait there as links (never copies) until they are dragged out somewhere
// else, removed, cleared, or gone from disk (checked at load and when the card opens, never polled). The list lives in
// DMS's session state, so every screen shares it and it survives a restart. A drag over the island, or its shortcut,
// opens its card in the island; the rest of the time it is a bubble on the machine side, so the island stays free.
// Opened on purpose (Super+S, its face clicked, a drop on a zone), the card holds the island open: only its close
// button or Super+S closes it, never a click. Its left column holds the drop zones (Convert, Share, Cloud, settings),
// its middle the list (search, filters, shelf folders: groups of links), its right the actions; all local tools
// (IslandShelf.command, scripts/island-shelf.sh), file names always passed as arguments, never through a shell.
// B9: coded step by step (source, card, island face).
QtObject {
    id: root

    required property IslandController controller
    property string screenName: ""
    property bool enabled: true
    // The wing's one shape size and one icon size (IslandBubbles.unitPx, iconFit).
    property real shapeSize: Theme.iconSize * 2
    property real iconSize: Theme.iconSize

    readonly property string sourceId: "dms:shelf"
    readonly property string script: Quickshell.shellDir + "/scripts/island-shelf.sh"

    readonly property var items: Shelf.load(SessionData.islandShelf)
    readonly property var groups: Shelf.groups(SessionData.islandShelf)
    // stat's answer for the kept files: their sizes and which are folders.
    property var facts: ({
            "size": {},
            "dirs": []
        })
    // The card in the island (a drag over it, or the shortcut), only while it is there.
    property string token: ""
    property bool cardOpen: false
    // Closed with its close button: no bubble until the next drop or the shortcut.
    property bool hidden: false
    // Opened on purpose: the island stays open until the close button or Super+S (controller.holdOpen).
    property bool pinned: false
    readonly property bool held: root.token !== "" && root.pinned
    // A file is being dragged over the island.
    property bool over: false
    // A file is being dragged out of the card: the card stays open under it.
    property bool takingOut: false
    // The keys being dragged out of the card (a folder is its key, not its files).
    property var dragKeys: []
    property bool inside: false

    // What the card shows and has chosen: the folder opened, the search, the filter, the chosen keys, the keyboard's
    // row, the click's anchor.
    property string folder: ""
    property string query: ""
    property string filter: "all"
    property var sel: []
    property int cur: 0
    property int anchor: 0
    readonly property var level: root.folder && root.groups[root.folder] ? root.groups[root.folder].items : root.items
    readonly property var shownItems: Shelf.shown(root.level, root.filter, root.facts.dirs, root.query, root.groups)
    readonly property var chosen: root.sel.filter(p => root.shownItems.indexOf(p) !== -1)
    // Remove, rename, preview, open: the chosen keys, else the keyboard's row.
    readonly property var focusKeys: root.chosen.length ? root.chosen : root.shownItems[root.cur] !== undefined ? [root.shownItems[root.cur]] : []
    // The tools found on this machine (probed once, when the card first shows), and the actions they allow.
    property var have: []
    property bool probed: false
    readonly property string choice: Shelf.selectionKind(Shelf.expand(root.chosen, root.groups), root.facts.dirs)
    readonly property var plan: Shelf.plan(root.choice, root.have)
    readonly property var keyed: Shelf.keysOf(root.plan)
    // Actions running now, by id; the card shows them busy.
    property var busy: ({})
    // A short word in the card's subtitle after an action (copied, checked, a size), for the brief timeout.
    property string notice: ""
    // Shift held: Remove becomes Trash (the card shows it).
    property bool shiftHeld: false
    // The row whose name is being edited in place, and the preview (Space) of the keyboard's row.
    property string renaming: ""
    property bool peek: false

    // The drop zones: the owner's list (settings), the one under a drag, the one opened by a drop and its files.
    readonly property var zones: Shelf.zones(SettingsData.islandShelfZones)
    property string zoneOpen: ""
    property var zoneFiles: []
    property var devices: []
    property bool devicesLoaded: false
    readonly property var clouds: Shelf.clouds(SettingsData.islandShelfClouds)
    readonly property var formats: Shelf.formats(root.zoneFiles, root.have)
    readonly property string localsend: Shelf.localsend(root.have)
    // Where a drag over the card is (window coordinates, x < 0: none) and what lies under it, set by the card: a zone,
    // a row, and whether it has been held there long enough to make a folder.
    property point dragAt: Qt.point(-1, -1)
    readonly property var noHover: ({
            "zone": "",
            "row": "",
            "merge": false
        })
    property var hover: ({
            "zone": "",
            "row": "",
            "merge": false
        })
    readonly property string hotZone: root.zoneOpen || root.hover.zone

    // Undo and redo (Ctrl+Z, Ctrl+Shift+Z): the list before and after each change, and what it did on disk.
    property var hist: Shelf.history()

    // An action ended: the card's button for it flashes (a check, or red with a shake).
    signal finished(string id, bool ok)
    // A new row to name in place (a folder just made, a new text file).
    signal renameStarted

    readonly property bool active: root.enabled && root.items.length > 0
    readonly property int count: root.items.length
    readonly property string countText: root.count === 1 ? I18n.tr("1 file", "island shelf: one file on the shelf") : I18n.tr("%1 files", "island shelf: files on the shelf").arg(root.count)
    readonly property string hint: I18n.tr("Drag a file out to use it", "island shelf: how to take a file back")
    readonly property string subtitle: root.notice || (root.count ? I18n.tr("%1 · drag them anywhere", "island shelf card subtitle: how many files, and what to do with them").arg(root.countText) : I18n.tr("Nothing yet", "island shelf card subtitle: the shelf is empty"))

    readonly property var face: root.active && !root.token && !root.hidden ? {
        "id": "shelf",
        "source": "shelf",
        // A lasting state on the machine side: behind the newest machine change (seq 0), its dot waiting.
        "side": "machine",
        "kind": "shelf",
        "seq": -1,
        "icon": "stacks",
        "text": String(root.count),
        "valued": true,
        "title": root.countText,
        "detail": root.hint,
        "open": root.cardOpen,
        // Three columns: twice a popup's width, as far as the screen beside the bubble allows.
        "cardWidth": root.cardWidth,
        "shelf": root
    } : null
    readonly property real cardWidth: 2 * NotificationMetrics.popupWidth

    function label(key) {
        return Shelf.label(key, root.groups);
    }

    function save(keys, gs) {
        SessionData.setIslandShelf(Shelf.dump(keys, gs ?? root.groups));
    }
    // A change Ctrl+Z can take back; disk: what it did to files (trash, rename), undone with it.
    function change(keys, gs, disk) {
        const before = SessionData.islandShelf;
        root.save(keys, gs);
        root.hist = Shelf.record(root.hist, {
            "before": before,
            "after": SessionData.islandShelf,
            "disk": disk ?? null
        });
    }

    // Forget the links whose file is gone, and learn sizes and folders. Every screen asks under one id.
    function check() {
        const asked = Shelf.expand(root.items, root.groups);
        if (!asked.length)
            return;
        Proc.runCommand("islandShelf", ["stat", "-c", "%s %f %n", "--"].concat(asked), (output, exitCode) => {
            // 1: some are missing; anything else (stat not run) must not empty the shelf.
            if (exitCode !== 0 && exitCode !== 1)
                return;
            const f = Shelf.facts(output);
            root.facts = f;
            const kept = Shelf.prune(root.items, root.groups, f.paths, asked);
            root.save(kept.items, kept.groups);
        });
    }
    property Connections session: Connections {
        target: SessionData

        function onLoaded() {
            root.check();
        }
    }
    Component.onCompleted: {
        if (SessionData._hasLoaded)
            root.check();
    }

    function probe() {
        if (root.probed)
            return;
        root.probed = true;
        Proc.runCommand("islandShelfTools", ["sh", "-c", "for t; do command -v \"$t\" >/dev/null 2>&1 && echo \"$t\"; done", "sh"].concat(Shelf.tools), output => {
            root.have = String(output || "").split("\n").filter(t => t !== "");
        });
    }
    // The card shows: fresh facts, and the tools once.
    function showing() {
        root.check();
        root.probe();
    }

    function release() {
        const token = root.token;
        root.token = "";
        root.pinned = false;
        if (token)
            IslandActivityService.remove(token, "released");
    }

    function request() {
        // Set after add: a request replacing an earlier one of the shelf drops that one's token first.
        const token = IslandActivityService.add(root.sourceId, {
            "kind": "alert",
            "expanded": true,
            "screen": root.screenName,
            "data": {
                "shelf": root
            }
        });
        root.token = token;
        return !!token;
    }

    // The shortcut: the card in the island, or closed if it shows (island or bubble).
    // What it did: "open", "closed", or "refused" (the shelf is off, or the island would not take it).
    function toggle() {
        if (!root.enabled)
            return "refused";
        if ((root.token && !root.over) || root.cardOpen) {
            root.dismiss();
            return "closed";
        }
        root.hidden = false;
        if (!root.request())
            return "refused";
        root.pinned = true;
        root.showing();
        // Opened on purpose: the island takes the keyboard (arrows, Space, Ctrl+A, Ctrl+C).
        Qt.callLater(() => root.controller.requestToggle(true));
        return "open";
    }
    // A press in the card in the island: it takes the keyboard back (let go by a click beside it, controller.requestDismiss).
    function wake() {
        if (!root.token || !root.controller.expanded)
            return;
        root.controller.keyboardYielded = false;
        root.controller.keyboardDismissRequested = true;
    }
    // The island's own face clicked: the island grows into the card where it is, never into the bubble beside.
    function expand() {
        root.pinned = true;
        root.showing();
        root.controller.requestToggle(true);
    }

    // A drag over the island: the island opens on the card, its drop zone lit, over whatever it showed. A drag out of
    // the card itself comes back here too: the card stays as it is.
    function enter() {
        if (!root.enabled)
            return false;
        root.over = true;
        // A drop lands on the list it can see.
        root.peek = false;
        if (root.takingOut)
            return true;
        root.hidden = false;
        // A card already open on purpose stays open after the drop.
        root.byDrag = !root.token;
        if (root.byDrag)
            root.request();
        else
            root.settle();
        return true;
    }
    property bool byDrag: false
    function leave() {
        root.dragAt = Qt.point(-1, -1);
        root.hover = root.noHover;
        if (!root.over)
            return;
        root.over = false;
        if (root.byDrag && !root.takingOut)
            root.release();
    }
    function dragMove(p) {
        root.dragAt = p;
    }
    // Where the drop lands: a zone shows what it can do with the files (the card then stays open), a file held on
    // makes a folder with them, a folder takes them in, anywhere else keeps them (a drag from the card: nothing).
    function drop(urls) {
        const own = root.takingOut;
        // Our own drag ends here, even when its row (merged into a folder) is gone before it could say so.
        root.takingOut = false;
        const keys = own ? root.dragKeys.slice() : Shelf.paths(urls);
        const h = root.hover;
        root.over = false;
        root.dragAt = Qt.point(-1, -1);
        root.hover = root.noHover;
        if (!keys.length) {
            if (root.byDrag && !own)
                root.release();
            return false;
        }
        if (h.zone) {
            root.pinned = true;
            root.openZone(h.zone, Shelf.expand(keys, root.groups));
            root.wakeTimer.restart();
            return true;
        }
        const target = h.row && keys.indexOf(h.row) === -1 ? h.row : "";
        const base = own ? root.items : Shelf.add(root.items, keys).list;
        if (target && Shelf.isGroup(target)) {
            const s = Shelf.intoGroup(base, root.groups, Shelf.groupId(target), keys);
            root.change(s.items, s.groups);
            root.say(I18n.tr("In “%1”", "island shelf: files dropped into a shelf folder").arg(root.label(target)));
        } else if (target && h.merge) {
            root.makeFolder(base, target, keys);
        } else if (!own) {
            root.change(root.folder ? root.items : base, root.folder ? Shelf.intoGroup(root.items, root.groups, root.folder, keys).groups : root.groups);
        }
        root.check();
        if (root.byDrag && !root.pinned && !own)
            root.release();
        else
            root.wakeTimer.restart();
        return true;
    }

    function makeFolder(base, target, moved) {
        const s = Shelf.makeGroup(base, root.groups, target, moved, I18n.tr("New folder", "island shelf: a folder made by holding a file on another"), String(Date.now()));
        root.change(s.items, s.groups);
        root.pinned = root.pinned || !!root.token;
        root.sel = [s.key];
        root.cur = Math.max(0, root.shownItems.indexOf(s.key));
        root.renaming = s.key;
        root.renameStarted();
    }
    function newFolder() {
        const id = String(Date.now());
        const g = Object.assign({}, root.groups);
        g[id] = {
            "name": I18n.tr("New folder", "island shelf: a folder made by holding a file on another"),
            "items": []
        };
        root.query = "";
        root.filter = "all";
        root.folder = "";
        root.change(["group:" + id].concat(root.items), g);
        root.sel = ["group:" + id];
        root.cur = 0;
        root.renaming = "group:" + id;
        root.renameStarted();
    }
    // A new file lands in the Documents folder (or a paste's links), then on the shelf, in the open folder if any.
    function keep(paths, name) {
        if (!paths.length)
            return;
        const added = Shelf.add(root.items, paths).list;
        if (root.folder)
            root.change(root.items, Shelf.intoGroup(root.items, root.groups, root.folder, paths).groups);
        else
            root.change(added, root.groups);
        root.check();
        root.query = "";
        root.sel = [paths[0]];
        root.cur = Math.max(0, root.shownItems.indexOf(paths[0]));
        if (name) {
            root.renaming = paths[0];
            root.renameStarted();
        }
    }
    function newText() {
        Proc.runCommand("islandShelf:newtext", ["sh", root.script, "newtext", "--"], (output, exitCode) => {
            const p = String(output || "").trim();
            if (exitCode === 0 && p.startsWith("/"))
                root.keep([p], true);
        });
    }
    function paste() {
        Proc.runCommand("islandShelf:paste", ["sh", root.script, "paste", "--"], (output, exitCode) => {
            const lines = String(output || "").split("\n");
            if (exitCode !== 0) {
                root.say(I18n.tr("Nothing to paste", "island shelf: the clipboard holds no file, picture or text"));
                return;
            }
            const paths = lines[0] === "uris" ? Shelf.paths(lines.slice(1)) : lines.filter(l => l.startsWith("/"));
            root.keep(paths, false);
            root.say(I18n.tr("Pasted", "island shelf: clipboard content added"));
        });
    }

    // Remove from the shelf (the links only, never the files); Shift: to the trash (files only, a folder's links go).
    function removeChosen(trash) {
        const gone = root.focusKeys;
        if (!gone.length)
            return;
        const s = Shelf.withoutKeys(root.items, root.groups, gone, root.folder);
        root.sel = [];
        root.peek = false;
        if (!trash) {
            root.change(s.items, s.groups);
            root.cur = Shelf.step(root.cur, 0, root.shownItems.length);
            root.say(gone.length === 1 ? I18n.tr("Removed · Ctrl Z undoes it", "island shelf: one link removed") : I18n.tr("%1 removed · Ctrl Z undoes it", "island shelf: links removed").arg(gone.length));
            return;
        }
        const files = gone.filter(k => !Shelf.isGroup(k));
        Proc.runCommand("islandShelf:trash", ["sh", root.script, "trash", "--"].concat(files), (output, exitCode) => {
            const done = String(output || "").split("\n").filter(l => l.startsWith("/"));
            const left = gone.filter(k => Shelf.isGroup(k) || done.indexOf(k) !== -1);
            const t = Shelf.withoutKeys(root.items, root.groups, left, root.folder);
            root.change(t.items, t.groups, done.length ? {
                "op": "trash",
                "paths": done
            } : null);
            root.say(exitCode === 0 ? I18n.tr("In the trash · Ctrl Z restores", "island shelf: files put in the trash") : I18n.tr("Could not move to the trash", "island shelf: gio trash failed"));
        });
    }
    function clear() {
        root.change([], {});
        root.sel = [];
        root.folder = "";
    }
    // The close button: the card goes, the island comes back to its size, the shelf folds into its bubble beside it.
    function dismiss() {
        root.takingOut = false;
        root.cardOpen = false;
        root.closeExtras();
        root.release();
    }
    function closeExtras() {
        root.peek = false;
        root.renaming = "";
        root.closeZone();
    }

    function undo() {
        const r = Shelf.back(root.hist);
        if (!r.entry) {
            root.say(I18n.tr("Nothing to undo", "island shelf"));
            return;
        }
        root.hist = r.history;
        root.replay(r.entry, true);
    }
    function redo() {
        const r = Shelf.forth(root.hist);
        if (!r.entry) {
            root.say(I18n.tr("Nothing to redo", "island shelf"));
            return;
        }
        root.hist = r.history;
        root.replay(r.entry, false);
    }
    // The list goes back (or forward) once the files are where they were; a file the trash cannot give back is said.
    function replay(e, back) {
        const list = back ? e.before : e.after;
        const d = e.disk;
        root.sel = [];
        if (!d) {
            SessionData.setIslandShelf(list);
            root.say(back ? I18n.tr("Undone", "island shelf") : I18n.tr("Redone", "island shelf"));
            return;
        }
        let cmd;
        if (d.op === "trash")
            cmd = ["sh", root.script, back ? "untrash" : "trash", "--"].concat(d.paths);
        else
            cmd = ["sh", root.script, "rename", Shelf.name(back ? d.from : d.to), "--", back ? d.to : d.from];
        Proc.runCommand("islandShelf:replay", cmd, (output, exitCode) => {
            if (exitCode !== 0) {
                root.say(d.op === "trash" && back ? I18n.tr("Could not restore from the trash", "island shelf: undo of a trash failed") : I18n.tr("Could not undo", "island shelf"));
                return;
            }
            SessionData.setIslandShelf(list);
            root.check();
            root.say(back ? I18n.tr("Undone", "island shelf") : I18n.tr("Redone", "island shelf"));
        });
    }

    // F2: a shelf folder takes a new name here; a file is renamed on disk, in its folder, never over another.
    function rename(key, name) {
        root.renaming = "";
        const n = String(name ?? "").trim();
        if (!Shelf.validName(n) || n === root.label(key))
            return;
        if (Shelf.isGroup(key)) {
            const g = Object.assign({}, root.groups);
            g[Shelf.groupId(key)] = {
                "name": n,
                "items": g[Shelf.groupId(key)].items
            };
            root.change(root.items, g);
            return;
        }
        Proc.runCommand("islandShelf:rename", ["sh", root.script, "rename", n, "--", key], (output, exitCode) => {
            const [from, to] = String(output || "").trim().split("\t");
            if (exitCode !== 0 || from !== key || !to) {
                root.say(exitCode === 5 ? I18n.tr("A file has that name", "island shelf: rename refused, the name is taken") : I18n.tr("Could not rename", "island shelf"));
                return;
            }
            const swap = list => list.map(p => p === from ? to : p);
            const g = Object.assign({}, root.groups);
            for (const id in g)
                g[id] = {
                    "name": g[id].name,
                    "items": swap(g[id].items)
                };
            root.change(swap(root.items), g, {
                "op": "rename",
                "from": from,
                "to": to
            });
            root.sel = [to];
            root.check();
        });
    }
    function startRename() {
        if (root.focusKeys.length !== 1)
            return;
        root.renaming = root.focusKeys[0];
        root.renameStarted();
    }

    function setQuery(q) {
        root.query = q;
        root.cur = 0;
        root.anchor = 0;
        root.peek = false;
    }
    function setFilter(f) {
        root.filter = f;
        root.sel = [];
        root.cur = 0;
        root.peek = false;
    }
    function openFolder(key) {
        root.folder = Shelf.groupId(key);
        root.sel = [];
        root.cur = 0;
        root.query = "";
        root.peek = false;
    }
    function leaveFolder() {
        const back = "group:" + root.folder;
        root.folder = "";
        root.sel = [];
        root.peek = false;
        root.cur = Math.max(0, root.shownItems.indexOf(back));
    }
    function pick(i, add, range) {
        const s = Shelf.pick({
            "sel": root.chosen,
            "anchor": root.anchor
        }, root.shownItems, i, add, range);
        root.sel = s.sel;
        root.anchor = s.anchor;
        root.cur = i;
    }
    function sweep(base, from, to) {
        root.sel = Shelf.sweep(base, root.shownItems, from, to);
        root.cur = to;
    }
    function chooseAll() {
        root.sel = root.shownItems.slice();
    }
    function chooseNone() {
        root.sel = [];
    }
    function move(delta) {
        root.cur = Shelf.step(root.cur, delta, root.shownItems.length);
    }
    // Arrows (Shift extends from the anchor), Home and End: the keyboard's row, chosen.
    function go(to, extend) {
        const n = root.shownItems.length;
        if (!n)
            return;
        const i = Math.max(0, Math.min(n - 1, to));
        if (extend) {
            root.pick(i, false, true);
            return;
        }
        root.sel = [root.shownItems[i]];
        root.anchor = i;
        root.cur = i;
    }
    // Escape closes the innermost thing open, one at a time; never the card.
    function closeInner() {
        if (root.peek)
            root.peek = false;
        else if (root.zoneOpen)
            root.closeZone();
        else if (root.query)
            root.setQuery("");
        else if (root.chosen.length)
            root.sel = [];
        else if (root.folder)
            root.leaveFolder();
        else
            return false;
        return true;
    }

    // A zone opened by a drop (or a click with files chosen): what it can do with them, the card keeping them.
    function openZone(z, files) {
        if (!files.length)
            return;
        root.zoneFiles = files;
        root.zoneOpen = z;
        root.showing();
        if (z === "share")
            root.loadDevices();
    }
    function closeZone() {
        root.zoneOpen = "";
        root.zoneFiles = [];
    }
    function loadDevices() {
        root.devicesLoaded = false;
        if (root.have.indexOf("kdeconnect-cli") === -1) {
            root.devices = [];
            root.devicesLoaded = true;
            return;
        }
        Proc.runCommand("islandShelf:devices", ["kdeconnect-cli", "-a", "--id-name-only"], output => {
            root.devices = Shelf.devices(output);
            root.devicesLoaded = true;
        });
    }
    // One choice in an open zone; its button flashes, then the zone closes.
    function zoneAct(id, arg) {
        const files = root.zoneFiles;
        if (id === "localsend") {
            Quickshell.execDetached([root.localsend].concat(files));
            root.end("zone:" + id + ":" + arg, true, "");
            return;
        }
        if (id === "pickCloud") {
            root.pickFor = "pickCloud";
            root.pickFiles = files;
            root.picker.active = true;
            root.picker.item?.open();
            return;
        }
        root.runCommand(id, arg, files, "zone:" + id + ":" + arg);
    }
    property Timer zoneTimer: Timer {
        interval: Kit.feedbackMs
        onTriggered: root.closeZone()
    }
    // A drop opened the card without the keyboard (a drag never takes it): it asks for it once the drag is over.
    // shortcut: niri still keeps the keys with the drag source until a click in the card, upgrade if niri refocuses.
    // How long after the drop it asks: the drag is over by then.
    readonly property int wakeDelayMs: 200
    property Timer wakeTimer: Timer {
        interval: root.wakeDelayMs
        onTriggered: root.wake()
    }

    // Its face small in the island (taken back after an interruption, or shown before its card could load, the drag
    // then finding nothing to open): the island grows into the card again; it never rests there.
    function settle() {
        const c = root.controller;
        if (!Shelf.growsOpen(!!root.token && c.pluginActive && c.pluginToken === root.token, c.expanded, c.pluginExpandable))
            return;
        root.showing();
        c.requestExpand(root.pinned && !root.over);
    }
    property Connections island: Connections {
        target: root.controller

        function onExpandedChanged() {
            Qt.callLater(root.settle);
        }
        function onPluginTokenChanged() {
            Qt.callLater(root.settle);
        }
        function onPluginExpandableChanged() {
            Qt.callLater(root.settle);
        }
        function onActiveActivityChanged() {
            Qt.callLater(root.settle);
        }
    }

    property Connections activities: Connections {
        target: IslandActivityService

        function onInterrupted(token) {
            if (token === root.token && !root.over && !root.pinned)
                root.release();
        }
        function onDropped(token, reason) {
            if (token !== root.token)
                return;
            root.token = "";
            root.pinned = false;
            root.over = false;
        }
    }

    // A click on the bubble: its card opens in the bubble, where the bubble is.
    function showCard() {
        root.release();
        root.openCard(true);
    }
    function openCard(open) {
        root.cardOpen = open;
        if (open)
            root.showing();
    }
    function closeCard() {
        // A file being dragged out still needs its card; it closes when the drag ends outside.
        if (root.takingOut)
            return;
        root.cardOpen = false;
        root.closeExtras();
        if (!root.pinned)
            root.release();
    }
    function hold(inside) {
        root.inside = inside;
        if (inside)
            root.showing();
    }
    function takeOut(going, keys) {
        root.takingOut = going;
        if (going) {
            root.dragKeys = keys ?? [];
            return;
        }
        root.check();
        if (!root.inside && !root.pinned)
            root.closeCard();
    }

    // The files an action works on: the chosen ones (a folder: its files), else the whole shelf (or open folder).
    readonly property var targets: Shelf.expand(root.chosen.length ? root.chosen : root.level, root.groups)

    property Timer noticeTimer: Timer {
        interval: root.controller.transientTimeout
        onTriggered: root.notice = ""
    }
    function say(text) {
        root.notice = text;
        root.noticeTimer.restart();
    }
    function setBusy(id, on) {
        const b = Object.assign({}, root.busy);
        if (on)
            b[id] = true;
        else
            delete b[id];
        root.busy = b;
    }
    function end(id, ok, text) {
        root.setBusy(id, false);
        if (text)
            root.say(text);
        root.finished(id, ok);
        if (id.startsWith("zone:") && ok)
            root.zoneTimer.restart();
    }

    // A copy from the shelf never plays the "copied" bubble: the card's button and subtitle say it.
    function ownCopy() {
        Copy.markOwnCopy();
    }
    function copyText(id, text, said) {
        root.ownCopy();
        DMSService.sendRequest("clipboard.copy", {
            "text": text
        }, response => root.end(id, !response?.error, response?.error ? "" : said));
    }
    function copyFiles(id, paths) {
        const n = paths.length;
        if (!n)
            return;
        root.ownCopy();
        DMSService.sendRequest(n === 1 && Shelf.isImage(paths[0]) ? "clipboard.copyFile" : "clipboard.copyFiles", n === 1 && Shelf.isImage(paths[0]) ? {
            "filePath": paths[0]
        } : {
            "filePaths": paths
        }, response => root.end(id, !response?.error, response?.error ? "" : n === 1 ? I18n.tr("1 file copied", "island shelf: one kept file put on the clipboard") : I18n.tr("%1 files copied", "island shelf: kept files put on the clipboard").arg(n)));
    }
    // Ctrl+C and Enter: the button showing that key (its check is the confirmation), else copy the files, open them.
    function shortcut(key) {
        root.act(Shelf.shortcut(root.plan, key));
    }

    function show(path) {
        const url = Shelf.url(path).replace(/'/g, "%27");
        Proc.runCommand("islandShelfShow", ["gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1", "--object-path", "/org/freedesktop/FileManager1", "--method", "org.freedesktop.FileManager1.ShowItems", "['" + url + "']", "''"], (output, exitCode) => {
            if (exitCode !== 0)
                Qt.openUrlExternally(Shelf.url(path.slice(0, path.lastIndexOf("/")) || "/"));
            root.end("show", true, "");
        });
    }

    // The file playing, and the one asked while it played: Listen again on the same file stops it, on another file
    // stops it and plays that one.
    property string listening: ""
    property string nextListen: ""
    property Process player: Process {
        onExited: {
            root.end("listen", true, "");
            const next = root.nextListen;
            root.nextListen = "";
            if (next)
                root.listen(next);
        }
    }
    function listen(path) {
        if (root.player.running) {
            root.nextListen = path === root.listening ? "" : path;
            root.player.signal(15);
            return;
        }
        root.listening = path;
        const app = ["mpv", "ffplay", "pw-play"].find(t => root.have.indexOf(t) !== -1);
        root.player.command = app === "mpv" ? ["mpv", "--no-video", "--really-quiet", "--", path] : app === "ffplay" ? ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", path] : ["pw-play", path];
        root.setBusy("listen", true);
        root.player.running = true;
    }

    // The folder picker (move, copy, extract to, a cloud folder) and the file picker ("browse"), made only while open.
    property string pickFor: ""
    property var pickFiles: []
    property LazyLoader picker: LazyLoader {
        active: false

        FileBrowserModal {
            browserTitle: root.pickFor === "browse" ? I18n.tr("Add files to the shelf", "island shelf: file picker title") : I18n.tr("Choose a folder", "island shelf: folder picker title")
            mode: root.pickFor === "browse" ? "open" : "openFolder"
            multiple: root.pickFor === "browse"
            onAccepted: paths => root.picked(paths)
            onDialogClosed: Qt.callLater(() => root.picker.active = false)
        }
    }
    function pickFolder(id) {
        root.pickFor = id;
        root.pickFiles = root.targets;
        root.picker.active = true;
        root.picker.item?.open();
    }
    function picked(paths) {
        const list = (paths || []).map(p => String(p).replace(/^file:\/\//, "")).filter(p => p.startsWith("/"));
        if (root.pickFor === "browse") {
            root.keep(list, false);
            return;
        }
        if (!list.length)
            return;
        // A folder chosen from the Cloud zone becomes one of its synced folders, then the files go there.
        if (root.pickFor === "pickCloud") {
            const saved = Array.isArray(SettingsData.islandShelfClouds) ? SettingsData.islandShelfClouds : [];
            if (!saved.some(c => c?.path === list[0]))
                SettingsData.set("islandShelfClouds", saved.concat([{
                        "name": Shelf.name(list[0]),
                        "icon": "cloud",
                        "path": list[0]
                    }]));
            root.runCommand("copyTo", list[0], root.pickFiles, "zone:copyTo:" + list[0]);
            return;
        }
        root.runCommand(root.pickFor, list[0], root.pickFiles);
    }

    function runCommand(id, dest, files, flashId) {
        const fid = flashId ?? id;
        const c = Shelf.command(id, files ?? root.targets, root.have, root.script, dest);
        if (!c)
            return;
        if (c.detach) {
            Quickshell.execDetached(c.detach);
            root.end(fid, true, "");
            return;
        }
        root.setBusy(fid, true);
        Proc.runCommand("islandShelf:" + fid, c.run, (output, exitCode) => root.ran(id, fid, c.out, String(output || ""), exitCode), 0, Proc.noTimeout);
    }
    function ran(id, fid, out, output, exitCode) {
        if (exitCode !== 0) {
            root.end(fid, false, (id === "phone" || id === "sendTo") && exitCode === 3 ? I18n.tr("No phone connected", "island shelf: KDE Connect finds no device") : "");
            return;
        }
        const lines = output.split("\n").filter(l => l !== "");
        switch (out) {
        case "paths":
            root.keep(lines.filter(l => l.startsWith("/")), false);
            root.end(fid, true, id === "convertTo" ? I18n.tr("Converted, on the shelf", "island shelf: a converted file kept beside its source") : "");
            return;
        case "moved":
            {
                let list = root.items.slice();
                const g = Object.assign({}, root.groups);
                for (const l of lines) {
                    const [from, to] = l.split("\t");
                    list = list.map(p => p === from ? to : p);
                    for (const k in g)
                        g[k] = {
                            "name": g[k].name,
                            "items": g[k].items.map(p => p === from ? to : p)
                        };
                }
                root.save(list, g);
                root.sel = [];
                root.end(fid, true, "");
                return;
            }
        case "copy":
            if (!output.trim()) {
                root.end(fid, false, I18n.tr("No text found", "island shelf: OCR or PDF text found nothing"));
                return;
            }
            root.copyText(fid, id === "copySha" ? output.trim() : output, id === "copySha" ? I18n.tr("SHA-256 copied", "island shelf: an image disk's checksum put on the clipboard") : I18n.tr("Text copied", "island shelf: a file's text put on the clipboard"));
            return;
        case "notice":
            if (id === "verify") {
                const [state, sum] = (lines[0] || "").split(" ");
                root.end(fid, true, state === "ok" ? I18n.tr("SHA-256 matches its checksum file", "island shelf: an image disk checked against the sums beside it") : I18n.tr("SHA-256 %1…", "island shelf: an image disk's checksum, no sum file to compare").arg((sum || "").slice(0, 16)));
                return;
            }
            root.end(fid, true, I18n.tr("Size: %1", "island shelf: a folder's size on disk").arg(lines[0] || ""));
            return;
        }
        root.end(fid, true, id === "sendTo" ? I18n.tr("Sent", "island shelf: files sent to a device") : id === "copyTo" && fid.startsWith("zone:") ? I18n.tr("Copied to the cloud folder", "island shelf: files copied into a synced folder") : "");
    }

    // One action of the card, on the chosen files (or the whole shelf).
    function act(id) {
        const files = root.targets;
        if (!files.length)
            return;
        switch (id) {
        case "copyFiles":
        case "copyImage":
            root.copyFiles(id, files);
            return;
        case "copyPaths":
            root.copyText(id, files.join("\n"), files.length === 1 ? I18n.tr("Path copied", "island shelf: a kept file's path put on the clipboard") : I18n.tr("Paths copied", "island shelf: kept files' paths put on the clipboard"));
            return;
        case "wallpaper":
            SessionData.setWallpaper(files[0]);
            root.end(id, true, "");
            return;
        case "open":
            // A shelf folder opens in the list; files in their apps.
            if (root.focusKeys.length === 1 && Shelf.isGroup(root.focusKeys[0])) {
                root.openFolder(root.focusKeys[0]);
                return;
            }
            (root.chosen.length ? files : Shelf.expand(root.focusKeys, root.groups)).forEach(p => SessionService.openPath(p));
            root.end(id, true, "");
            return;
        case "openWith":
            DMSService.appPickerRequested({
                "target": files[0],
                "requestType": "file"
            });
            root.end(id, true, "");
            return;
        case "show":
            root.show(files[0]);
            return;
        case "listen":
            root.listen(files[0]);
            return;
        case "terminal":
            {
                const term = SessionData.resolveTerminal() || Shelf.first(root.have, Shelf.needs.terminal);
                Quickshell.execDetached({
                    "command": [term],
                    "workingDirectory": files[0]
                });
                root.end(id, true, "");
                return;
            }
        case "moveTo":
        case "copyTo":
        case "extractTo":
            root.pickFolder(id);
            return;
        }
        root.runCommand(id);
    }
}
