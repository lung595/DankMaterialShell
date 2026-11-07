import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

// What goes in a bubble beside the island instead of inside it, eye breaks, and the way to the bubble table.
Item {
    id: root

    property var parentModal: null

    SettingsPage {
        SettingsCard {
            iconName: "bubble_chart"
            title: I18n.tr("Show in a bubble", "island settings: card of what goes beside the island")
            settingKey: "islandBubbles"
            tags: ["island", "bubbles", "bubble", "volume", "brightness", "osd", "notification", "reopen"]
            headerActions: IslandSharedBadge {}

            SettingsToggleRow {
                settingKey: "islandLevelBubbles"
                tags: ["island", "bubbles", "volume", "brightness", "microphone", "osd"]
                text: I18n.tr("Always show levels in a bubble", "island settings: volume, brightness and mic changes go beside the island")
                description: I18n.tr("Volume, brightness and microphone changes appear beside the island instead of inside it", "island settings: level bubbles description")
                checked: SettingsData.islandLevelBubbles
                onToggled: checked => SettingsData.set("islandLevelBubbles", checked)
            }

            SettingsToggleRow {
                settingKey: "islandBriefBubbles"
                tags: ["island", "bubbles", "copy", "copied", "clipboard", "screenshot", "notification"]
                text: I18n.tr("Always show brief info in a bubble", "island settings: a copy goes beside the island, its notification stays out of it")
                description: I18n.tr("A copy, a finished download, a file in the trash or a network change shows only its bubble beside the island; an app's notification saying the same thing does not open in the island", "island settings: brief info bubbles description")
                checked: SettingsData.islandBriefBubbles
                onToggled: checked => SettingsData.set("islandBriefBubbles", checked)
            }

            SettingsTextFieldRow {
                settingKey: "islandReopenApps"
                resetKeys: ["islandReopenApps"]
                tags: ["island", "bubbles", "reopen", "close", "background", "apps", "signal", "discord", "steam"]
                leftIconName: "replay"
                text: I18n.tr("Offer to reopen", "island settings: apps whose closed window gets a reopen bubble")
                description: I18n.tr("Apps that keep running in the background, separated by commas: closing their window shows a bubble to reopen it", "island settings: reopen apps description")
                value: SettingsData.islandReopenApps
                onValueEdited: value => SettingsData.set("islandReopenApps", value)
            }
        }

        SettingsCard {
            iconName: "visibility"
            title: I18n.tr("Eye breaks", "island settings: remind to rest the eyes at regular intervals")
            settingKey: "islandEyeBreaks"
            tags: ["island", "bubbles", "eyes", "break", "rest", "wellbeing"]
            headerActions: IslandSharedBadge {}

            SettingsToggleRow {
                settingKey: "islandEyeBreak"
                tags: ["island", "bubbles", "eyes", "break", "rest", "screen", "wellbeing", "20-20-20"]
                text: I18n.tr("Remind me to look away", "island settings: eye breaks toggle, remind to rest the eyes at regular intervals")
                description: I18n.tr("Now and then, look far away for a few seconds. Never over a fullscreen window or during a call", "island settings: eye breaks description")
                checked: SettingsData.islandEyeBreak
                onToggled: checked => SettingsData.set("islandEyeBreak", checked)
            }

            SettingsSliderRow {
                settingKey: "islandEyeBreakInterval"
                tags: ["island", "eyes", "break", "interval", "rhythm"]
                text: I18n.tr("Break every", "island settings: minutes between two eye breaks")
                unit: I18n.tr("min", "minutes unit")
                minimum: 5
                maximum: 120
                step: 5
                value: SettingsData.islandEyeBreakInterval
                visible: SettingsData.islandEyeBreak
                onSliderValueChanged: value => SettingsData.set("islandEyeBreakInterval", value)
            }

            SettingsSliderRow {
                settingKey: "islandEyeBreakDuration"
                tags: ["island", "eyes", "break", "duration", "length"]
                text: I18n.tr("Break length", "island settings: seconds an eye break lasts")
                unit: "s"
                minimum: 10
                maximum: 120
                step: 5
                value: SettingsData.islandEyeBreakDuration
                visible: SettingsData.islandEyeBreak
                onSliderValueChanged: value => SettingsData.set("islandEyeBreakDuration", value)
            }
        }

        SettingsCard {
            SettingsNavRow {
                iconName: "tune"
                title: SettingsTabs.page("island_bubble_table")?.text ?? ""
                hint: SettingsTabs.page("island_bubble_table")?.hint ?? ""
                onClicked: keyboard => root.parentModal?.navigateTo("island_bubble_table", keyboard)
            }
        }
    }
}
