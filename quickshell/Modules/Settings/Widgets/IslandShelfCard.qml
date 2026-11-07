pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import qs.Modals.FileBrowser
import "../../../Common/IslandShelf.js" as Shelf

// The shelf's drop zones (which ones, in what order) and the synced folders its Cloud zone copies into. Shared by
// every island. No account is ever asked: the folders are the ones the owner's sync app already keeps in step.
SettingsCard {
    id: root

    property string keyPrefix: "island"
    property bool shown: true

    readonly property var rows: Shelf.zoneRows(SettingsData.islandShelfZones)
    // The zones on: the last one stays on, so the card's left column is never empty.
    readonly property int zonesOn: root.rows.filter(r => r.enabled).length
    readonly property var clouds: Shelf.clouds(SettingsData.islandShelfClouds)
    readonly property var cloudIcons: ["cloud", "cloud_sync", "cloud_upload", "folder_shared", "backup"]

    iconName: "inventory_2"
    title: I18n.tr("Shelf", "island shelf: its name")
    settingKey: root.keyPrefix + "Shelf"
    tags: ["island", "shelf", "drop", "zone", "convert", "share", "cloud", "kde connect", "localsend", "sync", "folder"]
    visible: root.shown

    readonly property IslandShelfZones zones: IslandShelfZones {}
    function setZones(list) {
        SettingsData.set("islandShelfZones", list);
    }
    function setClouds(list) {
        SettingsData.set("islandShelfClouds", list);
    }

    SettingsRow {
        title: I18n.tr("Drop zones", "island shelf settings: the zones of the card's left column")
        subtitle: I18n.tr("Drag to reorder. A file dropped on a zone shows what it can do there.", "island shelf settings: drop zones description")
    }

    SettingsReorderList {
        id: zoneList

        model: root.rows
        onReordered: indices => root.setZones(indices.map(i => root.rows[i]))

        delegate: SettingsReorderRow {
            id: zoneRow

            required property var modelData

            readonly property bool lastOn: zoneRow.modelData.enabled && root.zonesOn <= 1

            reorderList: zoneList
            title: root.zones.name(zoneRow.modelData.id)
            clickable: !zoneRow.lastOn
            onClicked: root.setZones(root.rows.map(r => r.id === zoneRow.modelData.id ? Object.assign({}, r, {
                        "enabled": !r.enabled
                    }) : r))

            DToggle {
                hideText: true
                Accessible.name: zoneRow.title
                enabled: !zoneRow.lastOn
                checked: zoneRow.modelData.enabled
                onToggled: checked => root.setZones(root.rows.map(r => r.id === zoneRow.modelData.id ? Object.assign({}, r, {
                            "enabled": checked
                        }) : r))
            }
        }
    }

    SettingsRow {
        title: I18n.tr("Cloud folders", "island shelf settings: synced folders for the Cloud zone")
        subtitle: I18n.tr("Folders your sync app keeps in the cloud (Proton Drive, Nextcloud…). DMS only copies files into them and keeps no account.", "island shelf settings: cloud folders description")

        DIconButton {
            variant: "filled"
            iconName: "create_new_folder"
            Accessible.name: I18n.tr("Choose a folder…", "island shelf: pick a synced folder for the Cloud zone")
            tooltipText: Accessible.name
            onClicked: {
                picker.active = true;
                picker.item?.open();
            }
        }
    }

    Repeater {
        model: root.clouds

        delegate: SettingsTextFieldRow {
            id: cloudRow

            required property var modelData
            required property int index

            leftIconName: cloudRow.modelData.icon
            text: cloudRow.modelData.path
            value: cloudRow.modelData.name
            onEditingFinished: v => root.setClouds(root.clouds.map((c, i) => i === cloudRow.index ? Object.assign({}, c, {
                        "name": v.trim() || Shelf.name(c.path)
                    }) : c))

            actions: [
                DIconButton {
                    iconName: cloudRow.modelData.icon
                    Accessible.name: I18n.tr("Change icon", "island shelf settings: next icon for a cloud folder")
                    tooltipText: Accessible.name
                    onClicked: root.setClouds(root.clouds.map((c, i) => i === cloudRow.index ? Object.assign({}, c, {
                                "icon": root.cloudIcons[(root.cloudIcons.indexOf(c.icon) + 1) % root.cloudIcons.length]
                            }) : c))
                },
                DIconButton {
                    iconName: "delete"
                    Accessible.name: I18n.tr("Remove", "island shelf settings: forget a cloud folder, the folder stays")
                    tooltipText: Accessible.name
                    onClicked: root.setClouds(root.clouds.filter((c, i) => i !== cloudRow.index))
                }
            ]
        }
    }

    LazyLoader {
        id: picker

        active: false

        FileBrowserModal {
            browserTitle: I18n.tr("Choose a folder", "island shelf: folder picker title")
            mode: "openFolder"
            onAccepted: paths => {
                const p = String(paths?.[0] ?? "").replace(/^file:\/\//, "");
                if (p.startsWith("/") && !root.clouds.some(c => c.path === p))
                    root.setClouds(root.clouds.concat([
                        {
                            "name": Shelf.name(p),
                            "icon": "cloud",
                            "path": p
                        }
                    ]));
            }
            onDialogClosed: Qt.callLater(() => picker.active = false)
        }
    }
}
