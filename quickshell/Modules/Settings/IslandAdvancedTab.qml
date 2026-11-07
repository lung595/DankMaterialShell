import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

// Which layer a bar island lives on, and what may cover a fullscreen window.
Item {
    id: root

    property var parentModal: null
    property alias store: island.store
    readonly property bool hosted: island.hosted
    readonly property bool isDot: island.isDot

    // The layer row follows the bar selection, so it has to point at the hub's island.
    Component.onCompleted: SettingsUiState.selectIsland(SettingsUiState.islandHubSelection)

    IslandHubState {
        id: island
    }

    BarSelectionState {
        id: bar
    }

    SettingsPage {
        SettingsCard {
            iconName: "layers"
            title: I18n.tr("Layers", "noun plural, dock settings card for overlay layer and fullscreen options")
            settingKey: "islandLayers"
            tags: ["island", "advanced", "overlay", "layer", "fullscreen"]

            SettingsToggleRow {
                settingKey: "islandUseOverlayLayer"
                tags: ["island", "fullscreen", "overlay", "layer"]
                visible: bar.selectedBarIsIsland && !bar.selectedBarFrameStyled
                text: I18n.tr("Use overlay layer")
                description: I18n.tr("The island lives above fullscreen windows", "island settings: overlay layer toggle description")
                checked: bar.islandSetting("islandUseOverlayLayer")
                onToggled: checked => bar.apply("islandUseOverlayLayer", checked)
            }

            // A hosted island keeps its bar's layer, a dot and "Use overlay layer" already ride the overlay layer.
            SettingsToggleRow {
                settingKey: "islandOverlayOnRequest"
                tags: ["island", "fullscreen", "overlay", "layer", "polkit", "authentication", "plugin"]
                visible: !root.hosted && !root.isDot && !root.store.setting("islandUseOverlayLayer")
                text: I18n.tr("Show requests over fullscreen", "island settings: overlay layer during a fullscreen request toggle")
                description: I18n.tr("Authentication prompts and plugins that ask for it stay visible above fullscreen windows", "island settings: overlay layer during a fullscreen request toggle description")
                checked: root.store.setting("islandOverlayOnRequest")
                onToggled: checked => root.store.apply("islandOverlayOnRequest", checked)
            }
        }
    }
}
