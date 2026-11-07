import QtQuick
import qs.Common
import "../../../Common/IslandActivities.js" as Activities
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit

// Audio output bubble's open card (kind "output"): the output before the switch and Undo, back to it, while the undo's
// live liquid drains (IslandController.undoTimeout). The header already shows the new output's name and icon.
BubbleCardBase {
    id: card

    readonly property var output: card.bubble?.output ?? null

    StyledText {
        width: parent.width
        visible: text !== ""
        text: card.output?.previous ? I18n.tr("Before: %1", "island audio output bubble: the output before the switch").arg(card.output.previous) : ""
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        elide: Text.ElideRight
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    actions: [
        IslandUndoButton {
            id: undo

            visible: card.output?.canUndo ?? false
            // Same window as IslandController.undoTimeout.
            countdownMs: Activities.undoTimeoutMs
            activeFocusOnTab: true
            Accessible.name: text
            Component.onCompleted: undo.start()
            onClicked: {
                card.output.undo();
                card.dismissed(card.bubble);
            }
        }
    ]
}
