pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandBubbleTable.js" as BubbleTable

// One family of the bubble table (System, Apps or Alerts): its time scale, then a row per bubble with its Do Not
// Disturb box, its Show switch and badges for its side, lifetime, importance and sound. A click opens the bubble editor.
SettingsCard {
    id: root

    required property var bubbles
    // "system", "apps" or "alerts"
    required property string family
    // The Each bubble page filter: "all", a family, or "dnd" for the bubbles let through Do Not Disturb
    required property string filter

    signal editRequested(string id)

    // Side, lifetime, importance, then the sound unless there is none; a changed value is tinted.
    function badgesFor(bubble, state) {
        const table = root.bubbles.table;
        const badges = [
            {
                text: root.bubbles.sideLabels[root.bubbles.sideValues.indexOf(state.side)],
                changed: BubbleTable.changed(table, bubble.id, "side")
            },
            {
                text: root.bubbles.lifeLabel(state.lifeMs > 0 ? state.lifeMs : state.defaultLifeMs),
                changed: BubbleTable.changed(table, bubble.id, "lifeMs")
            },
            {
                text: root.bubbles.tierLabels[state.tier],
                changed: BubbleTable.changed(table, bubble.id, "tier")
            }
        ];
        if (state.sound !== "none")
            badges.push({
                text: root.bubbles.soundLabels[root.bubbles.soundValues.indexOf(state.sound)],
                changed: BubbleTable.changed(table, bubble.id, "sound")
            });
        return badges;
    }

    visible: {
        if (root.filter === "dnd")
            return BubbleTable.rowsOf(root.family).some(bubble => root.bubbles.stateOf(bubble).dnd);
        return root.filter === "all" || root.filter === root.family;
    }

    // Stored as a factor (0.5 to 2); the slider works in tenths. The Do Not Disturb filter lists bubbles only.
    SettingsSliderRow {
        id: scaleRow

        readonly property string scaleKey: BubbleTable.scaleKeys[root.family]

        settingKey: scaleRow.scaleKey
        tags: ["island", "bubbles", "time", "scale", "duration", "lifetime", "speed"]
        resetStore: root.bubbles.store
        resetKeys: [scaleRow.scaleKey]
        text: I18n.tr("Time scale", "island settings: factor on the default lifetimes of a family of bubbles")
        description: I18n.tr("Stretches or shortens the default lifetimes of these bubbles", "island settings: time scale description")
        minimum: 5
        maximum: 20
        step: 1
        decimals: 1
        unit: "×"
        value: Math.round(root.bubbles.scaleFor(root.family) * 10)
        visible: root.filter !== "dnd"
        onSliderDragFinished: finalValue => root.bubbles.store.apply(scaleRow.scaleKey, finalValue / 10)
    }

    Repeater {
        // Count model: a write must not rebuild the row that holds the focus.
        model: BubbleTable.rowsOf(root.family).length

        delegate: SettingsRow {
            id: bubbleRow

            required property int index
            readonly property var bubble: BubbleTable.rowsOf(root.family)[index]
            readonly property var bubbleState: root.bubbles.stateOf(bubble)

            iconName: bubble.icon
            title: root.bubbles.labels[bubble.id]
            singleLineTitle: true
            titleColor: bubbleState.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            subtitle: bubble.locked ? I18n.tr("Always shown: needed to answer authentication requests", "island settings: why the authentication bubble cannot be turned off") : ""
            visible: root.filter !== "dnd" || bubbleState.dnd
            clickable: true
            onClicked: root.editRequested(bubble.id)
            resetByKeys: false
            modified: !!root.bubbles.table[bubble.id]
            onResetRequested: root.bubbles.resetBubble(bubble.id)

            DActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: bubbleRow.bubbleState.dnd ? "check_box" : "check_box_outline_blank"
                iconColor: !enabled ? Theme.withAlpha(Theme.surfaceText, 0.38) : bubbleRow.bubbleState.dnd ? Theme.primary : Theme.surfaceVariantText
                tooltipText: I18n.tr("Allow in Do Not Disturb")
                enabled: !bubbleRow.bubble.locked
                Accessible.role: Accessible.CheckBox
                Accessible.name: I18n.tr("Allow in Do Not Disturb")
                Accessible.checkable: true
                Accessible.checked: bubbleRow.bubbleState.dnd
                onClicked: root.bubbles.setField(bubbleRow.bubble.id, "dnd", !bubbleRow.bubbleState.dnd)
            }

            DToggle {
                anchors.verticalCenter: parent.verticalCenter
                hideText: true
                text: bubbleRow.title
                checked: bubbleRow.bubbleState.enabled
                enabled: !bubbleRow.bubble.locked
                onToggled: checked => root.bubbles.setShow(bubbleRow.bubble, checked)
            }

            body: Flow {
                width: parent.width
                spacing: Theme.spacingXS
                visible: bubbleRow.bubbleState.enabled

                Repeater {
                    model: root.badgesFor(bubbleRow.bubble, bubbleRow.bubbleState)

                    delegate: DBadge {
                        required property var modelData
                        text: modelData.text
                        color: modelData.changed ? Theme.primaryContainer : Theme.surfaceContainerHighest
                        textColor: modelData.changed ? Theme.onPrimaryContainer : Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
