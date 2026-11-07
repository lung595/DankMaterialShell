import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

// How the island and its bubbles look: the island's surface, the shape behind app logos, then the bubbles' shapes
// and outline.
Item {
    id: root

    property var parentModal: null
    property alias store: island.store
    readonly property bool hosted: island.hosted

    readonly property var paletteValues: ["default", "bright", "dim"]

    IslandHubState {
        id: island
    }

    SettingsPage {
        // A hosted island takes its surface from its bar.
        SettingsCard {
            iconName: "palette"
            title: I18n.tr("Surface")
            settingKey: "islandSurface"
            tags: ["island", "appearance", "surface", "palette", "contrast"]
            visible: !root.hosted

            SettingsButtonGroupRow {
                settingKey: "islandPalette"
                tags: ["island", "appearance", "palette", "surface", "bright", "dim"]
                resetStore: root.store
                resetKeys: ["islandPalette"]
                text: I18n.tr("Palette", "island settings: surface tone choice")
                model: [I18n.tr("Default", "island settings: default surface tone"), I18n.tr("Bright", "island settings: bright surface tone"), I18n.tr("Dim", "island settings: dim surface tone")]
                values: root.paletteValues
                value: root.store.setting("islandPalette")
                fallbackValue: "default"
                onValueSelected: value => root.store.apply("islandPalette", value)
            }

            SettingsToggleRow {
                settingKey: "islandHighContrast"
                tags: ["island", "appearance", "contrast", "accessibility", "outline"]
                resetStore: root.store
                resetKeys: ["islandHighContrast"]
                text: I18n.tr("High contrast", "island settings: high contrast toggle")
                checked: root.store.setting("islandHighContrast")
                onToggled: checked => root.store.apply("islandHighContrast", checked)
            }
        }

        SettingsCard {
            iconName: "apps"
            title: I18n.tr("Logos", "island settings: card of the shape behind app logos")
            settingKey: "islandLogos"
            tags: ["island", "logos", "logo", "icon", "app", "shape", "background", "material"]

            SettingsButtonGroupRow {
                settingKey: "islandLogoShapeTone"
                tags: ["island", "logo", "icon", "background", "shape", "tone", "dark", "light", "contrast"]
                resetStore: root.store
                resetKeys: ["islandLogoShapeTone"]
                text: I18n.tr("Logo background", "island settings: tone of the shape behind app logos")
                description: I18n.tr("The shape behind app logos. Auto picks the tone that stands out from each logo", "island settings: logo background description")
                model: [I18n.tr("Auto", "island settings: logo background, the tone that contrasts with the logo"), I18n.tr("Dark", "island settings: logo background, always dark"), I18n.tr("Light", "island settings: logo background, always light"), I18n.tr("None", "island settings: logo background, no shape")]
                values: ["auto", "dark", "light", "none"]
                value: root.store.setting("islandLogoShapeTone")
                fallbackValue: "auto"
                onValueSelected: value => root.store.apply("islandLogoShapeTone", value)
            }

            SettingsRow {
                settingKey: "islandLogoShapeForm"
                tags: ["island", "logo", "icon", "shape", "material", "cycle", "cookie", "circle"]
                resetStore: root.store
                resetKeys: ["islandLogoShapeForm"]
                title: I18n.tr("Logo shape", "island settings: which Material shape sits behind app logos")
                subtitle: I18n.tr("Cycle changes the shape each time you click a bubble", "island settings: logo shape description")
                visible: root.store.setting("islandLogoShapeTone") !== "none"

                body: IslandLogoShapeGrid {
                    currentValue: root.store.setting("islandLogoShapeForm")
                    onSelected: value => root.store.apply("islandLogoShapeForm", value)
                }
            }
        }

        SettingsCard {
            iconName: "category"
            title: I18n.tr("Bubble shapes", "island settings: card of the bubble corners and shapes")
            settingKey: "islandShapes"
            tags: ["island", "bubbles", "corners", "shape", "style", "tone", "color"]
            headerActions: IslandSharedBadge {}

            SettingsDropdownRow {
                readonly property var cornerValues: ["island", "round"]

                settingKey: "islandBubbleCorners"
                tags: ["island", "bubbles", "corners", "radius", "notch", "pill", "shape"]
                text: I18n.tr("Bubble corners", "island settings: the corner shape of the bubbles beside the island")
                description: I18n.tr("Match the island's style, Notch included, or stay round", "island settings: bubble corners description")
                options: [I18n.tr("Like the island", "island settings: bubble corners option, the island's radius and edge"), I18n.tr("Round", "island settings: bubble corners option, round pills")]
                currentValue: options[Math.max(0, cornerValues.indexOf(SettingsData.islandBubbleCorners))]
                onValueChanged: value => SettingsData.set("islandBubbleCorners", cornerValues[options.indexOf(value)] ?? "island")
            }

            SettingsDropdownRow {
                readonly property var styleValues: ["flat", "tonal"]

                settingKey: "islandBubbleShapeStyle"
                tags: ["island", "bubbles", "shape", "style", "color", "tonal"]
                text: I18n.tr("Shape style", "island settings: how the shape behind a bubble's icon is colored")
                options: [I18n.tr("Filled", "island settings: shape style option, the shape filled with the app type's color"), I18n.tr("Tone on tone", "island settings: shape style option, a shape a shade off the bubble, only the icon in color")]
                currentValue: options[Math.max(0, styleValues.indexOf(SettingsData.islandBubbleShapeStyle))]
                onValueChanged: value => SettingsData.set("islandBubbleShapeStyle", styleValues[options.indexOf(value)] ?? "flat")
            }

            SettingsDropdownRow {
                readonly property var toneValues: ["theme"].concat(Theme.availableMatugenSchemes.map(s => s.value))

                settingKey: "islandBubbleShapeTone"
                tags: ["island", "bubbles", "shape", "tone", "color", "scheme", "matugen"]
                text: I18n.tr("Shape tone", "island settings: which color scheme the bubble shapes take their colors from")
                description: I18n.tr("Colors per app type from a color scheme of your wallpaper", "island settings: shape tone description")
                options: [I18n.tr("Theme colors", "island settings: shape tone option, the theme's own colors")].concat(Theme.availableMatugenSchemes.map(s => s.label))
                currentValue: options[Math.max(0, toneValues.indexOf(SettingsData.islandBubbleShapeTone))]
                onValueChanged: value => SettingsData.set("islandBubbleShapeTone", toneValues[options.indexOf(value)] ?? "theme")
            }
        }

        SettingsCard {
            iconName: "border_style"
            title: I18n.tr("Outline", "island settings: card of the line around bubbles")
            settingKey: "islandOutline"
            tags: ["island", "bubbles", "outline", "border", "stroke"]
            headerActions: IslandSharedBadge {}

            SettingsToggleRow {
                settingKey: "islandBubbleOutline"
                tags: ["island", "bubbles", "outline", "border", "stroke", "color"]
                text: I18n.tr("Outline the bubbles", "island settings: draw a colored line around the bubbles")
                description: I18n.tr("A thin line around the bubbles beside the island", "island settings: bubble outline description")
                checked: SettingsData.islandBubbleOutline
                onToggled: checked => SettingsData.set("islandBubbleOutline", checked)
            }

            SettingsSliderRow {
                settingKey: "islandBubbleOutlineWidth"
                tags: ["island", "bubbles", "outline", "border", "width", "thickness"]
                text: I18n.tr("Width", "island settings: bubble outline thickness slider")
                unit: "px"
                minimum: 1
                maximum: 4
                step: 1
                value: SettingsData.islandBubbleOutlineWidth
                visible: SettingsData.islandBubbleOutline
                onSliderValueChanged: value => SettingsData.set("islandBubbleOutlineWidth", value)
            }

            SettingsSliderRow {
                settingKey: "islandBubbleOutlineOpacity"
                tags: ["island", "bubbles", "outline", "border", "opacity", "transparency"]
                text: I18n.tr("Opacity", "island settings: bubble outline opacity slider")
                unit: "%"
                minimum: 10
                maximum: 100
                step: 5
                value: SettingsData.islandBubbleOutlineOpacity
                visible: SettingsData.islandBubbleOutline
                onSliderValueChanged: value => SettingsData.set("islandBubbleOutlineOpacity", value)
            }

            SettingsDropdownRow {
                readonly property var colorValues: ["type", "accent"]

                settingKey: "islandBubbleOutlineColor"
                tags: ["island", "bubbles", "outline", "border", "color", "accent"]
                text: I18n.tr("Color", "island settings: bubble outline color dropdown")
                options: [I18n.tr("Color of the app type", "island settings: bubble outline color option, the tone of messages, system, media or alerts"), I18n.tr("Theme accent", "island settings: bubble outline color option, the theme's accent")]
                currentValue: options[Math.max(0, colorValues.indexOf(SettingsData.islandBubbleOutlineColor))]
                visible: SettingsData.islandBubbleOutline
                onValueChanged: value => SettingsData.set("islandBubbleOutlineColor", colorValues[options.indexOf(value)] ?? "type")
            }
        }
    }
}
