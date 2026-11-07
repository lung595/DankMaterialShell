pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtMultimedia
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Services
import qs.Modules.DIsland.Kit
import qs.Modules.DDash
import "../../../Common/IslandShelf.js" as Shelf
import "../../../Common/IslandTransfer.js" as Transfer
import "../../../Common/IslandKit.js" as Kit

// The shelf's card (IslandShelfSource), in its bubble and in the island: shelves, direction D of the 01/11 redesign
// (A's gallery and C's pile, sorted on their own). At rest only the header and one shelf per family (Images, Documents,
// Folders, Archives, Media; islandShelfGroup), its title quiet, its tiles 96 px with a rich preview (a picture, a PDF's
// first page, a video's frame) and the name under each; a shelf past the card's edge scrolls sideways with the wheel,
// its outer tiles shrinking and fading like the dashboard's wallpaper carousel. A tile dragged takes its file, a
// shelf's title its family, the count every file. A hover shows the size and
// type, Preview and Remove; a click chooses, then three of the choice's actions come up under the shelves, the rest
// behind "⋯" or a right click. The drop zones (Convert, Share, Cloud) stay hidden until a drag: then they rise in a
// band at the bottom, the one under the pointer grows to half of it on a spring. A tile held ~0.6 s on another makes a
// shelf folder. Keys show only once a key is pressed, or in the "?" sheet (C8 and C9 revised for the shelf, 01/11).
// Close, or Super+S, is the only way out (C7).
Item {
    id: card

    property var bubble: null
    readonly property var shelf: card.bubble?.shelf ?? null
    readonly property var list: card.shelf?.shownItems ?? []
    readonly property var chosen: card.shelf?.chosen ?? []
    readonly property var dirs: card.shelf?.facts?.dirs ?? []
    readonly property bool empty: (card.shelf?.count ?? 0) === 0
    readonly property bool lit: card.shelf?.over ?? false
    readonly property bool shift: card.shelf?.shiftHeld ?? false
    // The card's grid: the same margin between its blocks as around the card.
    readonly property real gap: NotificationMetrics.cardPadding
    // Menu rows and the band's choices: a little flatter than a card button.
    readonly property real smallButton: Theme.buttonHeightS - Theme.spacingS
    // The shelves: one row each, tiles four icons wide (96 px; less on a card too narrow for five) a small gap apart,
    // the row inset from the card's edges by the grid's gap; past the edge the row scrolls sideways (the wheel), its
    // outer tiles shrinking and fading like the dashboard's wallpaper carousel. Under each tile, its name.
    readonly property int perRow: 5
    readonly property real tileSize: Math.min(Theme.iconSize * 4, (card.width - 2 * card.gap - (card.perRow - 1) * Theme.spacingS) / card.perRow)
    // A tight rhythm: three shelves of one row fit under the island's ceiling (480 px a face).
    readonly property real nameHeight: Theme.spacingXXS + Theme.fontSizeSmall + Theme.spacingXXS
    readonly property real cellHeight: card.tileSize + card.nameHeight
    readonly property real titleHeight: Theme.fontSizeSmall + Theme.spacingXXS
    readonly property real shelfHeight: card.titleHeight + Theme.spacingXXS + card.cellHeight
    // Three shelves of one row in view, or what the room allows; past that the wheel scrolls under an edge fade (L8).
    readonly property int shownShelves: 3
    // The most the card may take: the island's ceiling (IslandShelfActivity), none in a bubble.
    property real roomHeight: Number.POSITIVE_INFINITY
    readonly property var shelves: card.shelf?.shelves ?? []
    readonly property var drawnRows: Shelf.shelfRows(card.shelves)
    readonly property var shelfNames: ({
            "images": I18n.tr("Images", "island shelf: the shelf of pictures"),
            "documents": I18n.tr("Documents", "island shelf: the shelf of PDFs, texts and office files"),
            "folders": I18n.tr("Folders", "island shelf: the shelf of folders and shelf folders"),
            "archives": I18n.tr("Archives", "island shelf: the shelf of archives and disk images"),
            "media": I18n.tr("Media", "island shelf: the shelf of videos and sounds"),
            "all": I18n.tr("All", "island shelf: the one shelf when files are not grouped by kind")
        })
    // Three of the choice's actions in the row, the rest under "⋯" (C11).
    readonly property int planShown: 3

    // Keys are drawn only after a key was pressed in the card (or it was opened by its shortcut); a press of the pointer
    // hides them again (C9, 01/11), and so does a keyboard handed back to the windows.
    property bool keyboard: card.shelf?.keyOpened ?? false
    readonly property bool yielded: !!card.shelf?.token && (card.shelf?.controller?.keyboardYielded ?? false)
    onYieldedChanged: card.keyboard = !card.yielded && !!card.shelf?.keyOpened
    property bool sweeping: false
    property var sweepBase: []
    property int sweepFrom: -1
    // After a tile's ×, the tile sliding under the still pointer shows its buttons only once the pointer moves (a second
    // click must not remove it too); quietAt: where the pointer was, in the window.
    property bool quiet: false
    property point quietAt
    // The open menu: "shelf" (a right click on the room), "file" (on a tile), "more" (the "⋯" button), "" none.
    property string menu: ""
    property point menuAt: Qt.point(0, 0)
    // The "?" sheet of every key.
    property bool sheet: false
    // A synced folder of the Cloud zone held long enough under a drag splits it into one target per folder.
    property bool cloudSplit: false
    readonly property bool finding: search.activeFocus || (card.shelf?.query ?? "") !== ""

    signal activated(var bubble)
    signal dismissed(var bubble)

    // The height follows what shows (L12); an open menu may reach below the tiles, the card grows to hold it.
    implicitHeight: Math.max(content.implicitHeight, menuBox.visible ? menuBox.y + menuBox.height : 0)
    onChosenChanged: card.menu = ""

    // The keys shown for a shortcut, in DMS's words.
    readonly property var keyNames: ({
            "copy": [I18n.tr("Ctrl", "keyboard key"), "C"],
            "enter": [I18n.tr("Enter", "keyboard key")]
        })
    function keysFor(id) {
        const k = card.shelf?.keyed?.[id];
        return k ? card.keyNames[k] : [];
    }
    // A tile's click; letting the only chosen tile go waits out a double-click (Shelf.letsGo), which opens the tile
    // aimed at, chosen or not.
    function click(i, key, add, range) {
        if (!Shelf.letsGo(card.chosen, key, add, range))
            return card.shelf?.pick(i, add, range);
        letGo.at = i;
        letGo.restart();
    }
    function openTile(i) {
        letGo.stop();
        card.shelf?.go(i, false);
        card.shelf?.shortcut("enter");
    }
    Timer {
        id: letGo

        property int at: -1

        interval: Qt.styleHints.mouseDoubleClickInterval
        onTriggered: card.shelf?.pick(letGo.at, false, false)
    }
    // Labels and icons of every action, as the owner's table words them.
    readonly property var labels: ({
            "copyFiles": card.chosen.length || (card.shelf?.aside?.length ?? 0) ? I18n.tr("Copy", "island shelf action: copy the chosen files") : I18n.tr("Copy all", "island shelf action: copy every kept file"),
            "phone": I18n.tr("Send to phone", "island shelf action: KDE Connect share"),
            "zip": I18n.tr("Compress to .zip", "island shelf action"),
            "moveTo": I18n.tr("Move to…", "island shelf action: pick a folder"),
            "copyTo": I18n.tr("Copy to…", "island shelf action: pick a folder"),
            "copyPaths": (card.shelf?.targets?.length ?? 0) > 1 ? I18n.tr("Copy paths", "island shelf action") : I18n.tr("Copy path", "island shelf action"),
            "renameSeries": I18n.tr("Rename in series", "island shelf action: bulk rename"),
            "copyImage": I18n.tr("Copy image", "island shelf action"),
            "annotate": I18n.tr("Annotate", "island shelf action: draw on the picture"),
            "wallpaper": I18n.tr("Set as wallpaper", "island shelf action"),
            "ocr": I18n.tr("Extract text (OCR)", "island shelf action"),
            "toPng": I18n.tr("Convert to PNG", "island shelf action"),
            "toJpg": I18n.tr("Convert to JPG", "island shelf action"),
            "toWebp": I18n.tr("Convert to WebP", "island shelf action"),
            "shrinkImage": I18n.tr("Reduce size", "island shelf action: smaller pictures"),
            "rotate": I18n.tr("Rotate", "island shelf action"),
            "openWith": I18n.tr("Open with…", "island shelf action"),
            "open": I18n.tr("Open", "island shelf action"),
            "frame": I18n.tr("Extract a frame", "island shelf action: a still from a video"),
            "shrinkVideo": I18n.tr("Shrink to share", "island shelf action: a smaller video"),
            "gif": I18n.tr("Convert to GIF", "island shelf action"),
            "mute": I18n.tr("Remove sound", "island shelf action"),
            "show": I18n.tr("Show in folder", "island shelf action"),
            "listen": card.shelf?.busy?.listen ? I18n.tr("Stop", "island shelf action: stop playing the sound") : I18n.tr("Listen here", "island shelf action"),
            "mp3": I18n.tr("Convert to MP3", "island shelf action"),
            "copyText": I18n.tr("Copy Text", "island shelf action: a PDF's text"),
            "shrinkPdf": I18n.tr("Lighten PDF", "island shelf action: a smaller PDF"),
            "pdfImages": I18n.tr("Pages to images", "island shelf action"),
            "print": I18n.tr("Print", "island shelf action"),
            "copyContent": I18n.tr("Copy Text", "island shelf action: a text file's contents"),
            "editor": I18n.tr("Open in editor", "island shelf action"),
            "extractHere": I18n.tr("Extract here", "island shelf action"),
            "viewArchive": I18n.tr("View contents", "island shelf action: an archive's list"),
            "extractTo": I18n.tr("Extract to…", "island shelf action: pick a folder"),
            "writeUsb": I18n.tr("Write to USB stick", "island shelf action: opens the disk writing app"),
            "verify": I18n.tr("Verify (SHA-256)", "island shelf action"),
            "mount": I18n.tr("Mount", "island shelf action: a disk image"),
            "copySha": I18n.tr("Copy SHA-256", "island shelf action"),
            "terminal": I18n.tr("Terminal here", "island shelf action"),
            "folderSize": I18n.tr("Folder size", "island shelf action"),
            "pdfFromImages": I18n.tr("Combine into PDF", "island shelf action"),
            "contactSheet": I18n.tr("Make a contact sheet", "island shelf action"),
            "mergePdf": I18n.tr("Merge into one PDF", "island shelf action")
        })
    readonly property var icons: ({
            "copyFiles": "content_copy",
            "phone": "phone_iphone",
            "zip": "folder_zip",
            "moveTo": "drive_file_move",
            "copyTo": "file_copy",
            "copyPaths": "link",
            "renameSeries": "edit_note",
            "copyImage": "content_copy",
            "annotate": "draw",
            "wallpaper": "wallpaper",
            "ocr": "document_scanner",
            "toPng": "image",
            "toJpg": "image",
            "toWebp": "image",
            "shrinkImage": "photo_size_select_small",
            "rotate": "rotate_right",
            "openWith": "apps",
            "open": "open_in_new",
            "frame": "photo_camera",
            "shrinkVideo": "compress",
            "gif": "gif_box",
            "mute": "volume_off",
            "show": "folder_open",
            "listen": card.shelf?.busy?.listen ? "stop" : "play_arrow",
            "mp3": "music_note",
            "copyText": "content_copy",
            "shrinkPdf": "compress",
            "pdfImages": "collections",
            "print": "print",
            "copyContent": "content_copy",
            "editor": "edit",
            "extractHere": "unarchive",
            "viewArchive": "list",
            "extractTo": "drive_file_move",
            "writeUsb": "usb",
            "verify": "verified",
            "mount": "eject",
            "copySha": "tag",
            "terminal": "terminal",
            "folderSize": "data_usage",
            "pdfFromImages": "picture_as_pdf",
            "contactSheet": "grid_view",
            "mergePdf": "merge"
        })
    readonly property var kindLabels: ({
            "all": I18n.tr("The whole shelf", "island shelf: nothing chosen, actions apply to every file"),
            "image": I18n.tr("A picture", "island shelf: one picture chosen"),
            "video": I18n.tr("A video", "island shelf: one video chosen"),
            "audio": I18n.tr("A sound", "island shelf: one sound chosen"),
            "doc": I18n.tr("A PDF", "island shelf: one PDF chosen"),
            "text": I18n.tr("A text or code", "island shelf: one text file chosen"),
            "archive": I18n.tr("An archive", "island shelf: one archive chosen"),
            "iso": I18n.tr("A disk image", "island shelf: one ISO chosen"),
            "folder": I18n.tr("A folder", "island shelf: one folder chosen"),
            "images": I18n.tr("Several pictures", "island shelf: pictures chosen"),
            "pdfs": I18n.tr("Several PDFs", "island shelf: PDFs chosen"),
            "mixed": I18n.tr("Several files", "island shelf: files of different kinds chosen"),
            "file": I18n.tr("A file", "island shelf: one file of no known kind chosen")
        })

    function meta(path) {
        const n = card.shelf?.facts?.size?.[path];
        const ext = Shelf.extension(path).toUpperCase();
        if (card.dirs.indexOf(path) !== -1)
            return I18n.tr("Folder", "island shelf row: a kept folder");
        if (n === undefined)
            return ext;
        const b = Transfer.bytes(n);
        const size = b.value.toLocaleString(Qt.locale(), "f", b.decimals) + " " + b.unit;
        return ext ? size + " · " + ext : size;
    }

    function metaOf(key) {
        if (!Shelf.isGroup(key))
            return card.meta(key);
        const n = card.shelf?.groups?.[Shelf.groupId(key)]?.items?.length ?? 0;
        return I18n.tr("%1 items · Shelf folder", "island shelf row: a folder of the shelf (links, nothing on disk)").arg(n);
    }
    readonly property IslandShelfZones zones: IslandShelfZones {}
    function zoneHint(id) {
        return ({
                "convert": I18n.tr("Change the format", "island shelf drop zone hint"),
                "share": I18n.tr("To a device", "island shelf drop zone hint"),
                "cloud": I18n.tr("Synced folder", "island shelf drop zone hint")
            })[id] ?? "";
    }
    readonly property var zoneIcons: ({
            "convert": "swap_horiz",
            "share": "ios_share",
            "cloud": "cloud_sync"
        })

    // Under the title: what was just done, how many are chosen, the shelf folder open (a click goes back up), or the
    // number of files (D3).
    readonly property bool backLink: !!card.shelf?.folder && !card.shelf?.notice && !card.chosen.length && !card.shelf?.aside?.length && !card.hint
    // A drag handle under the pointer (a shelf's title, the count): what dragging it takes.
    property string hint: ""
    // Hover moves from one handle to the next in either order: a handle left clears only its own help.
    function hover(on, text) {
        if (on)
            card.hint = text;
        else if (card.hint === text)
            card.hint = "";
    }
    readonly property string subtitle: {
        const s = card.shelf;
        if (!s)
            return "";
        if (s.dropSays)
            return s.dropSays;
        if (s.notice)
            return s.notice;
        if (card.hint)
            return card.hint;
        if (card.yielded)
            return I18n.tr("Click or press Super S to type here", "island shelf: the keys went back to the windows");
        // A folder's quick look names its own selection, what Enter, Ctrl+C and its actions work on.
        if (s.aside.length)
            return Shelf.name(s.aside[0]);
        if (card.chosen.length)
            // In files, as the count at rest ("9 files"): a shelf folder counts its files.
            return I18n.tr("%1 of %2 chosen", "island shelf: how many of the shown files are chosen").arg(Shelf.expand(card.chosen, s.groups).length).arg(Shelf.expand(card.list, s.groups).length);
        if (s.folder)
            return "‹ " + s.label("group:" + s.folder);
        return s.subtitle;
    }

    // The menus' rows: what the shelf takes in (right click on the room), or what can be done with the choice.
    function entry(id, icon, text, keys) {
        return {
            "id": id,
            "icon": icon,
            "text": text,
            "keys": keys ?? []
        };
    }
    readonly property var menuItems: {
        const s = card.shelf;
        if (!s || !card.menu)
            return [];
        const ctrl = I18n.tr("Ctrl", "keyboard key");
        const del = I18n.tr("Del", "keyboard key");
        if (card.menu === "shelf")
            return [
                card.entry("newFolder", "create_new_folder", I18n.tr("New folder", "island shelf: a folder made by holding a file on another")),
                card.entry("newText", "note_add", I18n.tr("New text file", "island shelf: an empty text file in Documents, kept on the shelf")),
                card.entry("paste", "content_paste", I18n.tr("Paste", "island shelf: clipboard files as links, a picture or text as a new file"), [ctrl, "V"]),
                card.entry("browse", "add", I18n.tr("Add files…", "island shelf: pick files to keep, in the file picker"), [ctrl, "O"]),
                card.list.length ? card.entry("chooseAll", "select_all", I18n.tr("Select all", "island shelf"), [ctrl, "A"]) : null,
                card.entry("sheet", "keyboard", I18n.tr("Keyboard shortcuts", "island shelf: the sheet of every key"), ["?"]),
                card.entry("settings", "tune", I18n.tr("Shelf settings", "island shelf: its page in the DMS settings"))
            ].filter(e => e);
        // "⋯" holds what the row has no room for; a right click on a tile, the whole plan.
        const plan = s.plan;
        const acts = (card.menu === "more" ? plan.buttons.slice(card.planShown) : plan.buttons).concat(plan.more);
        const zoneItems = s.zones.map(z => card.entry("zone:" + z, card.zoneIcons[z] ?? "inbox", I18n.tr("%1…", "island shelf menu: a drop zone, opened for the chosen files").arg(card.zones.name(z))));
        // A quick look's selection lives in a real folder: no preview, rename, remove or trash of the shelf's here (P8).
        return acts.map(id => card.entry(id, card.icons[id] ?? "", card.labels[id] ?? id, card.keysFor(id))).concat(zoneItems, s.aside.length ? [] : [
            card.entry("peek", "visibility", I18n.tr("Preview", "island shelf: quick look at a file in the card"), [I18n.tr("Space", "keyboard key")]),
            s.focusKeys.length === 1 ? card.entry("rename", "edit", I18n.tr("Rename", "island shelf: rename a file or a shelf folder in place"), ["F2"]) : null,
            card.entry("remove", "remove_circle", I18n.tr("Remove from the shelf", "island shelf: forget the chosen file, the file stays"), [del]),
            card.entry("trash", "delete", I18n.tr("Put in the trash", "island shelf: screen reader name of Trash"), [I18n.tr("Shift", "keyboard key"), del])
        ].filter(e => e));
    }
    function openMenu(kind, at) {
        card.menuAt = at;
        card.menu = kind;
    }
    // Menu or Shift+F10: the choice's menu at the keys' tile, the shelf's with nothing chosen; its first row takes the keys.
    function keyMenu() {
        const s = card.shelf;
        const key = card.chosen.length && card.chosen.indexOf(card.list[s.cur]) === -1 ? card.chosen[0] : card.list[s.cur] ?? "";
        const c = card.cellOf(key);
        card.openMenu(card.chosen.length ? "file" : "shelf", c ? c.mapToItem(card, c.width / 2, c.height / 2) : Qt.point(0, header.height + card.gap));
        Qt.callLater(() => card.menuStep(false));
    }
    // ↑/↓ in a menu, Tab among the card's stops (the tiles, the row's buttons, "⋯", Close): around, never out of the card.
    function menuStep(back) {
        const rows = Array.from({
            "length": menuRows.count
        }, (_, i) => menuRows.itemAt(i));
        rows[Shelf.wrap(rows.indexOf(Window.activeFocusItem), back, rows.length)]?.forceActiveFocus(Qt.TabFocusReason);
    }
    function tabStep(back) {
        const row = planRow.visible ? Array.from({
            "length": planButtons.count
        }, (_, i) => planButtons.itemAt(i)).concat([moreButton]) : [];
        const stops = [card].concat(row, [closeButton]);
        stops[Shelf.wrap(stops.indexOf(Window.activeFocusItem), back, stops.length)].forceActiveFocus(back ? Qt.BacktabFocusReason : Qt.TabFocusReason);
    }
    function menuDo(id) {
        const s = card.shelf;
        card.menu = "";
        // The row that had the keys goes with the menu: they come back to the tiles.
        card.forceActiveFocus();
        if (!s)
            return;
        if (id.startsWith("zone:"))
            s.openZone(id.slice(5), s.targets);
        else if (id === "newFolder")
            s.newFolder();
        else if (id === "newText")
            s.newText();
        else if (id === "paste")
            s.paste();
        else if (id === "browse")
            s.pickFolder("browse");
        else if (id === "chooseAll")
            s.chooseAll();
        else if (id === "sheet")
            card.sheet = true;
        else if (id === "settings")
            card.openSettings();
        else if (id === "peek")
            s.peek = true;
        else if (id === "rename")
            s.startRename();
        else if (id === "remove" || id === "trash")
            s.removeChosen(id === "trash");
        else
            s.act(id);
    }
    // The shelf's page in the settings, as a settings search result reaches it: on a bar that holds an island, else the dot.
    function openSettings() {
        const bar = SettingsSearchService.islandBarFor("islandEnabled", SettingsUiState.selectedBarId);
        if (bar)
            SettingsUiState.selectedBarId = bar.id;
        SettingsSearchService.navigateToSection(bar ? "islandShelf" : "dotShelf");
        PopoutService.openSettingsWithTab(bar ? "dankbar_settings" : "dankbar_dot");
    }
    // "/" opens the search in the subtitle's place; a letter typed on the tiles starts it, Backspace takes one back.
    function find(text) {
        search.forceActiveFocus();
        if (text)
            card.shelf?.setQuery(Shelf.typed(card.shelf?.query ?? "", text));
        else
            search.selectAll();
        if (text)
            search.cursorPosition = search.text.length;
    }

    // The drawn cells (each has tileKeys: its file), shelf after shelf.
    function cells() {
        const out = [];
        for (let i = 0; i < shelfRepeater.count; i++)
            for (const c of shelfRepeater.itemAt(i)?.tiles?.children ?? [])
                if (c.tileKeys)
                    out.push(c);
        return out;
    }
    function cellOf(key) {
        return card.cells().find(c => c.tileKeys.indexOf(key) !== -1) ?? null;
    }
    // The cell under a point of the window, null between them.
    function cellAt(wx, wy) {
        const p = shelvesCol.mapFromItem(null, wx, wy);
        const g = shelvesCol.childAt(p.x, p.y)?.tiles;
        if (!g)
            return null;
        const q = g.mapFromItem(shelvesCol, p.x, p.y);
        const c = g.childAt(q.x, q.y);
        return c?.tileKeys ? c : null;
    }
    // The lasso: the files of every cell its rectangle touches (shelves' coordinates).
    function keysIn(r) {
        let hit = [];
        for (const c of card.cells()) {
            const p = c.mapToItem(shelvesCol, 0, 0);
            if (p.x < r.x + r.width && r.x < p.x + card.tileSize && p.y < r.y + r.height && r.y < p.y + card.tileSize)
                hit = hit.concat(c.tileKeys);
        }
        return hit;
    }
    // The keyboard's tile, or a name being edited, in view: its row scrolled to it, then the shelves.
    function reveal(i) {
        const key = card.list[i] ?? "";
        const n = card.shelves.findIndex(s => s.keys.indexOf(key) !== -1);
        if (n < 0)
            return;
        shelfRepeater.itemAt(n)?.tiles?.show(key);
        Qt.callLater(() => {
            const c = card.cellOf(key);
            if (!c)
                return;
            const y = c.mapToItem(shelvesCol, 0, 0).y;
            shelvesView.revealRange(y - card.titleHeight - Theme.spacingXS, y + card.cellHeight);
        });
    }

    // Every key of the card, for the "?" sheet (N6).
    readonly property var keySheet: {
        const ctrl = I18n.tr("Ctrl", "keyboard key");
        const shiftKey = I18n.tr("Shift", "keyboard key");
        const del = I18n.tr("Del", "keyboard key");
        return [
            [["Super", "S"], I18n.tr("Open or close the shelf", "island shelf keys sheet")],
            [["/"], I18n.tr("Search, or type a letter", "island shelf keys sheet")],
            [["←", "↑", "→", "↓"], I18n.tr("Move, Shift adds", "island shelf keys sheet: arrows choose, with Shift the choice grows")],
            [[I18n.tr("Home", "keyboard key"), I18n.tr("End", "keyboard key")], I18n.tr("First or last file", "island shelf keys sheet")],
            [[ctrl, "A"], I18n.tr("Select all", "island shelf")],
            [[ctrl, "C"], I18n.tr("Copy", "island shelf action: copy the chosen files")],
            [[ctrl, "V"], I18n.tr("Paste", "island shelf: clipboard files as links, a picture or text as a new file")],
            [[ctrl, "O"], I18n.tr("Add files…", "island shelf: pick files to keep, in the file picker")],
            [[ctrl, "Z"], I18n.tr("Undo", "island shelf keys sheet")],
            [[ctrl, shiftKey, "Z"], I18n.tr("Redo", "island shelf keys sheet")],
            [[del], I18n.tr("Remove from the shelf", "island shelf: forget the chosen file, the file stays")],
            [[shiftKey, del], I18n.tr("Put in the trash", "island shelf: screen reader name of Trash")],
            [[I18n.tr("Space", "keyboard key")], I18n.tr("Preview", "island shelf: quick look at a file in the card")],
            [[I18n.tr("Enter", "keyboard key")], I18n.tr("Open", "island shelf action")],
            [["F2"], I18n.tr("Rename", "island shelf: rename a file or a shelf folder in place")],
            [[I18n.tr("Menu", "keyboard key"), shiftKey + " F10"], I18n.tr("Menu of the choice, or of the shelf", "island shelf keys sheet: the context menu by keys")],
            [[I18n.tr("Tab", "keyboard key")], I18n.tr("Buttons, Shift goes back", "island shelf keys sheet: Tab walks the card's buttons")],
            [[I18n.tr("Esc", "keyboard key")], I18n.tr("Close what is open", "island shelf keys sheet: Escape closes the innermost thing, never the card")],
            [["?"], I18n.tr("These keys", "island shelf keys sheet: the key that shows this sheet")]
        ];
    }

    Connections {
        target: card.shelf
        ignoreUnknownSignals: true

        function onFinished(id, ok) {
            for (let i = 0; i < planButtons.count; i++) {
                const b = planButtons.itemAt(i);
                if (b?.actionId === id)
                    b.flash(ok);
            }
        }
        function onRenameStarted() {
            card.reveal(card.shelf?.cur ?? 0);
        }
        function onRevealCur() {
            card.reveal(card.shelf?.cur ?? 0);
        }
        function onFilesMoved() {
            if (peekBox.visible)
                peekBox.loadTree();
        }
    }

    // A drag over the card: what lies under the pointer (a zone of the band, one of Cloud's folders once it split, a
    // tile), and a tile held on long enough for a folder.
    readonly property point dragAt: card.shelf?.dragAt ?? Qt.point(-1, -1)
    function under(item) {
        const p = item?.mapFromItem(null, card.dragAt.x, card.dragAt.y);
        return !!p && item.visible && p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height;
    }
    // A folder on disk of the quick look under the drag (a row of its tree, a tile of its middle): the files move there.
    function dirAt() {
        for (const [view, box] of [[treeView, treeCol], [mosaicView, mosaicFlow]]) {
            if (!peekBox.visible || !card.under(view))
                continue;
            const p = box.mapFromItem(null, card.dragAt.x, card.dragAt.y);
            const it = box.childAt(p.x, p.y);
            if ((it?.path ?? "").startsWith("/") && (it.modelData?.dir || it.folder))
                return it.path;
        }
        return "";
    }
    onDragAtChanged: {
        const s = card.shelf;
        if (!s || card.dragAt.x < 0 || !card.visible)
            return;
        let zone = "";
        let cloud = "";
        for (let i = 0; i < zoneRepeater.count; i++) {
            const z = zoneRepeater.itemAt(i);
            if (card.under(z)) {
                zone = z.zoneId;
                cloud = z.cloudAt();
            }
        }
        if (zone !== "cloud")
            card.cloudSplit = false;
        // A tile (never a pile) under the pointer: a folder can be made on it, or a shelf folder takes the files; never
        // a tile hidden under the quick look.
        const c = !zone && !s.peek && card.under(shelvesView) ? card.cellAt(card.dragAt.x, card.dragAt.y) : null;
        const row = c?.tileKey ?? "";
        merge.cell = row ? c : null;
        // The band rising under the drag never hides the tile aimed at: its row scrolls into view.
        if (c)
            shelvesView.revealRange(c.mapToItem(shelvesCol, 0, 0).y, c.mapToItem(shelvesCol, 0, 0).y + card.cellHeight);
        const dir = !zone ? card.dirAt() : "";
        // A folder is made on a file, from another file, at the shelf's top level.
        const dragged = s.takingOut ? s.dragKeys : [];
        const mergeable = row && !Shelf.isGroup(row) && dragged.indexOf(row) === -1 && !s.folder;
        if (row !== s.hover.row || zone !== s.hover.zone || cloud !== (s.hover.cloud ?? "") || dir !== (s.hover.dir ?? "")) {
            s.hover = {
                "zone": zone,
                "cloud": cloud,
                "row": dragged.indexOf(row) === -1 ? row : "",
                "merge": false,
                "dir": dragged.indexOf(dir) === -1 ? dir : ""
            };
            if (mergeable || (zone === "cloud" && !card.cloudSplit && (s.clouds?.length ?? 0) > 0))
                folderTimer.restart();
            else
                folderTimer.stop();
        }
    }
    // The same 0.6 s makes a folder on a tile and opens Cloud into its folders (Finder's spring-loaded folders).
    Timer {
        id: folderTimer

        interval: Kit.folderHoldMs
        onTriggered: {
            const s = card.shelf;
            if (!s || !(s.over || s.takingOut))
                return;
            if (s.hover.zone === "cloud")
                card.cloudSplit = true;
            else if (s.hover.row)
                s.hover = Object.assign({}, s.hover, {
                    "merge": true
                });
        }
    }

    // A press on a tile or on their room (their MouseAreas take it before anyPress could see it): back to the pointer,
    // keys hidden, menu closed, the keyboard kept by the card.
    function pointerPress() {
        // A click anywhere in the card takes the keyboard back from the windows (after a click outside yielded it).
        card.shelf?.wake();
        // A file deleted elsewhere leaves, said, before it can go out in a drag.
        card.shelf?.check();
        card.keyboard = false;
        card.menu = "";
        card.forceActiveFocus();
    }

    // Any other press in the card takes the keyboard back, without taking the press from what is under it, and hides
    // the keys.
    PointHandler {
        id: anyPress

        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            if (!active)
                return;
            card.shelf?.wake();
            card.keyboard = false;
            const p = menuBox.mapFromItem(card, anyPress.point.position.x, anyPress.point.position.y);
            if (card.menu && !menuBox.contains(p))
                card.menu = "";
            // A clicked button takes the focus on press; give it back once the press is delivered (Space, arrows).
            Qt.callLater(() => {
                if (!search.activeFocus && !(card.shelf?.renaming ?? ""))
                    card.forceActiveFocus();
            });
        }
    }

    focus: true
    // Folded or closed (the launcher in its place), the card leaves no preview open behind it.
    Component.onDestruction: {
        if (card.shelf)
            card.shelf.peek = false;
    }
    onActiveFocusChanged: {
        if (!card.activeFocus && card.shelf) {
            card.shelf.shiftHeld = false;
            card.shelf.ctrlHeld = false;
        }
    }
    Keys.onReleased: event => {
        if (!card.shelf)
            return;
        card.shelf.shiftHeld = (event.modifiers & Qt.ShiftModifier) !== 0 && event.key !== Qt.Key_Shift;
        card.shelf.ctrlHeld = (event.modifiers & Qt.ControlModifier) !== 0 && event.key !== Qt.Key_Control;
    }
    Keys.onPressed: event => {
        const s = card.shelf;
        if (!s)
            return;
        s.shiftHeld = (event.modifiers & Qt.ShiftModifier) !== 0 || event.key === Qt.Key_Shift;
        s.ctrlHeld = (event.modifiers & Qt.ControlModifier) !== 0 || event.key === Qt.Key_Control;
        if (s.renaming)
            return;
        // A modifier alone (Shift to see Trash) is not yet the keyboard at work.
        const lone = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R].indexOf(event.key) !== -1;
        if (!lone)
            card.keyboard = true;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shiftOn = (event.modifiers & Qt.ShiftModifier) !== 0;
        const n = card.list.length;
        const arrows = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down];
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (card.menu)
                card.menuStep(event.key === Qt.Key_Backtab || shiftOn);
            else
                card.tabStep(event.key === Qt.Key_Backtab || shiftOn);
            event.accepted = true;
            return;
        }
        if (!s.peek && (event.key === Qt.Key_Menu || (shiftOn && event.key === Qt.Key_F10))) {
            card.keyMenu();
            event.accepted = true;
            return;
        }
        // Any other key from a button reached by Tab (or a menu's row) brings the keys back to the tiles.
        if (!card.activeFocus && !search.activeFocus && !lone)
            card.forceActiveFocus();
        // Over a folder's quick look the arrows walk its tree (← on the root closes it); over a file's, up and down
        // scroll what it shows (a document turns its page past the end); never the tiles. Backspace steps back out of
        // a folder; Escape closes the quick look as always.
        if (s.peek && peekBox.folderMode && event.key === Qt.Key_Space) {
            peekBox.space();
            event.accepted = true;
            return;
        }
        // Enter opens the folder's selection in its app (a subfolder in the file manager), not the shelf's tile.
        if (s.peek && peekBox.folderMode && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            if (!Shelf.isGroup(peekBox.subject))
                s.openApps([peekBox.subject]);
            event.accepted = true;
            return;
        }
        if (s.peek && peekBox.folderMode && arrows.indexOf(event.key) !== -1) {
            if (peekBox.pane === "tiles" && peekBox.file === "")
                peekBox.tilesMove(event.key);
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down)
                peekBox.move(event.key === Qt.Key_Down ? 1 : -1);
            else if (event.key === Qt.Key_Right)
                peekBox.goRight();
            else if (!peekBox.goLeft())
                s.peek = false;
            event.accepted = true;
            return;
        }
        // The browser's own keys: Home, End and the pages walk it, a letter jumps to a name; Delete and F2 never reach
        // the shelf's folder behind it (P8). Enter is handled above, on the same selection.
        if (s.peek && peekBox.folderMode) {
            const leaps = {
                [Qt.Key_Home]: "first",
                [Qt.Key_End]: "last",
                [Qt.Key_PageUp]: "pageUp",
                [Qt.Key_PageDown]: "pageDown"
            };
            // A printable letter (Escape, Backspace and the other control keys carry a text too).
            const typed = !ctrl && event.text.length === 1 && event.text.charCodeAt(0) > 32 && event.text.charCodeAt(0) !== 127 && event.text !== "?" && event.text !== "/";
            if (leaps[event.key] || typed) {
                peekBox.leap(leaps[event.key] ?? "", typed ? event.text : "");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Delete || event.key === Qt.Key_F2) {
                event.accepted = true;
                return;
            }
            // As in a file manager: Ctrl+C copies the file itself, never its text.
            if (ctrl && event.key === Qt.Key_C) {
                s.act("copyFiles");
                event.accepted = true;
                return;
            }
            // Menu or Shift+F10: the selection's whole menu at its row or tile, as its right click.
            if (event.key === Qt.Key_Menu || (shiftOn && event.key === Qt.Key_F10)) {
                const tiles = peekBox.pane === "tiles" && peekBox.file === "";
                const at = tiles ? mosaicRepeater.itemAt(peekBox.tileAt) : treeRepeater.itemAt(peekBox.curRow);
                if (at && s.aside.length)
                    card.openMenu("file", at.mapToItem(card, at.width / 2, at.height));
                event.accepted = true;
                return;
            }
        }
        if (s.peek && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            peekBox.scroll(event.key === Qt.Key_Down ? 1 : -1);
            event.accepted = true;
            return;
        }
        if (s.peek && peekBox.paged && (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)) {
            peekBox.turn(event.key === Qt.Key_PageDown ? 1 : -1);
            event.accepted = true;
            return;
        }
        if (s.peek && peekBox.canBack && event.key === Qt.Key_Backspace) {
            peekBox.back();
            event.accepted = true;
            return;
        }
        if (!ctrl && event.text === "?") {
            card.sheet = !card.sheet;
        } else if (!ctrl && event.text === "/") {
            card.find("");
        } else if (arrows.indexOf(event.key) !== -1) {
            // In two dimensions: left and right along the shelves, up and down a row as drawn, shelf to shelf.
            const k = arrows.indexOf(event.key);
            const vertical = k >= 2 ? card.list.indexOf(Shelf.rowStep(card.drawnRows, card.list[s.cur] ?? "", k === 2 ? -1 : 1)) : -1;
            const to = !card.chosen.length && !shiftOn ? (k % 2 ? 0 : n - 1) : k < 2 ? s.cur + (k ? 1 : -1) : vertical >= 0 ? vertical : s.cur;
            s.go(to, shiftOn);
            card.reveal(s.cur);
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            s.go(event.key === Qt.Key_Home ? 0 : n - 1, shiftOn);
            card.reveal(s.cur);
        } else if (ctrl && event.key === Qt.Key_A) {
            s.chooseAll();
        } else if (ctrl && event.key === Qt.Key_C) {
            s.shortcut("copy");
        } else if (ctrl && event.key === Qt.Key_V) {
            s.paste();
        } else if (ctrl && event.key === Qt.Key_O) {
            s.pickFolder("browse");
        } else if (ctrl && (event.key === Qt.Key_Z || event.key === Qt.Key_Y)) {
            if (shiftOn || event.key === Qt.Key_Y)
                s.redo();
            else
                s.undo();
        } else if (event.key === Qt.Key_Delete) {
            s.removeChosen(shiftOn);
        } else if (event.key === Qt.Key_Space && n) {
            s.peek = !s.peek;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            s.shortcut("enter");
        } else if (event.key === Qt.Key_F2) {
            s.startRename();
        } else if (event.key === Qt.Key_Escape) {
            // The innermost thing open closes, the choice last; the card itself never (its close button or Super+S, C7).
            if (card.sheet)
                card.sheet = false;
            else if (card.menu)
                card.menu = "";
            else
                s.closeInner();
        } else if (!ctrl && (Shelf.printable(event.text) || event.key === Qt.Key_Backspace && !!s.query)) {
            card.find(event.key === Qt.Key_Backspace ? "\b" : event.text);
        } else if (event.key !== Qt.Key_Shift) {
            return;
        }
        event.accepted = true;
    }

    // A key as the card shows it.
    component Keycaps: Row {
        property var keys: []

        spacing: Theme.spacingXXS
        Accessible.ignored: true

        Repeater {
            model: parent.keys

            DKeycap {
                required property string modelData

                text: modelData
            }
        }
    }

    Column {
        id: content

        width: parent.width
        spacing: card.gap

        // Header (C5): the bubble's own icon (D21), "Shelf", the subtitle or the search in its place; Close at the far right.
        Item {
            id: header

            width: parent.width
            height: Math.max(NotificationMetrics.appIconSize, titles.implicitHeight)

            Rectangle {
                id: logo

                anchors.verticalCenter: parent.verticalCenter
                width: NotificationMetrics.appIconSize
                height: width
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                DIcon {
                    anchors.centerIn: parent
                    name: "stacks"
                    size: Theme.iconSize
                    color: Theme.primary
                }
            }

            Column {
                id: titles

                anchors.left: logo.right
                anchors.leftMargin: NotificationMetrics.iconSpacing
                anchors.right: searchButton.visible ? searchButton.left : closeButton.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: NotificationMetrics.contentSpacing / 2

                // As tall as the title alone: its keys, shown after a key, sit on its line without moving the card.
                Item {
                    width: parent.width
                    height: titleText.implicitHeight

                    StyledText {
                        id: titleText

                        text: I18n.tr("Shelf", "island shelf: its name")
                        font.pixelSize: NotificationMetrics.summarySize
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                    }
                    // shortcut: the key of niri's default bind (niri-binds.kdl), written here; Hyprland and MangoWC already use
                    // Super+S, so there the shelf has no default key. Read the bind from KeybindsService if that matters.
                    Keycaps {
                        x: titleText.width + Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.keyboard
                        keys: ["Super", "S"]
                        Accessible.ignored: false
                        Accessible.name: I18n.tr("Shortcut Super S", "island shelf: its keyboard shortcut for screen readers")
                    }
                }
                Item {
                    width: parent.width
                    height: subtitleText.implicitHeight

                    // While a removal's notice shows: Undo in one click, the kit's countdown drains with it.
                    IslandUndoButton {
                        id: undoButton

                        readonly property string said: card.shelf?.notice ?? ""

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !card.finding && !!card.shelf?.undoable && undoButton.said !== ""
                        buttonHeight: card.smallButton - Theme.spacingXS
                        countdownMs: card.shelf?.noticeTimer.interval ?? 0
                        focusPolicy: Qt.TabFocus
                        onSaidChanged: if (undoButton.visible)
                            undoButton.start()
                        onVisibleChanged: if (undoButton.visible)
                            undoButton.start()
                        onPressed: card.pointerPress()
                        onClicked: card.shelf?.undo()
                    }
                    StyledText {
                        id: subtitleText

                        width: parent.width - (undoButton.visible ? undoButton.width + Theme.spacingXS : 0)
                        visible: !card.finding
                        text: card.subtitle
                        elide: Text.ElideRight
                        font.pixelSize: NotificationMetrics.bodySize
                        font.weight: card.backLink ? Theme.fontWeightMedium : Theme.fontWeight
                        color: card.backLink ? Theme.primary : Theme.surfaceVariantText

                        // The count is a handle: dragged, every file shown goes out (C's, N7). Inside a shelf folder: its
                        // name, a click goes back up (Escape too).
                        MouseArea {
                            id: countHandle

                            property point from

                            width: Math.min(parent.width, parent.implicitWidth)
                            height: parent.height
                            // Under the text: the kit's state layer shows the handle on hover, the subtitle says it.
                            z: -1
                            hoverEnabled: true
                            enabled: card.backLink || card.list.length > 0
                            cursorShape: card.backLink ? Qt.PointingHandCursor : countHandle.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            readonly property string help: I18n.tr("Drag to take all %1", "island shelf: the count's hover help, it drags every shown file").arg(card.list.length)
                            onContainsMouseChanged: card.hover(countHandle.containsMouse && !card.backLink, countHandle.help)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -Theme.spacingXXS
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceText, countHandle.pressed ? Theme.stateLayerPressed : countHandle.containsMouse ? Theme.stateLayerHover : 0)
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: card.backLink ? I18n.tr("Back to the shelf", "island shelf: leave a shelf folder") : I18n.tr("Drag every file out", "island shelf: the count dragged takes every file")
                            onPressed: mouse => {
                                countHandle.from = Qt.point(mouse.x, mouse.y);
                                card.pointerPress();
                            }
                            onPositionChanged: mouse => {
                                if (countHandle.pressed && !card.backLink && !card.shelf?.takingOut && !outProxy.starting && Math.abs(mouse.x - countHandle.from.x) + Math.abs(mouse.y - countHandle.from.y) > Theme.spacingS)
                                    outProxy.start(card.list.slice(), countHandle);
                            }
                            onClicked: {
                                if (card.backLink)
                                    card.shelf?.leaveFolder();
                            }
                        }
                    }
                    // The search, in the subtitle's place while it is open (F12).
                    DIcon {
                        id: searchIcon

                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.finding
                        name: "search"
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                    }
                    TextInput {
                        id: search

                        anchors.left: searchIcon.right
                        anchors.leftMargin: Theme.spacingXS
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.finding
                        clip: true
                        text: card.shelf?.query ?? ""
                        color: Theme.surfaceText
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onPrimary
                        font.pixelSize: NotificationMetrics.bodySize
                        font.family: Theme.fontFamily
                        Accessible.role: Accessible.EditableText
                        Accessible.name: I18n.tr("Search the shelf", "island shelf: the search field")
                        onTextEdited: card.shelf?.setQuery(text)
                        // One Escape empties and closes the search: Ctrl+C, Delete and Enter act on the choice at once.
                        Keys.onEscapePressed: event => {
                            event.accepted = true;
                            card.shelf?.setQuery("");
                            card.forceActiveFocus();
                        }
                        Keys.onPressed: event => {
                            if (event.key !== Qt.Key_Down && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                                return;
                            event.accepted = true;
                            card.keyboard = true;
                            card.forceActiveFocus();
                            card.shelf?.go(card.shelf?.cur ?? 0, false);
                            // Enter on a search opens the file its ring is on (P4); Down only reaches the tiles.
                            if (event.key !== Qt.Key_Down && search.text && card.list.length)
                                card.shelf?.shortcut("enter");
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            elide: Text.ElideRight
                            visible: !search.text
                            text: I18n.tr("Search the shelf", "island shelf: the search field")
                            font.pixelSize: NotificationMetrics.bodySize
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }

            // The search for the pointer too: the field opens with its hint, a letter typed does the same.
            BubbleAction {
                id: searchButton

                anchors.right: closeButton.left
                anchors.rightMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                visible: !card.finding && card.list.length > 1
                iconName: "search"
                Accessible.name: I18n.tr("Search the shelf", "island shelf: the search field")
                onClicked: {
                    card.pointerPress();
                    card.find("");
                }
            }
            BubbleAction {
                id: closeButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"
                // A Tab stop of the card's own ring (tabStep): Tab reaches the card's keys, never DMS's chain to the bar.
                focusPolicy: Qt.NoFocus
                Accessible.name: I18n.tr("Close the shelf", "island shelf: close the card, the files stay")
                onClicked: card.shelf?.dismiss()
            }
        }

        // The shelves, or what stands for them (nothing kept, nothing found), the preview or the keys sheet over them.
        Item {
            id: body

            readonly property real restHeight: card.list.length ? shelvesView.height : emptyState.implicitHeight + 2 * Theme.spacingL

            width: parent.width
            // The quick look takes three rows of tiles when the ceiling allows, never under two.
            height: Math.max(body.restHeight, peekBox.visible ? Math.min(3 * card.cellHeight, Math.max(2 * card.cellHeight, shelvesView.room)) : 0, keySheet.visible ? keySheet.implicitHeight : 0)

            // The room between and after the tiles: a drag there draws a lasso (Ctrl or Shift: added to the choice), a
            // click lets the choice go, a right click opens what the shelf takes in.
            MouseArea {
                id: lasso

                property point from
                property rect box: Qt.rect(0, 0, 0, 0)
                property var base: []
                property bool on: false

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: mouse => {
                    lasso.on = false;
                    lasso.from = lasso.mapToItem(shelvesCol, mouse.x, mouse.y);
                    lasso.base = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) ? card.chosen : [];
                    card.pointerPress();
                }
                onPositionChanged: mouse => {
                    if (!(lasso.pressedButtons & Qt.LeftButton) || !card.list.length)
                        return;
                    const p = lasso.mapToItem(shelvesCol, mouse.x, mouse.y);
                    lasso.box = Qt.rect(Math.min(lasso.from.x, p.x), Math.min(lasso.from.y, p.y), Math.abs(p.x - lasso.from.x), Math.abs(p.y - lasso.from.y));
                    if (!lasso.on && lasso.box.width + lasso.box.height < Theme.spacingS)
                        return;
                    lasso.on = true;
                    const hit = card.keysIn(lasso.box);
                    card.shelf?.choose(lasso.base.filter(k => hit.indexOf(k) === -1).concat(hit));
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        card.openMenu("shelf", lasso.mapToItem(card, mouse.x, mouse.y));
                    else if (!lasso.on)
                        card.shelf?.chooseNone();
                }
            }

            // A drop on the shelves keeps the files: the room lit while a drag is over it, and no zone or folder under it.
            Rectangle {
                anchors.fill: parent
                visible: card.lit && !(card.shelf?.hotZone ?? "") && !(card.shelf?.hover?.dir ?? "") && !Shelf.isGroup(card.shelf?.hover?.row ?? "")
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.primaryContainer, 0.28)
                border.width: Theme.outlineWidthFocused
                border.color: Theme.primary
            }

            // Nothing to show: an icon on its tile and one line (L12: the card stays small).
            Column {
                id: emptyState

                readonly property bool searching: !card.empty && (card.shelf?.query ?? "") !== ""

                anchors.centerIn: parent
                width: parent.width - 2 * NotificationMetrics.cardPadding
                visible: card.list.length === 0
                spacing: Theme.spacingS

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: NotificationMetrics.appIconSize * 1.5
                    height: width
                    radius: Theme.cornerRadiusL
                    color: Theme.surfaceContainerHigh

                    DIcon {
                        anchors.centerIn: parent
                        name: emptyState.searching ? "search_off" : "move_to_inbox"
                        size: Theme.iconSizeLarge
                        color: emptyState.searching ? Theme.surfaceVariantText : Theme.primary
                    }
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: emptyState.searching ? I18n.tr("No result. Esc clears the search.", "island shelf: the search finds nothing, and how to leave it") : I18n.tr("Drop or paste files here (Ctrl+V)", "island shelf: the empty gallery")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }
            }

            // A tile: the picture, a PDF's first page or a video's frame (else its type's icon), its name under it. On
            // hover its size and type at its foot, Preview and Remove in its corners.
            Component {
                id: tileCell

                Item {
                    id: cell

                    required property string modelData
                    readonly property string tileKey: cell.modelData
                    readonly property var tileKeys: [cell.modelData]
                    readonly property Item box: tileBox
                    readonly property int at: card.list.indexOf(cell.modelData)
                    readonly property bool picked: card.chosen.indexOf(cell.modelData) !== -1
                    // While typing a search, its first result already wears the ring Enter acts on.
                    readonly property bool current: (card.keyboard && card.activeFocus || search.activeFocus) && cell.at === (card.shelf?.cur ?? -1)
                    readonly property bool target: (card.shelf?.hover?.row ?? "") === cell.modelData
                    readonly property bool isGroup: Shelf.isGroup(cell.modelData)
                    readonly property bool renaming: (card.shelf?.renaming ?? "") === cell.modelData
                    readonly property bool hovered: press.containsMouse && !(card.shelf?.takingOut ?? false)
                    // Several files going out from this tile (its choice, its shelf, every file): their number on it.
                    readonly property int going: proxy.starting ? proxy.keys.length : outProxy.starting && outProxy.cell === cell ? outProxy.keys.length : 0

                    // How far the tile is into its row's edge zone (half a tile inside the edge: 0; touching it: 0.5;
                    // half out: 1), on the sides where the row goes on past the edge: the dashboard carousel's recipe
                    // shrinks, fades and turns it away, the left tiles one way, the right ones the other.
                    readonly property real over: {
                        const v = cell.parent;
                        if (!(v?.room > 0))
                            return 0;
                        const left = cell.x - v.offset;
                        const inLeft = v.offset > 1 ? left : Infinity;
                        const inRight = v.offset < v.room - 1 ? v.viewWidth - left - cell.width : Infinity;
                        return Math.min(1, Math.max(0, (cell.width / 2 - Math.min(inLeft, inRight)) / Math.max(1, cell.width)));
                    }
                    readonly property int side: cell.x - (cell.parent?.offset ?? 0) + cell.width / 2 < (cell.parent?.viewWidth ?? 0) / 2 ? 1 : -1

                    width: card.tileSize
                    height: card.cellHeight
                    scale: 1 - (1 - DashMetrics.carouselSideScale) * cell.over
                    opacity: ((card.shelf?.takingOut ?? false) && (card.shelf?.dragKeys ?? []).indexOf(cell.modelData) !== -1 ? 0.4 : 1) * (1 - (1 - DashMetrics.carouselSideAlpha) * cell.over)
                    transform: Rotation {
                        origin.x: cell.width / 2
                        origin.y: cell.height / 2
                        axis {
                            x: 0
                            y: 1
                            z: 0
                        }
                        angle: cell.side * DashMetrics.carouselAngle * cell.over
                    }
                    Accessible.role: Accessible.ListItem
                    Accessible.name: (card.shelf?.tileName(cell.modelData) ?? "") + ", " + card.metaOf(cell.modelData)
                    Accessible.selected: cell.picked

                    Rectangle {
                        id: tileBox

                        width: card.tileSize
                        height: width
                        radius: Theme.cornerRadius
                        color: cell.target && cell.isGroup ? Theme.primaryContainer : Theme.surfaceContainer

                        IslandShelfThumb {
                            anchors.fill: parent
                            visible: !cell.isGroup
                            radius: parent.radius
                            color: parent.color
                            path: cell.modelData
                            dirs: card.dirs
                            previews: card.shelf?.previews ?? null
                            iconSize: Theme.iconSizeLarge
                        }
                        // A shelf folder: four of its files, small (iOS).
                        Grid {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            visible: cell.isGroup
                            columns: 2
                            spacing: Theme.spacingXS

                            Repeater {
                                model: cell.isGroup ? (card.shelf?.groups?.[Shelf.groupId(cell.modelData)]?.items ?? []).slice(0, 4) : []

                                IslandShelfThumb {
                                    required property string modelData

                                    width: (tileBox.width - 2 * Theme.spacingS - Theme.spacingXS) / 2
                                    height: width
                                    path: modelData
                                    dirs: card.dirs
                                    previews: card.shelf?.previews ?? null
                                    iconSize: Theme.iconSizeSmall
                                }
                            }
                        }
                        // Chosen, the keyboard's tile, or the drop's target: the one accent (L5).
                        Rectangle {
                            anchors.fill: parent
                            visible: cell.picked || cell.current || cell.target
                            radius: parent.radius
                            color: "transparent"
                            border.width: Theme.outlineWidthFocused
                            border.color: Theme.primary
                        }
                        Rectangle {
                            id: check

                            x: Theme.spacingXS
                            y: parent.height - height - Theme.spacingXS
                            width: Theme.iconSizeMedium
                            height: width
                            radius: width / 2
                            visible: cell.picked
                            color: Theme.primary

                            DIcon {
                                anchors.centerIn: parent
                                name: "check"
                                size: Theme.iconSizeSmall
                                color: Theme.onPrimary
                            }
                        }
                        // On hover: its size and type, one line at its foot (L2).
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: cell.picked ? check.width + 2 * Theme.spacingXS : Theme.spacingXS
                            anchors.rightMargin: Theme.spacingXS
                            anchors.bottomMargin: Theme.spacingXS
                            height: metaText.implicitHeight + 2 * Theme.spacingXXS
                            radius: height / 2
                            // Never in the picture that goes out under the pointer.
                            visible: cell.hovered && !cell.isGroup && !proxy.starting
                            color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.9)

                            StyledText {
                                id: metaText

                                anchors.centerIn: parent
                                width: parent.width - 2 * Theme.spacingXS
                                horizontalAlignment: Text.AlignHCenter
                                text: card.metaOf(cell.modelData)
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }
                        // Several files going out: their number rides on the picture under the pointer (HIG).
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingXS
                            width: Math.max(height, dragCount.implicitWidth + Theme.spacingS)
                            height: Theme.iconSizeMedium
                            radius: height / 2
                            visible: cell.going > 1
                            color: Theme.primary

                            StyledText {
                                id: dragCount

                                anchors.centerIn: parent
                                text: String(cell.going)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightMedium
                                color: Theme.onPrimary
                            }
                        }
                    }

                    // Its name under it, one line, elided in the middle (the extension stays).
                    StyledText {
                        y: tileBox.height + Theme.spacingXXS
                        width: cell.width
                        visible: !cell.renaming && !(merge.on && cell.target)
                        text: card.shelf?.tileName(cell.modelData) ?? ""
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        wrapMode: Text.NoWrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                    // F2, or a folder just made: the name edited in place under the tile (Enter keeps, Escape leaves it).
                    Rectangle {
                        y: tileBox.height + Theme.spacingXXS
                        width: cell.width
                        height: renameField.implicitHeight + Theme.spacingXXS * 2
                        visible: cell.renaming
                        radius: Theme.cornerRadius / 2
                        color: Theme.surfaceContainer
                        border.width: Theme.outlineWidthFocused
                        border.color: Theme.primary

                        TextInput {
                            id: renameField

                            property bool done: false

                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingXS
                            anchors.rightMargin: Theme.spacingXS
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: Theme.surfaceText
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.onPrimary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            Accessible.role: Accessible.EditableText
                            Accessible.name: I18n.tr("New name", "island shelf: rename field")

                            function begin() {
                                renameField.done = false;
                                renameField.text = card.shelf?.label(cell.modelData) ?? "";
                                const dot = cell.isGroup ? -1 : renameField.text.lastIndexOf(".");
                                renameField.forceActiveFocus();
                                renameField.select(0, dot > 0 ? dot : renameField.text.length);
                            }
                            function finish(keep) {
                                if (renameField.done)
                                    return;
                                renameField.done = true;
                                if (keep)
                                    card.shelf?.rename(cell.modelData, renameField.text);
                                else if (card.shelf)
                                    card.shelf.renaming = "";
                                card.forceActiveFocus();
                            }

                            Keys.onReturnPressed: event => {
                                event.accepted = true;
                                renameField.finish(true);
                            }
                            Keys.onEnterPressed: event => {
                                event.accepted = true;
                                renameField.finish(true);
                            }
                            Keys.onEscapePressed: event => {
                                event.accepted = true;
                                renameField.finish(false);
                            }
                            onActiveFocusChanged: {
                                if (!activeFocus && cell.renaming)
                                    renameField.finish(true);
                            }
                        }
                    }
                    onRenamingChanged: {
                        if (cell.renaming)
                            Qt.callLater(renameField.begin);
                    }
                    Component.onCompleted: {
                        if (cell.renaming)
                            Qt.callLater(renameField.begin);
                    }

                    // The drag out: this tile, or the whole choice when this tile is in it. The shelf keeps its links.
                    Item {
                        id: proxy

                        readonly property var keys: cell.picked ? card.chosen : [cell.modelData]

                        // The tile's own picture rides under the pointer, held where it was grabbed (Qt's Drag doc:
                        // grabToImage, then active), on the shelf's carrier. starting: one grab per press while the pointer moves.
                        property bool starting: false
                        function start(at) {
                            proxy.starting = true;
                            tileBox.grabToImage(result => {
                                proxy.starting = false;
                                if (!press.pressed)
                                    return;
                                card.shelf?.carry(proxy.keys, result.url, at);
                            }, Qt.size(tileBox.width, tileBox.height));
                        }
                    }

                    MouseArea {
                        id: press

                        width: tileBox.width
                        height: tileBox.height
                        hoverEnabled: true
                        enabled: !cell.renaming
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: press.pressed && !card.sweeping ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        // Where the press began: past Theme.spacingS from it the tile goes out as a system drag. The
                        // MouseArea's own drag never armed here (a view's delegate), so the drag is started by hand.
                        property point from
                        onPressed: mouse => {
                            press.from = Qt.point(mouse.x, mouse.y);
                            card.sweepFrom = -1;
                            card.pointerPress();
                        }
                        onPressAndHold: {
                            if (!(press.pressedButtons & Qt.LeftButton))
                                return;
                            card.sweeping = true;
                            card.sweepFrom = cell.at;
                            card.sweepBase = card.chosen.filter(p => p !== cell.modelData);
                            card.shelf?.sweep(card.sweepBase, cell.at, cell.at);
                        }
                        onPositionChanged: mouse => {
                            if (card.quiet) {
                                const w = press.mapToItem(null, mouse.x, mouse.y);
                                card.quiet = Math.abs(w.x - card.quietAt.x) + Math.abs(w.y - card.quietAt.y) <= Theme.spacingXS;
                            }
                            if (!(press.pressedButtons & Qt.LeftButton))
                                return;
                            if (!card.sweeping) {
                                if (!card.shelf?.takingOut && !proxy.starting && Math.abs(mouse.x - press.from.x) + Math.abs(mouse.y - press.from.y) > Theme.spacingS)
                                    proxy.start(press.from);
                                return;
                            }
                            // Out of the shelves the sweep ends and what it chose goes out (a touchpad's press, pause, move).
                            if (!shelvesView.contains(press.mapToItem(shelvesView, mouse.x, mouse.y))) {
                                card.sweeping = false;
                                if (!card.shelf?.takingOut && !proxy.starting)
                                    proxy.start(press.from);
                                return;
                            }
                            // Across the shelves, in the order they read.
                            const p = press.mapToItem(null, mouse.x, mouse.y);
                            const at = card.list.indexOf(card.cellAt(p.x, p.y)?.tileKey ?? "");
                            if (at >= 0)
                                card.shelf?.sweep(card.sweepBase, card.sweepFrom, at);
                        }
                        onReleased: card.sweeping = false
                        onCanceled: card.sweeping = false
                        onClicked: mouse => {
                            // A right click acts on the tile: chosen alone unless it is in the choice.
                            if (mouse.button === Qt.RightButton) {
                                if (!cell.picked)
                                    card.shelf?.go(cell.at, false);
                                card.openMenu("file", press.mapToItem(card, mouse.x, mouse.y));
                                return;
                            }
                            // A long press already chose.
                            if (card.sweepFrom >= 0)
                                return;
                            card.click(cell.at, cell.modelData, (mouse.modifiers & Qt.ControlModifier) !== 0, (mouse.modifiers & Qt.ShiftModifier) !== 0);
                        }
                        onDoubleClicked: mouse => {
                            if (mouse.button === Qt.LeftButton)
                                card.openTile(cell.at);
                        }

                        // On hover, in its corners: a quick look, and Remove (Trash while Shift is held, C9).
                        BubbleAction {
                            x: Theme.spacingXS
                            y: Theme.spacingXS
                            visible: cell.hovered && !card.quiet
                            buttonHeight: Theme.buttonHeightS
                            iconName: "visibility"
                            Accessible.name: I18n.tr("Preview", "island shelf: quick look at a file in the card")
                            // It chooses its tile as a click does: ←/→, Delete and Enter then start from the file shown.
                            // A button takes the press from the tile's MouseArea: the card is woken here.
                            onPressed: card.pointerPress()
                            onClicked: {
                                if (!card.shelf)
                                    return;
                                card.shelf.go(cell.at, false);
                                card.shelf.peek = true;
                            }
                        }
                        BubbleAction {
                            x: parent.width - width - Theme.spacingXS
                            y: Theme.spacingXS
                            visible: cell.hovered && !card.quiet
                            buttonHeight: Theme.buttonHeightS
                            role: card.shift ? "danger" : "plain"
                            iconName: card.shift ? "delete" : "close"
                            Accessible.name: card.shift ? I18n.tr("Put in the trash", "island shelf: screen reader name of Trash") : I18n.tr("Remove from the shelf", "island shelf: forget the chosen file, the file stays")
                            onPressed: card.pointerPress()
                            onClicked: {
                                card.quietAt = press.mapToItem(null, press.mouseX, press.mouseY);
                                card.quiet = true;
                                card.shelf?.removeChosen(card.shift, cell.picked ? card.chosen : [cell.modelData]);
                            }
                        }
                    }
                }
            }

            // One shelf per family: a quiet title, then its tiles, five to a row; the wheel scrolls past three shelves.
            DFlickable {
                id: shelvesView

                width: parent.width
                // What is left under the ceiling once the header, the choice's row and the zones' band have their room.
                readonly property real room: card.roomHeight - header.height - card.gap - (chosenArea.visible ? chosenArea.height + card.gap : 0) - (band.visible ? band.height + card.gap : 0)

                height: Math.min(shelvesCol.implicitHeight, card.shownShelves * card.shelfHeight + (card.shownShelves - 1) * shelvesCol.spacing, Math.max(card.cellHeight, shelvesView.room))
                // Hidden under the preview and the sheet: a tile's frame would show through their antialiased edge.
                visible: card.list.length > 0 && !peekBox.visible && !keySheet.visible
                clip: true
                // A drag on a tile takes it out; on the room it draws the lasso. The wheel scrolls (DFlickable's own).
                interactive: false
                contentHeight: shelvesCol.implicitHeight
                Accessible.role: Accessible.List
                Accessible.name: I18n.tr("Shelf files", "island shelf: the list for screen readers")

                Column {
                    id: shelvesCol

                    width: shelvesView.width
                    spacing: Theme.spacingS

                    Repeater {
                        id: shelfRepeater

                        model: card.shelves

                        delegate: Column {
                            id: shelfBox

                            required property var modelData
                            readonly property alias tiles: strip
                            readonly property string name: card.shelfNames[shelfBox.modelData.id] ?? shelfBox.modelData.id

                            width: shelvesCol.width
                            spacing: Theme.spacingXXS
                            Accessible.role: Accessible.Grouping
                            Accessible.name: shelfBox.name

                            // "Images · 3": dragged, the whole family goes out.
                            Item {
                                width: parent.width
                                height: card.titleHeight

                                Row {
                                    id: shelfTitle

                                    x: card.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXXS

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shelfBox.name + " · " + shelfBox.modelData.keys.length
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                                MouseArea {
                                    id: titleHandle

                                    property point from

                                    x: shelfTitle.x
                                    width: shelfTitle.width
                                    height: parent.height
                                    // Under the title: the kit's state layer on hover, the subtitle says what goes out.
                                    z: -1
                                    hoverEnabled: true
                                    readonly property string help: I18n.tr("%1: drag to take all %2", "island shelf: a shelf title's hover help, it drags the family").arg(shelfBox.name).arg(shelfBox.modelData.keys.length)
                                    onContainsMouseChanged: card.hover(titleHandle.containsMouse, titleHandle.help)
                                    Component.onDestruction: card.hover(false, titleHandle.help)
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -Theme.spacingXXS
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.surfaceText, titleHandle.pressed ? Theme.stateLayerPressed : titleHandle.containsMouse ? Theme.stateLayerHover : 0)
                                    }
                                    cursorShape: titleHandle.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: I18n.tr("Drag every file of %1 out", "island shelf: a shelf's title dragged takes its whole family").arg(shelfBox.name)
                                    onPressed: mouse => {
                                        titleHandle.from = Qt.point(mouse.x, mouse.y);
                                        card.pointerPress();
                                    }
                                    onPositionChanged: mouse => {
                                        if (titleHandle.pressed && !card.shelf?.takingOut && !outProxy.starting && Math.abs(mouse.x - titleHandle.from.x) + Math.abs(mouse.y - titleHandle.from.y) > Theme.spacingS)
                                            outProxy.start(shelfBox.modelData.keys.slice(), titleHandle);
                                    }
                                }
                            }
                            // The row of tiles, inset from the card's edges; past them the wheel scrolls it sideways, its
                            // outer tiles shrinking, fading and turning away like the dashboard's wallpaper carousel.
                            Item {
                                x: card.gap
                                width: parent.width - 2 * card.gap
                                height: card.cellHeight

                                // Every tile of the shelf in one row (a hundred files at most), slid left by `offset`.
                                Row {
                                    id: strip

                                    // The room shown, and how far the row may slide.
                                    readonly property real viewWidth: parent.width
                                    readonly property real room: Math.max(0, strip.width - strip.viewWidth)
                                    property real offset: 0
                                    // A touchpad slides the row under the finger, unanimated.
                                    property bool finger: false

                                    // A tile in view, out of the faded edge: the row slides the least that brings it in.
                                    function show(key) {
                                        const c = card.cellOf(key);
                                        strip.finger = false;
                                        if (c)
                                            strip.offset = Shelf.slideTo(strip.offset, strip.room, strip.viewWidth, c.x, c.width, card.tileSize + strip.spacing);
                                    }

                                    x: -strip.offset
                                    spacing: Theme.spacingS
                                    onRoomChanged: strip.offset = Math.min(strip.offset, strip.room)

                                    Behavior on offset {
                                        id: slide

                                        enabled: !strip.finger && Theme.mediumDuration > 0 && !SettingsData.reduceMotion
                                        NumberAnimation {
                                            duration: Theme.mediumDuration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                                        }
                                    }

                                    Repeater {
                                        model: shelfBox.modelData.keys
                                        delegate: tileCell
                                    }
                                }
                                // The wheel over a row that overflows turns it a page a notch, a touchpad under the
                                // finger (Shelf.rowSlide); a row that fits leaves the wheel to the shelves' own scroll.
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: wheel => {
                                        const px = wheel.pixelDelta.y || wheel.pixelDelta.x;
                                        const angle = wheel.angleDelta.y || wheel.angleDelta.x;
                                        if (strip.room <= 0 || !(px || angle)) {
                                            wheel.accepted = false;
                                            return;
                                        }
                                        strip.finger = px !== 0;
                                        // From where the last notch sends the row, so quick notches add up.
                                        strip.offset = Shelf.rowSlide(slide.targetValue ?? strip.offset, strip.room, strip.viewWidth, card.tileSize + strip.spacing, px, angle);
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    x: lasso.box.x
                    y: lasso.box.y
                    width: lasso.box.width
                    height: lasso.box.height
                    visible: lasso.on && lasso.pressed
                    color: Theme.withAlpha(Theme.primary, 0.12)
                    border.width: Theme.outlineWidth
                    border.color: Theme.primary
                }
            }

            // iOS folder: the dragged file and the one under it come together on a pulsing tile, "New folder" under it.
            Item {
                id: merge

                // The tile under the drag (set with the hover, by card.onDragAtChanged).
                property Item cell: null
                readonly property point at: merge.cell ? merge.cell.mapToItem(body, 0, 0) : Qt.point(0, 0)
                readonly property bool on: (card.shelf?.hover?.merge ?? false) && !!merge.cell
                readonly property var source: (card.shelf?.takingOut ?? false) ? (card.shelf?.dragKeys?.[0] ?? "") : ""
                readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion

                onOnChanged: {
                    pairSpring.snapTo(0);
                    if (merge.on)
                        pairSpring.enabled ? pairSpring.retarget(1) : pairSpring.snapTo(1);
                }

                visible: merge.on && shelvesView.visible
                // It comes in with the two files' pop.
                opacity: Math.min(1, pair.together * 2)
                x: merge.at.x
                y: merge.at.y
                width: card.tileSize
                height: card.cellHeight

                Rectangle {
                    width: card.tileSize
                    height: width
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.width: Theme.outlineWidthFocused
                    border.color: Theme.primary

                    Rectangle {
                        id: halo

                        anchors.fill: parent
                        anchors.margins: -Theme.spacingXS
                        radius: parent.radius + Theme.spacingXS
                        color: "transparent"
                        border.width: Theme.spacingXS
                        // A faint ring of the accent, so the breath reads as light rather than as a border.
                        readonly property real ringAlpha: 0.3
                        border.color: Theme.withAlpha(Theme.primary, halo.ringAlpha)
                        // The kit's breath, in 1/16 steps pushed by a Timer (K8): the card redraws a few dozen times a
                        // second while the merge is on, never every frame, and nothing runs once it is off (K1).
                        opacity: merge.still ? 1 : Math.round(16 * Math.sin(Math.PI * halo.step / halo.steps)) / 16

                        readonly property int steps: 32
                        property int step: 0
                        Timer {
                            running: merge.on && !merge.still
                            repeat: true
                            interval: Math.max(1, Math.round(Kit.beat("breath", Theme.currentAnimationBaseDuration) / halo.steps))
                            onTriggered: halo.step = (halo.step + 1) % halo.steps
                        }
                    }

                    Item {
                        id: pair

                        readonly property real together: pairSpring.value
                        readonly property real thumb: card.tileSize / 2

                        anchors.centerIn: parent
                        width: pair.thumb * 2
                        height: pair.thumb

                        SpringMotion {
                            id: pairSpring

                            readonly property var spec: Kit.spring("pop", Theme.currentAnimationBaseDuration)
                            enabled: !merge.still
                            stiffness: spec.stiffness
                            damping: spec.damping
                            mass: spec.mass
                        }

                        IslandShelfThumb {
                            x: pair.together * pair.thumb / 4
                            width: pair.thumb
                            height: pair.thumb
                            rotation: -10 + 4 * pair.together
                            scale: 1 - 0.1 * pair.together
                            path: merge.source || (card.shelf?.hover?.row ?? "")
                            iconSize: Theme.iconSizeSmall
                        }
                        IslandShelfThumb {
                            x: pair.thumb - pair.together * pair.thumb / 4
                            width: pair.thumb
                            height: pair.thumb
                            rotation: 10 - 4 * pair.together
                            scale: 1 - 0.1 * pair.together
                            path: card.shelf?.hover?.row ?? ""
                            iconSize: Theme.iconSizeSmall
                        }
                    }
                }
                StyledText {
                    y: card.tileSize + Theme.spacingXS
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.tr("New folder", "island shelf: a folder made by holding a file on another")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.primary
                }
            }

            // Space or a tile's eye: a quick look over the whole body, ←/→ to the next (F16). What it shows follows the
            // file (Shelf.peekKind): the picture itself (wheel: zoom), a GIF or a mute video playing, a sound with its
            // cover and a play button, a PDF's or office document's pages (↑/↓ scroll, then turn), a text (Markdown
            // rendered, code coloured), an archive's contents. A folder opens a browser in three panes: its whole tree
            // on the left (the current place marked, folders fold), what is looked at in the middle (the folder's
            // tiles, or a file's look), the facts on the right. A tile or a row drags out of the island.
            Rectangle {
                id: peekBox

                readonly property string key: card.list[card.shelf?.cur ?? 0] ?? ""
                readonly property bool folderMode: peekBox.key !== "" && (card.dirs.indexOf(peekBox.key) !== -1 || Shelf.isGroup(peekBox.key))
                // Inside the key's folder: the folder browsed (a real one; "" for the key itself), the file opened, and
                // for a shelf folder the real folder entered from it (the tree's root while inside).
                property string dir: ""
                property string file: ""
                property string entered: ""
                // The row selected in the tree ("" for the root): what the right pane tells about, what Space opens.
                property string sel: ""
                readonly property string subject: peekBox.sel !== "" ? peekBox.sel : peekBox.shown
                // Where the keys are: the tree, or the tiles in the middle (→ from the folder entered, ← back out).
                property string pane: "tree"
                // The folder shown when the keys went to the tiles: ← there gives them back to the tree.
                property string tilesRoot: ""
                readonly property int tileAt: peekBox.mosaic.indexOf(peekBox.sel)
                readonly property string shown: peekBox.file !== "" ? peekBox.file : peekBox.dir !== "" ? peekBox.dir : peekBox.key
                readonly property bool canBack: peekBox.file !== "" || peekBox.dir !== ""
                readonly property string treeRoot: Shelf.isGroup(peekBox.key) ? (peekBox.dir !== "" ? peekBox.entered : "") : peekBox.key
                // The whole tree under treeRoot (find, once per root), or a shelf folder's items flat.
                property var treeAll: ({
                        "paths": [],
                        "dirs": [],
                        "size": {},
                        "mtime": {}
                    })
                readonly property var treeData: peekBox.treeRoot !== "" ? peekBox.treeAll : ({
                        "paths": card.shelf?.groups?.[Shelf.groupId(peekBox.key)]?.items ?? [],
                        "dirs": card.dirs,
                        "size": card.shelf?.facts?.size ?? {},
                        "mtime": card.shelf?.facts?.mtime ?? {}
                    })
                // Folders folded or unfolded by hand in the tree.
                property var open: ({})
                // The tree fitted the pane when read: it opens whole, and stays so when a folder is read again.
                property bool whole: false
                // Open along what is shown (never along the selection: see curPath).
                // K9: the shown file's folder, not the file, so moving among siblings keeps the same rows array.
                readonly property string along: peekBox.file !== "" ? Shelf.parent(peekBox.file) : peekBox.dir !== "" ? peekBox.dir : peekBox.treeRoot
                readonly property var rows: peekBox.folderMode && peekBox.visible ? Shelf.treeRows(peekBox.treeData, peekBox.treeRoot, peekBox.along, peekBox.open, peekBox.whole ? Infinity : 0) : []
                readonly property string look: peekBox.file !== "" ? Shelf.peekKind(peekBox.file, []) : peekBox.dir !== "" ? "mosaic" : peekBox.key !== "" ? Shelf.peekKind(peekBox.key, card.dirs) : "icon"
                readonly property bool paged: peekBox.look === "pages"
                readonly property bool textual: ["text", "code", "markdown", "listing"].indexOf(peekBox.look) !== -1
                // The folder looked at: its entries as tiles (a shelf folder: its items).
                readonly property var mosaic: peekBox.look !== "mosaic" ? [] : Shelf.isGroup(peekBox.shown) ? peekBox.treeData.paths : Shelf.children(peekBox.treeData, peekBox.shown)
                readonly property var mosaicDirs: peekBox.treeData.dirs
                property int pageNo: 1
                // The page asked for: {url, pages} once rendered, "" while rendering, false when it failed.
                readonly property var pageInfo: card.shelf?.previews?.pages?.[peekBox.shown + "\n" + peekBox.pageNo]
                readonly property int pageCount: peekBox.pageInfo?.pages ?? 0
                // The helper's answer for what is shown: a text (rich for code), an archive's listing, a picture's or a
                // sound's facts.
                property string content: ""
                property var facts: null
                // What is said instead of a body that cannot show: "empty", "binary", "missing" (Shelf.textWord).
                property string word: ""
                property real zoom: 1
                readonly property var codeColors: ({
                        "comment": Theme.surfaceVariantText.toString(),
                        "string": Theme.tertiary.toString(),
                        "number": Theme.secondary.toString(),
                        "keyword": Theme.primary.toString()
                    })

                // Asked again for each tile the arrows reach, and at each step inside a folder.
                function read() {
                    peekReader.running = false;
                    peekBox.content = "";
                    peekBox.facts = null;
                    peekBox.word = "";
                    peekBox.zoom = 1;
                    peekBox.pageNo = 1;
                    pageView.landAtEnd = false;
                    if (!peekBox.visible || peekBox.shown === "" || !card.shelf)
                        return;
                    const script = card.shelf.script;
                    switch (peekBox.look) {
                    case "pages":
                        card.shelf.previews.page(peekBox.shown, 1);
                        return;
                    case "text":
                    case "code":
                    case "markdown":
                        peekReader.command = ["sh", script, "content", "--", peekBox.shown];
                        break;
                    case "listing":
                        peekReader.command = ["sh", script, "list", "--", peekBox.shown];
                        break;
                    case "picture":
                        peekReader.command = ["sh", script, "info", "--", peekBox.shown];
                        break;
                    case "audio":
                    case "video":
                        peekReader.command = ["sh", script, "tags", "--", peekBox.shown];
                        break;
                    default:
                        return;
                    }
                    peekReader.running = true;
                }

                // The tree under the root, six levels deep at most, hidden entries left out.
                function loadTree() {
                    treeReader.running = false;
                    peekBox.whole = false;
                    peekBox.treeAll = {
                        "paths": [],
                        "dirs": [],
                        "size": {},
                        "mtime": {}
                    };
                    if (!peekBox.visible || peekBox.treeRoot === "")
                        return;
                    treeReader.command = ["find", peekBox.treeRoot, "-mindepth", "1", "-maxdepth", String(Shelf.treeDepth), "-not", "-path", "*/.*", "-printf", "%y\t%s\t%T@\t%p\n"];
                    treeReader.running = true;
                }

                function reset() {
                    peekBox.dir = "";
                    peekBox.file = "";
                    peekBox.entered = "";
                    peekBox.sel = "";
                    peekBox.pane = "tree";
                    peekBox.tilesRoot = "";
                    peekBox.open = {};
                }

                // The next or the previous page; a previous page opens at its end.
                function turn(d) {
                    if (!peekBox.paged || !card.shelf)
                        return;
                    const n = Math.max(1, Math.min(peekBox.pageCount || 1, peekBox.pageNo + d));
                    if (n === peekBox.pageNo)
                        return;
                    pageView.landAtEnd = d < 0;
                    peekBox.pageNo = n;
                    card.shelf.previews.page(peekBox.shown, n);
                }

                // ↑/↓: what shows scrolls by most of its height; a document at its page's end turns the page.
                function scroll(d) {
                    const view = pageView.visible ? pageView : textView.visible ? textView : mosaicView.visible ? mosaicView : null;
                    if (!view) {
                        peekBox.turn(d);
                        return;
                    }
                    const max = Math.max(0, view.contentHeight - view.height);
                    const to = Math.max(0, Math.min(max, view.contentY + d * view.height * 0.8));
                    if (to !== view.contentY)
                        view.contentY = to;
                    else
                        peekBox.turn(d);
                }

                // The selection (sel: a row of the tree, "" for the root) is one thing, what the middle shows (dir, file)
                // another: ↑/↓ and a click only select; Space, → or a double click open the selection (a file: its
                // look; a folder: its tiles, entered), Space again, ← or Backspace close or leave it.
                // The rows never follow the selection (a new selection rebuilt every row, a huge tree froze): each row
                // reads curPath. The selection moves along rows on show, inside what is shown.
                readonly property string curPath: peekBox.sel !== "" ? peekBox.sel : peekBox.treeRoot
                readonly property int curRow: peekBox.rows.findIndex(r => r.path === peekBox.curPath)
                readonly property bool selDir: peekBox.sel === "" || peekBox.sel === peekBox.treeRoot || peekBox.treeData.dirs.indexOf(peekBox.sel) !== -1
                function select(path) {
                    peekBox.sel = path === peekBox.treeRoot ? "" : path;
                }
                function enterDir(path) {
                    if (path === "" || path === peekBox.treeRoot) {
                        peekBox.dir = "";
                        return;
                    }
                    if (Shelf.isGroup(peekBox.key) && peekBox.dir === "")
                        peekBox.entered = path;
                    peekBox.open = Object.assign({}, peekBox.open, {
                        [path]: true
                    });
                    peekBox.dir = path;
                    peekBox.select(path);
                }
                // Open the selection: a folder is entered, a file shows its look.
                function openSel() {
                    if (peekBox.selDir)
                        peekBox.enterDir(peekBox.sel);
                    else {
                        peekBox.file = peekBox.sel;
                        peekBox.dir = Shelf.parent(peekBox.sel) === peekBox.treeRoot ? "" : Shelf.parent(peekBox.sel);
                    }
                }
                // Space: the selection opens, or closes if it is what shows (a file looked at, the folder entered).
                // Among the tiles, a folder entered puts the keys on its first tile.
                function space() {
                    if (peekBox.file !== "" && peekBox.file === peekBox.sel) {
                        peekBox.file = "";
                        return;
                    }
                    if (peekBox.selDir && peekBox.sel !== "" && peekBox.dir === peekBox.sel) {
                        peekBox.back();
                        return;
                    }
                    const wasDir = peekBox.selDir;
                    peekBox.openSel();
                    if (wasDir && peekBox.pane === "tiles" && peekBox.mosaic.length)
                        peekBox.sel = peekBox.mosaic[0];
                }
                // The keys among the tiles: ↑/↓ from tile to tile, → into the selected folder (its first tile) or onto a
                // file's look, ← out of the folder to the tile it was; ← where the keys came in: back to the tree.
                function tilesMove(key) {
                    const n = peekBox.mosaic.length;
                    const i = Math.max(0, peekBox.tileAt);
                    if (key === Qt.Key_Up || key === Qt.Key_Down) {
                        const j = key === Qt.Key_Up ? i - 1 : i + 1;
                        if (j >= 0 && j < n)
                            peekBox.sel = peekBox.mosaic[j];
                        return;
                    }
                    if (key === Qt.Key_Right) {
                        if (!peekBox.selDir) {
                            peekBox.openSel();
                            return;
                        }
                        // A folder read as empty (not walked yet, or empty) is entered all the same, as Space does.
                        if (peekBox.sel === "")
                            return;
                        peekBox.enterDir(peekBox.sel);
                        if (peekBox.mosaic.length)
                            peekBox.sel = peekBox.mosaic[0];
                        return;
                    }
                    if (peekBox.dir !== "" && peekBox.dir !== peekBox.tilesRoot)
                        peekBox.back();
                    else
                        peekBox.pane = "tree";
                }
                // One step back: out of the file, then up one folder (to the shelf folder's items past its real root).
                function back() {
                    if (peekBox.file !== "") {
                        peekBox.file = "";
                        return;
                    }
                    if (peekBox.dir === "")
                        return;
                    const up = Shelf.parent(peekBox.dir);
                    const out = peekBox.dir === peekBox.treeRoot || up === peekBox.treeRoot && !Shelf.isGroup(peekBox.key);
                    peekBox.select(peekBox.dir);
                    peekBox.dir = out ? "" : up;
                    if (out && Shelf.isGroup(peekBox.key))
                        peekBox.entered = "";
                }
                function toggle(path) {
                    const row = peekBox.rows.find(r => r.path === path);
                    peekBox.open = Object.assign({}, peekBox.open, {
                        [path]: !(row?.open ?? false)
                    });
                }
                function move(d) {
                    const i = peekBox.curRow;
                    const j = Math.max(0, Math.min(peekBox.rows.length - 1, i + d));
                    if (j !== i)
                        peekBox.select(peekBox.rows[j].path);
                }
                // Home, End, a page or a letter: among the tiles when they hold the keys, else along the tree's rows.
                function leap(to, text) {
                    const tiles = peekBox.pane === "tiles" && peekBox.file === "";
                    const list = tiles ? peekBox.mosaic : peekBox.rows.map(r => r.path);
                    const i = tiles ? peekBox.tileAt : peekBox.curRow;
                    const page = tiles ? mosaicView.columns * Math.max(1, Math.floor(mosaicView.height / mosaicView.step)) : Math.max(1, Math.floor(treeView.height / treePane.rowHeight) - 1);
                    const j = text ? Shelf.typeAhead(list.map(p => Shelf.name(p)), text, i) : Shelf.leap(i, list.length, to, page);
                    if (j < 0)
                        return;
                    if (tiles)
                        peekBox.sel = list[j];
                    else
                        peekBox.select(list[j]);
                }
                onTileAtChanged: mosaicView.reveal(peekBox.tileAt)
                // →: the selected folder is entered and the keys go to its tiles (the first one); a file opens.
                function goRight() {
                    if (!peekBox.selDir) {
                        peekBox.openSel();
                        return;
                    }
                    if (peekBox.sel !== "" && peekBox.dir !== peekBox.sel)
                        peekBox.enterDir(peekBox.sel);
                    if (!peekBox.mosaic.length)
                        return;
                    peekBox.tilesRoot = peekBox.dir;
                    peekBox.pane = "tiles";
                    peekBox.sel = peekBox.mosaic[0];
                }
                // ←: the file closes; the folder entered is left; an unfolded folder folds; else the parent row is
                // selected; on the root: false, the quick look closes.
                function goLeft() {
                    if (peekBox.file !== "") {
                        peekBox.file = "";
                        return true;
                    }
                    const r = peekBox.rows[peekBox.curRow];
                    if (!r)
                        return false;
                    if (peekBox.dir !== "" && peekBox.dir === r.path) {
                        peekBox.back();
                        return true;
                    }
                    if (r.dir && r.open && r.kids > 0 && r.depth > 0) {
                        peekBox.toggle(r.path);
                        return true;
                    }
                    if (r.depth === 0)
                        return false;
                    peekBox.select(r.depth === 1 ? peekBox.treeRoot : Shelf.parent(r.path));
                    return true;
                }
                onCurRowChanged: treeView.reveal(peekBox.curRow)

                // The name on top: the shelf's label for a key, the entry's own name inside a folder.
                function title(key) {
                    return peekBox.subject !== key ? Shelf.name(peekBox.subject) : card.shelf?.label(key) ?? "";
                }
                function when(ms) {
                    return ms ? Qt.locale().toString(new Date(ms), Locale.ShortFormat) : "";
                }
                function bytes(n) {
                    if (n === undefined)
                        return "";
                    const b = Transfer.bytes(n);
                    return b.value.toLocaleString(Qt.locale(), "f", b.decimals) + " " + b.unit;
                }
                // The folder and the change date, under the name (a file alone).
                function where(key) {
                    const p = peekBox.shown;
                    if (Shelf.isGroup(p))
                        return "";
                    const ms = peekBox.canBack ? peekBox.treeData.mtime[p] : card.shelf?.facts?.mtime?.[key];
                    const dir = Shelf.parent(p);
                    return ms ? dir + " · " + peekBox.when(ms) : dir;
                }
                // The third line: the size and type, with a picture's dimensions and camera, a sound's tags, a page count.
                function detail(key) {
                    let d = card.metaOf(key);
                    if (peekBox.canBack) {
                        const ext = Shelf.extension(peekBox.shown).toUpperCase();
                        const size = peekBox.bytes(peekBox.treeData.size[peekBox.shown]);
                        d = peekBox.look === "mosaic" ? I18n.tr("Folder", "island shelf row: a kept folder") : size ? size + (ext ? " · " + ext : "") : ext;
                    }
                    const f = peekBox.facts;
                    if (peekBox.look === "picture" && f && f.width)
                        d = f.width + " × " + f.height + " · " + d + (f.camera ? " · " + f.camera : "") + (f.when ? " · " + peekBox.when(f.when) : "");
                    else if (peekBox.look === "audio" && f)
                        d = [f.title, f.artist, f.album].filter(s => s).join(" · ") + (f.length && f.seconds ? " · " + f.length : "") + " · " + d;
                    else if (peekBox.look === "video" && f)
                        d = (f.width ? f.width + " × " + f.height + " · " : "") + (f.seconds ? f.length + " · " : "") + d;
                    else if (peekBox.paged && peekBox.pageCount)
                        d = I18n.tr("Page %1 of %2", "island shelf: quick look at a document, the page shown").arg(peekBox.pageNo).arg(peekBox.pageCount) + " · " + d;
                    return d;
                }
                // The right pane: label and value rows about the subject (the selection, else what is looked at).
                function info() {
                    const p = peekBox.subject;
                    const group = Shelf.isGroup(p);
                    const inside = p !== peekBox.key;
                    const isDir = group || p === peekBox.treeRoot || peekBox.treeData.dirs.indexOf(p) !== -1 || (!inside && card.dirs.indexOf(p) !== -1);
                    // The same facts whichever way it was reached: the tree's, else the shelf's (a folder entered from a shelf folder).
                    const ms = group ? 0 : inside ? peekBox.treeData.mtime[p] ?? card.shelf?.facts?.mtime?.[p] : card.shelf?.facts?.mtime?.[p];
                    const size = group ? "" : peekBox.bytes(inside ? peekBox.treeData.size[p] ?? card.shelf?.facts?.size?.[p] : card.shelf?.facts?.size?.[p]);
                    const f = peekBox.file === p ? peekBox.facts : null;
                    const out = [];
                    const add = (label, value) => {
                        if (value)
                            out.push({
                                "label": label,
                                "value": String(value)
                            });
                    };
                    add(I18n.tr("Where", "island shelf: quick look, the folder holding the item"), group ? "" : Shelf.wrapPath(Paths.shortenHome(Shelf.parent(p))));
                    add(I18n.tr("Modified", "island shelf: quick look, the change date"), peekBox.when(ms));
                    if (isDir)
                        add(I18n.tr("Items", "island shelf: quick look, how many entries a folder holds"), group ? peekBox.treeData.paths.length : Shelf.children(peekBox.treeData, p).length);
                    else
                        add(I18n.tr("Size", "island shelf: quick look, the file's size"), size);
                    add(I18n.tr("Type", "island shelf: quick look, the file's type"), isDir ? (group ? I18n.tr("Shelf folder", "island shelf: a folder of the shelf") : I18n.tr("Folder", "island shelf row: a kept folder")) : Shelf.extension(p).toUpperCase());
                    if (peekBox.look === "picture" && f && f.width) {
                        add(I18n.tr("Dimensions", "island shelf: quick look, a picture's width and height"), f.width + " × " + f.height);
                        add(I18n.tr("Taken", "island shelf: quick look, when a photo was shot"), peekBox.when(f.when));
                        add(I18n.tr("Camera", "island shelf: quick look, the camera of a photo"), f.camera);
                    } else if (peekBox.look === "audio" && f) {
                        add(I18n.tr("Title", "island shelf: quick look, a sound's title"), f.title);
                        add(I18n.tr("Artist", "island shelf: quick look, a sound's artist"), f.artist);
                        add(I18n.tr("Album", "island shelf: quick look, a sound's album"), f.album);
                        add(I18n.tr("Length", "island shelf: quick look, a sound's length"), f.seconds ? f.length : "");
                    } else if (peekBox.file === p && peekBox.paged && peekBox.pageCount) {
                        add(I18n.tr("Page", "island shelf: quick look, the page shown"), peekBox.pageNo + " / " + peekBox.pageCount);
                    }
                    return out;
                }

                anchors.fill: parent
                visible: (card.shelf?.peek ?? false) && peekBox.key !== ""
                clip: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: Theme.outlineWidth
                border.color: Theme.outlineVariant
                Accessible.role: Accessible.Dialog
                Accessible.name: I18n.tr("Quick look", "island shelf: the preview of a file")

                onVisibleChanged: {
                    peekBox.reset();
                    peekBox.loadTree();
                    peekBox.read();
                    // Closed: the tile it showed comes back into view, above the actions' row.
                    if (!peekBox.visible && card.shelf)
                        card.reveal(card.shelf.cur);
                }
                onKeyChanged: peekBox.reset()
                onTreeRootChanged: peekBox.loadTree()
                // A folder looked at that the tree may lack (past its depth, or after its cut) is read on its own.
                readonly property string relook: peekBox.look === "mosaic" && !treeReader.running && Shelf.unread(peekBox.treeAll, peekBox.treeRoot, peekBox.shown) ? peekBox.shown : ""
                onRelookChanged: {
                    if (peekBox.relook === "")
                        return;
                    dirReader.running = false;
                    dirReader.dir = peekBox.relook;
                    dirReader.command = ["find", peekBox.relook, "-mindepth", "1", "-maxdepth", "1", "-not", "-name", ".*", "-printf", "%y\t%s\t%T@\t%p\n"];
                    dirReader.running = true;
                }
                // The selection, for the shelf's actions, Enter and Ctrl+C while the browser shows (root: the folder);
                // set by hand, so that closing always gives the shelf its own choice back.
                readonly property var asideNow: peekBox.visible && peekBox.folderMode && (peekBox.sel !== "" || peekBox.treeRoot !== "") ? [peekBox.sel !== "" ? peekBox.sel : peekBox.treeRoot] : []
                onAsideNowChanged: {
                    if (!card.shelf)
                        return;
                    card.shelf.asideDirs = peekBox.selDir ? peekBox.asideNow : [];
                    card.shelf.aside = peekBox.asideNow;
                }
                // The key, or a folder entered or a file opened inside it: asked again at each step.
                onShownChanged: peekBox.read()
                Process {
                    id: peekReader

                    onExited: code => {
                        if (code === 4)
                            peekBox.word = "missing";
                    }
                    stdout: StdioCollector {
                        onStreamFinished: {
                            // An empty or binary text says so instead of its body (a gone file's word stays).
                            const w = peekBox.textual ? Shelf.textWord(text) : "";
                            if (w !== "") {
                                peekBox.word = peekBox.word || w;
                                return;
                            }
                            switch (peekBox.look) {
                            case "code":
                                peekBox.content = Shelf.highlight(text, Shelf.extension(peekBox.shown), peekBox.codeColors);
                                break;
                            case "listing": {
                                const l = Shelf.listing(text);
                                peekBox.content = l.empty ? I18n.tr("Empty archive", "island shelf: quick look at an archive with nothing in it") : l.more ? l.text + "\n" + I18n.tr("… %1 more", "island shelf: quick look at a folder, the lines left out").arg(l.more) : l.text;
                                break;
                            }
                            case "picture":
                                peekBox.facts = Shelf.imageInfo(text);
                                break;
                            case "audio":
                            case "video":
                                peekBox.facts = Shelf.audioInfo(text);
                                break;
                            case "markdown":
                                // A1: the theme's accent where it reads as text on the card, else its text tone.
                                peekBox.content = Shelf.markdownLinks(text, Kit.legible(Theme.primary, Theme.surfaceText, Theme.surfaceContainerHigh, 1, Kit.textMin).toString());
                                break;
                            default:
                                peekBox.content = text;
                            }
                        }
                    }
                }
                Process {
                    id: treeReader

                    stdout: StdioCollector {
                        onStreamFinished: {
                            const t = Shelf.entries(text);
                            peekBox.whole = Math.floor(treeView.height / treePane.rowHeight) > t.paths.length;
                            peekBox.treeAll = t;
                        }
                    }
                }
                Process {
                    id: dirReader

                    property string dir: ""

                    stdout: StdioCollector {
                        onStreamFinished: {
                            if (dirReader.dir !== "" && Shelf.unread(peekBox.treeAll, peekBox.treeRoot, dirReader.dir))
                                peekBox.treeAll = Shelf.merge(peekBox.treeAll, text, dirReader.dir);
                        }
                    }
                }

                // The tiles under it stay out of reach; a click on the margins does nothing (Escape, Space or ← on the
                // tree's root close it, his word).
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    onPressed: card.pointerPress()
                }

                // A file alone: name, place and facts on top, its look under. A folder: the three panes. The keys that
                // close it at the bottom once the keyboard is in use.
                Item {
                    id: peekInner

                    readonly property real roomTop: peekBox.folderMode ? 0 : peekHead.height + Theme.spacingS
                    readonly property real room: Math.max(0, (peekKeys.visible ? peekKeys.y - Theme.spacingS : height) - peekInner.roomTop)
                    readonly property real quarter: Math.floor((width - 2 * Theme.spacingM) / 4)

                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    // One click closes the preview, the card stays (a folder's: under its facts, on the right).
                    BubbleAction {
                        id: peekClose

                        x: parent.width - width
                        visible: !peekBox.folderMode
                        buttonHeight: card.smallButton
                        iconName: "close"
                        Accessible.name: I18n.tr("Close preview", "island shelf: button that closes the quick look, the card stays")
                        onClicked: card.shelf.peek = false
                    }
                    Column {
                        id: peekHead

                        width: parent.width - peekClose.width - Theme.spacingS
                        visible: !peekBox.folderMode
                        spacing: Theme.spacingXXS

                        StyledText {
                            width: parent.width
                            text: peekBox.title(peekBox.key)
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: peekBox.where(peekBox.key)
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            width: parent.width
                            text: peekBox.detail(peekBox.key)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    // Left pane: the tree. Each row: its depth as an indent, a fold arrow for a folder with entries, the
                    // type's icon, the name; the current place filled, its ancestors in the strong colour. A click on
                    // the arrow folds, on the rest goes there; a press that moves drags the entry out.
                    Rectangle {
                        id: treePane

                        readonly property real rowHeight: Theme.iconSize + Theme.spacingS

                        visible: peekBox.folderMode
                        width: peekInner.quarter
                        height: peekInner.room
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer
                        // The pane holding the keys wears a ring.
                        border.width: peekBox.pane === "tree" && card.keyboard ? Theme.outlineWidth : 0
                        border.color: Theme.primary

                        DFlickable {
                            id: treeView

                            // The row i brought into view, once the rows are laid out.
                            function reveal(i) {
                                if (i < 0)
                                    return;
                                Qt.callLater(() => {
                                    const y = i * treePane.rowHeight;
                                    if (y < treeView.contentY)
                                        treeView.contentY = y;
                                    else if (y + treePane.rowHeight > treeView.contentY + treeView.height)
                                        treeView.contentY = Math.max(0, y + treePane.rowHeight - treeView.height);
                                });
                            }

                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            contentHeight: treeCol.implicitHeight
                            fadeLength: Theme.spacingS
                            clip: true
                            interactive: contentHeight > height

                            Column {
                                id: treeCol

                                width: treeView.width

                                Repeater {
                                    id: treeRepeater

                                    model: peekBox.rows

                                    Rectangle {
                                        id: treeRow

                                        required property var modelData
                                        readonly property string path: treeRow.modelData.path
                                        readonly property bool isRoot: treeRow.modelData.depth === 0
                                        readonly property bool current: treeRow.path === peekBox.curPath
                                        readonly property bool onPath: treeRow.current || treeRow.isRoot || peekBox.curPath.startsWith(treeRow.path + "/")
                                        readonly property string label: treeRow.isRoot ? (peekBox.treeRoot !== "" ? Shelf.name(peekBox.treeRoot) : card.shelf?.label(peekBox.key) ?? "") : Shelf.name(treeRow.path)

                                        width: treeCol.width
                                        height: treePane.rowHeight
                                        radius: Theme.cornerRadius / 2
                                        color: treeRow.current ? Theme.primaryContainer : rowPress.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                        // A drag over it: the folder the files would move into wears the drop ring.
                                        border.width: treeRow.path !== "" && treeRow.path === (card.shelf?.hover?.dir ?? "") ? Theme.outlineWidthFocused : 0
                                        border.color: Theme.primary
                                        Accessible.role: Accessible.TreeItem
                                        Accessible.name: treeRow.label
                                        Accessible.selected: treeRow.current

                                        Row {
                                            id: rowLine

                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.spacingXS + treeRow.modelData.depth * Theme.spacingM
                                            anchors.rightMargin: Theme.spacingXS
                                            spacing: Theme.spacingXXS

                                            DIcon {
                                                id: fold

                                                readonly property bool folds: treeRow.modelData.dir && treeRow.modelData.kids > 0 && !treeRow.isRoot

                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: treeRow.modelData.dir
                                                opacity: fold.folds ? 1 : 0
                                                name: treeRow.modelData.open ? "expand_more" : "chevron_right"
                                                size: Theme.iconSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                            DIcon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: treeRow.modelData.dir ? (treeRow.modelData.open ? "folder_open" : "folder") : Shelf.icon(treeRow.path, [])
                                                size: Theme.iconSizeSmall
                                                color: treeRow.current ? Theme.primary : treeRow.onPath ? Theme.surfaceText : Theme.surfaceVariantText
                                            }
                                            StyledText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(0, parent.width - (fold.visible ? fold.width + parent.spacing : 0) - Theme.iconSizeSmall - parent.spacing)
                                                text: treeRow.label
                                                elide: Text.ElideMiddle
                                                wrapMode: Text.NoWrap
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: treeRow.onPath || treeRow.current ? Theme.fontWeightMedium : Theme.fontWeight
                                                color: treeRow.current ? Theme.primary : treeRow.onPath ? Theme.surfaceText : Theme.surfaceVariantText
                                            }
                                        }
                                        Item {
                                            id: rowProxy

                                            property bool starting: false

                                            Drag.dragType: Drag.Automatic
                                            Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
                                            Drag.mimeData: ({
                                                    "text/uri-list": Shelf.uriList(Shelf.isGroup(treeRow.path) ? Shelf.expand([treeRow.path], card.shelf?.groups ?? {}) : [treeRow.path])
                                                })
                                            Drag.onActiveChanged: card.shelf?.takeOut(rowProxy.Drag.active, [treeRow.path])

                                            function start(at) {
                                                rowProxy.starting = true;
                                                rowProxy.Drag.hotSpot = at;
                                                treeRow.grabToImage(result => {
                                                    rowProxy.starting = false;
                                                    if (!rowPress.pressed)
                                                        return;
                                                    rowProxy.Drag.imageSource = result.url;
                                                    rowProxy.Drag.active = true;
                                                }, Qt.size(treeRow.width, treeRow.height));
                                            }
                                        }
                                        MouseArea {
                                            id: rowPress

                                            property point from

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: rowPress.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            onPressed: mouse => {
                                                rowPress.from = Qt.point(mouse.x, mouse.y);
                                                card.pointerPress();
                                            }
                                            onPositionChanged: mouse => {
                                                if (treeRow.path !== "" && (rowPress.pressedButtons & Qt.LeftButton) && !rowProxy.Drag.active && !rowProxy.starting && Math.abs(mouse.x - rowPress.from.x) + Math.abs(mouse.y - rowPress.from.y) > Theme.spacingS)
                                                    rowProxy.start(rowPress.from);
                                            }
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                // A right click: the row selected, its whole plan at the pointer (P8).
                                                const at = rowPress.mapToItem(card, mouse.x, mouse.y);
                                                if (mouse.button === Qt.RightButton) {
                                                    peekBox.pane = "tree";
                                                    peekBox.select(treeRow.path);
                                                    card.openMenu("file", at);
                                                    return;
                                                }
                                                // Left of the name, on the fold arrow's side: the folder folds or unfolds.
                                                if (fold.folds && mouse.x < rowLine.x + fold.x + fold.width + Theme.spacingXS) {
                                                    peekBox.toggle(treeRow.path);
                                                    return;
                                                }
                                                peekBox.pane = "tree";
                                                peekBox.select(treeRow.path);
                                            }
                                            onDoubleClicked: {
                                                peekBox.select(treeRow.path);
                                                peekBox.openSel();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Middle (a folder) or whole width (a file alone): what is looked at.
                    Item {
                        id: peekContent

                        x: peekBox.folderMode ? treePane.width + Theme.spacingM : 0
                        y: peekInner.roomTop
                        width: peekBox.folderMode ? peekInner.width - 2 * peekInner.quarter - 2 * Theme.spacingM : peekInner.width
                        height: peekInner.room

                        // A picture whole, fitted in the room, decoded at the size shown; the wheel zooms on its middle.
                        Item {
                            anchors.fill: parent
                            clip: true
                            visible: peekBox.look === "picture" && peekPic.status === Image.Ready

                            Image {
                                id: peekPic

                                anchors.fill: parent
                                source: peekBox.visible && peekBox.look === "picture" ? Shelf.url(peekBox.shown) : ""
                                sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                scale: peekBox.zoom
                                // shortcut: the zoom stays on the middle, no pan; a drag to pan when he asks.
                                Behavior on scale {
                                    enabled: Theme.shortDuration > 0 && !SettingsData.reduceMotion
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Theme.expressiveCurves.standardDecel
                                    }
                                }
                            }
                            // A mouse wheel and a touchpad alike (a WheelHandler takes the mouse alone).
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => peekBox.zoom = Shelf.zoomBy(peekBox.zoom, wheel.angleDelta.y || wheel.pixelDelta.y)
                            }
                        }
                        // A GIF plays as the picture it is.
                        AnimatedImage {
                            anchors.fill: parent
                            source: peekBox.visible && peekBox.look === "gif" ? Shelf.url(peekBox.shown) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            playing: visible
                            visible: peekBox.look === "gif" && status === Image.Ready
                        }
                        // A video plays mute, in a loop, only while looked at.
                        Loader {
                            anchors.fill: parent
                            active: peekBox.visible && peekBox.look === "video"
                            sourceComponent: Video {
                                source: Shelf.url(peekBox.shown)
                                muted: true
                                loops: MediaPlayer.Infinite
                                fillMode: VideoOutput.PreserveAspectFit
                                // Started once loaded: reached by ←/→, the source settles just after creation and a
                                // play() from onCompleted went to the previous file.
                                autoPlay: true
                            }
                        }
                        // A sound: its cover (or the icon), a play button with the time.
                        Loader {
                            anchors.fill: parent
                            active: peekBox.visible && peekBox.look === "audio"
                            sourceComponent: Item {
                                MediaPlayer {
                                    id: player

                                    source: Shelf.url(peekBox.shown)
                                    audioOutput: AudioOutput {}
                                }
                                IslandShelfThumb {
                                    id: cover

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.max(0, (parent.height - playRow.height - Theme.spacingS - height) / 2)
                                    width: Math.min(parent.width, Math.max(0, parent.height - playRow.height - Theme.spacingS), Theme.iconSize * 5)
                                    height: width
                                    path: peekBox.shown
                                    dirs: card.dirs
                                    previews: card.shelf?.previews ?? null
                                    iconSize: Theme.iconSizeLarge
                                }
                                Row {
                                    id: playRow

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    spacing: Theme.spacingS

                                    BubbleAction {
                                        anchors.verticalCenter: parent.verticalCenter
                                        buttonHeight: card.smallButton
                                        iconName: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                                        Accessible.name: player.playbackState === MediaPlayer.PlayingState ? I18n.tr("Pause", "island shelf: quick look at a sound") : I18n.tr("Play", "island shelf: quick look at a sound")
                                        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Shelf.clock(player.position / 1000) + " / " + Shelf.clock((player.duration || (peekBox.facts?.seconds ?? 0) * 1000) / 1000)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                        // A document's page, wide as the room, scrolled with the wheel or ↑/↓; past its end, the next page.
                        DFlickable {
                            id: pageView

                            // A page reached by ↑ shows its end first.
                            property bool landAtEnd: false

                            anchors.fill: parent
                            visible: peekBox.paged && pageImage.status === Image.Ready
                            contentHeight: pageImage.height
                            fadeLength: Theme.spacingS
                            clip: true
                            interactive: contentHeight > height

                            Image {
                                id: pageImage

                                width: pageView.width
                                height: status === Image.Ready && implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                                source: peekBox.pageInfo?.url ?? ""
                                sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                // Once the page is laid out (its height follows the decode), not before the flickable clamps.
                                onStatusChanged: {
                                    if (status === Image.Ready)
                                        Qt.callLater(() => pageView.contentY = pageView.landAtEnd ? Math.max(0, pageView.contentHeight - pageView.height) : 0);
                                }
                            }
                        }
                        // A text whole: Markdown rendered, code coloured, the rest and an archive's listing in mono.
                        DFlickable {
                            id: textView

                            anchors.fill: parent
                            visible: peekBox.textual && peekBox.content !== ""
                            contentHeight: peekText.implicitHeight
                            fadeLength: Theme.spacingS
                            clip: true
                            interactive: contentHeight > height

                            StyledText {
                                id: peekText

                                width: textView.width
                                text: peekBox.content
                                wrapMode: Text.Wrap
                                textFormat: peekBox.look === "markdown" ? Text.MarkdownText : peekBox.look === "code" ? Text.RichText : Text.PlainText
                                font.family: peekBox.look === "markdown" ? Theme.fontFamily : Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                        // The tiles' ring, when the keys are on them.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Theme.spacingXS
                            z: 1
                            visible: peekBox.pane === "tiles" && card.keyboard && peekBox.look === "mosaic"
                            radius: Theme.cornerRadius
                            color: "transparent"
                            border.width: Theme.outlineWidth
                            border.color: Theme.primary
                        }
                        // The folder looked at: its entries as named tiles, three to a row, folders first. A click selects,
                        // a double click enters a folder or opens a file's look; a press that moves drags the entry out
                        // (the shelf's own drag: takeOut masks the dismiss layer, the drop lands anywhere).
                        DFlickable {
                            id: mosaicView

                            readonly property int shown: Math.min(peekBox.mosaic.length, 200)
                            readonly property real cell: Math.max(Theme.iconSize * 2, (width - 2 * Theme.spacingS) / 3)
                            readonly property int columns: Math.max(1, Math.floor((width + Theme.spacingS) / (cell + Theme.spacingS)))
                            readonly property real step: cell + card.nameHeight + Theme.spacingS
                            // The tile i brought into view (one of those drawn).
                            function reveal(i) {
                                if (i < 0 || i >= mosaicView.shown)
                                    return;
                                const y = Math.floor(i / mosaicView.columns) * mosaicView.step;
                                if (y < mosaicView.contentY)
                                    mosaicView.contentY = y;
                                else if (y + mosaicView.step > mosaicView.contentY + mosaicView.height)
                                    mosaicView.contentY = Math.max(0, y + mosaicView.step - mosaicView.height);
                            }

                            anchors.fill: parent
                            visible: peekBox.look === "mosaic" && peekBox.mosaic.length > 0
                            contentHeight: mosaicFlow.implicitHeight
                            fadeLength: Theme.spacingS
                            clip: true
                            interactive: contentHeight > height

                            Flow {
                                id: mosaicFlow

                                width: mosaicView.width
                                spacing: Theme.spacingS

                                Repeater {
                                    id: mosaicRepeater

                                    model: mosaicView.shown

                                    Item {
                                        id: entry

                                        required property int index
                                        readonly property string path: peekBox.mosaic[index] ?? ""
                                        readonly property bool folder: peekBox.mosaicDirs.indexOf(entry.path) !== -1

                                        width: mosaicView.cell
                                        height: mosaicView.cell + card.nameHeight
                                        Accessible.role: Accessible.ListItem
                                        Accessible.name: Shelf.name(entry.path)

                                        Rectangle {
                                            id: entryBox

                                            width: parent.width
                                            height: width
                                            radius: Theme.cornerRadius
                                            color: entryPress.containsMouse ? Theme.surfaceContainerHighest : entry.folder ? Theme.primaryContainer : Theme.surfaceContainer

                                            IslandShelfThumb {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: parent.color
                                                path: entry.path
                                                dirs: peekBox.mosaicDirs
                                                previews: card.shelf?.previews ?? null
                                                iconSize: Theme.iconSizeLarge
                                            }
                                            // The selected tile wears the shelf tiles' ring, over its picture (L5).
                                            Rectangle {
                                                anchors.fill: parent
                                                visible: entry.path === peekBox.sel || entry.path === (card.shelf?.hover?.dir ?? "")
                                                radius: parent.radius
                                                color: "transparent"
                                                border.width: Theme.outlineWidthFocused
                                                border.color: Theme.primary
                                            }
                                        }
                                        StyledText {
                                            anchors.top: entryBox.bottom
                                            anchors.topMargin: Theme.spacingXXS
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: Shelf.name(entry.path)
                                            elide: Text.ElideMiddle
                                            wrapMode: Text.NoWrap
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                        // The drag out of one entry (a folder goes as itself).
                                        Item {
                                            id: entryProxy

                                            property bool starting: false

                                            Drag.dragType: Drag.Automatic
                                            Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
                                            Drag.mimeData: ({
                                                    "text/uri-list": Shelf.uriList([entry.path])
                                                })
                                            Drag.onActiveChanged: card.shelf?.takeOut(entryProxy.Drag.active, [entry.path])

                                            function start(at) {
                                                entryProxy.starting = true;
                                                entryProxy.Drag.hotSpot = at;
                                                entryBox.grabToImage(result => {
                                                    entryProxy.starting = false;
                                                    if (!entryPress.pressed)
                                                        return;
                                                    entryProxy.Drag.imageSource = result.url;
                                                    entryProxy.Drag.active = true;
                                                }, Qt.size(entryBox.width, entryBox.height));
                                            }
                                        }
                                        MouseArea {
                                            id: entryPress

                                            property point from

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: entryPress.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            onPressed: mouse => {
                                                entryPress.from = Qt.point(mouse.x, mouse.y);
                                                card.pointerPress();
                                            }
                                            onPositionChanged: mouse => {
                                                if ((entryPress.pressedButtons & Qt.LeftButton) && !entryProxy.Drag.active && !entryProxy.starting && Math.abs(mouse.x - entryPress.from.x) + Math.abs(mouse.y - entryPress.from.y) > Theme.spacingS)
                                                    entryProxy.start(entryPress.from);
                                            }
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                const at = entryPress.mapToItem(card, mouse.x, mouse.y);
                                                if (peekBox.pane !== "tiles")
                                                    peekBox.tilesRoot = peekBox.dir;
                                                peekBox.pane = "tiles";
                                                peekBox.select(entry.path);
                                                // A right click: the selection's whole plan at the pointer (P8).
                                                if (mouse.button === Qt.RightButton)
                                                    card.openMenu("file", at);
                                            }
                                            onDoubleClicked: {
                                                peekBox.select(entry.path);
                                                peekBox.openSel();
                                            }
                                        }
                                    }
                                }
                                // Past the tiles drawn: how many more, and the folder opened in the file manager for them.
                                Item {
                                    visible: peekBox.mosaic.length > mosaicView.shown
                                    width: mosaicView.cell
                                    height: mosaicView.cell

                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: moreTiles.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        text: I18n.tr("%1 more", "island shelf: quick look at a folder, the entries not drawn as tiles").arg(peekBox.mosaic.length - mosaicView.shown)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                    BubbleAction {
                                        id: moreTiles

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        buttonHeight: card.smallButton
                                        iconName: "open_in_new"
                                        text: I18n.tr("Open", "island shelf action")
                                        Accessible.name: I18n.tr("Open the folder to see the rest", "island shelf: quick look at a huge folder, its file manager")
                                        onClicked: SessionService.openPath(peekBox.shown)
                                    }
                                }
                            }
                        }
                        // Waiting for a page, an empty folder, or a file with no look of its own: a word, or the type's icon.
                        // A gone, empty or binary file and a picture too big to decode say so too.
                        StyledText {
                            id: peekNote

                            readonly property string said: peekBox.word !== "" ? peekBox.word : peekBox.look === "picture" && peekPic.status === Image.Error ? (Shelf.tooBig(peekBox.facts?.width ?? 0, peekBox.facts?.height ?? 0) ? "large" : "none") : ""
                            readonly property var words: ({
                                    "missing": I18n.tr("File not found", "island shelf: quick look at a file deleted meanwhile"),
                                    "empty": I18n.tr("Empty file", "island shelf: quick look at a text file of 0 bytes"),
                                    "binary": I18n.tr("Binary file", "island shelf: quick look at a text that is not text"),
                                    "large": I18n.tr("Too large to preview", "island shelf: quick look at a picture too big to decode"),
                                    "none": I18n.tr("No preview", "island shelf: quick look, the document could not be drawn")
                                })

                            anchors.fill: parent
                            visible: text !== ""
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: peekNote.said !== "" ? peekNote.words[peekNote.said] : peekBox.paged && peekBox.pageInfo === "" ? I18n.tr("Rendering…", "island shelf: quick look at a document, its page not drawn yet") : peekBox.paged && peekBox.pageInfo === false ? I18n.tr("No preview", "island shelf: quick look, the document could not be drawn") : peekBox.look !== "mosaic" || peekBox.mosaic.length ? "" : treeReader.running || dirReader.running || peekBox.relook !== "" ? I18n.tr("Loading...", "island shelf: quick look at a folder, its entries not read yet") : I18n.tr("Empty folder", "island shelf: quick look at a folder with nothing in it")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        IslandShelfThumb {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (parent.height - height) / 2
                            visible: peekNote.said === "" && (peekBox.look === "icon" || (peekBox.look === "picture" && peekPic.status !== Image.Ready && peekPic.status !== Image.Loading))
                            width: Math.min(parent.width, parent.height, Theme.iconSize * 5)
                            height: width
                            path: peekBox.shown
                            dirs: card.dirs
                            previews: card.shelf?.previews ?? null
                            iconSize: Theme.iconSizeLarge
                        }
                    }

                    // Right pane: the facts about what is looked at, one label and value per row, and the way back.
                    Rectangle {
                        id: infoPane

                        visible: peekBox.folderMode
                        x: peekInner.width - width
                        width: peekInner.quarter
                        height: peekInner.room
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        // The selection's three likeliest actions under its facts, Open first with Enter; the rest
                        // behind More and the right click (the owner's word, 01/11).
                        Column {
                            id: selActs

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.spacingS
                            visible: peekBox.sel !== "" && (card.shelf?.aside?.length ?? 0) > 0
                            spacing: Theme.spacingXS

                            Repeater {
                                model: selActs.visible ? card.shelf?.plan?.buttons ?? [] : []

                                delegate: BubbleAction {
                                    required property string modelData
                                    required property int index

                                    width: selActs.width
                                    buttonHeight: card.smallButton
                                    role: index === 0 ? "primary" : "plain"
                                    iconName: card.icons[modelData] ?? ""
                                    text: card.labels[modelData] ?? modelData
                                    keys: card.keyboard ? card.keysFor(modelData) : []
                                    leading: true
                                    busy: !!card.shelf?.busy?.[modelData] && modelData !== "listen"
                                    feedbackText: ["copyFiles", "copyImage", "copyText", "copyContent", "copyPaths", "copySha"].indexOf(modelData) !== -1 ? I18n.tr("Copied!", "island shelf: an action's button after a copy") : ""
                                    Accessible.name: text
                                    onClicked: card.shelf?.act(modelData)
                                }
                            }
                            BubbleAction {
                                id: selMore

                                visible: (card.shelf?.plan?.more?.length ?? 0) > 0
                                width: selActs.width
                                buttonHeight: card.smallButton
                                iconName: "more_horiz"
                                text: I18n.tr("More", "island shelf: the actions under the four buttons")
                                leading: true
                                Accessible.name: text
                                onClicked: card.openMenu("more", selMore.mapToItem(card, selMore.width, 0))
                            }
                        }

                        DFlickable {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: selActs.visible ? selActs.top : parent.bottom
                            anchors.margins: Theme.spacingS
                            contentHeight: infoCol.implicitHeight
                            fadeLength: Theme.spacingS
                            clip: true
                            interactive: contentHeight > height

                            Column {
                                id: infoCol

                                width: parent.width
                                spacing: Theme.spacingS

                                BubbleAction {
                                    visible: peekBox.canBack
                                    width: parent.width
                                    buttonHeight: card.smallButton
                                    iconName: "arrow_back"
                                    text: I18n.tr("Back", "island shelf: quick look inside a folder, one step up")
                                    Accessible.name: text
                                    onClicked: peekBox.back()
                                }
                                BubbleAction {
                                    width: parent.width
                                    buttonHeight: card.smallButton
                                    iconName: "close"
                                    text: I18n.tr("Close", "island shelf: button that closes the quick look of a folder, the card stays")
                                    Accessible.name: text
                                    onClicked: card.shelf.peek = false
                                }
                                StyledText {
                                    width: parent.width
                                    text: peekBox.title(peekBox.key)
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideMiddle
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.surfaceText
                                }
                                Repeater {
                                    model: peekBox.info()

                                    Column {
                                        required property var modelData

                                        width: infoCol.width
                                        spacing: 0

                                        StyledText {
                                            width: parent.width
                                            text: parent.modelData.label
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Theme.fontWeightMedium
                                            color: Theme.surfaceVariantText
                                        }
                                        StyledText {
                                            width: parent.width
                                            text: parent.modelData.value
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 4
                                            elide: Text.ElideMiddle
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: peekKeys

                        anchors.bottom: parent.bottom
                        width: parent.width
                        visible: card.keyboard
                        spacing: Theme.spacingXS

                        Keycaps {
                            id: peekSpace

                            // Inside a folder, Space opens the selection: it no longer closes.
                            visible: !peekBox.folderMode

                            anchors.verticalCenter: parent.verticalCenter
                            keys: [I18n.tr("Space", "keyboard key")]
                        }
                        Keycaps {
                            id: peekEsc

                            anchors.verticalCenter: parent.verticalCenter
                            keys: [I18n.tr("Esc", "keyboard key")]
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, peekKeys.width - (peekSpace.visible ? peekSpace.width + peekKeys.spacing : 0) - peekEsc.width - peekKeys.spacing)
                            text: peekBox.folderMode ? I18n.tr("to close · ↑ ↓ ← → move · Space look · Enter open · Menu actions · ⌫ back", "island shelf: keys that close the preview, move in a folder's tree and tiles, look at the selection, open it in its app, its menu, step back") : peekBox.paged ? I18n.tr("to close · ↑ ↓ scroll · PgUp PgDn page · Enter open in app", "island shelf: keys that close the preview, scroll a document, turn its pages and open it in its app") : peekBox.textual ? I18n.tr("to close · ↑ ↓ scroll · Enter open in app", "island shelf: keys that close the preview, scroll it and open the file in its app") : peekBox.look === "picture" && peekPic.status === Image.Ready ? I18n.tr("to close · scroll to zoom · Enter open in app", "island shelf: keys that close the preview, the wheel zooms the picture, Enter opens it in its app") : I18n.tr("to close · Enter open in app", "island shelf: keys that close the preview and open the file in its app")
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }

            // "?": every key of the card, in two columns, over the tiles (N6); a click or Escape closes it.
            Rectangle {
                id: keySheet

                anchors.fill: parent
                implicitHeight: sheetGrid.implicitHeight + 2 * Theme.spacingM
                visible: card.sheet
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: Theme.outlineWidth
                border.color: Theme.outlineVariant
                Accessible.role: Accessible.Dialog
                Accessible.name: I18n.tr("Keyboard shortcuts", "island shelf: the sheet of every key")

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.sheet = false
                }
                Grid {
                    id: sheetGrid

                    readonly property real half: (keySheet.width - 2 * Theme.spacingM - Theme.spacingL) / 2

                    x: Theme.spacingM
                    y: Theme.spacingM
                    columns: 2
                    columnSpacing: Theme.spacingL
                    rowSpacing: Theme.spacingXS

                    Repeater {
                        model: card.keySheet

                        Item {
                            id: keyLine

                            required property var modelData

                            width: sheetGrid.half
                            height: Math.max(keyCaps.implicitHeight, keyText.implicitHeight)

                            // The keys right-aligned in their own column, the words lined up after them.
                            Keycaps {
                                id: keyCaps

                                x: Theme.iconSize * 5 - width
                                anchors.verticalCenter: parent.verticalCenter
                                keys: keyLine.modelData[0]
                            }
                            StyledText {
                                id: keyText

                                x: Theme.iconSize * 5 + Theme.spacingS
                                width: parent.width - x
                                anchors.verticalCenter: parent.verticalCenter
                                text: keyLine.modelData[1]
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }
                    }
                }
            }
        }

        // A choice: its name and size, then three of its actions (C11), the rest behind "⋯".
        Column {
            id: chosenArea

            width: parent.width
            visible: card.chosen.length > 0 && !peekBox.visible && !keySheet.visible
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                // No button in sight shows Enter (an image, an ISO: Open is under More): the line says what it does (C9).
                text: (card.chosen.length === 1 ? (card.shelf?.label(card.chosen[0]) ?? "") + " · " + card.metaOf(card.chosen[0]) : card.kindLabels[card.shelf?.choice ?? "all"] ?? "") + (card.keyboard && planRow.ids.indexOf(Shelf.shortcut(card.shelf?.plan, "enter")) === -1 ? " · " + I18n.tr("Enter open in app", "island shelf: the key that opens the chosen files in their apps") : "")
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
            Item {
                id: planRow

                readonly property var ids: (card.shelf?.plan?.buttons ?? []).slice(0, card.planShown)
                // "⋯" takes half a button's share.
                readonly property var cells: Kit.rowLayout(planRow.width, planRow.ids.map(() => 1).concat([0.5]), Theme.spacingXS)

                width: parent.width
                height: Theme.buttonHeightS

                Repeater {
                    id: planButtons

                    model: planRow.ids

                    delegate: BubbleAction {
                        required property string modelData
                        required property int index
                        readonly property string actionId: modelData

                        x: planRow.cells[index]?.x ?? 0
                        width: planRow.cells[index]?.width ?? 0
                        height: planRow.height
                        role: index === 0 ? "primary" : "plain"
                        iconName: card.icons[modelData] ?? ""
                        text: card.labels[modelData] ?? modelData
                        keys: card.keyboard ? card.keysFor(modelData) : []
                        leading: true
                        busy: !!card.shelf?.busy?.[modelData] && modelData !== "listen"
                        // A copy is confirmed here, never by a "Copied" bubble (C20).
                        feedbackText: ["copyFiles", "copyImage", "copyText", "copyContent", "copyPaths", "copySha"].indexOf(modelData) !== -1 ? I18n.tr("Copied!", "island shelf: an action's button after a copy") : ""
                        focusPolicy: Qt.NoFocus
                        Accessible.name: text
                        onClicked: card.shelf?.act(modelData)
                    }
                }
                BubbleAction {
                    id: moreButton

                    readonly property var cell: planRow.cells[planRow.ids.length] ?? ({
                            "x": 0,
                            "width": 0
                        })

                    x: moreButton.cell.x
                    width: moreButton.cell.width
                    height: planRow.height
                    iconName: "more_horiz"
                    focusPolicy: Qt.NoFocus
                    Accessible.name: I18n.tr("More", "island shelf: the actions under the four buttons")
                    onClicked: card.openMenu("more", moreButton.mapToItem(card, moreButton.width, 0))
                }
            }
        }

        // The drop zones, hidden at rest: a band rises at the bottom while a drag is over the card, and holds a zone
        // opened by a drop or by "⋯" (F27 to F31).
        Item {
            id: band

            readonly property bool wanted: (card.lit || !!card.shelf?.zoneOpen) && (card.shelf?.zones?.length ?? 0) > 0
            readonly property real full: card.shelf?.zoneOpen ? zoneSheet.implicitHeight : zoneBox.height

            width: parent.width
            height: Math.round(band.full * bandIn.value)
            visible: band.height > 0
            clip: true
            onWantedChanged: {
                if (!band.wanted)
                    card.cloudSplit = false;
                bandIn.enabled ? bandIn.retarget(band.wanted ? 1 : 0) : bandIn.snapTo(band.wanted ? 1 : 0);
            }
            Component.onCompleted: bandIn.snapTo(band.wanted ? 1 : 0)

            SpringMotion {
                id: bandIn

                readonly property var spec: Kit.spring("surface", Theme.currentAnimationBaseDuration)
                enabled: Theme.currentAnimationBaseDuration > 0 && !SettingsData.reduceMotion
                stiffness: spec.stiffness
                damping: spec.damping
                mass: spec.mass
            }

            // Side by side, equal at rest; the one under the pointer grows to half the band on a spring (F27 lying down).
            Item {
                id: zoneBox

                // The springs' growth so far: of every zone, or of the first k (they place each zone every frame, no array).
                function grown(k) {
                    let g = 0;
                    for (let i = 0; i < Math.min(k, zoneRepeater.count); i++)
                        g += zoneRepeater.itemAt(i)?.grow ?? 0;
                    return g;
                }
                function edge(k) {
                    const n = zoneRepeater.count;
                    return Kit.rowEdge(zoneBox.width, n, Theme.spacingS, k + zoneBox.grown(k), n + zoneBox.grown(n));
                }

                width: parent.width
                height: Theme.buttonHeightS + Theme.spacingL
                visible: !card.shelf?.zoneOpen

                Repeater {
                    id: zoneRepeater

                    model: card.shelf?.zones ?? []

                    delegate: Item {
                        id: zone

                        required property string modelData
                        required property int index

                        readonly property string zoneId: zone.modelData
                        readonly property bool hot: (card.shelf?.hotZone ?? "") === zone.zoneId
                        readonly property real grow: growth.value
                        readonly property real edgeLeft: zoneBox.edge(zone.index)
                        // Cloud held 0.6 s under a drag: one target per synced folder.
                        readonly property bool split: card.cloudSplit && zone.zoneId === "cloud" && (card.shelf?.clouds?.length ?? 0) > 0

                        // The synced folder under the pointer, once split.
                        function cloudAt() {
                            for (let i = 0; i < cloudTargets.count; i++) {
                                const t = cloudTargets.itemAt(i);
                                if (card.under(t))
                                    return t.path;
                            }
                            return "";
                        }

                        x: zone.edgeLeft + zone.index * Theme.spacingS
                        width: zoneBox.edge(zone.index + 1) - zone.edgeLeft
                        height: zoneBox.height

                        SpringMotion {
                            id: growth

                            readonly property var spec: Kit.spring("surface", Theme.currentAnimationBaseDuration)
                            enabled: Theme.currentAnimationBaseDuration > 0 && !SettingsData.reduceMotion
                            stiffness: spec.stiffness
                            damping: spec.damping
                            mass: spec.mass
                        }
                        onHotChanged: growth.enabled ? growth.retarget(zone.hot ? 1 : 0) : growth.snapTo(zone.hot ? 1 : 0)

                        // The tint deepens with the growth (an opacity, no new color per frame).
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: Theme.primaryContainer
                            opacity: Math.max(0.28, 0.55 * Math.min(1, zone.grow))
                        }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: Theme.primary
                                strokeWidth: Theme.outlineWidthFocused
                                strokeStyle: zone.hot ? ShapePath.SolidLine : ShapePath.DashLine
                                dashPattern: [3, 3]
                                fillColor: "transparent"
                                PathRectangle {
                                    x: Theme.outlineWidth
                                    y: Theme.outlineWidth
                                    width: zone.width - 2 * Theme.outlineWidth
                                    height: zone.height - 2 * Theme.outlineWidth
                                    radius: Theme.cornerRadius
                                }
                            }
                        }
                        // Centered at rest; under the pointer it moves to the left edge with its hint, out from under the
                        // dragged picture (D22).
                        Row {
                            x: zone.hot ? Theme.spacingM : (parent.width - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !zone.split
                            spacing: Theme.spacingS

                            DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: card.zoneIcons[zone.zoneId] ?? "inbox"
                                size: Theme.iconSizeMedium
                                color: Theme.primary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.zones.name(zone.zoneId)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: zone.hot
                                text: card.zoneHint(zone.zoneId)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            visible: zone.split
                            spacing: Theme.spacingXS

                            Repeater {
                                id: cloudTargets

                                model: zone.split ? card.shelf.clouds : []

                                delegate: Rectangle {
                                    id: cloudTarget

                                    required property var modelData
                                    readonly property string path: cloudTarget.modelData.path

                                    width: (parent.width - (cloudTargets.count - 1) * Theme.spacingXS) / Math.max(1, cloudTargets.count)
                                    height: parent.height
                                    radius: Theme.cornerRadius
                                    color: (card.shelf?.hover?.cloud ?? "") === cloudTarget.path ? Theme.primaryContainer : Theme.surfaceContainerHigh

                                    Row {
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, parent.width - Theme.spacingS)
                                        spacing: Theme.spacingXS

                                        DIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: cloudTarget.modelData.icon
                                            size: Theme.iconSizeSmall
                                            color: Theme.primary
                                        }
                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(implicitWidth, cloudTarget.width - Theme.iconSizeSmall - 2 * Theme.spacingS)
                                            text: cloudTarget.modelData.name
                                            elide: Text.ElideMiddle
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // A zone opened: its name, what it got, its choices side by side (formats, devices, folders), Close.
            Rectangle {
                id: zoneSheet

                implicitHeight: zoneCol.implicitHeight + 2 * Theme.spacingM
                width: parent.width
                height: zoneSheet.implicitHeight
                visible: !!card.shelf?.zoneOpen
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer

                Column {
                    id: zoneCol

                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - 2 * Theme.spacingM
                    spacing: Theme.spacingS

                    Item {
                        width: parent.width
                        height: card.smallButton

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: card.zoneIcons[card.shelf?.zoneOpen ?? ""] ?? "inbox"
                                size: Theme.iconSizeMedium
                                color: Theme.primary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.zones.name(card.shelf?.zoneOpen ?? "")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                            }
                        }
                        BubbleAction {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            buttonHeight: card.smallButton
                            role: "quiet"
                            iconName: "close"
                            Accessible.name: I18n.tr("Close the zone", "island shelf: back from a drop zone's choices")
                            onClicked: card.shelf?.closeZone()
                        }
                    }
                    ZoneChoices {
                        width: parent.width
                        card: card
                        zoneId: card.shelf?.zoneOpen ?? ""
                    }
                }
            }
        }
    }

    // A shelf's title or the count, dragged: that family, or every file (C's handle, N7). The
    // picture is the first of them's cell, their number on it (HIG); the shelf keeps its links.
    Item {
        id: outProxy

        property var keys: []
        property Item cell: null
        property bool starting: false

        // area: the MouseArea still pressed.
        function start(keys, area) {
            const c = card.cellOf(keys[0] ?? "");
            if (!c)
                return;
            outProxy.keys = keys;
            outProxy.cell = c;
            outProxy.starting = true;
            c.box.grabToImage(result => {
                outProxy.starting = false;
                if (!area.pressed)
                    return;
                card.shelf?.carry(keys, result.url, Qt.point(c.box.width / 2, c.box.height / 2));
            }, Qt.size(c.box.width, c.box.height));
        }
    }

    // The menus: what the shelf takes in, or what the choice can do (its whole plan, the zones, Rename, Remove, Trash);
    // two columns past eight rows. Their keys show at once: a menu is opened on purpose, not the card at rest.
    Rectangle {
        id: menuBox

        readonly property int columns: card.menuItems.length > 8 ? 2 : 1
        readonly property real colWidth: Theme.iconSize * 11

        visible: card.menu !== ""
        x: Math.max(0, Math.min((card.menu === "more" ? card.menuAt.x - width : card.menuAt.x), card.width - width))
        // Held under the island's ceiling: opened low, the menu rises until its last row shows.
        y: card.menu === "more" ? Math.max(header.height + card.gap, card.menuAt.y - height - Theme.spacingXS) : Shelf.menuY(card.menuAt.y, height, 0, Math.min(content.implicitHeight, card.roomHeight))
        z: 2
        width: menuBox.columns * menuBox.colWidth + (menuBox.columns - 1) * Theme.spacingXS + 2 * Theme.spacingXS
        height: menuCol.implicitHeight + 2 * Theme.spacingXS
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: Theme.outlineWidth
        border.color: Theme.outlineVariant
        Accessible.role: Accessible.PopupMenu
        Accessible.name: I18n.tr("List menu", "island shelf: the right-click menu")
        // Its rows by keys (Menu or Shift+F10 opened it): ↑/↓ around them, Enter does, Escape closes (the card's keys).
        Keys.onUpPressed: card.menuStep(true)
        Keys.onDownPressed: card.menuStep(false)

        // Between its rows a press stays in the menu, never reaching a tile under it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
        Column {
            id: menuCol

            x: Theme.spacingXS
            y: Theme.spacingXS
            width: parent.width - 2 * Theme.spacingXS

            // Read down the first column, then the second.
            Grid {
                flow: Grid.TopToBottom
                rows: Math.ceil(card.menuItems.length / menuBox.columns)
                columnSpacing: Theme.spacingXS

                Repeater {
                    id: menuRows

                    model: card.menuItems

                    delegate: BubbleAction {
                        required property var modelData

                        focusPolicy: Qt.NoFocus
                        width: menuBox.colWidth
                        buttonHeight: card.smallButton
                        role: "quiet"
                        iconName: modelData.icon
                        text: modelData.text
                        keys: modelData.keys
                        leading: true
                        busy: !!card.shelf?.busy?.[modelData.id]
                        Accessible.name: text
                        onClicked: card.menuDo(modelData.id)
                    }
                }
            }
            IslandHoldButton {
                id: clearAll

                width: parent.width
                visible: card.menu === "shelf" && !card.empty
                role: "danger"
                buttonHeight: card.smallButton
                iconName: "delete_sweep"
                text: I18n.tr("Clear All", "island shelf: forget every kept file, held 2 s")
                Accessible.name: I18n.tr("Clear all, hold 2 seconds", "island shelf: screen reader name of the held Clear all")
                onLetGoEarly: card.shelf?.say(I18n.tr("Hold %1 s to clear all", "island shelf: Clear all let go before it confirmed").arg(clearAll.holdMs / 1000))
                onConfirmed: {
                    card.menu = "";
                    card.shelf?.clear();
                }
            }
        }
    }

    // What an opened zone offers: formats (Convert), devices (Share), synced folders (Cloud), side by side.
    component ZoneChoices: Column {
        id: choices

        property var card: null
        property string zoneId: ""
        readonly property var files: card?.shelf?.zoneFiles ?? []
        readonly property string what: choices.files.length === 1 ? Shelf.name(choices.files[0]) : I18n.tr("%1 files", "island shelf: files on the shelf").arg(choices.files.length)
        readonly property var fmts: card?.shelf?.formats ?? null

        Connections {
            target: choices.card?.shelf ?? null
            ignoreUnknownSignals: true

            function onFinished(id, ok) {
                for (let i = 0; i < zoneButtons.count; i++) {
                    const b = zoneButtons.itemAt(i);
                    if (b?.actionId === id)
                        b.flash(ok);
                }
            }
        }

        spacing: Theme.spacingXS

        StyledText {
            width: parent.width
            text: choices.zoneId === "convert" ? I18n.tr("%1 · convert to", "island shelf convert zone: the file, then its formats").arg(choices.what) : choices.zoneId === "share" ? I18n.tr("%1 · send to", "island shelf share zone: the file, then the devices").arg(choices.what) : I18n.tr("%1 · copy into", "island shelf cloud zone: the file, then the synced folders").arg(choices.what)
            elide: Text.ElideMiddle
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.Wrap
            text: {
                if (choices.zoneId === "convert")
                    return choices.fmts === null ? I18n.tr("Different types: choose files of one type.", "island shelf convert zone: mixed types") : !choices.fmts.length ? I18n.tr("No local tool here converts this type.", "island shelf convert zone: nothing to offer") : "";
                if (choices.zoneId === "share")
                    return (card?.shelf?.devicesLoaded ?? false) && !(card?.shelf?.devices?.length) ? I18n.tr("No KDE Connect device reachable.", "island shelf share zone: no paired device around") : "";
                return !(card?.shelf?.clouds?.length) ? I18n.tr("No synced folder chosen yet.", "island shelf cloud zone: none set in the settings") : "";
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        Flow {
            width: parent.width
            spacing: Theme.spacingXS

            Repeater {
                id: zoneButtons

                model: {
                    if (choices.zoneId === "convert")
                        return (choices.fmts ?? []).map(f => ({
                                    "id": "convertTo",
                                    "arg": f.tool + ":" + f.to,
                                    "icon": "transform",
                                    "label": f.to.toUpperCase()
                                }));
                    if (choices.zoneId === "share")
                        return (card?.shelf?.devices ?? []).map(d => ({
                                    "id": "sendTo",
                                    "arg": d.id,
                                    "icon": "smartphone",
                                    "label": d.name
                                })).concat(card?.shelf?.localsend ? [
                                {
                                    "id": "localsend",
                                    "arg": "",
                                    "icon": "laptop",
                                    "label": "LocalSend"
                                }
                            ] : []);
                    if (choices.zoneId === "cloud")
                        return (card?.shelf?.clouds ?? []).map(c => ({
                                    "id": "copyTo",
                                    "arg": c.path,
                                    "icon": c.icon,
                                    "label": c.name
                                })).concat([
                            {
                                "id": "pickCloud",
                                "arg": "",
                                "icon": "folder_open",
                                "label": I18n.tr("Choose a folder…", "island shelf: pick a synced folder for the Cloud zone")
                            }
                        ]);
                    return [];
                }

                delegate: BubbleAction {
                    required property var modelData
                    readonly property string actionId: "zone:" + modelData.id + ":" + modelData.arg

                    buttonHeight: Theme.buttonHeightS - Theme.spacingS
                    // An empty Cloud zone has one way forward: its folder picker takes the primary role (C13).
                    role: modelData.id === "pickCloud" && !(card?.shelf?.clouds?.length) ? "primary" : "tonal"
                    iconName: modelData.icon
                    leading: true
                    text: modelData.label
                    busy: !!card?.shelf?.busy?.[actionId]
                    Accessible.name: text
                    onClicked: card?.shelf?.zoneAct(modelData.id, modelData.arg)
                }
            }
        }
        StyledText {
            width: parent.width
            visible: choices.zoneId === "cloud"
            wrapMode: Text.Wrap
            text: I18n.tr("Folders your sync app keeps up to date: DMS keeps no account.", "island shelf cloud zone: no credentials in DMS")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
