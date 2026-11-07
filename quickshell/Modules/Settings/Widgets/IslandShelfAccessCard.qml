import QtQuick
import qs.Common

// Motion, text size, target size and announcements of the shelf. Shared by every island.
SettingsCard {
    iconName: "accessibility"
    title: I18n.tr("Accessibility", "island shelf settings: access card title")
    settingKey: "islandShelfAccess"
    tags: ["island", "shelf", "accessibility"]

    SettingsRow {
        subtitle: I18n.tr("Motion, size and announcements", "island shelf settings: access card intro")
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfReduceMotion"
        tags: ["island", "shelf", "motion", "animation"]
        text: I18n.tr("Reduce motion", "island shelf settings: reduce motion")
        description: I18n.tr("Follows the DMS setting, or always skips the shelf animations", "island shelf settings: reduce motion description")
        model: [I18n.tr("Follow DMS", "island shelf settings: reduce motion option"), I18n.tr("Always", "island shelf settings: reduce motion option")]
        values: ["follow", "always"]
        value: SettingsData.islandShelfReduceMotion
        fallbackValue: "follow"
        onValueSelected: value => SettingsData.set("islandShelfReduceMotion", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfTextScale"
        tags: ["island", "shelf", "font", "text", "scale"]
        text: I18n.tr("Text size", "island shelf settings: text size")
        description: I18n.tr("Follows the DMS font size, or makes the shelf text larger", "island shelf settings: text size description")
        model: [I18n.tr("Follow DMS", "island shelf settings: text size option"), I18n.tr("Larger", "island shelf settings: text size option")]
        values: ["follow", "larger"]
        value: SettingsData.islandShelfTextScale
        fallbackValue: "follow"
        onValueSelected: value => SettingsData.set("islandShelfTextScale", value)
    }

    SettingsToggleRow {
        settingKey: "islandShelfLargeTargets"
        tags: ["island", "shelf", "target", "size", "fitts"]
        text: I18n.tr("Larger targets", "island shelf settings: larger targets")
        description: I18n.tr("Tiles, rows and zones are 25 percent bigger", "island shelf settings: larger targets description")
        checked: SettingsData.islandShelfLargeTargets
        onToggled: checked => SettingsData.set("islandShelfLargeTargets", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfAnnounce"
        tags: ["island", "shelf", "screen reader", "announce"]
        text: I18n.tr("Announce changes", "island shelf settings: announce changes")
        description: I18n.tr("A screen reader reads the sentence that says what an action did", "island shelf settings: announce changes description")
        checked: SettingsData.islandShelfAnnounce
        onToggled: checked => SettingsData.set("islandShelfAnnounce", checked)
    }
}
