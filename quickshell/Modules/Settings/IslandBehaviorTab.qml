import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets

// How the island opens, which activities it takes over, and what the wheel does over it.
Item {
    id: root

    property var parentModal: null
    property alias store: island.store
    readonly property bool hosted: island.hosted
    readonly property bool docked: island.docked

    readonly property var routingValues: ["normal", "always", "last-used"]
    readonly property var interactionModeValues: ["click", "hybrid"]
    readonly property var routeActivities: ["launcher", "controlcenter", "notificationcenter", "clipboard", "powermenu", "home", "media", "weather", "wallpaper"]
    readonly property var routeKeys: routeActivities.map(activity => SettingsData.islandRouteKey(activity))
    readonly property string sharedRouting: SettingsData.islandSharedRoutingMode(root.store.config)

    IslandHubState {
        id: island
    }

    SettingsPage {
        SettingsCard {
            iconName: "touch_app"
            title: I18n.tr("Opening", "island settings: card of how the island opens")
            settingKey: "islandInteraction"
            tags: ["island", "interaction", "click", "hover", "open", "delay", "expand"]
            visible: root.docked

            SettingsButtonGroupRow {
                settingKey: "islandInteractionMode"
                tags: ["island", "interaction", "click", "hybrid", "hover", "expand"]
                resetStore: root.store
                resetKeys: ["islandInteractionMode"]
                text: I18n.tr("Open on", "island settings: click or hover opening row")
                model: [I18n.tr("Click", "island settings: opening mode, click only"), I18n.tr("Click or hover", "island settings: opening mode, hover peeks plus click")]
                values: root.interactionModeValues
                value: root.store.setting("islandInteractionMode")
                fallbackValue: "hybrid"
                onValueSelected: value => root.store.apply("islandInteractionMode", value)
            }

            SettingsRow {
                visible: root.store.setting("islandInteractionMode") !== "click"
                body: StyledText {
                    width: parent.width
                    text: I18n.tr("Hover peeks at the current compact face. A click keeps it open", "island settings: click or hover mode hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            SettingsSliderRow {
                settingKey: "islandHoverOpenDelay"
                tags: ["island", "interaction", "hover", "open", "delay"]
                resetStore: root.store
                resetKeys: ["islandHoverOpenDelay"]
                text: I18n.tr("Open delay", "island settings: hover open delay slider")
                unit: "ms"
                minimum: 0
                maximum: 1000
                step: 10
                value: root.store.setting("islandHoverOpenDelay")
                visible: root.store.setting("islandInteractionMode") !== "click"
                onSliderDragFinished: value => root.store.apply("islandHoverOpenDelay", value)
            }

            SettingsSliderRow {
                settingKey: "islandHoverCloseDelay"
                tags: ["island", "interaction", "hover", "close", "delay"]
                resetStore: root.store
                resetKeys: ["islandHoverCloseDelay"]
                text: I18n.tr("Hide delay", "island settings: hover hide delay slider")
                unit: "ms"
                minimum: 0
                maximum: 1000
                step: 10
                value: root.store.setting("islandHoverCloseDelay")
                visible: root.store.setting("islandInteractionMode") !== "click"
                onSliderDragFinished: value => root.store.apply("islandHoverCloseDelay", value)
            }
        }

        SettingsCard {
            iconName: "open_in_new"
            title: I18n.tr("Open in the island", "island widget settings: activities routed to the island")
            settingKey: "islandRouting"
            tags: ["island", "routing", "shortcuts", "launcher", "control center", "dashboard", "ipc"]

            SettingsDropdownRow {
                settingKey: "islandSharedRouting"
                tags: ["island", "routing", "launcher", "dash", "control center", "ipc", "last used"]
                visible: !root.hosted
                resetStore: root.store
                resetKeys: ["islandSharedRouting"]
                text: I18n.tr("Global shortcuts open in", "island settings dropdown label, which island handles global shortcuts")
                description: I18n.tr("Routes launcher, dash, control center and notification shortcuts. Bar widget clicks always open their own popout", "shared shortcuts dropdown description")
                options: [I18n.tr("Default island", "shared shortcuts option, shortcuts open where they normally would"), I18n.tr("This island", "shared shortcuts option, shortcuts always open on this island"), I18n.tr("Last used on this screen", "shared shortcuts option, shortcuts open on the island last used on this display")]
                dropdownWidth: Theme.smallBreakpoint / 2
                currentValue: options[Math.max(0, root.routingValues.indexOf(root.sharedRouting))]
                onValueChanged: value => SettingsData.setIslandSharedRouting(root.store.config?.id ?? "", root.routingValues[options.indexOf(value)] ?? "normal")
            }

            // A hosted island's card title already says it; a bar island or the dot lists the activities pinned to it.
            SettingsRow {
                settingKey: "islandRouteActivities"
                tags: ["island", "routing", "shortcuts", "launcher", "control center", "notification center", "clipboard", "power menu", "dashboard", "media", "weather", "wallpaper", "ipc"]
                visible: root.hosted || root.sharedRouting !== "always"
                resetStore: root.store
                resetKeys: root.routeKeys
                title: root.hosted ? "" : I18n.tr("Always open here", "island settings: activities pinned to this island")
                subtitle: root.hosted ? I18n.tr("The rest open the bar's own popouts", "island widget settings: unselected activities use the bar") : I18n.tr("The rest follow the shared rule", "island settings: unselected activities follow shared shortcuts")
            }

            IslandRouteRow {
                settingKey: "islandRouteLauncher"
                store: root.store
                hosted: root.hosted
                activity: "launcher"
                text: I18n.tr("Launcher")
            }

            IslandRouteRow {
                settingKey: "islandRouteControlCenter"
                store: root.store
                hosted: root.hosted
                activity: "controlcenter"
                text: I18n.tr("Control Center")
            }

            IslandRouteRow {
                settingKey: "islandRouteNotificationCenter"
                store: root.store
                hosted: root.hosted
                activity: "notificationcenter"
                text: I18n.tr("Notification Center")
            }

            IslandRouteRow {
                settingKey: "islandRouteClipboard"
                store: root.store
                hosted: root.hosted
                activity: "clipboard"
                text: I18n.tr("Clipboard")
            }

            IslandRouteRow {
                settingKey: "islandRoutePowerMenu"
                store: root.store
                hosted: root.hosted
                activity: "powermenu"
                text: I18n.tr("Power menu", "island settings: route the power menu to the island")
            }

            IslandRouteRow {
                settingKey: "islandRouteDash"
                store: root.store
                hosted: root.hosted
                activity: "home"
                text: I18n.tr("Dashboard")
            }

            IslandRouteRow {
                settingKey: "islandRouteMedia"
                store: root.store
                hosted: root.hosted
                activity: "media"
                text: I18n.tr("Media")
            }

            IslandRouteRow {
                settingKey: "islandRouteWeather"
                store: root.store
                hosted: root.hosted
                activity: "weather"
                text: I18n.tr("Weather")
            }

            IslandRouteRow {
                settingKey: "islandRouteWallpaper"
                store: root.store
                hosted: root.hosted
                activity: "wallpaper"
                text: I18n.tr("Wallpapers")
            }
        }

        SettingsCard {
            iconName: "swap_vert"
            title: I18n.tr("Scrolling", "island settings: card of the wheel over the island")
            settingKey: "islandScrolling"
            tags: ["island", "wheel", "scroll", "touchpad", "direction"]
            headerActions: IslandSharedBadge {}

            SettingsToggleRow {
                settingKey: "islandArrivalWheel"
                tags: ["island", "arrival", "wheel", "scroll", "touchpad", "burst"]
                text: I18n.tr("Scroll through arrivals", "island settings: the wheel turns the pages of the infos open in the island")
                description: I18n.tr("The wheel or touchpad over the open island goes from one arrival to the next", "island settings: arrival wheel description")
                checked: SettingsData.islandArrivalWheel
                onToggled: checked => SettingsData.set("islandArrivalWheel", checked)
            }

            SettingsToggleRow {
                settingKey: "islandArrivalWheelDirection"
                tags: ["island", "arrival", "wheel", "scroll", "direction", "natural", "inverted"]
                visible: SettingsData.islandArrivalWheel
                text: I18n.tr("Reverse scroll direction", "island settings: the wheel turns the pages of the infos the other way")
                checked: SettingsData.islandArrivalWheelInverted
                onToggled: checked => SettingsData.set("islandArrivalWheelInverted", checked)
            }
        }

        SettingsCard {
            iconName: "space_dashboard"
            title: I18n.tr("Dashboard", "settings page name for the dank dash popout")
            settingKey: "islandDashboard"
            tags: ["island", "dashboard", "dash", "tabs"]

            SettingsToggleRow {
                settingKey: "islandDashTabs"
                tags: ["island", "dashboard", "dash", "tabs", "navigation"]
                text: I18n.tr("Dashboard tabs", "island settings: dashboard tab bar toggle")
                description: I18n.tr("Shows the dashboard tab bar instead of the sheet handle", "island settings: dashboard tab bar toggle description")
                checked: root.store.setting("islandDashTabs")
                onToggled: checked => root.store.apply("islandDashTabs", checked)
            }
        }
    }
}
