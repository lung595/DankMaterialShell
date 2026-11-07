import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets

// Where a bar in island layout sits: its edge, how it is placed and the strip it keeps from windows.
Item {
    id: root

    property var parentModal: null

    readonly property bool selectedIslandFree: bar.selectedBarIsIsland && SettingsData.islandFreePlacement(bar.selectedBarConfig)
    readonly property bool selectedIslandDocked: bar.selectedBarIsIsland && !selectedIslandFree
    readonly property int placementIndex: !bar.islandSetting("islandFloating") ? 0 : (bar.islandSetting("islandPlacement") === "free" ? 2 : 1)

    // The bar rows below follow the bar selection, so it has to point at the hub's island.
    Component.onCompleted: SettingsUiState.selectIsland(SettingsUiState.islandHubSelection)

    BarSelectionState {
        id: bar
    }

    SettingsPage {
        SettingsCard {
            iconName: "vertical_align_center"
            title: I18n.tr("Position")
            settingKey: "islandGeneralPosition"
            tags: ["island", "position", "edge", "orientation", "top", "bottom", "left", "right"]

            SettingsButtonGroupRow {
                settingKey: "islandFreeOrientation"
                tags: ["island", "free", "orientation", "horizontal", "vertical"]
                visible: root.selectedIslandFree
                text: I18n.tr("Orientation", "island settings: horizontal or vertical row for a free island")
                model: [I18n.tr("Horizontal", "island settings: free island orientation"), I18n.tr("Vertical", "island settings: free island orientation")]
                currentIndex: SettingsData.islandVertical(bar.selectedBarConfig) ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        position: index === 1 ? SettingsData.Position.Left : SettingsData.Position.Top
                    });
                }
            }

            SettingsLayoutPicker {
                edgePlacement: true
                visible: !root.selectedIslandFree
                choices: [SettingsData.Position.Top, SettingsData.Position.Bottom, SettingsData.Position.Left, SettingsData.Position.Right].map(position => ({
                            key: String(position),
                            label: bar.positionLabel(position),
                            enabled: bar.positionChoices.includes(position)
                        }))
                selectedKey: String(bar.selectedBarConfig?.position ?? SettingsData.Position.Top)
                onSelected: key => {
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        position: Number(key)
                    });
                    bar.notifyHorizontalBarChange();
                }
            }
        }

        SettingsCard {
            iconName: "open_with"
            title: I18n.tr("Placement", "island settings: docked, overlay or floating placement row")
            settingKey: "islandGeneralPlacement"
            tags: ["island", "placement", "docked", "overlay", "floating", "notch", "pill", "gap", "offset", "reserved"]

            SettingsButtonGroupRow {
                settingKey: "islandPlacement"
                tags: ["island", "placement", "docked", "overlay", "floating", "float", "free", "anywhere", "edge", "drag", "exclusive", "reserve"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandFloating", "islandPlacement"]
                text: I18n.tr("Mode", "island settings: docked, overlay or floating placement row")
                description: I18n.tr("Docked keeps windows out of its strip, Overlay floats over them, Floating goes anywhere", "island settings: placement row description")
                model: [I18n.tr("Docked", "island settings: island reserves its edge strip"), I18n.tr("Overlay", "island settings: island floats over windows along its edge without reserving space"), I18n.tr("Floating", "island settings: island can be dragged anywhere on the display")]
                currentIndex: root.placementIndex
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    const patch = {
                        islandFloating: index > 0
                    };
                    if (index > 0)
                        patch.islandPlacement = index === 2 ? "free" : "edge";
                    SettingsData.updateBarConfig(bar.selectedBarId, patch);
                    bar.notifyHorizontalBarChange();
                }
            }

            SettingsRow {
                settingKey: "islandNotch"
                tags: ["island", "notch", "pill", "shape", "style", "flush", "attached", "edge", "corners", "macbook"]
                title: I18n.tr("Style")
                visible: root.selectedIslandDocked
                resetStore: bar
                resetKeys: ["islandNotch"]

                body: SettingsLayoutPicker {
                    islandShape: true
                    choices: [
                        {
                            key: "pill",
                            label: I18n.tr("Pill")
                        },
                        {
                            key: "notch",
                            label: I18n.tr("Notch", "island style option, the island is fused to the screen edge like a notch")
                        }
                    ]
                    selectedKey: bar.islandSetting("islandNotch") ? "notch" : "pill"
                    onSelected: key => bar.apply("islandNotch", key === "notch")
                }
            }

            SettingsRow {
                visible: root.selectedIslandFree
                body: StyledText {
                    width: parent.width
                    text: I18n.tr("Drag to move, click to open activities", "island settings: free placement hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            SettingsSliderRow {
                settingKey: "islandFreeEdgeMargin"
                tags: ["island", "free", "edge", "margin", "gap"]
                visible: root.selectedIslandFree
                resetStore: bar
                resetKeys: ["islandFreeEdgeMargin"]
                text: I18n.tr("Edge margin", "island settings: gap kept from the display edge")
                unit: "px"
                minimum: 0
                maximum: 64
                step: 1
                value: bar.islandSetting("islandFreeEdgeMargin")
                onSliderDragFinished: value => bar.apply("islandFreeEdgeMargin", value)
            }

            SettingsSliderRow {
                settingKey: "islandOuterGap"
                tags: ["island", "placement", "gap", "top", "margin"]
                visible: root.selectedIslandDocked && !bar.islandSetting("islandNotch")
                resetStore: bar
                resetKeys: ["islandOuterGap"]
                text: I18n.tr("Outer gap", "island settings: gap between screen edge and island")
                unit: "px"
                minimum: 0
                maximum: 48
                step: 1
                value: bar.islandSetting("islandOuterGap")
                onSliderDragFinished: value => bar.apply("islandOuterGap", value)
            }

            SettingsSliderRow {
                settingKey: "islandAlongOffset"
                tags: ["island", "placement", "horizontal", "vertical", "offset", "center"]
                visible: root.selectedIslandDocked
                resetStore: bar
                resetKeys: ["islandAlongOffset"]
                text: bar.selectedBarIsVertical ? I18n.tr("Vertical offset", "island settings: vertical offset slider") : I18n.tr("Horizontal offset", "island settings: horizontal offset slider")
                unit: "px"
                minimum: -600
                maximum: 600
                step: 1
                value: bar.islandSetting("islandAlongOffset")
                onSliderDragFinished: value => bar.apply("islandAlongOffset", value)
            }

            SettingsSliderRow {
                settingKey: "islandReserveThickness"
                tags: ["island", "placement", "reservation", "exclusive", "height", "width", "thickness"]
                visible: root.selectedIslandDocked
                resetStore: bar
                resetKeys: ["islandReserveThickness"]
                text: I18n.tr("Reserved space", "island settings: strip kept free of windows")
                description: I18n.tr("Windows stay out of this strip", "island settings: reserved space slider description")
                unit: "px"
                minimum: 24
                maximum: 128
                step: 1
                value: bar.islandSetting("islandReserveThickness")
                enabled: !bar.islandSetting("islandFloating")
                onSliderDragFinished: value => bar.apply("islandReserveThickness", value)
            }
        }
    }
}
