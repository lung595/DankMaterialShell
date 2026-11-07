import QtQuick
import qs.Common

// The widgets beside a bar island; the custom radius also shapes the notch.
SettingsCard {
    id: root

    required property var store
    property bool free: false
    readonly property var satellitePositionValues: ["island", "edges"]
    readonly property bool notch: !root.free && root.store.setting("islandNotch")

    iconName: "widgets"
    title: I18n.tr("Satellites", "island settings: satellite widgets card title")
    settingKey: "islandSatellites"
    collapsible: true
    expanded: true

    SettingsToggleRow {
        settingKey: "islandSatellitesEnabled"
        tags: ["island", "satellite", "widgets", "left", "right"]
        text: I18n.tr("Show", "island settings: satellite widgets toggle")
        checked: root.store.setting("islandSatellitesEnabled")
        onToggled: checked => root.store.apply("islandSatellitesEnabled", checked)
    }

    SettingsButtonGroupRow {
        settingKey: "islandSatellitePosition"
        tags: ["island", "satellite", "widgets", "position", "edges", "center"]
        resetStore: root.store
        resetKeys: ["islandSatellitePosition"]
        text: I18n.tr("Position", "island settings: position card title")
        model: [I18n.tr("Near island", "island settings: satellites hug the island"), I18n.tr("Display edges", "island settings: satellites sit at screen edges")]
        values: root.satellitePositionValues
        value: root.store.setting("islandSatellitePosition")
        fallbackValue: "island"
        enabled: root.store.setting("islandSatellitesEnabled")
        onValueSelected: value => root.store.apply("islandSatellitePosition", value)
    }

    SettingsToggleRow {
        settingKey: "islandSatelliteBackground"
        tags: ["island", "satellite", "widgets", "background", "chrome"]
        text: I18n.tr("Background", "island settings: satellite background toggle")
        checked: root.store.setting("islandSatelliteBackground")
        visible: root.store.setting("islandSatellitesEnabled")
        onToggled: checked => root.store.apply("islandSatelliteBackground", checked)
    }

    SettingsToggleRow {
        settingKey: "islandSatelliteGothCorners"
        tags: ["island", "satellite", "goth", "corners", "wing", "sweep"]
        text: I18n.tr("Goth corners", "island settings: satellite goth corners toggle")
        checked: root.store.setting("islandSatelliteGothCorners")
        visible: root.store.setting("islandSatellitesEnabled")
        enabled: root.store.setting("islandSatelliteBackground")
        onToggled: checked => root.store.apply("islandSatelliteGothCorners", checked)
    }

    SettingsToggleSliderRow {
        resetStore: root.store
        settingKey: "islandGothCornerRadius"
        tags: ["island", "satellite", "notch", "goth", "corners", "radius", "sweep", "size"]
        valueKeys: ["gothCornerRadiusValue"]
        text: I18n.tr("Custom radius")
        checked: root.store.config?.gothCornerRadiusOverride ?? false
        unit: "px"
        minimum: 0
        maximum: 64
        step: 1
        value: root.store.config?.gothCornerRadiusValue ?? SettingsData.barConfigDefault("gothCornerRadiusValue")
        visible: root.store.setting("islandSatellitesEnabled") || root.notch
        enabled: (root.store.setting("islandSatelliteBackground") && root.store.setting("islandSatelliteGothCorners")) || root.notch
        onToggled: checked => root.store.apply("gothCornerRadiusOverride", checked)
        onSliderDragFinished: finalValue => root.store.apply("gothCornerRadiusValue", finalValue)
    }

    SettingsToggleSliderRow {
        resetStore: root.store
        settingKey: "islandSatelliteTransparency"
        tags: ["island", "satellite", "background", "opacity", "transparency", "blur", "override", "interface", "style"]
        valueKeys: ["islandSatelliteTransparency"]
        text: I18n.tr("Custom opacity", "island settings: satellite background opacity, instead of the interface style")
        description: I18n.tr("Set the background opacity here instead of following the interface style", "island settings: satellite background opacity description")
        checked: !root.store.setting("islandSatelliteFollowInterfaceStyle")
        minimum: 0
        maximum: 100
        step: 1
        value: Math.round(SettingsData.islandSatelliteTransparency(root.store.config) * 100)
        visible: root.store.setting("islandSatellitesEnabled")
        enabled: root.store.setting("islandSatelliteBackground")
        onToggled: checked => root.store.apply("islandSatelliteFollowInterfaceStyle", !checked)
        onSliderValueChanged: value => root.store.apply("islandSatelliteTransparency", value / 100)
    }

    SettingsSliderRow {
        settingKey: "islandSatelliteGap"
        tags: ["island", "satellite", "widgets", "gap", "spacing"]
        resetStore: root.store
        resetKeys: ["islandSatelliteGap"]
        text: I18n.tr("Gap", "island settings: satellite to island gap slider")
        unit: "px"
        minimum: 0
        maximum: 48
        step: 1
        value: root.store.setting("islandSatelliteGap")
        visible: root.store.setting("islandSatellitesEnabled")
        enabled: root.store.setting("islandSatellitePosition") !== "edges" || root.store.setting("islandSatelliteBackground")
        onSliderValueChanged: value => root.store.apply("islandSatelliteGap", value)
    }
}
