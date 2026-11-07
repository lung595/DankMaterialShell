import QtQuick
import qs.Common
import "../../../Common/IslandShelf.js" as Shelf

// What the shelf's drop zones card reads and writes: the zones in the owner's order, the one being edited, and the
// formats Convert offers. A zone is {id, enabled}, which the shelf reads, plus the fields saved here (name, icon,
// action, target, keep); a zone added here has an id "zone-N" and the shelf ignores it for now.
QtObject {
    id: root

    readonly property var raw: Array.isArray(SettingsData.islandShelfZones) ? SettingsData.islandShelfZones : []
    // The owner's order; an added zone keeps its place and a missing built-in zone comes back last.
    readonly property var rows: {
        const out = [];
        for (const r of root.raw) {
            const known = r && typeof r.id === "string" && (Shelf.zoneIds.indexOf(r.id) !== -1 || r.id.startsWith("zone-"));
            if (known && !out.some(o => o.id === r.id))
                out.push(Object.assign({}, r, {
                    "enabled": r.enabled !== false
                }));
        }
        for (const id of Shelf.zoneIds)
            if (!out.some(o => o.id === id))
                out.push({
                    "id": id,
                    "enabled": true
                });
        return out;
    }
    // The zones on: the last one stays on, so the shelf never has an empty column of zones.
    readonly property int zonesOn: root.rows.filter(r => r.enabled).length
    property int editIndex: 0
    readonly property var edited: root.rows[Math.min(root.editIndex, root.rows.length - 1)]
    readonly property var formats: SettingsData.islandShelfConvertFormats ?? ({})
    readonly property IslandShelfZones zones: IslandShelfZones {}
    readonly property var builtinIcons: ({
            "convert": "swap_horiz",
            "share": "ios_share",
            "cloud": "cloud_sync"
        })
    readonly property var builtinActions: ({
            "convert": "convert",
            "share": "share",
            "cloud": "copy"
        })
    readonly property var iconNames: ["swap_horiz", "ios_share", "cloud_sync", "folder", "drive_file_move", "terminal", "send", "upload", "archive", "bolt"]
    readonly property var iconLabels: [I18n.tr("Arrows", "island shelf settings: zone icon option"), I18n.tr("Share", "island shelf settings: zone icon option"), I18n.tr("Cloud", "island shelf settings: zone icon option"), I18n.tr("Folder", "island shelf settings: zone icon option"), I18n.tr("Move", "island shelf settings: zone icon option"), I18n.tr("Terminal", "island shelf settings: zone icon option"), I18n.tr("Send", "island shelf settings: zone icon option"), I18n.tr("Upload", "island shelf settings: zone icon option"), I18n.tr("Archive", "island shelf settings: zone icon option"), I18n.tr("Bolt", "island shelf settings: zone icon option")]
    readonly property var formatTypes: [
        {
            "id": "image",
            "label": I18n.tr("Images", "island shelf settings: convert formats, file type")
        },
        {
            "id": "video",
            "label": I18n.tr("Videos", "island shelf settings: convert formats, file type")
        },
        {
            "id": "audio",
            "label": I18n.tr("Audio", "island shelf settings: convert formats, file type")
        },
        {
            "id": "pdf",
            "label": I18n.tr("PDF", "island shelf settings: convert formats, file type")
        },
        {
            "id": "text",
            "label": I18n.tr("Text", "island shelf settings: convert formats, file type")
        }
    ]

    function isCustom(r) {
        return Shelf.zoneIds.indexOf(r.id) === -1;
    }
    function nameOf(r) {
        return r.name || (root.isCustom(r) ? I18n.tr("New zone", "island shelf settings: name of a zone added by the owner") : root.zones.name(r.id));
    }
    function iconOf(r) {
        return r.icon || root.builtinIcons[r.id] || "folder";
    }
    function actionOf(r) {
        return r.action || root.builtinActions[r.id] || "copy";
    }
    function setZones(list) {
        SettingsData.set("islandShelfZones", list);
    }
    function patch(id, fields) {
        root.setZones(root.rows.map(r => r.id === id ? Object.assign({}, r, fields) : r));
    }
    function addZone() {
        let n = 1;
        while (root.rows.some(r => r.id === "zone-" + n))
            n++;
        root.setZones(root.rows.concat([
            {
                "id": "zone-" + n,
                "enabled": true,
                "name": "",
                "icon": "folder",
                "action": "copy",
                "target": "",
                "keep": false
            }
        ]));
        root.editIndex = root.rows.length - 1;
    }
    function formatsOf(type) {
        return root.formats[type] ?? Shelf.convertible[type].map(p => p[0]);
    }
    // One format at least stays on; all of them back is the default, so the type's entry goes.
    function setFormat(type, format, on) {
        const all = Shelf.convertible[type].map(p => p[0]);
        const now = root.formatsOf(type);
        const next = all.filter(f => f === format ? on : now.includes(f));
        if (next.length === 0)
            return;
        const map = Object.assign({}, root.formats);
        if (next.length === all.length)
            delete map[type];
        else
            map[type] = next;
        SettingsData.set("islandShelfConvertFormats", map);
    }
}
