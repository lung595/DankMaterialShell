import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Do-not-disturb bubble's open card (kind "dnd"): quick durations on SessionData, like the control center's DND detail,
// and the do-not-disturb toggle in the bottom row.
BubbleCardBase {
    id: card

    // Same "tomorrow" as the control center's "Until 8 AM" preset.
    function minutesUntilTomorrowMorning() {
        const now = new Date();
        const target = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 8, 0, 0, 0);
        return Math.max(1, Math.round((target.getTime() - now.getTime()) / 60000));
    }

    StyledText {
        width: parent.width
        visible: SettingsData.notificationDndAllowCritical
        text: I18n.tr("Calls and critical notifications still come through", "island do-not-disturb card: urgent notifications bypass")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    DButtonGroup {
        width: parent.width
        fillWidth: true
        checkEnabled: false
        Accessible.role: Accessible.Grouping
        Accessible.name: I18n.tr("Do not disturb")
        model: [
            {
                "text": I18n.tr("%1 min", "short duration chip, %1 is a number of minutes").arg(30)
            },
            {
                "text": I18n.duration(3600)
            },
            {
                "text": I18n.tr("Tomorrow", "island do-not-disturb card: until tomorrow morning")
            }
        ]
        // The durations leave nothing to mark: the toggle below shows the state.
        currentIndex: -1
        onSelectionChanged: (index, selected) => {
            if (selected)
                SessionData.setDoNotDisturb(true, [30, 60, card.minutesUntilTomorrowMorning()][index]);
        }
    }

    actions: [
        BubbleAction {
            toggle: true
            isOn: SessionData.doNotDisturb
            iconName: "notifications_off"
            text: I18n.tr("Do not disturb")
            activeFocusOnTab: true
            onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb, 0)
        }
    ]
}
