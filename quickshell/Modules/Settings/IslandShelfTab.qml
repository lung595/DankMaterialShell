import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.Settings.Widgets

// The shelf's settings, in eleven cards: how files show, what happens on arrival, what is kept, the ways in, the drop
// zones, the cloud folders, sharing, shortcuts, privacy, accessibility and screens. Shared by every island.
Item {
    id: root

    property var parentModal: null

    SettingsPage {
        IslandShelfLookCard {
            headerActions: IslandSharedBadge {}
        }

        IslandShelfArrivalsCard {}

        IslandShelfKeepingCard {}

        IslandShelfInputsCard {}

        IslandShelfCard {}

        IslandShelfCloudCard {}

        SettingsCard {
            iconName: "ios_share"
            title: I18n.tr("Share", "island shelf settings: share card title")
            settingKey: "islandShelfShare"
            tags: ["island", "shelf", "share"]

            SettingsRow {
                subtitle: I18n.tr("Devices that can receive files", "island shelf settings: share card intro")
            }

            SettingsToggleRow {
                settingKey: "islandShelfShareKdeConnect"
                tags: ["island", "shelf", "kde connect", "phone", "device"]
                text: I18n.tr("KDE Connect", "island shelf settings: kde connect")
                description: I18n.tr("Send to phones and computers paired with KDE Connect", "island shelf settings: kde connect description")
                checked: SettingsData.islandShelfShareKdeConnect
                onToggled: checked => SettingsData.set("islandShelfShareKdeConnect", checked)
            }

            SettingsToggleRow {
                settingKey: "islandShelfShareLocalSend"
                tags: ["island", "shelf", "localsend", "device", "network"]
                text: I18n.tr("LocalSend", "island shelf settings: localsend")
                description: I18n.tr("Send to devices running LocalSend", "island shelf settings: localsend description")
                checked: SettingsData.islandShelfShareLocalSend
                onToggled: checked => SettingsData.set("islandShelfShareLocalSend", checked)
            }

            SettingsDropdownRow {
                settingKey: "islandShelfShareDevice"
                tags: ["island", "shelf", "device", "ask", "default"]
                text: I18n.tr("Default device", "island shelf settings: default device")
                description: I18n.tr("Ask every time, or send to one device without asking", "island shelf settings: default device description")
                options: [I18n.tr("Ask", "island shelf settings: default device option")]
                readonly property var choices: ["ask"]
                dropdownWidth: Theme.smallBreakpoint / 2
                currentValue: options[Math.max(0, choices.indexOf(SettingsData.islandShelfShareDevice))]
                onValueChanged: value => SettingsData.set("islandShelfShareDevice", choices[options.indexOf(value)] ?? "ask")
            }
        }

        SettingsCard {
            iconName: "keyboard"
            title: I18n.tr("Shortcuts", "island shelf settings: shortcuts card title")
            settingKey: "islandShelfShortcuts"
            tags: ["island", "shelf", "shortcuts"]

            SettingsRow {
                subtitle: I18n.tr("Set in Keyboard shortcuts, listed here", "island shelf settings: shortcuts card intro")
            }

            SettingsNavRow {
                settingKey: "islandShelfShortcutToggle"
                tags: ["island", "shelf", "shortcut", "keyboard", "super", "toggle", "open", "close"]
                title: I18n.tr("Open or close the shelf", "island shelf settings: shortcut to toggle the shelf")
                hint: I18n.tr("Super S in the niri binds that come with DMS", "island shelf settings: shortcut to toggle the shelf description")
                onClicked: keyboard => root.parentModal?.navigateTo("keybinds", keyboard)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DKeycap {
                        text: "Super"
                    }

                    DKeycap {
                        text: "S"
                    }
                }
            }

            SettingsNavRow {
                settingKey: "islandShelfShortcutClipboard"
                tags: ["island", "shelf", "shortcut", "keyboard", "clipboard", "paste"]
                title: I18n.tr("Clipboard to the shelf", "island shelf settings: shortcut to put the clipboard on the shelf")
                hint: I18n.tr("Puts what you copied on the shelf, without opening it", "island shelf settings: shortcut to put the clipboard on the shelf description")
                onClicked: keyboard => root.parentModal?.navigateTo("keybinds", keyboard)

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Not set", "island shelf settings: a shortcut with no key")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            SettingsNavRow {
                settingKey: "islandShelfShortcutScreenshot"
                tags: ["island", "shelf", "shortcut", "keyboard", "screenshot", "capture"]
                title: I18n.tr("Screenshot to the shelf", "island shelf settings: shortcut to take a screenshot onto the shelf")
                hint: I18n.tr("Takes a screenshot and keeps it on the shelf", "island shelf settings: shortcut to take a screenshot onto the shelf description")
                onClicked: keyboard => root.parentModal?.navigateTo("keybinds", keyboard)

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Not set", "island shelf settings: a shortcut with no key")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandShelfTypeToSearch"
                tags: ["island", "shelf", "search", "slash", "type"]
                text: I18n.tr("Start a search with", "island shelf settings: start a search with")
                description: I18n.tr("A letter starts the search as soon as you type a name, without the slash", "island shelf settings: start a search with description")
                model: [I18n.tr("/ only", "island shelf settings: start a search with option"), I18n.tr("Any letter", "island shelf settings: start a search with option")]
                values: [false, true]
                value: SettingsData.islandShelfTypeToSearch
                fallbackValue: false
                onValueSelected: value => SettingsData.set("islandShelfTypeToSearch", value)
            }
        }

        IslandShelfPrivacyCard {}

        IslandShelfAccessCard {}

        SettingsCard {
            iconName: "monitor"
            title: I18n.tr("Screens", "island shelf settings: screens card title")
            settingKey: "islandShelfScreens"
            tags: ["island", "shelf", "screens"]

            SettingsRow {
                subtitle: I18n.tr("Where the shelf opens", "island shelf settings: screens card intro")
            }

            SettingsButtonGroupRow {
                settingKey: "islandShelfScreen"
                tags: ["island", "shelf", "screen", "monitor", "display"]
                text: I18n.tr("Open on", "island shelf settings: open on")
                description: I18n.tr("The screen the shelf opens on", "island shelf settings: open on description")
                model: [I18n.tr("Focused screen", "island shelf settings: open on option"), I18n.tr("Screen under the pointer", "island shelf settings: open on option")]
                values: ["focused", "pointer"]
                value: SettingsData.islandShelfScreen
                fallbackValue: "focused"
                onValueSelected: value => SettingsData.set("islandShelfScreen", value)
            }

            SettingsButtonGroupRow {
                settingKey: "islandShelfBubbleScreens"
                tags: ["island", "shelf", "bubble", "screen", "monitor"]
                text: I18n.tr("Bubble on", "island shelf settings: bubble on")
                description: I18n.tr("The screens that show the shelf bubble", "island shelf settings: bubble on description")
                model: [I18n.tr("Focused screen", "island shelf settings: bubble on option"), I18n.tr("Every screen", "island shelf settings: bubble on option")]
                values: ["focused", "every"]
                value: SettingsData.islandShelfBubbleScreens
                fallbackValue: "focused"
                onValueSelected: value => SettingsData.set("islandShelfBubbleScreens", value)
            }

            SettingsNavRow {
                settingKey: "islandShelfBubble"
                tags: ["island", "shelf", "bubble", "side", "lifetime", "sound", "each bubble"]
                iconName: "tune"
                title: I18n.tr("Bubble", "island shelf settings: link to the shelf bubble in Each bubble")
                hint: I18n.tr("Side, lifetime and sound of the shelf bubble", "island shelf settings: link to the shelf bubble in Each bubble description")
                onClicked: keyboard => {
                    SettingsUiState.islandBubbleFilter = "system";
                    root.parentModal?.navigateTo("island_bubble_table", keyboard);
                }
            }
        }
    }
}
