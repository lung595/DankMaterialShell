pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Services
import qs.Modules.DIsland.Kit
import "../../../Common/IslandShelf.js" as Shelf
import "../../../Common/IslandTransfer.js" as Transfer
import "../../../Common/IslandKit.js" as Kit

// The shelf's card (IslandShelfSource), in its bubble and in the island, three panels (1.1, 1.55, 1.1): the drop zones
// (Convert, Share, Cloud, from the settings; the one under a drag grows to half the column, a drop shows what it can
// do there), the list (search with "/", filters, rows; a file held ~0.6 s on another makes a shelf folder,
// one dropped on a folder goes in; right click: new folder, new text file, paste; under it Remove, Trash while Shift
// is held, and Clear all held 2 s), the actions (each with its shortcut at its right). Its header: the logo, "Shelf"
// and Super S, the subtitle, Close, the only way out with Super+S. Every shortcut is shown where it acts and works.
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
    // The card's grid: the same margin between header and body and between the columns as around the card.
    readonly property real gap: NotificationMetrics.cardPadding
    // Inside each column's panel.
    readonly property real inset: Theme.spacingS
    // The list panel's buttons: a little flatter than the search field.
    readonly property real smallButton: Theme.buttonHeightS - Theme.spacingS
    // Columns 1.1 : 1.55 : 1.1, the two sides equal and wide enough for a label beside its keys.
    readonly property real unit: (card.width - 2 * card.gap) / 3.75
    readonly property real thumb: Theme.iconSize + Theme.spacingM
    readonly property real rowHeight: card.thumb + Theme.spacingS
    property bool more: false
    property bool sweeping: false
    property var sweepBase: []
    property int sweepFrom: -1
    // The right-click menu of the list, where it was opened (in the middle column).
    property bool menu: false
    property point menuAt: Qt.point(0, 0)

    signal activated(var bubble)
    signal dismissed(var bubble)

    // The zones' note is always there: a line under the columns that links to their settings (C8).
    implicitHeight: body.y + body.height + Theme.spacingS + zonesNote.height
    onChosenChanged: card.more = false

    // The keys shown for a shortcut, in DMS's words.
    readonly property var keyNames: ({
            "copy": [I18n.tr("Ctrl", "keyboard key"), "C"],
            "enter": [I18n.tr("Enter", "keyboard key")]
        })
    function keysFor(id) {
        const k = card.shelf?.keyed?.[id];
        return k ? card.keyNames[k] : [];
    }
    // Labels and icons of every action, as the owner's table words them.
    readonly property var labels: ({
            "copyFiles": card.chosen.length ? I18n.tr("Copy", "island shelf action: copy the chosen files") : I18n.tr("Copy all", "island shelf action: copy every kept file"),
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

    Connections {
        target: card.shelf
        ignoreUnknownSignals: true

        function onFinished(id, ok) {
            for (const r of [buttons, moreList])
                for (const b of r.flashable())
                    if (b?.actionId === id)
                        b.flash(ok);
        }
        function onRenameStarted() {
            Qt.callLater(() => rows.positionViewAtIndex(card.shelf?.cur ?? 0, ListView.Contain));
        }
    }

    // A drag over the card: what lies under the pointer (a zone, a row), and a row held on long enough for a folder.
    readonly property point dragAt: card.shelf?.dragAt ?? Qt.point(-1, -1)
    onDragAtChanged: {
        const s = card.shelf;
        if (!s || card.dragAt.x < 0 || !card.visible)
            return;
        let zone = "";
        for (let i = 0; i < zoneRepeater.count; i++) {
            const z = zoneRepeater.itemAt(i);
            const p = z?.mapFromItem(null, card.dragAt.x, card.dragAt.y);
            if (p && p.x >= 0 && p.y >= 0 && p.x < z.width && p.y < z.height)
                zone = z.zoneId;
        }
        let row = "";
        const q = rows.mapFromItem(null, card.dragAt.x, card.dragAt.y);
        if (!zone && rows.visible && q.x >= 0 && q.y >= 0 && q.x < rows.width && q.y < rows.height) {
            const at = rows.indexAt(q.x, q.y + rows.contentY);
            row = at >= 0 ? card.list[at] ?? "" : "";
        }
        // A folder is made on a file, from another file, at the shelf's top level.
        const dragged = s.takingOut ? s.dragKeys : [];
        const mergeable = row && !Shelf.isGroup(row) && dragged.indexOf(row) === -1 && !s.folder;
        if (row !== s.hover.row || zone !== s.hover.zone) {
            s.hover = {
                "zone": zone,
                "row": dragged.indexOf(row) === -1 ? row : "",
                "merge": false
            };
            if (mergeable)
                folderTimer.restart();
            else
                folderTimer.stop();
        }
    }
    Timer {
        id: folderTimer

        interval: Kit.folderHoldMs
        onTriggered: {
            const s = card.shelf;
            if (s && s.hover.row && (s.over || s.takingOut))
                s.hover = Object.assign({}, s.hover, {
                    "merge": true
                });
        }
    }

    // Any press in the card takes the keyboard back, without taking the press from what is under it.
    PointHandler {
        id: anyPress

        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            if (!active)
                return;
            card.shelf?.wake();
            const p = menuBox.mapFromItem(card, anyPress.point.position.x, anyPress.point.position.y);
            if (card.menu && !menuBox.contains(p))
                card.menu = false;
            // A clicked button takes the focus on press; give it back once the press is delivered (Space, arrows).
            Qt.callLater(() => {
                if (!search.activeFocus && !(card.shelf?.renaming ?? ""))
                    card.forceActiveFocus();
            });
        }
    }

    focus: true
    onActiveFocusChanged: {
        if (!card.activeFocus && card.shelf)
            card.shelf.shiftHeld = false;
    }
    Keys.onReleased: event => {
        if (card.shelf)
            card.shelf.shiftHeld = (event.modifiers & Qt.ShiftModifier) !== 0 && event.key !== Qt.Key_Shift;
    }
    Keys.onPressed: event => {
        const s = card.shelf;
        if (!s)
            return;
        s.shiftHeld = (event.modifiers & Qt.ShiftModifier) !== 0 || event.key === Qt.Key_Shift;
        if (s.renaming)
            return;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shiftOn = (event.modifiers & Qt.ShiftModifier) !== 0;
        const n = card.list.length;
        if (!ctrl && event.text === "/") {
            search.forceActiveFocus();
            search.selectAll();
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            const d = event.key === Qt.Key_Down ? 1 : -1;
            s.go((card.chosen.length || shiftOn ? s.cur : d > 0 ? -1 : n) + d, shiftOn);
            rows.positionViewAtIndex(s.cur, ListView.Contain);
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            s.go(event.key === Qt.Key_Home ? 0 : n - 1, shiftOn);
            rows.positionViewAtIndex(s.cur, ListView.Contain);
        } else if (ctrl && event.key === Qt.Key_A) {
            s.chooseAll();
        } else if (ctrl && event.key === Qt.Key_C) {
            s.shortcut("copy");
        } else if (ctrl && event.key === Qt.Key_V) {
            s.paste();
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
            // The innermost thing open closes; the card itself never (its close button or Super+S).
            if (card.menu)
                card.menu = false;
            else if (card.more)
                card.more = false;
            else
                s.closeInner();
        } else if (event.key !== Qt.Key_Shift) {
            return;
        }
        event.accepted = true;
    }

    // A key as the card shows it everywhere (cartes.md: shortcuts always visible).
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

    // Header: logo centred on the two lines of the name and its keys and the subtitle; Close at the far right.
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
                name: "inventory_2"
                size: Theme.iconSize
                color: Theme.primary
            }
        }

        Column {
            id: titles

            anchors.left: logo.right
            anchors.leftMargin: NotificationMetrics.iconSpacing
            anchors.right: headerButtons.left
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            spacing: NotificationMetrics.contentSpacing / 2

            Row {
                spacing: Theme.spacingS

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Shelf", "island shelf: its name")
                    font.pixelSize: NotificationMetrics.summarySize
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }
                // shortcut: the key of niri's default bind (niri-binds.kdl), written here; Hyprland and MangoWC already use
                // Super+S, so there the shelf has no default key. Read the bind from KeybindsService if that matters.
                Keycaps {
                    anchors.verticalCenter: parent.verticalCenter
                    keys: ["Super", "S"]
                    Accessible.ignored: false
                    Accessible.name: I18n.tr("Shortcut Super S", "island shelf: its keyboard shortcut for screen readers")
                }
            }
            StyledText {
                width: parent.width
                text: card.shelf?.subtitle ?? ""
                elide: Text.ElideRight
                font.pixelSize: NotificationMetrics.bodySize
                color: Theme.surfaceVariantText
            }
        }

        Row {
            id: headerButtons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            BubbleAction {
                iconName: "close"
                Accessible.name: I18n.tr("Close the shelf", "island shelf: close the card, the files stay")
                onClicked: card.shelf?.dismiss()
            }
        }
    }

    Row {
        id: body

        y: header.height + card.gap
        width: parent.width
        height: actionsCol.fixedHeight + 2 * card.inset
        spacing: card.gap

        // Left: the drop zones, equal at rest; the one under a drag grows to half the column on a spring.
        Item {
            id: leftPanel

            width: card.unit * 1.1
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
            }

            // The actions column's heading, mirrored: the zones start where its buttons start.
            Column {
                id: zonesHead

                x: card.inset
                y: card.inset
                width: parent.width - 2 * card.inset
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Zones", "island shelf: the drop zones column").toUpperCase()
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width
                    text: I18n.tr("Drop files on one", "island shelf: what the drop zones are for")
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }
            }

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
                    return Kit.rowEdge(zoneBox.height, n, Theme.spacingS, k + zoneBox.grown(k), n + zoneBox.grown(n));
                }

                anchors.fill: parent
                anchors.margins: card.inset
                anchors.topMargin: zonesHead.y + zonesHead.height + Theme.spacingS

                Repeater {
                    id: zoneRepeater

                    model: card.shelf?.zones ?? []

                    delegate: Item {
                        id: zone

                        required property string modelData
                        required property int index

                        readonly property string zoneId: zone.modelData
                        readonly property bool hot: (card.shelf?.hotZone ?? "") === zone.zoneId
                        readonly property bool opened: (card.shelf?.zoneOpen ?? "") === zone.zoneId
                        readonly property real grow: growth.value
                        // How far another zone has grown over this one: its centered face fades out, then the one-line one in
                        // (never both at once).
                        readonly property real squeeze: Math.max(0, Math.min(1, zoneBox.grown(zoneRepeater.count) - zone.grow))
                        readonly property real edgeTop: zoneBox.edge(zone.index)

                        y: zone.edgeTop + zone.index * Theme.spacingS
                        width: zoneBox.width
                        height: zoneBox.edge(zone.index + 1) - zone.edgeTop
                        clip: true

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
                            opacity: Math.max(card.lit ? 0.28 : 0, 0.55 * Math.min(1, zone.grow))
                            visible: opacity > 0
                        }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: zone.hot || card.lit ? Theme.primary : Theme.outlineVariant
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

                        // At rest: icon over name and hint, centered; squeezed by another: one line; opened: a header.
                        Item {
                            id: zoneHead

                            width: parent.width
                            height: zone.opened ? Theme.buttonHeightS : parent.height

                            Column {
                                anchors.centerIn: parent
                                opacity: zone.opened ? 0 : Math.max(0, 1 - 2 * zone.squeeze)
                                visible: opacity > 0
                                spacing: Theme.spacingXS

                                DIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: card.zoneIcons[zone.zoneId] ?? "inbox"
                                    size: Theme.iconSizeLarge
                                    color: zone.hot || card.lit ? Theme.primary : Theme.surfaceVariantText
                                }
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.zones.name(zone.zoneId)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: zone.height > Theme.iconSizeLarge * 3
                                    text: card.zoneHint(zone.zoneId)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: zone.opened ? 1 : Math.max(0, 2 * zone.squeeze - 1)
                                visible: opacity > 0
                                spacing: Theme.spacingS

                                DIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: card.zoneIcons[zone.zoneId] ?? "inbox"
                                    size: Theme.iconSizeMedium
                                    color: zone.hot ? Theme.primary : Theme.surfaceVariantText
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.zones.name(zone.zoneId)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.surfaceText
                                }
                            }
                            // Without a drag: the chosen files go to the zone with a click.
                            MouseArea {
                                anchors.fill: parent
                                enabled: !zone.opened && card.chosen.length > 0
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: card.zones.name(zone.zoneId) + ", " + card.zoneHint(zone.zoneId)
                                onClicked: card.shelf?.openZone(zone.zoneId, card.shelf.targets)
                            }
                            BubbleAction {
                                anchors.right: parent.right
                                // Its glyph as far from the right edge as the header's icon from the left.
                                anchors.rightMargin: Theme.spacingM - (buttonHeight - Theme.iconSizeMedium) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: zone.opened
                                buttonHeight: Theme.buttonHeightS - Theme.spacingS
                                role: "quiet"
                                iconName: "close"
                                Accessible.name: I18n.tr("Close the zone", "island shelf: back from a drop zone's choices")
                                onClicked: card.shelf?.closeZone()
                            }
                        }

                        DFlickable {
                            anchors.top: zoneHead.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            // Its text lines up with the zone's header icon.
                            anchors.margins: Theme.spacingM
                            anchors.topMargin: 0
                            visible: zone.opened
                            clip: true
                            contentHeight: zoneBody.implicitHeight

                            ZoneChoices {
                                id: zoneBody

                                width: parent.width
                                card: card
                                zoneId: zone.opened ? zone.zoneId : ""
                            }
                        }
                    }
                }
            }
        }

        // Middle: search, filters, the list.
        Item {
            id: middle

            width: card.unit * 1.55
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
            }

            Column {
                id: middleCol

                anchors.fill: parent
                anchors.margins: card.inset
                spacing: Theme.spacingS

                // The search field, its only shortcut "/" inside it on the right.
                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightS - Theme.spacingXS
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.width: search.activeFocus ? Theme.outlineWidthFocused : Theme.outlineWidth
                    border.color: search.activeFocus ? Theme.primary : Theme.outlineVariant

                    // The whole field takes the press, not only the text line.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onPressed: search.forceActiveFocus()
                    }
                    DIcon {
                        id: searchIcon

                        anchors.left: parent.left
                        // The glyph's own inset taken off, so its ink sits as far from the edge as the "/" key's.
                        anchors.leftMargin: Theme.spacingS - Theme.spacingXXS
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: Theme.iconSizeMedium
                        color: Theme.surfaceVariantText
                    }
                    TextInput {
                        id: search

                        anchors.left: searchIcon.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: searchKeys.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        text: card.shelf?.query ?? ""
                        color: Theme.surfaceText
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onPrimary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        Accessible.role: Accessible.EditableText
                        Accessible.name: I18n.tr("Search the shelf", "island shelf: the search field")
                        onTextEdited: card.shelf?.setQuery(text)
                        Keys.onEscapePressed: event => {
                            event.accepted = true;
                            if (text)
                                card.shelf?.setQuery("");
                            else
                                card.forceActiveFocus();
                        }
                        Keys.onPressed: event => {
                            if (event.key !== Qt.Key_Down && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                                return;
                            event.accepted = true;
                            card.forceActiveFocus();
                            card.shelf?.go(0, false);
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            elide: Text.ElideRight
                            visible: !search.text && !search.activeFocus
                            text: I18n.tr("Search the shelf", "island shelf: the search field")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                    Keycaps {
                        id: searchKeys

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        keys: ["/"]
                    }
                }

                DFilterChips {
                    id: chips

                    visible: !card.empty
                    width: parent.width
                    showCheck: false
                    chipPadding: Theme.spacingS
                    spacing: Theme.spacingXS
                    readonly property var counts: Shelf.counts(card.shelf?.level ?? [], card.dirs)
                    readonly property var keys: ["all", "image", "doc", "other"]
                    model: [
                        {
                            "label": I18n.tr("All", "island shelf filter"),
                            "count": chips.counts.all
                        },
                        {
                            "label": I18n.tr("Images", "island shelf filter"),
                            "count": chips.counts.image
                        },
                        {
                            "label": I18n.tr("Documents", "island shelf filter"),
                            "count": chips.counts.doc
                        },
                        {
                            "label": I18n.tr("Others", "island shelf filter"),
                            "count": chips.counts.other
                        }
                    ]
                    currentIndex: Math.max(0, chips.keys.indexOf(card.shelf?.filter ?? "all"))
                    onSelectionChanged: index => card.shelf?.setFilter(chips.keys[index])
                }

                Row {
                    id: selbar

                    visible: !card.empty
                    width: parent.width
                    height: Theme.fontSizeSmall * 1.6
                    spacing: Theme.spacingS

                    // Inside a shelf folder: its name (the user's, of any length), a click goes back up.
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, selbar.width * 0.5)
                        elide: Text.ElideMiddle
                        wrapMode: Text.NoWrap
                        visible: !!card.shelf?.folder
                        text: "‹ " + (card.shelf?.label("group:" + (card.shelf?.folder ?? "")) ?? "")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.primary

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: I18n.tr("Back to the shelf", "island shelf: leave a shelf folder")
                            onClicked: card.shelf?.leaveFolder()
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.chosen.length > 0
                        text: I18n.tr("%1 chosen", "island shelf: how many files are chosen").arg(card.chosen.length)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.list.length > 0
                        text: card.chosen.length ? I18n.tr("Deselect all", "island shelf") : I18n.tr("Select all", "island shelf")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.primary

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: parent.text
                            onClicked: card.chosen.length ? card.shelf?.chooseNone() : card.shelf?.chooseAll()
                        }
                    }
                    Keycaps {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.list.length > 0 && !card.chosen.length
                        keys: [I18n.tr("Ctrl", "keyboard key"), "A"]
                    }
                }

                Item {
                    id: listBox

                    width: parent.width
                    height: parent.height - y - (shelfButtons.visible ? shelfButtons.height + parent.spacing : 0)
                    // The merge frame follows a row that may be scrolled half out.
                    clip: true

                    // The middle takes a drop to keep files; a right click opens its menu.
                    Rectangle {
                        anchors.fill: parent
                        visible: card.lit && !(card.shelf?.hotZone ?? "")
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.primaryContainer, 0.28)
                        border.width: Theme.outlineWidthFocused
                        border.color: Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: mouse => {
                            card.menuAt = mapToItem(middle, mouse.x, mouse.y);
                            card.menu = true;
                            card.more = false;
                        }
                    }

                    // Nothing to list: an icon on its tile, a title, a hint, centered in the list's room with the card's margins.
                    Column {
                        id: emptyState

                        readonly property bool searching: !card.empty && (card.shelf?.query ?? "") !== ""
                        // The shelf, or the shelf folder open, holds nothing: a drop fills it.
                        readonly property bool bare: (card.shelf?.level?.length ?? 0) === 0

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
                                name: emptyState.bare ? "move_to_inbox" : emptyState.searching ? "search_off" : "filter_alt_off"
                                size: Theme.iconSizeLarge
                                color: emptyState.bare ? Theme.primary : Theme.surfaceVariantText
                            }
                        }
                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: emptyState.bare ? I18n.tr("Drop files here", "island shelf: the empty list's title") : emptyState.searching ? I18n.tr("No result.", "island shelf: the search finds nothing") : I18n.tr("Nothing in this filter.", "island shelf: a filter with no file")
                            font.pixelSize: NotificationMetrics.summarySize
                            font.weight: Theme.fontWeightMedium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            width: parent.width
                            visible: emptyState.bare
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: I18n.tr("Dropped files stay here, ready to be dragged elsewhere.", "island shelf: the empty list")
                            font.pixelSize: NotificationMetrics.bodySize
                            color: Theme.surfaceVariantText
                        }
                    }

                    DListView {
                        id: rows

                        anchors.fill: parent
                        // Hidden under the preview: the current row's border would show through its antialiased edge.
                        visible: card.list.length > 0 && !peekBox.visible
                        clip: true
                        interactive: false
                        spacing: Theme.spacingXXS
                        model: card.list
                        Accessible.role: Accessible.List
                        Accessible.name: I18n.tr("Shelf files", "island shelf: the list for screen readers")

                        delegate: Rectangle {
                            id: row

                            required property string modelData
                            required property int index

                            readonly property bool picked: card.chosen.indexOf(row.modelData) !== -1
                            readonly property bool current: row.index === (card.shelf?.cur ?? -1) && card.activeFocus
                            readonly property bool target: (card.shelf?.hover?.row ?? "") === row.modelData
                            readonly property bool isGroup: Shelf.isGroup(row.modelData)
                            readonly property bool renaming: (card.shelf?.renaming ?? "") === row.modelData

                            width: rows.width
                            height: card.rowHeight
                            radius: Theme.cornerRadius
                            color: row.target && row.isGroup ? Theme.primaryContainer : row.picked ? Theme.secondaryContainer : press.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"
                            border.width: row.current || row.target ? Theme.outlineWidthFocused : 0
                            border.color: Theme.primary
                            opacity: (card.shelf?.takingOut ?? false) && (card.shelf?.dragKeys ?? []).indexOf(row.modelData) !== -1 ? 0.4 : 1
                            Accessible.role: Accessible.ListItem
                            Accessible.name: card.shelf?.label(row.modelData) ?? ""
                            Accessible.selected: row.picked

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.iconSizeSmall
                                    height: width
                                    radius: width / 2
                                    opacity: row.picked || press.containsMouse || card.chosen.length > 1 ? 1 : 0
                                    color: row.picked ? Theme.primary : "transparent"
                                    border.width: row.picked ? 0 : Theme.outlineWidthFocused
                                    border.color: Theme.outline

                                    DIcon {
                                        anchors.centerIn: parent
                                        visible: row.picked
                                        name: "check"
                                        size: Theme.iconSizeSmall - Theme.spacingXS
                                        color: Theme.onPrimary
                                    }
                                }
                                IslandShelfThumb {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: card.thumb
                                    height: card.thumb
                                    path: row.modelData
                                    dirs: card.dirs
                                    iconSize: Theme.iconSizeSmall
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Theme.iconSizeSmall - card.thumb - 2 * parent.spacing

                                    StyledText {
                                        width: parent.width
                                        visible: !row.renaming
                                        text: card.shelf?.label(row.modelData) ?? ""
                                        elide: Text.ElideMiddle
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                    }
                                    // F2, or a folder just made: the name edited in place (Enter keeps, Escape leaves it).
                                    Rectangle {
                                        width: parent.width
                                        height: renameField.implicitHeight + Theme.spacingXXS * 2
                                        visible: row.renaming
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
                                            font.weight: Theme.fontWeightMedium
                                            font.family: Theme.fontFamily
                                            Accessible.role: Accessible.EditableText
                                            Accessible.name: I18n.tr("New name", "island shelf: rename field")

                                            function begin() {
                                                renameField.done = false;
                                                renameField.text = card.shelf?.label(row.modelData) ?? "";
                                                const dot = row.isGroup ? -1 : renameField.text.lastIndexOf(".");
                                                renameField.forceActiveFocus();
                                                renameField.select(0, dot > 0 ? dot : renameField.text.length);
                                            }
                                            function finish(keep) {
                                                if (renameField.done)
                                                    return;
                                                renameField.done = true;
                                                if (keep)
                                                    card.shelf?.rename(row.modelData, renameField.text);
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
                                                if (!activeFocus && row.renaming)
                                                    renameField.finish(true);
                                            }
                                        }
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: card.metaOf(row.modelData)
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                            onRenamingChanged: {
                                if (row.renaming)
                                    Qt.callLater(renameField.begin);
                            }
                            Component.onCompleted: {
                                if (row.renaming)
                                    Qt.callLater(renameField.begin);
                            }

                            // The drag out: this row, or the whole choice when this row is in it. The shelf keeps its links.
                            Item {
                                id: proxy

                                readonly property var keys: row.picked ? card.chosen : [row.modelData]

                                Drag.dragType: Drag.Automatic
                                Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
                                Drag.mimeData: ({
                                        "text/uri-list": Shelf.uriList(Shelf.expand(proxy.keys, card.shelf?.groups ?? {}))
                                    })
                                Drag.imageSource: Shelf.isImage(row.modelData) ? Shelf.url(row.modelData) : ""
                                Drag.imageSourceSize: Qt.size(card.thumb, card.thumb)
                                Drag.onActiveChanged: card.shelf?.takeOut(proxy.Drag.active, proxy.keys)
                            }

                            MouseArea {
                                id: press

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !row.renaming
                                cursorShape: Qt.PointingHandCursor
                                // Where the press began: past Theme.spacingS from it the row goes out as a system drag. The
                                // MouseArea's own drag never armed here (a list delegate), so the drag is started by hand.
                                property point from
                                onPressed: mouse => {
                                    press.from = Qt.point(mouse.x, mouse.y);
                                    card.sweepFrom = -1;
                                    card.menu = false;
                                    card.forceActiveFocus();
                                }
                                onPressAndHold: {
                                    card.sweeping = true;
                                    card.sweepFrom = row.index;
                                    card.sweepBase = card.chosen.filter(p => p !== row.modelData);
                                    card.shelf?.sweep(card.sweepBase, row.index, row.index);
                                }
                                onPositionChanged: mouse => {
                                    if (!card.sweeping) {
                                        if (press.pressed && !proxy.Drag.active && Math.abs(mouse.x - press.from.x) + Math.abs(mouse.y - press.from.y) > Theme.spacingS)
                                            proxy.Drag.active = true;
                                        return;
                                    }
                                    const p = press.mapToItem(rows.contentItem, mouse.x, mouse.y);
                                    const at = rows.indexAt(p.x, p.y);
                                    if (at >= 0)
                                        card.shelf?.sweep(card.sweepBase, card.sweepFrom, at);
                                }
                                onReleased: card.sweeping = false
                                onCanceled: card.sweeping = false
                                onClicked: mouse => {
                                    // A long press already chose.
                                    if (card.sweepFrom >= 0)
                                        return;
                                    card.shelf?.pick(row.index, (mouse.modifiers & Qt.ControlModifier) !== 0, (mouse.modifiers & Qt.ShiftModifier) !== 0);
                                }
                                onDoubleClicked: card.shelf?.shortcut("enter")
                            }
                        }
                    }

                    // iOS folder: the dragged file and the one under it come together in a pulsing frame, "New folder".
                    Rectangle {
                        id: merge

                        readonly property int at: card.list.indexOf(card.shelf?.hover?.row ?? "")
                        readonly property bool on: (card.shelf?.hover?.merge ?? false) && merge.at >= 0
                        readonly property var source: (card.shelf?.takingOut ?? false) ? (card.shelf?.dragKeys?.[0] ?? "") : ""
                        readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion

                        onOnChanged: {
                            pairSpring.snapTo(0);
                            if (merge.on)
                                pairSpring.enabled ? pairSpring.retarget(1) : pairSpring.snapTo(1);
                        }

                        visible: merge.on
                        // It comes in with the two files' pop.
                        opacity: Math.min(1, pair.together * 2)
                        x: 0
                        y: merge.at * (card.rowHeight + rows.spacing) - rows.contentY
                        width: rows.width
                        height: card.rowHeight
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

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: card.thumb * 2
                            height: card.thumb

                            SpringMotion {
                                id: pairSpring

                                readonly property var spec: Kit.spring("pop", Theme.currentAnimationBaseDuration)
                                enabled: !merge.still
                                stiffness: spec.stiffness
                                damping: spec.damping
                                mass: spec.mass
                            }

                            IslandShelfThumb {
                                x: -Theme.spacingS + pair.together * Theme.spacingM
                                width: card.thumb
                                height: card.thumb
                                rotation: -10 + 4 * pair.together
                                scale: 1 - 0.1 * pair.together
                                path: merge.source || (card.shelf?.hover?.row ?? "")
                                iconSize: Theme.iconSizeSmall
                            }
                            IslandShelfThumb {
                                x: card.thumb - Theme.spacingXS - pair.together * Theme.spacingM
                                width: card.thumb
                                height: card.thumb
                                rotation: 10 - 4 * pair.together
                                scale: 1 - 0.1 * pair.together
                                path: card.shelf?.hover?.row ?? ""
                                iconSize: Theme.iconSizeSmall
                            }
                        }
                        Column {
                            anchors.left: pair.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("New folder", "island shelf: a folder made by holding a file on another")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: I18n.tr("Let go to make it", "island shelf: release to create the folder")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    // Space: a quick look at the keyboard's row, in the card.
                    Rectangle {
                        id: peekBox

                        readonly property string key: card.list[card.shelf?.cur ?? 0] ?? ""
                        readonly property bool textual: ["text"].indexOf(Shelf.kind(peekBox.key)) !== -1

                        // The first bytes of a text file, read again for each row the arrows reach.
                        function read() {
                            peekReader.running = false;
                            peekText.text = "";
                            if (!peekBox.visible || !peekBox.textual)
                                return;
                            peekReader.command = ["head", "-c", "600", "--", peekBox.key];
                            peekReader.running = true;
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

                        onVisibleChanged: peekBox.read()
                        onKeyChanged: peekBox.read()
                        Process {
                            id: peekReader

                            stdout: StdioCollector {
                                onStreamFinished: peekText.text = text
                            }
                        }

                        // The rows under it stay out of reach; a click closes it.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            hoverEnabled: true
                            onClicked: {
                                if (card.shelf)
                                    card.shelf.peek = false;
                            }
                        }

                        // Name and meta on top, the keys that close it at the bottom, the picture or the text between.
                        Item {
                            id: peekInner

                            readonly property real roomTop: peekHead.height + Theme.spacingS
                            readonly property real room: Math.max(0, peekKeys.y - Theme.spacingS - peekInner.roomTop)

                            anchors.fill: parent
                            anchors.margins: Theme.spacingM

                            Column {
                                id: peekHead

                                width: parent.width
                                spacing: Theme.spacingXXS

                                StyledText {
                                    width: parent.width
                                    text: card.shelf?.label(peekBox.key) ?? ""
                                    elide: Text.ElideMiddle
                                    wrapMode: Text.NoWrap
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    width: parent.width
                                    text: card.metaOf(peekBox.key)
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                            // A picture whole, fitted in the room, decoded at the size shown.
                            Image {
                                id: peekPic

                                y: peekInner.roomTop
                                width: parent.width
                                height: peekInner.room
                                source: Shelf.isImage(peekBox.key) ? Shelf.url(peekBox.key) : ""
                                sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            IslandShelfThumb {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: peekInner.roomTop + (peekInner.room - height) / 2
                                visible: !peekText.visible && peekPic.status !== Image.Ready && peekPic.status !== Image.Loading
                                width: Math.min(parent.width, peekInner.room, Theme.iconSize * 5)
                                height: width
                                path: peekBox.key
                                dirs: card.dirs
                                iconSize: Theme.iconSizeLarge
                            }
                            StyledText {
                                id: peekText

                                y: peekInner.roomTop
                                width: parent.width
                                height: peekInner.room
                                visible: text !== ""
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                            Row {
                                id: peekKeys

                                anchors.bottom: parent.bottom
                                width: parent.width
                                spacing: Theme.spacingXS

                                Keycaps {
                                    id: peekSpace

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
                                    width: Math.max(0, peekKeys.width - peekSpace.width - peekEsc.width - 2 * peekKeys.spacing)
                                    text: I18n.tr("to close", "island shelf: keys that close the preview")
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }

                // Forgetting files acts on the list: a band under it, behind a hairline, the two buttons sharing its width;
                // Shift (Remove turns Trash) gives Trash more of it.
                Item {
                    id: shelfButtons

                    readonly property bool trash: card.shift
                    readonly property real share: 0.5 + 0.2 * split.value

                    width: parent.width
                    height: Theme.outlineWidth + Theme.spacingS + card.smallButton
                    visible: !card.empty
                    onTrashChanged: split.enabled ? split.retarget(trash ? 1 : 0) : split.snapTo(trash ? 1 : 0)

                    SpringMotion {
                        id: split

                        readonly property var spec: Kit.spring("surface", Theme.currentAnimationBaseDuration)
                        enabled: Theme.currentAnimationBaseDuration > 0 && !SettingsData.reduceMotion
                        stiffness: spec.stiffness
                        damping: spec.damping
                        mass: spec.mass
                    }
                    Rectangle {
                        width: parent.width
                        height: Theme.outlineWidth
                        color: Theme.outlineVariant
                    }

                    // Remove the chosen links (never the files); Shift held turns it into Trash, in the error color.
                    BubbleAction {
                        id: removeButton

                        y: shelfButtons.height - height
                        readonly property real room: parent.width - Theme.spacingS
                        readonly property real need: removeButton.implicitWidth + clearButton.implicitWidth
                        // Its share, never less than its label beside its key, and Clear all keeps its own; too narrow
                        // for both, they split the room as their own widths do (the keys go first, IslandButton).
                        width: need > room ? room * removeButton.implicitWidth / need : Math.min(room - clearButton.implicitWidth, Math.max(removeButton.implicitWidth, room * shelfButtons.share))
                        buttonHeight: card.smallButton
                        // Del acts on the choice, else on the keyboard's row.
                        enabled: (card.shelf?.focusKeys?.length ?? 0) > 0
                        role: card.shift ? "danger" : "tonal"
                        iconName: card.shift ? "delete" : "remove_circle"
                        text: card.shift ? I18n.tr("Trash", "island shelf: put the chosen files in the trash") : I18n.tr("Remove", "island shelf: forget the chosen files, the files stay")
                        // Shift is the key already held: Trash shows only Del, its label keeps the room.
                        keys: [I18n.tr("Del", "keyboard key")]
                        Accessible.name: card.shift ? I18n.tr("Put in the trash", "island shelf: screen reader name of Trash") : I18n.tr("Remove from the shelf", "island shelf: forget the chosen file, the file stays")
                        onClicked: card.shelf?.removeChosen(card.shift)
                    }
                    IslandHoldButton {
                        id: clearButton

                        x: removeButton.width + Theme.spacingS
                        y: removeButton.y
                        width: parent.width - x
                        role: "danger"
                        buttonHeight: card.smallButton
                        iconName: "delete_sweep"
                        text: I18n.tr("Clear All", "island shelf: forget every kept file, held 2 s")
                        Accessible.name: I18n.tr("Clear all, hold 2 seconds", "island shelf: screen reader name of the held Clear all")
                        onConfirmed: card.shelf?.clear()
                    }
                }
            }

            // Right click in the list: new folder, new text file, paste.
            Rectangle {
                id: menuBox

                visible: card.menu
                x: Math.max(card.inset, Math.min(card.menuAt.x, middle.width - width - card.inset))
                y: Math.max(card.inset, Math.min(card.menuAt.y, middle.height - height - card.inset))
                width: Math.min(middle.width - 2 * card.inset, Theme.iconSize * 11)
                height: menuCol.implicitHeight + 2 * Theme.spacingXS
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: Theme.outlineWidth
                border.color: Theme.outlineVariant
                Accessible.role: Accessible.PopupMenu
                Accessible.name: I18n.tr("List menu", "island shelf: the right-click menu")

                Column {
                    id: menuCol

                    x: Theme.spacingXS
                    y: Theme.spacingXS
                    width: parent.width - 2 * Theme.spacingXS

                    BubbleAction {
                        width: parent.width
                        role: "quiet"
                        iconName: "create_new_folder"
                        leading: true
                        text: I18n.tr("New folder", "island shelf: a folder made by holding a file on another")
                        Accessible.name: text
                        onClicked: {
                            card.menu = false;
                            card.shelf?.newFolder();
                        }
                    }
                    BubbleAction {
                        width: parent.width
                        role: "quiet"
                        iconName: "note_add"
                        leading: true
                        text: I18n.tr("New text file", "island shelf: an empty text file in Documents, kept on the shelf")
                        Accessible.name: text
                        onClicked: {
                            card.menu = false;
                            card.shelf?.newText();
                        }
                    }
                    BubbleAction {
                        width: parent.width
                        role: "quiet"
                        iconName: "content_paste"
                        text: I18n.tr("Paste", "island shelf: clipboard files as links, a picture or text as a new file")
                        keys: [I18n.tr("Ctrl", "keyboard key"), "V"]
                        leading: true
                        Accessible.name: text
                        onClicked: {
                            card.menu = false;
                            card.shelf?.paste();
                        }
                    }
                }
            }
        }

        // Right: act on the choice (or on the whole shelf); each button's shortcut at its right, in one column.
        Item {
            width: card.unit * 1.1
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
            }

            Column {
                id: actionsCol

                // Four buttons, then Preview, Rename and More, set the card's height; More's list scrolls in the four's room.
                readonly property real fixedHeight: colTitle.implicitHeight + ctx.implicitHeight + 7 * Theme.buttonHeightS + 8 * spacing

                anchors.fill: parent
                anchors.margins: card.inset
                spacing: Theme.spacingS

                StyledText {
                    id: colTitle

                    text: I18n.tr("Actions", "island shelf: the actions column").toUpperCase()
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    id: ctx

                    width: parent.width
                    text: card.empty ? I18n.tr("Nothing yet", "island shelf card subtitle: the shelf is empty") : card.kindLabels[card.shelf?.choice ?? "all"] ?? ""
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }

                Item {
                    width: parent.width
                    height: 4 * Theme.buttonHeightS + 3 * actionsCol.spacing

                    Column {
                        visible: !card.more && !card.empty
                        width: parent.width
                        spacing: actionsCol.spacing

                        Repeater {
                            id: buttons

                            function flashable() {
                                return Array.from({
                                    "length": buttons.count
                                }, (_, i) => buttons.itemAt(i));
                            }

                            model: card.shelf?.plan?.buttons ?? []

                            delegate: BubbleAction {
                                required property string modelData
                                required property int index
                                readonly property string actionId: modelData

                                width: parent.width
                                role: index === 0 ? "primary" : "tonal"
                                iconName: card.icons[modelData] ?? ""
                                text: card.labels[modelData] ?? modelData
                                keys: card.keysFor(modelData)
                                leading: true
                                busy: !!card.shelf?.busy?.[modelData] && modelData !== "listen"
                                // A copy is confirmed here, never by a "Copied" bubble (cartes.md, Copier).
                                feedbackText: ["copyFiles", "copyImage", "copyText", "copyContent", "copyPaths", "copySha"].indexOf(modelData) !== -1 ? I18n.tr("Copied!", "island shelf: an action's button after a copy") : ""
                                activeFocusOnTab: true
                                Accessible.name: text
                                onClicked: card.shelf?.act(modelData)
                            }
                        }
                    }

                    DFlickable {
                        anchors.fill: parent
                        visible: card.more
                        contentHeight: moreCol.implicitHeight
                        clip: true

                        Column {
                            id: moreCol

                            width: parent.width
                            spacing: Theme.spacingXS

                            BubbleAction {
                                width: parent.width
                                role: "quiet"
                                iconName: "arrow_back"
                                text: I18n.tr("Back", "island shelf: back from More to the four buttons")
                                keys: [I18n.tr("Esc", "keyboard key")]
                                leading: true
                                Accessible.name: text
                                onClicked: card.more = false
                            }
                            Repeater {
                                id: moreList

                                function flashable() {
                                    return Array.from({
                                        "length": moreList.count
                                    }, (_, i) => moreList.itemAt(i));
                                }

                                model: card.shelf?.plan?.more ?? []

                                delegate: BubbleAction {
                                    required property string modelData
                                    readonly property string actionId: modelData

                                    width: parent.width
                                    role: "quiet"
                                    iconName: card.icons[modelData] ?? ""
                                    leading: true
                                    text: card.labels[modelData] ?? modelData
                                    busy: !!card.shelf?.busy?.[modelData]
                                    Accessible.name: text
                                    onClicked: card.shelf?.act(modelData)
                                }
                            }
                        }
                    }
                }

                // Preview, rename, more: their keys in the same column as the actions'.
                Column {
                    id: tools

                    width: parent.width
                    spacing: actionsCol.spacing
                    visible: !card.empty

                    BubbleAction {
                        width: parent.width
                        role: "quiet"
                        enabled: card.list.length > 0
                        iconName: "visibility"
                        text: I18n.tr("Preview", "island shelf: quick look at a file in the card")
                        keys: [I18n.tr("Space", "keyboard key")]
                        leading: true
                        Accessible.name: text
                        onClicked: {
                            if (card.shelf)
                                card.shelf.peek = !card.shelf.peek;
                        }
                    }
                    BubbleAction {
                        width: parent.width
                        role: "quiet"
                        enabled: (card.shelf?.focusKeys?.length ?? 0) === 1
                        iconName: "edit"
                        text: I18n.tr("Rename", "island shelf: rename a file or a shelf folder in place")
                        keys: ["F2"]
                        leading: true
                        Accessible.name: text
                        onClicked: card.shelf?.startRename()
                    }
                    BubbleAction {
                        width: parent.width
                        role: "quiet"
                        visible: (card.shelf?.plan?.more?.length ?? 0) > 0
                        iconName: "more_horiz"
                        leading: true
                        text: I18n.tr("More", "island shelf: the actions under the four buttons")
                        Accessible.name: text
                        onClicked: card.more = !card.more
                    }
                }
            }
        }
    }

    Item {
        id: zonesNote

        x: Math.max(0, Math.round((leftPanel.width - width) / 2))
        y: body.y + body.height + Theme.spacingS
        width: zonesNoteRow.implicitWidth
        height: zonesNoteRow.implicitHeight
        Accessible.role: Accessible.Link
        Accessible.name: zonesNoteText.text
        Accessible.onPressAction: zonesNote.openSettings()

        // The zones' card in the settings, as a settings search result reaches it: on a bar that holds an island, else the dot.
        function openSettings() {
            const bar = SettingsSearchService.islandBarFor("islandEnabled", SettingsUiState.selectedBarId);
            if (bar)
                SettingsUiState.selectedBarId = bar.id;
            SettingsSearchService.navigateToSection(bar ? "islandShelf" : "dotShelf");
            PopoutService.openSettingsWithTab(bar ? "dankbar_settings" : "dankbar_dot");
        }

        Row {
            id: zonesNoteRow

            spacing: Theme.spacingXS

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "tune"
                size: Theme.iconSizeSmall
                color: zonesNoteText.color
            }
            StyledText {
                id: zonesNoteText

                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Zones set in the settings", "island shelf: the drop zones are chosen in DMS settings")
                font.pixelSize: Theme.fontSizeSmall
                font.underline: zonesNoteMouse.containsMouse
                color: zonesNoteMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
            }
        }

        MouseArea {
            id: zonesNoteMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: zonesNote.openSettings()
        }
    }

    // What an opened zone offers: formats (Convert), devices (Share), synced folders (Cloud).
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
                for (const b of zoneButtons.flashable())
                    if (b?.actionId === id)
                        b.flash(ok);
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
        StyledText {
            visible: choices.zoneId === "share" && (card?.shelf?.devices?.length ?? 0) > 0
            text: "KDE Connect"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceVariantText
        }
        Repeater {
            id: zoneButtons

            function flashable() {
                return Array.from({
                    "length": zoneButtons.count
                }, (_, i) => zoneButtons.itemAt(i));
            }

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

                width: choices.width
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
