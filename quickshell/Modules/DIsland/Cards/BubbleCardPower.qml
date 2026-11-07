import QtQuick
import qs.Common
import "../../../Common/IslandActivities.js" as Activities
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit

// Power profile bubble's card (kind "powerprofile"): the header shows the new profile, the undo puts the previous one back
// while its live liquid drains (the wing drops the bubble after the same 4 s, IslandController.machineBubbleTimer).
BubbleCardBase {
    id: card

    actions: [
        IslandUndoButton {
            id: undo

            // Same window as IslandController's power profile bubble.
            countdownMs: Activities.undoTimeoutMs
            text: I18n.tr("Undo", "island power profile bubble: restore the previous profile")
            activeFocusOnTab: true
            Accessible.name: text
            Component.onCompleted: undo.start()
            onClicked: {
                // The restore must not pop the bubble again.
                SessionData.suppressOSDTemporarily();
                PowerProfileWatcher.applyProfile(PowerProfileWatcher.previousProfile);
                card.dismissed(card.bubble);
            }
        }
    ]
}
