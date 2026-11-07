pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/IslandBubbleTable.js" as BubbleTable

// Every bubble, one row each: side, lifetime, importance, sound and Do Not Disturb, filtered by family.
Item {
    id: root

    property var parentModal: null
    // "all", "system", "apps", "alerts" or "dnd" (only the bubbles let through Do Not Disturb). Opens on one family, the
    // chips acting as tabs: All is 41 rows.
    property string filter: "system"
    readonly property var filters: ["all", "system", "apps", "alerts", "dnd"]
    // A search hit opens the chip of its family card, so it never lands on a hidden card.
    readonly property var searchFamilies: ({
            "islandBubblesSystem": "system",
            "islandBubblesApps": "apps",
            "islandBubblesAlerts": "alerts"
        })
    property string editingBubble: ""

    function openEditor(id) {
        root.editingBubble = id;
        if (editorLoader.item)
            (editorLoader.item as IslandBubbleEditorDialog).show(id);
        else
            editorLoader.active = true;
    }

    // One-shot request from Notifications (its Allowed bubbles row opens this page on Do Not Disturb).
    function takeFilterRequest() {
        if (SettingsUiState.islandBubbleFilter === "")
            return;
        root.filter = SettingsUiState.islandBubbleFilter;
        SettingsUiState.islandBubbleFilter = "";
    }

    function takeSearchTarget() {
        const family = root.searchFamilies[SettingsSearchService.targetSection];
        if (family)
            root.filter = family;
    }

    // A search may have picked its target before this page loaded.
    Component.onCompleted: {
        root.takeFilterRequest();
        root.takeSearchTarget();
    }

    IslandHubState {
        id: island
    }

    IslandBubbleTableState {
        id: bubbleTable
        store: island.store
        tierLabels: island.tierLabels
    }

    Connections {
        target: SettingsUiState

        function onIslandBubbleFilterChanged() {
            root.takeFilterRequest();
        }
    }

    Connections {
        target: SettingsSearchService

        function onTargetSectionChanged() {
            root.takeSearchTarget();
        }
    }

    SettingsPage {
        // No title: the page is named after it.
        SettingsCard {
            settingKey: "islandBubbleTable"
            tags: ["island", "bubbles", "bubble", "table", "side", "lifetime", "importance", "sound", "do not disturb", "dnd"]

            SettingsRow {
                subtitle: I18n.tr("Click a bubble to change its side, lifetime, importance and sound. Changes apply right away, and picking a default value removes your change. Tick its box to let it through Do Not Disturb", "island settings: each bubble card intro")
            }

            SettingsNoteRow {
                paintBackground: false
                noteIconName: "info"
                tint: Theme.surfaceVariantText
                tintBackground: Theme.surfaceVariantAlpha
                text: I18n.tr("Importance also sets the bounce and tint. Durations already include the time scale", "island settings: each bubble card note")
            }

            SettingsRow {
                body: DFilterChips {
                    width: parent.width
                    model: [
                        {
                            label: I18n.tr("All"),
                            count: BubbleTable.rows.length
                        },
                        {
                            label: I18n.tr("System"),
                            count: BubbleTable.rowsOf("system").length
                        },
                        {
                            label: I18n.tr("Apps"),
                            count: BubbleTable.rowsOf("apps").length
                        },
                        {
                            label: I18n.tr("Alerts"),
                            count: BubbleTable.rowsOf("alerts").length
                        },
                        {
                            label: I18n.tr("Allowed in Do Not Disturb", "island settings: bubble table filter, bubbles let through Do Not Disturb"),
                            count: BubbleTable.countDnd(bubbleTable.table)
                        }
                    ]
                    showCounts: true
                    onSelectionChanged: index => root.filter = root.filters[index]

                    // A click sets the chips' own index; this keeps them on the filter when search or Notifications change it.
                    Binding on currentIndex {
                        value: root.filters.indexOf(root.filter)
                    }
                }
            }
        }

        IslandBubbleFamily {
            iconName: "memory"
            title: I18n.tr("System", "island settings: card of the system bubbles, left of the island")
            settingKey: "islandBubblesSystem"
            tags: ["island", "bubbles", "volume", "sound", "audio", "mic", "microphone", "input", "micmute", "mute", "brightness", "screen", "backlight", "output", "speaker", "headphones", "powerprofile", "power", "performance", "keepawake", "idle inhibitor", "caffeine", "network", "wifi", "openwifi", "portal", "hotspot", "dnd", "quiet", "capslock", "keyboard", "charging", "plug", "battery", "low", "periph", "bluetooth", "mouse", "headset", "gamepad", "display", "monitor", "disk", "storage", "space", "eyes", "rest", "shelf", "files", "drop", "time scale"]
            bubbles: bubbleTable
            family: "system"
            filter: root.filter
            onEditRequested: id => root.openEditor(id)
        }

        IslandBubbleFamily {
            iconName: "apps"
            title: I18n.tr("Apps", "island settings: card of the app bubbles, right of the island")
            settingKey: "islandBubblesApps"
            tags: ["island", "bubbles", "notification", "message", "progress", "transfer", "download", "copy", "extract", "torrent", "clipboard", "password", "secret", "trash", "undo", "reopen", "window", "frozen", "crash", "media", "music", "player", "call", "voice", "camera", "webcam", "privacy", "vpn", "tunnel", "ssh", "remote", "usb", "drive", "print", "printer", "plugin", "glance", "live", "time scale"]
            bubbles: bubbleTable
            family: "apps"
            filter: root.filter
            onEditRequested: id => root.openEditor(id)
        }

        IslandBubbleFamily {
            iconName: "warning"
            title: I18n.tr("Alerts", "island settings: card of the alert bubbles")
            settingKey: "islandBubblesAlerts"
            tags: ["island", "bubbles", "callincoming", "ring", "phone", "code2fa", "2fa", "otp", "code", "auth", "polkit", "password prompt", "urgent", "attention", "batterycritical", "battery", "critical", "weatheralert", "weather", "storm", "rain", "pluginalert", "plugin", "alert", "time scale"]
            bubbles: bubbleTable
            family: "alerts"
            filter: root.filter
            onEditRequested: id => root.openEditor(id)
        }
    }

    Loader {
        id: editorLoader
        parent: root.parentModal?.modalFocusScope ?? root
        anchors.fill: parent
        z: 100
        active: false
        onLoaded: (item as IslandBubbleEditorDialog).show(root.editingBubble)

        sourceComponent: IslandBubbleEditorDialog {
            id: editor

            bubbles: bubbleTable
            onRejected: editor.opened = false
            // Unloaded once its closing fade ends, like the rule editor.
            onActiveChanged: {
                if (!editor.active)
                    editorLoader.active = false;
            }
        }
    }
}
