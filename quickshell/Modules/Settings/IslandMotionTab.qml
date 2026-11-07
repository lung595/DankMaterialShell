pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import "../../Common/IslandArrival.js" as Arrival

// How an info arrives (growth, bounce and tint per importance), how bubbles move, and the island's spring.
Item {
    id: root

    property var parentModal: null

    readonly property var bounceLabels: [I18n.tr("None", "island settings: arrival bounce option"), I18n.tr("Light", "island settings: arrival bounce option"), I18n.tr("Medium", "island settings: arrival bounce option"), I18n.tr("Strong", "island settings: arrival bounce option")]
    readonly property var tintLabels: [I18n.tr("None", "island settings: arrival tint option"), I18n.tr("Light", "island settings: arrival tint option"), I18n.tr("Normal", "island settings: arrival tint option"), I18n.tr("Strong", "island settings: arrival tint option")]

    function setTier(key, tier, name) {
        const list = (SettingsData[key] ?? []).slice();
        const defaults = key === "islandArrivalBounce" ? Arrival.defaultBounce : Arrival.defaultTint;
        for (let i = 0; i < 3; i++)
            list[i] = list[i] ?? defaults[i];
        list[tier] = name;
        SettingsData.set(key, list);
    }

    // One importance of the Bounce or Tint card; the card title says which.
    component TierRow: SettingsDropdownRow {
        id: row

        required property int tier
        // "islandArrivalBounce" or "islandArrivalTint"
        required property string key
        readonly property bool bounce: row.key === "islandArrivalBounce"
        readonly property var names: row.bounce ? Arrival.bounceNames : Arrival.tintNames
        readonly property var defaults: row.bounce ? Arrival.defaultBounce : Arrival.defaultTint
        readonly property string current: (SettingsData[row.key] ?? [])[row.tier] ?? row.defaults[row.tier]

        settingKey: "island" + (row.bounce ? "ArrivalBounce" : "ArrivalTint") + row.tier
        tags: ["island", "arrival", row.bounce ? "bounce" : "tint", row.bounce ? "spring" : "color"]
        text: island.tierLabels[row.tier]
        options: row.bounce ? root.bounceLabels : root.tintLabels
        currentValue: options[Math.max(0, row.names.indexOf(row.current))]
        onValueChanged: value => root.setTier(row.key, row.tier, row.names[options.indexOf(value)] ?? row.defaults[row.tier])
        // One slot of a shared list: the reset puts back this importance only.
        resetByKeys: false
        modified: row.current !== row.defaults[row.tier]
        onResetRequested: root.setTier(row.key, row.tier, row.defaults[row.tier])
    }

    IslandHubState {
        id: island
    }

    SettingsPage {
        SettingsCard {
            iconName: "animation"
            title: I18n.tr("Arrival", "island settings: card of how an info arrives")
            settingKey: "islandArrival"
            tags: ["island", "arrival", "notification", "animation", "style"]
            headerActions: IslandSharedBadge {}

            SettingsDropdownRow {
                readonly property var styleValues: Arrival.styles

                settingKey: "islandArrivalStyle"
                tags: ["island", "arrival", "notification", "animation", "style"]
                text: I18n.tr("Style", "island settings: how the island grows when an info arrives")
                description: {
                    switch (SettingsData.islandArrivalStyle) {
                    case "c":
                        return I18n.tr("The island swells, bounces and takes color, without a card", "island settings: arrival style description, bounce");
                    case "a":
                        return I18n.tr("The island swells once, the same for every importance, with no bounce and no color", "island settings: arrival style description, breath");
                    default:
                        return I18n.tr("The island opens a card with more detail, bounces and takes color, then folds to compact", "island settings: arrival style description");
                    }
                }
                options: [I18n.tr("Step and bounce", "island settings: arrival style option, a detailed card that bounces and takes colour"), I18n.tr("Bounce", "island settings: arrival style option, the island bounces and takes colour"), I18n.tr("Breath", "island settings: arrival style option, one quiet breath, no bounce, no colour")]
                currentValue: options[Math.max(0, styleValues.indexOf(SettingsData.islandArrivalStyle))]
                onValueChanged: value => SettingsData.set("islandArrivalStyle", styleValues[options.indexOf(value)] ?? "bc")
            }
        }

        // Breath has no bounce and no colour, so both cards step aside.
        SettingsCard {
            iconName: "sports_basketball"
            title: I18n.tr("Bounce", "island settings: card of the arrival bounce per importance")
            settingKey: "islandBounce"
            tags: ["island", "arrival", "bounce", "spring", "importance"]
            headerActions: IslandSharedBadge {}
            visible: SettingsData.islandArrivalStyle !== "a"

            TierRow {
                key: "islandArrivalBounce"
                tier: 0
            }
            TierRow {
                key: "islandArrivalBounce"
                tier: 1
            }
            TierRow {
                key: "islandArrivalBounce"
                tier: 2
            }
        }

        SettingsCard {
            iconName: "format_color_fill"
            title: I18n.tr("Tint", "island settings: card of the arrival tint per importance")
            settingKey: "islandTint"
            tags: ["island", "arrival", "tint", "color", "importance"]
            headerActions: IslandSharedBadge {}
            visible: SettingsData.islandArrivalStyle !== "a"

            TierRow {
                key: "islandArrivalTint"
                tier: 0
            }
            TierRow {
                key: "islandArrivalTint"
                tier: 1
            }
            TierRow {
                key: "islandArrivalTint"
                tier: 2
            }
        }

        // Bubble motion follows the shell's reduce-motion setting.
        SettingsCard {
            iconName: "motion_photos_on"
            title: I18n.tr("Bubble animation", "island settings: card of how bubbles move")
            settingKey: "islandAnimation"
            tags: ["island", "bubbles", "motion", "animation", "launcher", "level"]
            headerActions: IslandSharedBadge {}

            SettingsSliderRow {
                settingKey: "islandBubbleMotion"
                tags: ["island", "bubbles", "motion", "animation", "intensity", "bounce", "expressive"]
                text: I18n.tr("Motion intensity", "island settings: how much the bubbles lean, stretch and bounce")
                description: I18n.tr("How much the bubbles lean, stretch and bounce as they move", "island settings: bubble motion intensity description")
                unit: "%"
                minimum: 0
                maximum: 150
                step: 10
                value: SettingsData.islandBubbleMotion
                onSliderValueChanged: value => SettingsData.set("islandBubbleMotion", value)
            }

            SettingsDropdownRow {
                readonly property var dialValues: ["wave", "lean"]

                settingKey: "islandBubbleDialStyle"
                tags: ["island", "bubbles", "volume", "level", "animation", "wave", "lean"]
                text: I18n.tr("Level animation", "island settings: how a bubble moves while a level such as the volume is being set")
                options: [I18n.tr("Wave", "island settings: level animation option, the bubble fills like a liquid"), I18n.tr("Lean", "island settings: level animation option, the bubble tips and stretches")]
                currentValue: options[Math.max(0, dialValues.indexOf(SettingsData.islandBubbleDialStyle))]
                onValueChanged: value => SettingsData.set("islandBubbleDialStyle", dialValues[options.indexOf(value)] ?? "wave")
            }

            SettingsDropdownRow {
                readonly property var hopValues: ["jelly", "liquid", "pivot"]

                settingKey: "islandBubbleLauncherTransition"
                tags: ["island", "bubbles", "launcher", "transition", "animation", "jelly", "liquid", "pivot"]
                text: I18n.tr("Launcher transition", "island settings: how every bubble moves beside the open launcher")
                options: [I18n.tr("Jelly", "island settings: launcher transition option, the bubble wobbles as it moves"), I18n.tr("Liquid", "island settings: launcher transition option, the bubble splits at its icon, a thread snaps, a bridge merges the parts again"), I18n.tr("Pivot", "island settings: launcher transition option, the bubble turns a quarter round its icon")]
                currentValue: options[Math.max(0, hopValues.indexOf(SettingsData.islandBubbleLauncherTransition))]
                onValueChanged: value => SettingsData.set("islandBubbleLauncherTransition", hopValues[options.indexOf(value)] ?? "liquid")
            }
        }

        IslandMotionCard {
            store: island.store
        }
    }
}
