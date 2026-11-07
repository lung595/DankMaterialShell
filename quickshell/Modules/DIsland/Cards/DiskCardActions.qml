pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskUsage.js" as DiskUsage
import "../../../Common/DiskCleanup.js" as Cleanup
import "../../../Common/IslandShelf.js" as Shelf

// The disk card's actions on its chosen item (BubbleCardDisk): trash (never a deletion) with its Undo, open, put on the
// shelf. The trash answer may come after the card closed: it holds the cleanup service, not the card.
QtObject {
    id: actions

    required property BubbleCardDisk card
    required property IslandUndoButton undoButton
    required property BubbleAction shelfAction

    function trash(items, label) {
        const paths = items.map(i => i.path).filter(p => Cleanup.canTrash(p, card.clean.home));
        if (!paths.length || card.pend)
            return;
        const nodes = items.map(i => i.node).filter(n => !!n);
        nodes.forEach(n => DiskUsage.detach(n));
        card.svc.revision++;
        const p = {
            "label": label,
            "nodes": nodes,
            "entries": null,
            "undone": false
        };
        card.pend = p;
        card.sel = null;
        card.hovered = null;
        actions.undoButton.start();
        // The closure, not the card: the answer may come after the card closed.
        const clean = card.clean;
        clean.trash(paths, entries => {
            p.entries = entries;
            if (p.undone)
                clean.restore(entries);
        });
    }

    function undoTrash() {
        const p = card.pend;
        card.pend = null;
        if (!p)
            return;
        p.undone = true;
        p.nodes.forEach(n => DiskUsage.attach(n));
        card.svc.revision++;
        if (p.entries)
            card.clean.restore(p.entries);
        if (p.nodes.length === 1) {
            card.cur = p.nodes[0].parent;
            card.pick(p.nodes[0]);
        }
    }

    function trashChosen() {
        if (card.sel && Cleanup.canTrash(card.sel.path, card.clean.home))
            actions.trash([card.sel], card.sel.name);
    }

    function openChosen() {
        const s = card.sel;
        if (!s)
            return;
        if (s.dir)
            Qt.openUrlExternally(Shelf.url(s.path));
        else
            card.bubble?.shelf?.show(s.path);
    }

    function shelveChosen() {
        const sh = card.bubble?.shelf;
        if (!card.sel || !sh)
            return;
        sh.change(Shelf.add(sh.items, [card.sel.path]).list, sh.groups);
        sh.check();
        actions.shelfAction.flash(true);
    }
}
