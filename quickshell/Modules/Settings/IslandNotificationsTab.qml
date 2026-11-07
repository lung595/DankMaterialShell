pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Modules.Settings.Widgets
import "../../Common/IslandBubbleTable.js" as BubbleTable

// Where arriving notifications and level changes show (in the island or as the regular DMS popups and OSDs),
// which apps may show bubbles, what a bubble hides, and when the island stays quiet.
Item {
    id: root

    property var parentModal: null
    property alias store: island.store
    // A dot has no home layout editor, so its badge row must not follow the notifications group.
    readonly property bool isDot: island.isDot

    property var desktopApps: []
    readonly property string appFilterMode: root.store.setting("islandAppFilterMode")
    readonly property var appFilterList: root.store.setting("islandAppFilterList") ?? []

    function addApp(name) {
        const id = name.trim().replace(/\.desktop$/, "");
        if (id)
            root.store.apply("islandAppFilterList", SettingsData.addAppIdToList(id, root.appFilterList));
    }

    function removeApp(index) {
        root.store.apply("islandAppFilterList", SettingsData.removeAppIdFromList(index, root.appFilterList));
    }

    Component.onCompleted: desktopApps = AppSearchService.getVisibleApplications() || []

    IslandHubState {
        id: island
    }

    SettingsPage {
        SettingsCard {
            iconName: "notifications"
            title: I18n.tr("Notifications", "island settings: notifications card title")
            settingKey: "islandNotifications"
            tags: ["island", "notifications", "popup", "badge", "expand"]

            SettingsToggleRow {
                settingKey: "islandNotificationPopups"
                tags: ["island", "notifications", "popup", "standard", "bar", "stack", "arrival"]
                text: I18n.tr("Notifications as popups", "island settings: show arriving notifications as stacked popups instead of in the island")
                description: I18n.tr("New notifications show as DMS popups instead of in the island", "island notifications as popups toggle description")
                checked: root.store.setting("islandNotificationPopups")
                onToggled: checked => root.store.apply("islandNotificationPopups", checked)
            }

            SettingsToggleRow {
                settingKey: "islandNotificationExpand"
                tags: ["island", "notifications", "expand", "arrival", "size"]
                text: I18n.tr("Expand by default", "island settings: expanded notification toggle")
                checked: root.store.setting("islandNotificationExpand")
                onToggled: checked => root.store.apply("islandNotificationExpand", checked)
            }

            SettingsToggleRow {
                settingKey: "islandNotificationBadgeClearOnOpen"
                tags: ["island", "home", "notifications", "badge", "unread", "clear", "dismiss", "open"]
                text: I18n.tr("Clear badge on open", "island settings: clear the notification badge when the center opens")
                checked: root.store.setting("islandNotificationBadgeClearOnOpen")
                enabled: root.isDot || SettingsData.islandHomeGroupEnabled(root.store.config, "notifications")
                onToggled: checked => root.store.apply("islandNotificationBadgeClearOnOpen", checked)
            }
        }

        SettingsCard {
            iconName: "tune"
            title: I18n.tr("On-screen displays", "island settings: card of the volume and brightness displays")
            settingKey: "islandOsd"
            tags: ["island", "osd", "volume", "brightness", "charging"]

            // Stored the other way round: islandSystemOsd means the island draws them.
            SettingsToggleRow {
                settingKey: "islandSystemOsd"
                tags: ["island", "volume", "brightness", "microphone", "caps lock", "power profile", "idle inhibitor", "osd", "level", "standard"]
                text: I18n.tr("Volume and brightness as OSD", "island settings: show volume and brightness changes as the regular on-screen displays instead of in the island")
                description: I18n.tr("Volume, brightness, microphone and Caps Lock use the DMS on-screen displays instead of the island", "island settings: volume and brightness as OSD toggle description")
                checked: !root.store.setting("islandSystemOsd")
                onToggled: checked => root.store.apply("islandSystemOsd", !checked)
            }

            SettingsToggleRow {
                settingKey: "islandChargingPulse"
                tags: ["island", "battery", "charging", "plugged", "power", "pulse"]
                text: I18n.tr("Charging", "island settings: pulse the island when power is connected or removed")
                description: I18n.tr("Show the battery briefly when power is connected or removed", "island settings: charging pulse toggle description")
                visible: root.store.setting("islandSystemOsd") && BatteryService.batteryAvailable
                checked: root.store.setting("islandChargingPulse")
                onToggled: checked => root.store.apply("islandChargingPulse", checked)
            }
        }

        SettingsCard {
            iconName: "filter_alt"
            title: I18n.tr("App filter", "island settings: card of the apps allowed or blocked in the island")
            settingKey: "islandAppFilter"
            tags: ["island", "apps", "filter", "allow", "block", "only", "exclude", "notifications", "bubbles"]

            SettingsButtonGroupRow {
                settingKey: "islandAppFilterMode"
                tags: ["island", "apps", "filter", "allow", "block", "only", "exclude", "all"]
                resetStore: root.store
                resetKeys: ["islandAppFilterMode"]
                text: I18n.tr("Apps", "island settings: which apps may show bubbles in the island")
                description: {
                    switch (root.appFilterMode) {
                    case "allow":
                        return I18n.tr("Only these apps can show bubbles in the island", "island settings: app filter description, allow list");
                    case "block":
                        return I18n.tr("These apps never show bubbles in the island. Their notifications still reach the notification center", "island settings: app filter description, block list");
                    default:
                        return I18n.tr("Every app can show bubbles in the island", "island settings: app filter description, no filter");
                    }
                }
                model: [I18n.tr("All", "island settings: app filter, every app"), I18n.tr("Only these", "island settings: app filter, allow list"), I18n.tr("All but these", "island settings: app filter, block list")]
                values: ["off", "allow", "block"]
                value: root.appFilterMode
                fallbackValue: "off"
                onValueSelected: value => root.store.apply("islandAppFilterMode", value)
            }

            SettingsTextFieldRow {
                id: appEditor

                function submit() {
                    root.addApp(appEditor.value);
                    appEditor.value = "";
                }

                settingKey: "islandAppFilterList"
                tags: ["island", "apps", "filter", "list", "name", "desktop"]
                visible: root.appFilterMode !== "off"
                leftIconName: "apps"
                text: I18n.tr("Name")
                description: I18n.tr("App name or desktop file name, case-insensitive", "island settings: app filter name field description")
                placeholderText: I18n.tr("App name (e.g., signal)", "island settings: app filter name field placeholder")
                onAccepted: appEditor.submit()

                actions: [
                    DIconButton {
                        variant: "filled"
                        iconName: "add"
                        Accessible.name: I18n.tr("Add")
                        enabled: appEditor.value.trim() !== ""
                        onClicked: appEditor.submit()
                    },
                    DIconButton {
                        iconName: "apps"
                        tooltipText: I18n.tr("Browse")
                        onClicked: appBrowserPopup.show()
                    }
                ]
            }

            Repeater {
                model: root.appFilterMode !== "off" ? root.appFilterList : []

                delegate: SettingsRow {
                    id: appRow

                    required property string modelData
                    required property int index

                    title: appRow.modelData
                    iconName: root.appFilterMode === "block" ? "block" : "check_circle"

                    DActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "delete"
                        iconColor: Theme.error
                        Accessible.name: I18n.tr("Remove")
                        onClicked: root.removeApp(appRow.index)
                    }
                }
            }

            SettingsRow {
                visible: root.appFilterMode !== "off" && !root.appFilterList.length
                title: I18n.tr("No apps listed", "island settings: app filter with an empty list")
                titleColor: Theme.surfaceVariantText
            }
        }

        SettingsCard {
            iconName: "visibility_off"
            title: I18n.tr("Privacy", "notification settings card title")
            settingKey: "islandPrivacy"
            tags: ["island", "privacy", "hide", "message", "body", "title"]

            SettingsToggleRow {
                settingKey: "islandPrivacyTitleOnly"
                tags: ["island", "privacy", "hide", "message", "body", "title", "content"]
                resetStore: root.store
                resetKeys: ["islandPrivacyTitleOnly"]
                text: I18n.tr("Privacy mode")
                description: I18n.tr("Bubbles show the app and title, the message stays hidden", "island settings: privacy mode description")
                checked: root.store.setting("islandPrivacyTitleOnly")
                onToggled: checked => root.store.apply("islandPrivacyTitleOnly", checked)
            }
        }

        SettingsCard {
            iconName: "bedtime"
            title: I18n.tr("Quiet hours", "island settings: card of the quiet times")
            settingKey: "islandQuiet"
            tags: ["island", "quiet", "hours", "schedule", "night", "do not disturb", "dnd", "silence"]

            SettingsToggleRow {
                settingKey: "islandQuietFollowDnd"
                tags: ["island", "quiet", "do not disturb", "dnd", "follow"]
                resetStore: root.store
                resetKeys: ["islandQuietFollowDnd"]
                text: I18n.tr("Follow Do Not Disturb", "island settings: the island is quiet while DMS Do Not Disturb is on")
                description: I18n.tr("Quiet while Do Not Disturb is on in DMS", "island settings: follow Do Not Disturb description")
                checked: root.store.setting("islandQuietFollowDnd")
                onToggled: checked => root.store.apply("islandQuietFollowDnd", checked)
            }

            // Also resets the times: the time row has no reset arrow of its own.
            SettingsToggleRow {
                settingKey: "islandQuietHours"
                tags: ["island", "quiet", "hours", "schedule", "night", "start", "end", "time"]
                resetStore: root.store
                resetKeys: ["islandQuietHours", "islandQuietStart", "islandQuietEnd"]
                text: I18n.tr("Scheduled quiet hours", "island settings: quiet every day between two times")
                description: I18n.tr("Quiet every day between these times", "island settings: scheduled quiet hours description")
                checked: root.store.setting("islandQuietHours")
                onToggled: checked => root.store.apply("islandQuietHours", checked)
            }

            // Minutes after midnight; the range may cross midnight.
            SettingsTimeRow {
                id: quietTimes

                readonly property int startMinutes: root.store.setting("islandQuietStart")
                readonly property int endMinutes: root.store.setting("islandQuietEnd")

                visible: root.store.setting("islandQuietHours")
                is24Hour: SettingsData.use24HourClock
                startTitle: I18n.tr("Start")
                startHour: Math.floor(quietTimes.startMinutes / 60)
                startMinute: quietTimes.startMinutes % 60
                endTitle: I18n.tr("End")
                endHour: Math.floor(quietTimes.endMinutes / 60)
                endMinute: quietTimes.endMinutes % 60
                onStartChanged: (hour, minute) => root.store.apply("islandQuietStart", hour * 60 + minute)
                onEndChanged: (hour, minute) => root.store.apply("islandQuietEnd", hour * 60 + minute)
            }

            SettingsRow {
                subtitle: I18n.tr("While quiet, only bubbles allowed in Do Not Disturb get through", "island settings: quiet hours note")
            }

            SettingsNavRow {
                iconName: "do_not_disturb_on"
                title: I18n.tr("Allowed bubbles", "island settings: bubbles let through Do Not Disturb and quiet hours")
                hint: I18n.tr("Pick them in Each bubble", "island settings: allowed bubbles hint")
                trailingBadge: String(BubbleTable.countDnd(root.store.setting("islandBubbleTable") ?? ({})))
                onClicked: keyboard => {
                    SettingsUiState.islandBubbleFilter = "dnd";
                    root.parentModal?.navigateTo("island_bubble_table", keyboard);
                }
            }
        }
    }

    AppBrowserPopup {
        id: appBrowserPopup
        appsModel: root.desktopApps
        parentModal: root.parentModal
        onAppSelected: appId => root.addApp(appId)
    }
}
