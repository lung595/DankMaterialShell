pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandShelf.js" as Shelf

// The shelf's drop zones: which ones, in what order, what each does, and the formats Convert offers. Shared by every
// island. What it reads and writes lives in IslandShelfZoneState.
SettingsCard {
    id: root

    IslandShelfZoneState {
        id: zs
    }

    iconName: "inventory_2"
    title: I18n.tr("Drop zones", "island shelf settings: zones card title")
    settingKey: "islandShelf"
    tags: ["island", "shelf", "drop", "zones"]

    SettingsRow {
        subtitle: I18n.tr("Drag to reorder. A file dropped on a zone shows what it can do there", "island shelf settings: zones card intro")
    }

    SettingsReorderList {
        id: zoneList

        model: zs.rows
        onReordered: indices => zs.setZones(indices.map(i => zs.rows[i]))

        delegate: SettingsReorderRow {
            id: zoneRow

            required property var modelData

            readonly property bool lastOn: zoneRow.modelData.enabled && zs.zonesOn <= 1

            reorderList: zoneList
            title: zs.nameOf(zoneRow.modelData)
            clickable: !zoneRow.lastOn
            onClicked: zs.patch(zoneRow.modelData.id, {
                "enabled": !zoneRow.modelData.enabled
            })

            DIconButton {
                visible: zs.isCustom(zoneRow.modelData)
                iconName: "delete"
                Accessible.name: I18n.tr("Remove", "island shelf settings: remove a zone added here")
                tooltipText: Accessible.name
                onClicked: zs.setZones(zs.rows.filter(r => r.id !== zoneRow.modelData.id))
            }

            DToggle {
                hideText: true
                Accessible.name: zoneRow.title
                enabled: !zoneRow.lastOn
                checked: zoneRow.modelData.enabled
                onToggled: checked => zs.patch(zoneRow.modelData.id, {
                    "enabled": checked
                })
            }
        }
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfZonesShown"
        tags: ["island", "shelf", "zones", "drag", "always"]
        text: I18n.tr("Show zones", "island shelf settings: show zones")
        description: I18n.tr("When the zones show on the card", "island shelf settings: show zones description")
        model: [I18n.tr("While dragging", "island shelf settings: show zones option"), I18n.tr("Always", "island shelf settings: show zones option")]
        values: ["dragging", "always"]
        value: SettingsData.islandShelfZonesShown
        fallbackValue: "dragging"
        onValueSelected: value => SettingsData.set("islandShelfZonesShown", value)
    }

    SettingsRow {
        settingKey: "islandShelfZoneEdit"
        tags: ["island", "shelf", "zone", "edit", "name", "icon", "action", "target", "keep"]
        title: I18n.tr("Edit a zone", "island shelf settings: pick the zone to edit")
        subtitle: I18n.tr("Name, icon and what a drop does", "island shelf settings: edit a zone description")

        body: DFilterChips {
            width: parent.width
            model: zs.rows.map(r => zs.nameOf(r))
            onSelectionChanged: index => zs.editIndex = index

            // A click sets the chips' own index; this keeps them on the zone being edited when a zone is added or removed.
            Binding on currentIndex {
                value: Math.min(zs.editIndex, zs.rows.length - 1)
            }
        }
    }

    SettingsTextFieldRow {
        settingKey: "islandShelfZoneName"
        tags: ["island", "shelf", "zone", "name", "rename"]
        leftIconName: zs.iconOf(zs.edited)
        text: I18n.tr("Name", "island shelf settings: zone name")
        description: I18n.tr("Shown on the zone tile", "island shelf settings: zone name description")
        value: zs.nameOf(zs.edited)
        onEditingFinished: v => zs.patch(zs.edited.id, {
            "name": v.trim() === zs.zones.name(zs.edited.id) ? "" : v.trim()
        })
    }

    SettingsDropdownRow {
        settingKey: "islandShelfZoneIcon"
        tags: ["island", "shelf", "zone", "icon", "symbol"]
        text: I18n.tr("Icon", "island shelf settings: zone icon")
        description: I18n.tr("Shown on the zone tile", "island shelf settings: zone icon description")
        options: zs.iconLabels
        optionIcons: zs.iconNames
        dropdownWidth: Theme.smallBreakpoint / 2
        currentValue: zs.iconLabels[Math.max(0, zs.iconNames.indexOf(zs.iconOf(zs.edited)))]
        onValueChanged: value => zs.patch(zs.edited.id, {
            "icon": zs.iconNames[zs.iconLabels.indexOf(value)] ?? "folder"
        })
    }

    SettingsDropdownRow {
        settingKey: "islandShelfZoneAction"
        tags: ["island", "shelf", "zone", "action", "convert", "share", "copy", "move", "command"]
        text: I18n.tr("Action", "island shelf settings: zone action")
        description: I18n.tr("What dropping a file on this zone does", "island shelf settings: zone action description")
        options: [I18n.tr("Convert", "island shelf settings: zone action option"), I18n.tr("Share", "island shelf settings: zone action option"), I18n.tr("Copy to folder", "island shelf settings: zone action option"), I18n.tr("Move to folder", "island shelf settings: zone action option"), I18n.tr("Run a command", "island shelf settings: zone action option")]
        readonly property var choices: ["convert", "share", "copy", "move", "run"]
        dropdownWidth: Theme.smallBreakpoint / 2
        currentValue: options[Math.max(0, choices.indexOf(zs.actionOf(zs.edited)))]
        onValueChanged: value => zs.patch(zs.edited.id, {
            "action": choices[options.indexOf(value)] ?? "copy"
        })
    }

    SettingsTextFieldRow {
        id: targetRow

        readonly property string zoneAction: zs.actionOf(zs.edited)

        settingKey: "islandShelfZoneTarget"
        tags: ["island", "shelf", "zone", "target", "folder", "device", "command"]
        visible: zoneAction !== "convert"
        leftIconName: zoneAction === "run" ? "terminal" : (zoneAction === "share" ? "devices" : "folder")
        text: I18n.tr("Target", "island shelf settings: zone target")
        description: zoneAction === "run" ? I18n.tr("A command. The file names are passed to it as arguments, never through a shell", "island shelf settings: zone target description, command") : (zoneAction === "share" ? I18n.tr("A device name. Empty asks every time", "island shelf settings: zone target description, device") : I18n.tr("The folder the files go to", "island shelf settings: zone target description, folder"))
        placeholderText: zoneAction === "run" ? I18n.tr("Command", "island shelf settings: zone target placeholder, command") : (zoneAction === "share" ? I18n.tr("Device", "island shelf settings: zone target placeholder, device") : I18n.tr("Folder", "island shelf settings: zone target placeholder, folder"))
        value: zs.edited.target ?? ""
        onEditingFinished: v => zs.patch(zs.edited.id, {
            "target": v.trim()
        })

        actions: [
            DIconButton {
                visible: targetRow.zoneAction === "copy" || targetRow.zoneAction === "move"
                iconName: "folder_open"
                Accessible.name: I18n.tr("Choose a folder…", "island shelf settings: pick the folder of a zone")
                tooltipText: Accessible.name
                onClicked: targetPicker.open()
            }
        ]
    }

    SettingsToggleRow {
        settingKey: "islandShelfZoneKeep"
        tags: ["island", "shelf", "zone", "keep", "drop", "stay"]
        text: I18n.tr("Keep files dropped here", "island shelf settings: zone keep")
        description: I18n.tr("A file dropped on this zone also stays on the shelf", "island shelf settings: zone keep description")
        checked: zs.edited.keep === true
        onToggled: checked => zs.patch(zs.edited.id, {
            "keep": checked
        })
    }

    SettingsRow {
        settingKey: "islandShelfZoneAdd"
        tags: ["island", "shelf", "zone", "add", "new", "custom"]
        title: I18n.tr("Add a zone", "island shelf settings: add a zone")
        subtitle: I18n.tr("Up to 6 zones", "island shelf settings: add a zone description")

        DIconButton {
            variant: "filled"
            iconName: "add"
            enabled: zs.rows.length < 6
            Accessible.name: I18n.tr("Add a zone", "island shelf settings: add a zone")
            tooltipText: Accessible.name
            onClicked: zs.addZone()
        }
    }

    SettingsRow {
        settingKey: "islandShelfConvertFormats"
        tags: ["island", "shelf", "convert", "format", "png", "jpg", "mp4", "pdf"]
        title: I18n.tr("Convert formats", "island shelf settings: convert formats")
        subtitle: I18n.tr("The formats Convert offers for each type. All the ones found are offered until you choose", "island shelf settings: convert formats description")
    }

    Repeater {
        model: zs.formatTypes

        delegate: SettingsRow {
            id: formatRow

            required property var modelData

            readonly property var all: Shelf.convertible[formatRow.modelData.id].map(p => p[0])
            readonly property var chosen: zs.formatsOf(formatRow.modelData.id)

            title: formatRow.modelData.label

            body: DFilterChips {
                width: parent.width
                multiSelect: true
                showCounts: false
                model: formatRow.all.map(f => ({
                            "label": f.toUpperCase(),
                            "value": f
                        }))
                selectedValues: formatRow.chosen
                onSelectionToggled: (index, selected) => zs.setFormat(formatRow.modelData.id, formatRow.all[index], selected)
            }
        }
    }

    IslandFolderPicker {
        id: targetPicker

        onChosen: path => zs.patch(zs.edited.id, {
                "target": path
            })
    }
}
