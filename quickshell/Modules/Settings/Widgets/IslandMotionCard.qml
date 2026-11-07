import QtQuick
import qs.Common

SettingsCard {
    id: root

    required property var store
    property string keyPrefix: "island"

    iconName: "animation"
    title: I18n.tr("Spring", "island settings: spring motion card title")
    settingKey: root.keyPrefix + "Motion"
    tags: ["island", "motion", "spring", "animation"]

    SettingsNoteRow {
        visible: SettingsData.reduceMotion
        noteIconName: "info"
        tint: Theme.surfaceVariantText
        tintBackground: Theme.surfaceVariantAlpha
        text: I18n.tr("Reduce motion is on, so the island skips the spring", "island settings: spring card note while reduce motion is on")
    }

    SettingsSliderRow {
        settingKey: root.keyPrefix + "SpringStiffness"
        tags: ["island", "motion", "spring", "stiffness", "animation"]
        resetStore: root.store
        resetKeys: ["islandSpringStiffness"]
        text: I18n.tr("Stiffness", "island settings: spring stiffness slider")
        description: I18n.tr("How fast the island snaps into shape", "island settings: spring stiffness description")
        unit: ""
        minimum: 100
        maximum: 1200
        step: 10
        value: Math.round(root.store.setting("islandSpringStiffness"))
        enabled: !SettingsData.reduceMotion
        onSliderDragFinished: finalValue => root.store.apply("islandSpringStiffness", finalValue)
    }

    SettingsSliderRow {
        settingKey: root.keyPrefix + "SpringDamping"
        tags: ["island", "motion", "spring", "damping", "bounce", "animation"]
        resetStore: root.store
        resetKeys: ["islandSpringDamping"]
        text: I18n.tr("Damping", "island settings: spring damping slider")
        description: I18n.tr("How quickly the bounce settles. Lower bounces more", "island settings: spring damping description")
        unit: ""
        minimum: 10
        maximum: 100
        step: 1
        value: Math.round(root.store.setting("islandSpringDamping"))
        enabled: !SettingsData.reduceMotion
        onSliderDragFinished: finalValue => root.store.apply("islandSpringDamping", finalValue)
    }

    SettingsSliderRow {
        settingKey: root.keyPrefix + "SpringMass"
        tags: ["island", "motion", "spring", "mass", "inertia", "animation"]
        resetStore: root.store
        resetKeys: ["islandSpringMass"]
        text: I18n.tr("Mass", "island settings: spring mass slider")
        description: I18n.tr("How heavy the island feels. Higher is slower and swings further", "island settings: spring mass description")
        minimum: 25
        maximum: 300
        step: 5
        unit: ""
        decimals: 2
        value: Math.round(root.store.setting("islandSpringMass") * 100)
        enabled: !SettingsData.reduceMotion
        onSliderDragFinished: finalValue => root.store.apply("islandSpringMass", finalValue / 100)
    }
}
