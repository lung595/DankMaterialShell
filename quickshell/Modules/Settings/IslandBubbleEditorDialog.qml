pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/IslandBubbleTable.js" as BubbleTable

// One bubble of the island bubble table. Unlike the rule editor, every change is written at once, like the rest of
// the settings; Done only closes.
DDialog {
    id: root

    required property var bubbles
    property string bubbleId: ""
    readonly property var bubble: BubbleTable.row(root.bubbleId)
    readonly property var bubbleState: root.bubble ? root.bubbles.stateOf(root.bubble) : ({})
    readonly property bool locked: root.bubble?.locked === true
    // 0 is the default lifetime, then the Notifications > Timeouts choices.
    readonly property var lifeValues: [0].concat(root.bubble ? BubbleTable.lifeChoicesMs(root.bubble) : [])
    readonly property var lifeOptions: root.lifeValues.map((ms, index) => index === 0 ? I18n.tr("Default (%1)", "island bubble lifetime: the default choice, %1 is its real duration").arg(root.bubbles.lifeLabel(root.bubbleState.defaultLifeMs ?? 0)) : I18n.duration(ms / 1000))

    embedded: nativeWindow
    opened: nativeWindow
    maximumWidth: SettingsMetrics.formDialogWidth
    surfaceColor: Theme.hostSurface
    title: root.bubbles.labels[root.bubbleId] ?? ""

    function show(id) {
        bubbleId = id;
        opened = true;
        forceActiveFocus();
    }

    function write(field, value) {
        root.bubbles.setField(root.bubbleId, field, value);
    }

    actions: [
        DButton {
            text: I18n.tr("Reset to default")
            backgroundColor: "transparent"
            textColor: Theme.primary
            enabled: !!root.bubbles.table[root.bubbleId]
            onClicked: root.bubbles.resetBubble(root.bubbleId)
        },
        DButton {
            text: I18n.tr("Done", "island bubble editor: close button")
            onClicked: root.rejected()
        }
    ]

    SettingsCard {
        title: I18n.tr("Display", "island bubble editor: card of where the bubble shows")

        SettingsToggleRow {
            text: I18n.tr("Show", "island bubble editor: the bubble appears")
            checked: root.bubbleState.enabled === true
            enabled: !root.locked
            onToggled: checked => root.bubbles.setShow(root.bubble, checked)
        }

        SettingsToggleRow {
            text: I18n.tr("Allow in Do Not Disturb")
            checked: root.bubbleState.dnd === true
            enabled: !root.locked
            onToggled: checked => root.write("dnd", checked)
        }

        SettingsButtonGroupRow {
            text: I18n.tr("Side", "island bubble editor: left or right of the island")
            description: I18n.tr("System bubbles sit on the left, apps on the right", "island bubble editor: side description")
            model: root.bubbles.sideLabels
            values: root.bubbles.sideValues
            value: root.bubbleState.side
            onValueSelected: value => root.write("side", value)
        }
    }

    // Two cards, so the whole editor fits a 780 px window without scrolling.
    SettingsCard {
        title: I18n.tr("Timing and sound", "island bubble editor: card of importance, lifetime and sound")

        SettingsButtonGroupRow {
            text: I18n.tr("Importance", "island bubble editor: brief, normal or important")
            description: I18n.tr("Also sets the bounce, the tint and the default lifetime", "island bubble editor: importance description")
            model: root.bubbles.tierLabels
            values: [0, 1, 2]
            value: root.bubbleState.tier
            onValueSelected: value => root.write("tier", value)
        }

        SettingsDropdownRow {
            text: I18n.tr("Lifetime", "island bubble editor: how long the bubble stays")
            description: root.bubbleId === "eyes" ? I18n.tr("Follows Break length in Eye breaks", "island bubble editor: eye breaks lifetime description") : root.locked ? I18n.tr("Stays while the request waits", "island bubble editor: authentication lifetime description") : I18n.tr("Default follows the importance and the family time scale", "island bubble editor: lifetime description")
            enabled: !root.locked && root.bubble?.lockLife !== true
            options: root.lifeOptions
            currentValue: root.bubbleState.lifeMs > 0 ? I18n.duration(root.bubbleState.lifeMs / 1000) : root.lifeOptions[0]
            onValueChanged: value => root.write("lifeMs", root.lifeValues[root.lifeOptions.indexOf(value)] ?? 0)
        }

        SettingsDropdownRow {
            text: I18n.tr("Sound", "island bubble editor: sound played with the bubble")
            description: I18n.tr("Uses the sound theme from Sounds. Silent in Do Not Disturb", "island bubble editor: sound description")
            options: root.bubbles.soundLabels
            currentValue: root.bubbles.soundLabels[Math.max(0, root.bubbles.soundValues.indexOf(root.bubbleState.sound))]
            onValueChanged: value => root.write("sound", root.bubbles.soundValues[root.bubbles.soundLabels.indexOf(value)] ?? "none")
        }
    }
}
