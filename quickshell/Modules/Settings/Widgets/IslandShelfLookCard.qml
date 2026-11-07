import QtQuick
import qs.Common

// How the shelf's files show: shape, density, previews, labels, order, key hints and count. Shared by every island.
SettingsCard {
    iconName: "visibility"
    title: I18n.tr("Look", "island shelf settings: look card title")
    settingKey: "islandShelfLook"
    tags: ["island", "shelf", "look"]

    SettingsRow {
        subtitle: I18n.tr("How files show on the shelf", "island shelf settings: look card intro")
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfLayout"
        tags: ["island", "shelf", "view", "gallery", "list", "stack"]
        text: I18n.tr("Layout", "island shelf settings: layout")
        description: I18n.tr("The shape of the shelf card", "island shelf settings: layout description")
        model: [I18n.tr("Gallery", "island shelf settings: layout option"), I18n.tr("List", "island shelf settings: layout option"), I18n.tr("Stack", "island shelf settings: layout option")]
        values: ["gallery", "list", "stack"]
        value: SettingsData.islandShelfLayout
        fallbackValue: "list"
        onValueSelected: value => SettingsData.set("islandShelfLayout", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfDensity"
        tags: ["island", "shelf", "spacing", "compact"]
        text: I18n.tr("Density", "island shelf settings: density")
        description: I18n.tr("Spacing and height of the rows or tiles", "island shelf settings: density description")
        model: [I18n.tr("Comfortable", "island shelf settings: density option"), I18n.tr("Compact", "island shelf settings: density option")]
        values: ["comfortable", "compact"]
        value: SettingsData.islandShelfDensity
        fallbackValue: "comfortable"
        onValueSelected: value => SettingsData.set("islandShelfDensity", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfPreviews"
        tags: ["island", "shelf", "thumbnail", "icon", "picture"]
        text: I18n.tr("Previews", "island shelf settings: previews")
        description: I18n.tr("A small picture of each file, or an icon for its type", "island shelf settings: previews description")
        model: [I18n.tr("Thumbnails", "island shelf settings: previews option"), I18n.tr("Type icons", "island shelf settings: previews option")]
        values: ["thumbnails", "icons"]
        value: SettingsData.islandShelfPreviews
        fallbackValue: "thumbnails"
        onValueSelected: value => SettingsData.set("islandShelfPreviews", value)
    }

    SettingsToggleRow {
        settingKey: "islandShelfRichPreviews"
        tags: ["island", "shelf", "pdf", "video", "thumbnail"]
        text: I18n.tr("Rich previews", "island shelf settings: rich previews")
        description: I18n.tr("First page of PDFs and a frame of videos. Needs pdftoppm and ffmpeg", "island shelf settings: rich previews description")
        enabled: SettingsData.islandShelfPreviews === "thumbnails"
        checked: SettingsData.islandShelfRichPreviews
        onToggled: checked => SettingsData.set("islandShelfRichPreviews", checked)
    }

    SettingsSliderRow {
        settingKey: "islandShelfPreviewSize"
        tags: ["island", "shelf", "thumbnail", "size"]
        text: I18n.tr("Preview size", "island shelf settings: preview size")
        description: I18n.tr("Size of the thumbnails", "island shelf settings: preview size description")
        enabled: SettingsData.islandShelfPreviews === "thumbnails"
        minimum: 32
        maximum: 160
        step: 8
        unit: " px"
        value: SettingsData.islandShelfPreviewSize
        onSliderDragFinished: finalValue => SettingsData.set("islandShelfPreviewSize", finalValue)
    }

    SettingsDropdownRow {
        settingKey: "islandShelfLabel"
        tags: ["island", "shelf", "name", "size", "caption"]
        text: I18n.tr("Under each file", "island shelf settings: under each file")
        description: I18n.tr("What is written with a file at rest", "island shelf settings: under each file description")
        options: [I18n.tr("Nothing", "island shelf settings: under each file option"), I18n.tr("Name", "island shelf settings: under each file option"), I18n.tr("Name and size", "island shelf settings: under each file option")]
        readonly property var choices: ["none", "name", "nameSize"]
        dropdownWidth: Theme.smallBreakpoint / 2
        currentValue: options[Math.max(0, choices.indexOf(SettingsData.islandShelfLabel))]
        onValueChanged: value => SettingsData.set("islandShelfLabel", choices[options.indexOf(value)] ?? "name")
    }

    SettingsToggleRow {
        settingKey: "islandShelfHoverDetails"
        tags: ["island", "shelf", "hover", "preview", "remove"]
        text: I18n.tr("Details on hover", "island shelf settings: details on hover")
        description: I18n.tr("Size, type and two buttons appear when the pointer rests on a file", "island shelf settings: details on hover description")
        checked: SettingsData.islandShelfHoverDetails
        onToggled: checked => SettingsData.set("islandShelfHoverDetails", checked)
    }

    SettingsSliderRow {
        settingKey: "islandShelfMaxRows"
        tags: ["island", "shelf", "height", "scroll", "rows"]
        text: I18n.tr("Rows before scrolling", "island shelf settings: rows before scrolling")
        description: I18n.tr("The card stops growing after this many rows", "island shelf settings: rows before scrolling description")
        minimum: 3
        maximum: 10
        step: 1
        value: SettingsData.islandShelfMaxRows
        onSliderDragFinished: finalValue => SettingsData.set("islandShelfMaxRows", finalValue)
    }

    SettingsDropdownRow {
        settingKey: "islandShelfSort"
        tags: ["island", "shelf", "order", "recent", "name", "type", "size"]
        text: I18n.tr("Sort by", "island shelf settings: sort by")
        description: I18n.tr("The order of the list", "island shelf settings: sort by description")
        options: [I18n.tr("Recent first", "island shelf settings: sort by option"), I18n.tr("Oldest first", "island shelf settings: sort by option"), I18n.tr("Name", "island shelf settings: sort by option"), I18n.tr("Type", "island shelf settings: sort by option"), I18n.tr("Size", "island shelf settings: sort by option")]
        readonly property var choices: ["recent", "oldest", "name", "type", "size"]
        dropdownWidth: Theme.smallBreakpoint / 2
        currentValue: options[Math.max(0, choices.indexOf(SettingsData.islandShelfSort))]
        onValueChanged: value => SettingsData.set("islandShelfSort", choices[options.indexOf(value)] ?? "recent")
    }

    SettingsToggleRow {
        settingKey: "islandShelfPinnedFirst"
        tags: ["island", "shelf", "pin", "favorite"]
        text: I18n.tr("Pinned on top", "island shelf settings: pinned on top")
        description: I18n.tr("Pinned files stay before the rest", "island shelf settings: pinned on top description")
        checked: SettingsData.islandShelfPinnedFirst
        onToggled: checked => SettingsData.set("islandShelfPinnedFirst", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfKeyHints"
        tags: ["island", "shelf", "shortcut", "keys", "kbd", "hints"]
        text: I18n.tr("Key hints", "island shelf settings: key hints")
        description: I18n.tr("When the shortcut keys show on the card. The one by the title always stays", "island shelf settings: key hints description")
        model: [I18n.tr("Always", "island shelf settings: key hints option"), I18n.tr("After a key press", "island shelf settings: key hints option"), I18n.tr("Never", "island shelf settings: key hints option")]
        values: ["always", "press", "never"]
        value: SettingsData.islandShelfKeyHints
        fallbackValue: "press"
        onValueSelected: value => SettingsData.set("islandShelfKeyHints", value)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfCountMode"
        tags: ["island", "shelf", "number", "badge", "files", "entries"]
        text: I18n.tr("Count", "island shelf settings: count")
        description: I18n.tr("What the subtitle and the bubble count", "island shelf settings: count description")
        model: [I18n.tr("Files", "island shelf settings: count option"), I18n.tr("Entries", "island shelf settings: count option")]
        values: ["files", "entries"]
        value: SettingsData.islandShelfCountMode
        fallbackValue: "files"
        onValueSelected: value => SettingsData.set("islandShelfCountMode", value)
    }
}
