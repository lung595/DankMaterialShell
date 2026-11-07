import QtQuick
import qs.Modules.DIsland.Kit

// Kit category: every card button. The cards' name for the kit's one button (Kit/IslandButton): its look, motion and
// feedback live there. role says what the action means: "plain" (a secondary tile), "primary", "danger", "quiet".
// Inside a BubbleActions row it takes its weight's share of the width.
IslandButton {
    role: "plain"
    // A click leaves the keyboard to the card (arrows, Space, Delete): a focused button would take Space as its click.
    focusPolicy: Qt.TabFocus
}
