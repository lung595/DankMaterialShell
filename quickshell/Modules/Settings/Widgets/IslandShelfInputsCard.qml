import QtQuick
import qs.Common
import qs.DCommon.Widgets

// The ways to put something on the shelf: drops, paste, screenshots, downloads. Shared by every island.
SettingsCard {
    iconName: "input"
    title: I18n.tr("Inputs", "island shelf settings: inputs card title")
    settingKey: "islandShelfInputs"
    tags: ["island", "shelf", "inputs"]

    SettingsRow {
        subtitle: I18n.tr("Ways to put something on the shelf", "island shelf settings: inputs card intro")
    }

    SettingsToggleRow {
        settingKey: "islandShelfDropIsland"
        tags: ["island", "shelf", "drop", "island"]
        text: I18n.tr("Drop on the island", "island shelf settings: drop on the island")
        description: I18n.tr("A file dropped on the island goes on the shelf", "island shelf settings: drop on the island description")
        checked: SettingsData.islandShelfDropIsland
        onToggled: checked => SettingsData.set("islandShelfDropIsland", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfEdgeDrop"
        tags: ["island", "shelf", "drop", "edge", "fitts"]
        text: I18n.tr("Drop at the screen edge", "island shelf settings: drop at the screen edge")
        description: I18n.tr("The drop area of the island reaches the edge of the screen", "island shelf settings: drop at the screen edge description")
        checked: SettingsData.islandShelfEdgeDrop
        onToggled: checked => SettingsData.set("islandShelfEdgeDrop", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfAcceptText"
        tags: ["island", "shelf", "link", "url", "text", "drop"]
        text: I18n.tr("Links and text", "island shelf settings: links and text")
        description: I18n.tr("Links and text dropped or pasted are kept as items", "island shelf settings: links and text description")
        checked: SettingsData.islandShelfAcceptText
        onToggled: checked => SettingsData.set("islandShelfAcceptText", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfPaste"
        tags: ["island", "shelf", "paste", "clipboard", "ctrl v"]
        text: I18n.tr("Paste with Ctrl+V", "island shelf settings: paste with ctrl+v")
        description: I18n.tr("Files in the clipboard go on the shelf", "island shelf settings: paste with ctrl+v description")
        checked: SettingsData.islandShelfPaste
        onToggled: checked => SettingsData.set("islandShelfPaste", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfPasteAs"
        tags: ["island", "shelf", "paste", "text", "note", "file"]
        text: I18n.tr("Pasted text becomes", "island shelf settings: pasted text becomes")
        description: I18n.tr("Where text from the clipboard ends up", "island shelf settings: pasted text becomes description")
        model: [I18n.tr("A note", "island shelf settings: pasted text becomes option"), I18n.tr("A text file", "island shelf settings: pasted text becomes option")]
        values: ["note", "file"]
        value: SettingsData.islandShelfPasteAs
        fallbackValue: "note"
        onValueSelected: value => SettingsData.set("islandShelfPasteAs", value)
    }

    SettingsTextFieldRow {
        settingKey: "islandShelfNewFilesDir"
        tags: ["island", "shelf", "folder", "paste", "documents", "new file", "untitled"]
        leftIconName: "folder"
        text: I18n.tr("Folder for new files", "island shelf settings: folder for new files")
        description: I18n.tr("Where pasted and untitled files are written. Empty means Documents", "island shelf settings: folder for new files description")
        placeholderText: I18n.tr("Documents", "island shelf settings: folder for new files placeholder")
        value: SettingsData.islandShelfNewFilesDir
        onEditingFinished: v => SettingsData.set("islandShelfNewFilesDir", v.trim())

        actions: [
            DIconButton {
                iconName: "folder_open"
                Accessible.name: I18n.tr("Choose a folder…", "island shelf settings: pick the folder for new files")
                tooltipText: Accessible.name
                onClicked: newFilesPicker.open()
            }
        ]
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfScreenshots"
        tags: ["island", "shelf", "screenshot", "capture"]
        text: I18n.tr("Screenshots", "island shelf settings: screenshots")
        description: I18n.tr("Screenshots you take", "island shelf settings: screenshots description")
        model: [I18n.tr("Off", "island shelf settings: screenshots option"), I18n.tr("Also on the shelf", "island shelf settings: screenshots option")]
        values: ["off", "shelf"]
        value: SettingsData.islandShelfScreenshots
        fallbackValue: "off"
        onValueSelected: value => SettingsData.set("islandShelfScreenshots", value)
    }

    SettingsToggleRow {
        settingKey: "islandShelfDownloads"
        tags: ["island", "shelf", "download"]
        text: I18n.tr("Finished downloads", "island shelf settings: finished downloads")
        description: I18n.tr("Files that finish downloading land on the shelf", "island shelf settings: finished downloads description")
        checked: SettingsData.islandShelfDownloads
        onToggled: checked => SettingsData.set("islandShelfDownloads", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfKeepOutputs"
        tags: ["island", "shelf", "convert", "zip", "output"]
        text: I18n.tr("Files made by actions", "island shelf settings: files made by actions")
        description: I18n.tr("Conversions, archives and extracts are kept on the shelf", "island shelf settings: files made by actions description")
        checked: SettingsData.islandShelfKeepOutputs
        onToggled: checked => SettingsData.set("islandShelfKeepOutputs", checked)
    }

    IslandFolderPicker {
        id: newFilesPicker

        onChosen: path => SettingsData.set("islandShelfNewFilesDir", path)
    }
}
