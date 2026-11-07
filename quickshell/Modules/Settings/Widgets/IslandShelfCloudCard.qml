pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandShelf.js" as Shelf

// The synced folders the shelf's Cloud zone copies into, and what a drop on one does. Shared by every island. No
// account is ever asked: the folders are the ones the owner's sync app already keeps in step.
SettingsCard {
    id: root

    readonly property var clouds: Shelf.clouds(SettingsData.islandShelfClouds)
    readonly property var cloudIcons: ["cloud", "cloud_sync", "cloud_upload", "folder_shared", "backup"]

    iconName: "cloud"
    title: I18n.tr("Cloud folders", "island shelf settings: cloud card title")
    settingKey: "islandShelfCloud"
    tags: ["island", "shelf", "cloud", "folders"]

    function setClouds(list) {
        SettingsData.set("islandShelfClouds", list);
    }

    SettingsRow {
        settingKey: "islandShelfClouds"
        tags: ["island", "shelf", "cloud", "folder", "sync", "proton drive", "nextcloud"]
        subtitle: I18n.tr("Folders your sync app keeps in the cloud (Proton Drive, Nextcloud…). DMS only copies files into them and keeps no account", "island shelf settings: cloud folders description")

        DIconButton {
            variant: "filled"
            iconName: "create_new_folder"
            Accessible.name: I18n.tr("Choose a folder…", "island shelf: pick a synced folder for the Cloud zone")
            tooltipText: Accessible.name
            onClicked: picker.open()
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

    SettingsToggleRow {
        settingKey: "islandShelfCloudSpring"
        tags: ["island", "shelf", "hover", "cloud", "folders"]
        text: I18n.tr("Open on hover", "island shelf settings: open on hover")
        description: I18n.tr("Holding a file on Cloud shows its folders as targets", "island shelf settings: open on hover description")
        checked: SettingsData.islandShelfCloudSpring
        onToggled: checked => SettingsData.set("islandShelfCloudSpring", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfCloudMode"
        tags: ["island", "shelf", "copy", "move", "cloud"]
        text: I18n.tr("Copy or move", "island shelf settings: copy or move")
        description: I18n.tr("What dropping a file on a folder does", "island shelf settings: copy or move description")
        model: [I18n.tr("Copy", "island shelf settings: copy or move option"), I18n.tr("Move", "island shelf settings: copy or move option")]
        values: ["copy", "move"]
        value: SettingsData.islandShelfCloudMode
        fallbackValue: "copy"
        onValueSelected: value => SettingsData.set("islandShelfCloudMode", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfCloudAfter"
        tags: ["island", "shelf", "after", "show", "folder"]
        text: I18n.tr("After copying", "island shelf settings: after copying")
        description: I18n.tr("What happens once the file is in the folder", "island shelf settings: after copying description")
        model: [I18n.tr("Nothing", "island shelf settings: after copying option"), I18n.tr("Show in folder", "island shelf settings: after copying option")]
        values: ["nothing", "show"]
        value: SettingsData.islandShelfCloudAfter
        fallbackValue: "nothing"
        onValueSelected: value => SettingsData.set("islandShelfCloudAfter", value)
    }

    IslandFolderPicker {
        id: picker

        onChosen: path => {
            if (!root.clouds.some(c => c.path === path))
                root.setClouds(root.clouds.concat([
                    {
                        "name": Shelf.name(path),
                        "icon": "cloud",
                        "path": path
                    }
                ]));
        }
    }
}
