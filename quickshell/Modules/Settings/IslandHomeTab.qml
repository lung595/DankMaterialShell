pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets

// The compact face at rest: its groups, their style, its size, the media face and, for a bar island, its satellites.
Item {
    id: root

    property var parentModal: null
    property alias store: island.store
    readonly property bool hosted: island.hosted
    readonly property bool isDot: island.isDot
    readonly property bool layout: island.layout
    readonly property bool free: island.free
    readonly property bool vertical: island.vertical

    readonly property var clockDisplayValues: ["time", "date", "both"]
    readonly property var systemLevelDisplayValues: ["icon", "percentage", "both"]
    readonly property bool batteryShown: SettingsData.islandHomeGroupEnabled(root.store.config, "status") && BatteryService.batteryAvailable && SettingsData.islandHomeStatusContent(root.store.config) === "battery"

    IslandHubState {
        id: island
    }

    // A search hit inside the folded Satellites card unfolds it first.
    Connections {
        target: SettingsSearchService

        function onTargetSectionChanged() {
            const section = SettingsSearchService.targetSection;
            if (section.startsWith("islandSatellite") || section === "islandGothCornerRadius")
                satellitesCard.expanded = true;
        }
    }

    SettingsPage {
        SettingsCard {
            iconName: "widgets"
            title: I18n.tr("Layout", "noun, settings section title for arrangement options")
            settingKey: "islandHomeGroups"
            tags: ["island", "home", "compact", "layout", "groups", "order"]

            // Island-layout bars edit the home layout on the Bar widgets page; a hosted island edits it right here.
            SettingsNavRow {
                iconName: "widgets"
                title: I18n.tr("Edit layout", "island settings: opens the home layout editor on the Bar widgets page")
                hint: I18n.tr("Bar widgets")
                visible: !root.hosted
                onClicked: keyboard => {
                    if (!root.parentModal)
                        return;
                    SettingsSearchService.navigateToSection("islandHomeLayout");
                    root.parentModal.navigateTo("dankbar_widgets", keyboard);
                }
            }

            Loader {
                width: parent.width
                readonly property bool isSettingsRow: true
                readonly property bool transparentSlot: true
                height: (item as Item)?.implicitHeight ?? 0
                visible: root.hosted
                active: root.hosted && !!root.store.config
                sourceComponent: IslandHomeLayoutEditor {
                    settingKey: ""
                    barId: root.store.config?.id ?? ""
                }
            }
        }

        SettingsCard {
            iconName: "palette"
            title: I18n.tr("Style", "island settings: card of the compact face style")
            settingKey: "islandHomeStyle"
            tags: ["island", "home", "compact", "clock", "volume", "brightness", "battery", "status"]

            SettingsButtonGroupRow {
                settingKey: "islandHomeClockDisplay"
                tags: ["island", "home", "compact", "clock", "time", "date"]
                resetStore: root.store
                resetKeys: ["islandHomeClockDisplay"]
                text: I18n.tr("Clock style", "island settings: clock display mode row")
                model: [I18n.tr("Time", "island settings: clock shows time only"), I18n.tr("Date", "island settings: clock shows date only"), I18n.tr("Both", "island settings: clock shows time and date")]
                values: root.clockDisplayValues
                value: root.store.setting("islandHomeClockDisplay")
                fallbackValue: "both"
                onValueSelected: value => root.store.apply("islandHomeClockDisplay", value)
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeVolumeDisplay"
                tags: ["island", "home", "compact", "volume", "icon", "percentage"]
                resetStore: root.store
                resetKeys: ["islandHomeVolumeDisplay"]
                text: I18n.tr("Volume style", "island settings: volume display mode row")
                visible: SettingsData.islandHomeGroupEnabled(root.store.config, "volume")
                model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                values: root.systemLevelDisplayValues
                value: root.store.setting("islandHomeVolumeDisplay")
                fallbackValue: "both"
                onValueSelected: value => root.store.apply("islandHomeVolumeDisplay", value)
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeBrightnessDisplay"
                tags: ["island", "home", "compact", "brightness", "icon", "percentage"]
                resetStore: root.store
                resetKeys: ["islandHomeBrightnessDisplay"]
                text: I18n.tr("Brightness style", "island settings: brightness display mode row")
                visible: SettingsData.islandHomeGroupEnabled(root.store.config, "brightness")
                model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                values: root.systemLevelDisplayValues
                value: root.store.setting("islandHomeBrightnessDisplay")
                fallbackValue: "both"
                onValueSelected: value => root.store.apply("islandHomeBrightnessDisplay", value)
            }

            SettingsRow {
                settingKey: "islandHomeStatusContent"
                tags: ["island", "home", "compact", "status", "battery", "gauge", "solid", "outline", "ring", "circle", "duo", "wifi", "bluetooth", "connectivity"]
                title: I18n.tr("Status")
                visible: SettingsData.islandHomeGroupEnabled(root.store.config, "status")
                resetStore: root.store
                resetKeys: ["islandHomeStatusContent", "islandBatteryStyle"]

                body: SettingsLayoutPicker {
                    statusStyle: true
                    choices: [
                        {
                            key: "solid",
                            label: I18n.tr("Solid", "island settings: filled battery meter style"),
                            enabled: BatteryService.batteryAvailable
                        },
                        {
                            key: "outline",
                            label: I18n.tr("Outline", "island settings: outlined battery meter style"),
                            enabled: BatteryService.batteryAvailable
                        },
                        {
                            key: "ring",
                            label: I18n.tr("Circle", "island settings: circular battery meter style"),
                            enabled: BatteryService.batteryAvailable
                        },
                        {
                            key: "duo",
                            label: I18n.tr("Duo", "battery meter style: open battery arc around the network glyph"),
                            enabled: BatteryService.batteryAvailable
                        },
                        {
                            key: "connectivity",
                            label: I18n.tr("Wi-Fi & Bluetooth", "island settings: status group connectivity content")
                        }
                    ]
                    selectedKey: SettingsData.islandHomeStatusContent(root.store.config) === "connectivity" ? "connectivity" : root.store.setting("islandBatteryStyle")
                    onSelected: key => {
                        if (key === "connectivity") {
                            root.store.apply("islandHomeStatusContent", key);
                            return;
                        }
                        root.store.apply("islandBatteryStyle", key);
                        root.store.apply("islandHomeStatusContent", "battery");
                    }
                }
            }

            // The colour mode is a bar key; a hosted island follows its bar's Appearance page.
            SettingsButtonGroupRow {
                settingKey: "islandBatteryColorMode"
                tags: ["island", "battery", "color", "level", "theme", "meter", "accent", "green", "red"]
                resetStore: root.store
                resetKeys: ["batteryColorMode"]
                text: I18n.tr("Color")
                visible: root.batteryShown && !root.hosted
                model: [I18n.tr("Theme", "battery settings: theme accent indicator colors"), I18n.tr("Level", "battery settings: charge level indicator colors")]
                currentIndex: (root.store.config?.batteryColorMode ?? "theme") === "level" ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        root.store.apply("batteryColorMode", index === 1 ? "level" : "theme");
                }
            }
        }

        SettingsCard {
            iconName: "height"
            title: I18n.tr("Size", "island settings: card of the compact face size")
            settingKey: "islandHomeSize"
            tags: ["island", "home", "compact", "size", "height", "width", "background"]

            SettingsButtonGroupRow {
                settingKey: "islandHomeCompactTight"
                tags: ["island", "home", "compact", "pill", "narrow", "tight", "width", "height", "size", "clock"]
                resetStore: root.store
                resetKeys: ["islandHomeCompactTight"]
                text: I18n.tr("Density", "island settings: normal or compact home face")
                model: [I18n.tr("Normal"), I18n.tr("Compact")]
                currentIndex: root.store.setting("islandHomeCompactTight") ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        root.store.apply("islandHomeCompactTight", index === 1);
                }
            }

            SettingsSliderRow {
                settingKey: "islandCompactThickness"
                tags: ["island", "placement", "compact", "height", "width", "thickness", "size", "satellite"]
                visible: root.layout && !root.free
                resetStore: root.store
                resetKeys: ["islandCompactThickness"]
                text: root.vertical ? I18n.tr("Width") : I18n.tr("Height")
                unit: "px"
                minimum: 24
                maximum: 72
                step: 1
                value: root.store.setting("islandCompactThickness")
                onSliderValueChanged: value => root.store.apply("islandCompactThickness", value)
            }

            // Follows the bar's widget background setting like any other widget; this only opts the island out.
            SettingsToggleRow {
                settingKey: "islandWidgetBackground"
                tags: ["island", "widget", "background", "pill", "transparent"]
                visible: root.hosted
                text: I18n.tr("Background")
                description: I18n.tr("Bar widget background behind the compact face", "island widget settings: background toggle")
                checked: root.store.setting("islandWidgetBackground") === true
                onToggled: checked => root.store.apply("islandWidgetBackground", checked)
            }
        }

        SettingsCard {
            iconName: "music_note"
            title: I18n.tr("Media", "island settings: card of the media face")
            settingKey: "islandHomeMedia"
            tags: ["island", "media", "clock", "lyrics", "playback"]
            // A dot's compact face is a circle, so it never shows the media face.
            visible: !root.isDot

            SettingsToggleRow {
                settingKey: "islandMediaClockVisible"
                tags: ["island", "media", "clock", "compact", "time"]
                text: I18n.tr("Keep clock with media", "island settings: clock in media face toggle")
                checked: root.store.setting("islandMediaClockVisible")
                onToggled: checked => root.store.apply("islandMediaClockVisible", checked)
            }

            SettingsToggleRow {
                settingKey: "islandMediaLyrics"
                tags: ["island", "media", "lyrics", "compact"]
                text: I18n.tr("Lyrics", "Media player lyrics button")
                description: I18n.tr("Shows the line being sung instead of the title and artist while synced lyrics are available", "media widget lyrics toggle description")
                checked: root.store.setting("islandMediaLyrics")
                onToggled: checked => root.store.apply("islandMediaLyrics", checked)
            }

            SettingsToggleRow {
                settingKey: "islandMediaAutoSwitch"
                tags: ["island", "media", "playback", "auto", "switch", "compact"]
                text: I18n.tr("Switch to media when playback starts", "island settings: auto-switch the compact face to media toggle")
                checked: root.store.setting("islandMediaAutoSwitch")
                onToggled: checked => root.store.apply("islandMediaAutoSwitch", checked)
            }
        }

        IslandSatellitesCard {
            id: satellitesCard

            store: root.store
            free: root.free
            visible: root.layout
        }
    }
}
