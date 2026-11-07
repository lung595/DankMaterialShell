import QtQuick
import qs.Common

// What happens when files arrive and leave: where they land, when the shelf opens, drag out, messages and clearing.
// Shared by every island.
SettingsCard {
    iconName: "move_to_inbox"
    title: I18n.tr("Arrivals", "island shelf settings: arrivals card title")
    settingKey: "islandShelfArrivals"
    tags: ["island", "shelf", "arrivals"]

    SettingsRow {
        subtitle: I18n.tr("What happens when files come and go", "island shelf settings: arrivals card intro")
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfDropPosition"
        tags: ["island", "shelf", "top", "bottom", "drop", "position"]
        text: I18n.tr("New files go", "island shelf settings: new files go")
        description: I18n.tr("Where a dropped file lands in the list", "island shelf settings: new files go description")
        model: [I18n.tr("At the top", "island shelf settings: new files go option"), I18n.tr("At the bottom", "island shelf settings: new files go option")]
        values: ["top", "bottom"]
        value: SettingsData.islandShelfDropPosition
        fallbackValue: "top"
        onValueSelected: value => SettingsData.set("islandShelfDropPosition", value)
    }

    SettingsDropdownRow {
        settingKey: "islandShelfOpenOnArrival"
        tags: ["island", "shelf", "open", "drop", "auto"]
        text: I18n.tr("Open when files arrive", "island shelf settings: open when files arrive")
        description: I18n.tr("Opens the shelf by itself when something lands", "island shelf settings: open when files arrive description")
        options: [I18n.tr("Always", "island shelf settings: open when files arrive option"), I18n.tr("When dropped on the island", "island shelf settings: open when files arrive option"), I18n.tr("Never", "island shelf settings: open when files arrive option")]
        readonly property var choices: ["always", "island", "never"]
        dropdownWidth: Theme.smallBreakpoint / 2
        currentValue: options[Math.max(0, choices.indexOf(SettingsData.islandShelfOpenOnArrival))]
        onValueChanged: value => SettingsData.set("islandShelfOpenOnArrival", choices[options.indexOf(value)] ?? "island")
    }

    SettingsToggleRow {
        settingKey: "islandShelfStayOpen"
        tags: ["island", "shelf", "close", "drop"]
        text: I18n.tr("Stay open after a drop", "island shelf settings: stay open after a drop")
        description: I18n.tr("A shelf opened by a drag folds back after the drop unless this is on", "island shelf settings: stay open after a drop description")
        checked: SettingsData.islandShelfStayOpen
        onToggled: checked => SettingsData.set("islandShelfStayOpen", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfDragOut"
        tags: ["island", "shelf", "copy", "link", "move", "drag"]
        text: I18n.tr("Drag out as", "island shelf settings: drag out as")
        description: I18n.tr("What dragging a file out of the shelf does with it", "island shelf settings: drag out as description")
        model: [I18n.tr("Copy", "island shelf settings: drag out as option"), I18n.tr("Link", "island shelf settings: drag out as option"), I18n.tr("Move", "island shelf settings: drag out as option")]
        values: ["copy", "link", "move"]
        value: SettingsData.islandShelfDragOut
        fallbackValue: "copy"
        onValueSelected: value => SettingsData.set("islandShelfDragOut", value)
    }

    SettingsToggleRow {
        settingKey: "islandShelfRemoveOnDragOut"
        tags: ["island", "shelf", "drag", "remove"]
        text: I18n.tr("Remove after dragging out", "island shelf settings: remove after dragging out")
        description: I18n.tr("The file leaves the shelf once it is dropped elsewhere", "island shelf settings: remove after dragging out description")
        checked: SettingsData.islandShelfRemoveOnDragOut
        onToggled: checked => SettingsData.set("islandShelfRemoveOnDragOut", checked)
    }

    SettingsToggleRow {
        settingKey: "islandShelfCloseOnDragOut"
        tags: ["island", "shelf", "drag", "close", "bubble"]
        text: I18n.tr("Close after dragging out", "island shelf settings: close after dragging out")
        description: I18n.tr("The card folds into its bubble", "island shelf settings: close after dragging out description")
        checked: SettingsData.islandShelfCloseOnDragOut
        onToggled: checked => SettingsData.set("islandShelfCloseOnDragOut", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfDoubleClick"
        tags: ["island", "shelf", "click", "open", "preview", "rename"]
        text: I18n.tr("Double-click", "island shelf settings: double-click")
        description: I18n.tr("What a double-click does to a file", "island shelf settings: double-click description")
        model: [I18n.tr("Open", "island shelf settings: double-click option"), I18n.tr("Preview", "island shelf settings: double-click option"), I18n.tr("Rename", "island shelf settings: double-click option")]
        values: ["open", "preview", "rename"]
        value: SettingsData.islandShelfDoubleClick
        fallbackValue: "open"
        onValueSelected: value => SettingsData.set("islandShelfDoubleClick", value)
    }

    SettingsToggleRow {
        settingKey: "islandShelfLightDismiss"
        tags: ["island", "shelf", "escape", "dismiss", "click outside", "close"]
        text: I18n.tr("Close with Escape or a click outside", "island shelf settings: close with escape or a click outside")
        description: I18n.tr("Lifts the rule that only the cross or the shortcut close the shelf", "island shelf settings: close with escape or a click outside description")
        checked: SettingsData.islandShelfLightDismiss
        onToggled: checked => SettingsData.set("islandShelfLightDismiss", checked)
    }

    SettingsSliderRow {
        settingKey: "islandShelfMessageMs"
        tags: ["island", "shelf", "message", "duration", "feedback"]
        text: I18n.tr("Message time", "island shelf settings: message time")
        description: I18n.tr("How long the sentence that says what an action did stays", "island shelf settings: message time description")
        minimum: 10
        maximum: 60
        step: 5
        unit: " s"
        decimals: 1
        value: Math.round(SettingsData.islandShelfMessageMs / 100)
        onSliderDragFinished: finalValue => SettingsData.set("islandShelfMessageMs", finalValue * 100)
    }

    SettingsButtonGroupRow {
        settingKey: "islandShelfClearConfirm"
        tags: ["island", "shelf", "clear", "empty", "confirm", "hold"]
        text: I18n.tr("Clear All", "island shelf settings: clear all")
        description: I18n.tr("How emptying the shelf is confirmed", "island shelf settings: clear all description")
        model: [I18n.tr("Hold 2 s", "island shelf settings: clear all option"), I18n.tr("Ask", "island shelf settings: clear all option"), I18n.tr("Right away", "island shelf settings: clear all option")]
        values: ["hold", "ask", "now"]
        value: SettingsData.islandShelfClearConfirm
        fallbackValue: "hold"
        onValueSelected: value => SettingsData.set("islandShelfClearConfirm", value)
    }

    SettingsSliderRow {
        settingKey: "islandShelfFolderHoldMs"
        tags: ["island", "shelf", "folder", "hold", "group"]
        text: I18n.tr("Folder hold", "island shelf settings: folder hold")
        description: I18n.tr("Holding a file over another one makes a folder", "island shelf settings: folder hold description")
        minimum: 30
        maximum: 150
        step: 5
        unit: " s"
        decimals: 2
        value: Math.round(SettingsData.islandShelfFolderHoldMs / 10)
        onSliderDragFinished: finalValue => SettingsData.set("islandShelfFolderHoldMs", finalValue * 10)
    }
}
