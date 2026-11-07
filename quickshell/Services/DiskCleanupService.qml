pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/DiskUsage.js" as DiskUsage
import "../Common/DiskCleanup.js" as Cleanup

// The disk card's cleanup (DiskCleanup.js): what each suggestion would free, the trash (never a deletion) with its Undo,
// emptying it, and the tools' own prune. Reads only until a cleanup is asked; nothing goes out to the network.
Singleton {
    id: root

    // The card's cleanup: what each suggestion would free (DiskCleanup.rows), measured when the card opens (at most
    // every DiskUsage.freshMs) and again after each cleanup. Reads only; nothing goes out to the network.
    // A tool that never answers is let go after this long, and blocks the next measure no longer.
    readonly property int toolTimeoutMs: 60000
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string downloads: String(StandardPaths.writableLocation(StandardPaths.DownloadLocation)).replace(/^file:\/\//, "")
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || (root.home + "/.local/share")) + "/Trash"
    property var facts: ({})
    property real factsAt: 0
    property int factsPending: 0
    // Deletions the card makes itself, counted since start: each screen's trash bubble lets that many pass (the card
    // shows their Undo), keeping its own count of those it let pass.
    property int quietTrash: 0

    function _fact(key, value) {
        const f = Object.assign({}, root.facts);
        f[key] = value;
        root.facts = f;
        root.factsPending = Math.max(0, root.factsPending - 1);
    }

    function measure(force) {
        const age = Date.now() - root.factsAt;
        // A tool that never answers does not block the next measure for long.
        if (!root.home || (root.factsPending > 0 && age < root.toolTimeoutMs) || (!force && root.factsAt && age < DiskUsage.freshMs))
            return;
        root.factsAt = Date.now();
        root.factsPending = 5;
        const caches = Cleanup.safeCaches(root.home);
        Proc.runCommand("diskFactsDu", ["du", "-0sb", "--", root.trashDir + "/files"].concat(caches), out => {
            const s = Cleanup.sizes(out);
            root._fact("trash", s.filter(i => i.path === root.trashDir + "/files").reduce((a, i) => a + i.size, 0));
            root._fact("caches", s.filter(i => caches.indexOf(i.path) !== -1 && i.size > 0));
        }, 0, root.toolTimeoutMs);
        // shortcut: "not opened" = a file's atime over 180 days, a folder's mtime (listing it, as du does, bumps its atime);
        // a noatime mount reads as never opened since it was written.
        Proc.runCommand("diskFactsOld", ["find", root.downloads, "-mindepth", "1", "-maxdepth", "1", "(", "(", "-type", "d", "-mtime", "+180", ")", "-o", "(", "!", "-type", "d", "-atime", "+180", ")", ")", "-exec", "du", "-0sb", "--", "{}", "+"], out => root._fact("old", Cleanup.sizes(out).filter(i => Cleanup.canTrash(i.path, root.home))), 0, root.toolTimeoutMs);
        // Through env: a tool that is not installed exits 127 and answers, where a missing binary never calls back.
        Proc.runCommand("diskFactsFlatpakRt", ["env", "flatpak", "list", "--runtime", "--columns=application,branch,installation,size"], rt => {
            Proc.runCommand("diskFactsFlatpakApps", ["env", "flatpak", "list", "--app", "--columns=application,runtime"], apps => root._fact("flatpak", Cleanup.flatpakUnused(rt, apps)), 0);
        }, 0);
        Proc.runCommand("diskFactsPodman", ["env", "podman", "images", "--filter", "dangling=true", "--format", "json"], pod => {
            Proc.runCommand("diskFactsDocker", ["env", "docker", "images", "--filter", "dangling=true", "--format", "{{json .}}"], dock => {
                const p = Cleanup.images(pod);
                const d = Cleanup.images(dock);
                root._fact("images", {
                    "count": p.count + d.count,
                    "podman": p.count,
                    "docker": d.count,
                    "size": p.size + d.size
                });
            }, 0);
        }, 0);
    }

    // To the trash (never deleted): done(entries) gets what Undo restores, one {name, dir} per path put there.
    function trash(paths, done) {
        const list = paths.filter(p => Cleanup.canTrash(p, root.home, root.trashDir));
        if (!list.length)
            return done([]);
        root.quietTrash += list.length;
        Proc.runCommand(null, [Proc.dmsBin, "trash", "put"].concat(list), (out, code) => {
            const put = String(out || "").split("\n").filter(p => list.indexOf(p) !== -1);
            root.quietTrash = Math.max(0, root.quietTrash - (list.length - put.length));
            if (code !== 0)
                ToastService.showError(I18n.tr("Failed to move to trash"), list.filter(p => put.indexOf(p) === -1).join("\n"));
            Proc.runCommand(null, [Proc.dmsBin, "trash", "list", "--json"], json => done(put.map(p => Cleanup.trashed(json, p)).filter(e => !!e)), 0);
            root.measure(true);
        }, 0, 120000);
    }

    function restore(entries) {
        let left = entries.length;
        for (const e of entries)
            Proc.runCommand(null, [Proc.dmsBin, "trash", "restore", "--trash-dir", e.dir, e.name], (out, code) => {
                if (code !== 0)
                    ToastService.showError(I18n.tr("Failed to restore from trash", "island trash bubble undo error"), e.name);
                if (--left === 0)
                    root.measure(true);
            }, 0);
    }

    function emptyTrash() {
        Proc.runCommand(null, [Proc.dmsBin, "trash", "empty"], (out, code) => {
            if (code !== 0)
                ToastService.showError(I18n.tr("Failed to empty trash"), out || "");
            root.measure(true);
        }, 0, Proc.noTimeout);
    }

    // The tools' own cleanup, after the card's hold: unused Flatpak runtimes, dangling podman / docker images.
    function prune() {
        const f = root.facts;
        const runs = [];
        if (f.flatpak?.refs?.length)
            runs.push(["flatpak", "uninstall", "--unused", "--noninteractive", "-y"]);
        if (f.images?.podman)
            runs.push(["podman", "image", "prune", "-f"]);
        if (f.images?.docker)
            runs.push(["docker", "image", "prune", "-f"]);
        let left = runs.length;
        for (const cmd of runs)
            Proc.runCommand(null, cmd, (out, code) => {
                if (code !== 0)
                    ToastService.showError(I18n.tr("Cleanup failed", "island disk card: a cleanup command failed"), cmd.join(" "));
                if (--left === 0)
                    root.measure(true);
            }, 0, Proc.noTimeout);
    }
}
