import QtQuick
import qs.Common

// How long the shelf keeps files, how many, and how it stores them. Shared by every island.
SettingsCard {
    iconName: "schedule"
    title: I18n.tr("Keeping", "island shelf settings: keeping card title")
    settingKey: "islandShelfKeeping"
    tags: ["island", "shelf", "keeping"]

    SettingsRow {
        subtitle: I18n.tr("How long files stay, and how many", "island shelf settings: keeping card intro")
    }

    SettingsDropdownRow {
        settingKey: "islandShelfKeepFor"
        tags: ["island", "shelf", "expire", "age", "forever", "time"]
        text: I18n.tr("Keep files for", "island shelf settings: keep files for")
        description: I18n.tr("Older files fall off the shelf. Pinned files stay", "island shelf settings: keep files for description")
        options: [I18n.tr("1 hour", "island shelf settings: keep files for option"), I18n.tr("1 day", "island shelf settings: keep files for option"), I18n.tr("1 week", "island shelf settings: keep files for option"), I18n.tr("1 month", "island shelf settings: keep files for option"), I18n.tr("Forever", "island shelf settings: keep files for option")]
        readonly property var choices: ["hour", "day", "week", "month", "forever"]
        dropdownWidth: Theme.smallBreakpoint / 2
        currentValue: options[Math.max(0, choices.indexOf(SettingsData.islandShelfKeepFor))]
        onValueChanged: value => SettingsData.set("islandShelfKeepFor", choices[options.indexOf(value)] ?? "forever")
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfMaxItems"
        tags: ["island", "shelf", "limit", "count", "maximum"]
        text: I18n.tr("At most", "island shelf settings: at most")
        description: I18n.tr("Past this, the oldest files fall off", "island shelf settings: at most description")
        model: [I18n.tr("25", "island shelf settings: at most option"), I18n.tr("50", "island shelf settings: at most option"), I18n.tr("100", "island shelf settings: at most option"), I18n.tr("200", "island shelf settings: at most option")]
        values: [25, 50, 100, 200]
        value: SettingsData.islandShelfMaxItems
        fallbackValue: 100
        onValueSelected: value => SettingsData.set("islandShelfMaxItems", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfMissing"
        tags: ["island", "shelf", "missing", "deleted", "forget"]
        text: I18n.tr("Missing files", "island shelf settings: missing files")
        description: I18n.tr("A file that was moved or deleted", "island shelf settings: missing files description")
        model: [I18n.tr("Keep them greyed", "island shelf settings: missing files option"), I18n.tr("Forget them", "island shelf settings: missing files option")]
        values: ["grey", "forget"]
        value: SettingsData.islandShelfMissing
        fallbackValue: "grey"
        onValueSelected: value => SettingsData.set("islandShelfMissing", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfStoreMode"
        tags: ["island", "shelf", "links", "copies", "store"]
        text: I18n.tr("Keep", "island shelf settings: keep")
        description: I18n.tr("Copies outlive their source but take disk space", "island shelf settings: keep description")
        model: [I18n.tr("Links", "island shelf settings: keep option"), I18n.tr("Copies", "island shelf settings: keep option")]
        values: ["links", "copies"]
        value: SettingsData.islandShelfStoreMode
        fallbackValue: "links"
        onValueSelected: value => SettingsData.set("islandShelfStoreMode", value)
    }

    SettingsSliderRow {
        settingKey: "islandShelfUndoSteps"
        tags: ["island", "shelf", "undo", "redo", "history"]
        text: I18n.tr("Undo steps", "island shelf settings: undo steps")
        description: I18n.tr("How many actions can be undone", "island shelf settings: undo steps description")
        minimum: 10
        maximum: 100
        step: 5
        value: SettingsData.islandShelfUndoSteps
        onSliderDragFinished: finalValue => SettingsData.set("islandShelfUndoSteps", finalValue)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfRecentRemoved"
        tags: ["island", "shelf", "trash", "restore", "bring back"]
        text: I18n.tr("Recently removed", "island shelf settings: recently removed")
        description: I18n.tr("A list to bring removed files back", "island shelf settings: recently removed description")
        model: [I18n.tr("Off", "island shelf settings: recently removed option"), I18n.tr("10", "island shelf settings: recently removed option"), I18n.tr("50", "island shelf settings: recently removed option")]
        values: [0, 10, 50]
        value: SettingsData.islandShelfRecentRemoved
        fallbackValue: 10
        onValueSelected: value => SettingsData.set("islandShelfRecentRemoved", value)
    }
}
