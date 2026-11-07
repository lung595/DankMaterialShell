pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskUsage.js" as DiskUsage
import "../../../Common/DiskCleanup.js" as Cleanup

// Disk bubble's open card (kind "disk", "almost full"): statfs line and gauge, the live scan's progress, what a cleanup
// would free, then the folder as a treemap (default), rings or its largest files, filled by DiskUsageService while du runs.
// Click a folder to go in (crumbs to go back), hover for its detail; arrows, Enter, Backspace / Escape and Del once the
// card has the keyboard (a click in it). Cells glide to their new place as sizes or the folder change (exponential
// approach, as the web mockup); reduced motion puts them in place at once, the service then applies in steps.
// Opening it scans the full folder (DiskSpaceService.lowFolder) unless its scan is still fresh (DiskUsage.freshMs).
// C29: built on BubbleCardBase; K1: its breathing dot runs only while du runs and the card is seen.
BubbleCardBase {
    id: card

    readonly property var svc: DiskUsageService
    readonly property var clean: DiskCleanupService
    // The service only ever scans / or the home folder (no user path on screen).
    readonly property string place: card.svc.path === "/" ? "/" : "~"

    Component.onCompleted: {
        const folder = DiskSpaceService.lowFolder;
        if (folder && !card.svc.scanning && (card.svc.path !== folder || Date.now() - card.svc.scannedAt > DiskUsage.freshMs))
            card.svc.scan(folder);
        card.clean.measure(false);
    }
    // A closed card never keeps the keyboard from the windows.
    Component.onDestruction: {
        if (card.keysTaken)
            card.bubble?.keyboard?.(null);
    }
    onVisibleChanged: {
        if (card.visible || !card.keysTaken)
            return;
        card.keysTaken = false;
        card.bubble?.keyboard?.(null);
    }
    readonly property bool reduce: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    readonly property real usedRatio: svc.fsSize > 0 ? svc.fsUsed / svc.fsSize : 0
    readonly property color alarm: card.usedRatio >= 0.9 ? Theme.error : Theme.primary

    // The folder shown (a node of svc.tree), the chosen item ({path, name, size, dir, node}) and the hovered node.
    property var cur: null
    property var sel: null
    property var hovered: null
    // The largest list shows the old downloads only (the cleanup's Review).
    property bool oldOnly: false
    // The last trash, while its Undo runs: {label, nodes, entries, undone}.
    property var pend: null
    property bool keysTaken: false
    property bool cleanupOpen: false

    // The shown folder, back to the top when a new scan or a trash took it away.
    readonly property var folder: {
        card.svc.revision;
        const c = card.cur;
        return c && DiskUsage.find(card.svc.tree, card.svc.path, DiskUsage.pathOf(c, card.svc.path)) === c ? c : card.svc.tree;
    }
    readonly property var chosenNode: card.sel?.node ?? null

    function shortPath(p) {
        return card.clean.home && p.indexOf(card.clean.home) === 0 ? "~" + p.slice(card.clean.home.length) : p;
    }
    function pick(n) {
        if (!n || n.other) {
            card.sel = null;
            return;
        }
        card.sel = {
            "path": DiskUsage.pathOf(n, card.svc.path),
            "name": n.name,
            "size": n.size,
            "dir": !!n.children,
            "node": n
        };
        chart.requestPaint();
    }
    function enter(n) {
        if (!n || n.other || !n.children || n.size <= 0)
            return false;
        card.cur = n;
        card.sel = null;
        card.hovered = null;
        chart.requestPaint();
        return true;
    }
    function up() {
        const f = card.folder;
        if (!f.parent)
            return false;
        card.cur = f.parent;
        card.pick(f);
        return true;
    }
    // From the list: the item in its folder, on the treemap.
    function reveal(item) {
        if (!item?.node)
            return;
        card.svc.mode = "tree";
        card.oldOnly = false;
        card.cur = item.node.parent;
        card.pick(item.node);
    }
    // Its buttons take the focus by Tab only: a clicked one may go away under the pointer (a cleanup row) with the keys.
    function takeKeys() {
        if (card.activeFocus || !card.bubble?.keyboard)
            return;
        card.keysTaken = true;
        card.bubble.keyboard(card);
    }

    readonly property DiskCardActions act: DiskCardActions {
        card: card
        undoButton: undo
        shelfAction: shelfButton
    }

    keepsClicks: true
    onBodyPressed: card.takeKeys()
    focus: true
    Keys.onPressed: event => card.keys.press(event)
    readonly property DiskCardKeys keys: DiskCardKeys {
        card: card
        listView: largestList
        chartView: chart
    }

    StyledText {
        width: parent.width
        text: card.svc.fsSize > 0 ? I18n.tr("%1 · %2 used of %3", "island disk card: folder, used size, file system size").arg(card.place).arg(DiskUsage.fmt(card.svc.fsUsed)).arg(DiskUsage.fmt(card.svc.fsSize)) : card.place
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        elide: Text.ElideRight
    }

    // statfs: used share of the whole file system, known before the scan.
    Rectangle {
        width: parent.width
        height: Theme.spacingXS * 1.5
        radius: height / 2
        color: Theme.surfaceContainerHigh

        Rectangle {
            width: parent.width * Math.min(1, card.usedRatio)
            height: parent.height
            radius: parent.radius
            color: card.alarm
        }
    }

    DiskScanStatus {
        card: card
    }

    // What a cleanup would free: folded under its total, each row with its own button.
    DiskCleanupPanel {
        card: card
    }

    DButtonGroup {
        width: parent.width
        visible: !card.cleanupOpen
        fillWidth: true
        checkEnabled: false
        Accessible.role: Accessible.Grouping
        Accessible.name: I18n.tr("Chart type", "island disk card: chart switch")
        model: [{
                "text": I18n.tr("Treemap", "island disk card: chart switch"),
                "icon": "dashboard"
            }, {
                "text": I18n.tr("Rings", "island disk card: chart switch"),
                "icon": "donut_large"
            }, {
                "text": I18n.tr("Largest", "island disk card: chart switch, the biggest files"),
                "icon": "format_list_numbered"
            }]
        currentIndex: card.svc.mode === "sun" ? 1 : card.svc.mode === "list" ? 2 : 0
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            card.svc.mode = index === 1 ? "sun" : index === 2 ? "list" : "tree";
            card.oldOnly = false;
        }
    }

    // Crumbs: back, then the folders down to the shown one, the end kept in sight.
    DiskCrumbs {
        chartView: chart
        card: card
    }

    Rectangle {
        width: parent.width
        visible: !card.cleanupOpen
        height: Math.round(width * 0.56)
        radius: Theme.cornerRadius
        color: Theme.surface
        clip: true

        DiskChartView {
            id: chart
            card: card
        }

        DiskLargestList {
            id: largestList
            card: card
        }
    }

    // What the pointer is on (else the chosen item, else the folder): its name, size and share of its folder.
    StyledText {
        width: parent.width
        visible: !card.cleanupOpen
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        elide: Text.ElideMiddle
        text: {
            card.svc.revision;
            const n = card.hovered ?? card.chosenNode ?? card.folder;
            if (!n || n.size <= 0)
                return card.sel ? I18n.tr("%1 · %2", "island disk card detail: name, size").arg(card.sel.name).arg(DiskUsage.fmt(card.sel.size)) : " ";
            const share = n.parent && n.parent.size > 0 ? Math.round(n.size / n.parent.size * 100) : 100;
            return I18n.tr("%1 · %2 · %3 % of its folder", "island disk card detail: name, size, share of the parent folder").arg(n.parent ? n.name : card.place).arg(DiskUsage.fmt(n.size)).arg(share);
        }
    }

    // The keys, always in sight.
    DiskKeyHints {
        card: card
    }

    actions: [
        BubbleAction {
            focusPolicy: Qt.TabFocus
            visible: !card.pend && !card.cleanupOpen
            enabled: !!card.sel && Cleanup.canTrash(card.sel.path, card.clean.home)
            // Room for its key beside the label.
            weight: 1.5
            iconName: "delete"
            text: I18n.tr("Trash", "island disk card: move the chosen item to the trash")
            keys: [I18n.tr("Del", "keyboard key")]
            Accessible.name: I18n.tr("Move to trash", "island disk card: screen reader name of Trash")
            onClicked: card.act.trashChosen()
        },
        BubbleAction {
            focusPolicy: Qt.TabFocus
            visible: !card.pend && !card.cleanupOpen
            enabled: !!card.sel
            iconName: "folder_open"
            text: I18n.tr("Open", "island disk card: show the chosen item in the file manager")
            Accessible.name: I18n.tr("Open in Files", "island disk card: screen reader name of Open")
            onClicked: card.act.openChosen()
        },
        BubbleAction {
            focusPolicy: Qt.TabFocus
            id: shelfButton

            visible: !card.pend && !card.cleanupOpen
            enabled: !!card.sel && !!card.bubble?.shelf
            iconName: "stacks"
            text: I18n.tr("Shelf", "island disk card: put the chosen item on the shelf")
            Accessible.name: I18n.tr("Put on shelf", "island disk card: screen reader name of Shelf")
            onClicked: card.act.shelveChosen()
        },
        IslandUndoButton {
            focusPolicy: Qt.TabFocus
            id: undo

            visible: !!card.pend
            text: card.pend ? I18n.tr("Undo · %1", "island disk card: restore what was just trashed, its name").arg(card.pend.label) : I18n.tr("Undo")
            Accessible.name: I18n.tr("Undo")
            onClicked: card.act.undoTrash()
            onExpired: card.pend = null
        }
    ]
}
