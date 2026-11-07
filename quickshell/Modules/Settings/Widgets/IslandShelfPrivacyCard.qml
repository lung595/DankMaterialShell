import QtQuick
import qs.Common

// What the shelf remembers: restart, logout, names in the island, removable drives and the preview cache. Shared by every island.
SettingsCard {
    iconName: "lock"
    title: I18n.tr("Privacy", "island shelf settings: privacy card title")
    settingKey: "islandShelfPrivacy"
    tags: ["island", "shelf", "privacy"]

    SettingsRow {
        subtitle: I18n.tr("What the shelf remembers", "island shelf settings: privacy card intro")
    }

    SettingsToggleRow {
        settingKey: "islandShelfPersist"
        tags: ["island", "shelf", "restart", "session", "remember"]
        text: I18n.tr("Remember after restart", "island shelf settings: remember after restart")
        description: I18n.tr("Files stay on the shelf when DMS restarts", "island shelf settings: remember after restart description")
        checked: SettingsData.islandShelfPersist
        onToggled: checked => SettingsData.set("islandShelfPersist", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfClearOnLogout"
        tags: ["island", "shelf", "logout", "clear"]
        text: I18n.tr("Clear when logging out", "island shelf settings: clear when logging out")
        description: I18n.tr("The shelf starts empty at the next login", "island shelf settings: clear when logging out description")
        checked: SettingsData.islandShelfClearOnLogout
        onToggled: checked => SettingsData.set("islandShelfClearOnLogout", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfHideNames"
        tags: ["island", "shelf", "names", "thumbnails", "hide"]
        text: I18n.tr("Hide names in the island", "island shelf settings: hide names in the island")
        description: I18n.tr("The island and the bubble show no names or thumbnails", "island shelf settings: hide names in the island description")
        checked: SettingsData.islandShelfHideNames
        onToggled: checked => SettingsData.set("islandShelfHideNames", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfForgetRemovable"
        tags: ["island", "shelf", "usb", "drive", "removable"]
        text: I18n.tr("Forget removable drives", "island shelf settings: forget removable drives")
        description: I18n.tr("Files of an unplugged drive are forgotten", "island shelf settings: forget removable drives description")
        checked: SettingsData.islandShelfForgetRemovable
        onToggled: checked => SettingsData.set("islandShelfForgetRemovable", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfPreviewCache"
        tags: ["island", "shelf", "cache", "disk", "memory", "preview"]
        text: I18n.tr("Preview cache", "island shelf settings: preview cache")
        description: I18n.tr("Rich previews are never written to disk unless you ask", "island shelf settings: preview cache description")
        model: [I18n.tr("Memory only", "island shelf settings: preview cache option"), I18n.tr("On disk", "island shelf settings: preview cache option")]
        values: ["memory", "disk"]
        value: SettingsData.islandShelfPreviewCache
        fallbackValue: "memory"
        onValueSelected: value => SettingsData.set("islandShelfPreviewCache", value)
    }
}
