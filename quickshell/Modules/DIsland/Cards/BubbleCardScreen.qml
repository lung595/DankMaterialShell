import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit

// Screen plugged bubble's open card (kind "display"). Asking: the three layouts as chips (extend, duplicate, only this
// one) and, in the bottom row, Extend with the kit's live liquid draining until the source extends by itself. Applied (a
// kept choice): that layout and Undo, draining until the source keeps it.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var source: card.bubble?.screenSource ?? null
    readonly property bool asking: card.source?.phase === "ask"
    readonly property string phase: card.source?.phase ?? ""
    readonly property var layouts: [
        {
            "id": "extend",
            "text": I18n.tr("Extend", "island screen bubble: one desktop across both screens")
        },
        {
            "id": "duplicate",
            "text": I18n.tr("Same place", "island screen bubble: the new screen put where the other one is (niri cannot mirror)")
        },
        {
            "id": "only",
            "text": I18n.tr("Only this one", "island screen bubble: the new screen alone")
        }
    ]

    // Started by hand once the source is known: a bound countdown may still be 0 when the card completes.
    function runFuse() {
        fuse.countdownMs = card.source?.waitMs ?? 0;
        if (card.phase !== "")
            fuse.start();
    }
    onPhaseChanged: card.runFuse()
    Component.onCompleted: card.runFuse()

    DButtonGroup {
        width: parent.width
        fillWidth: true
        checkEnabled: false
        // Three labels side by side: the small chips keep "Only this one" whole at the card's fixed width.
        size: "small"
        enabled: card.asking
        Accessible.role: Accessible.Grouping
        Accessible.name: I18n.tr("Screen layout", "island screen bubble: layout choice")
        model: card.layouts
        currentIndex: card.asking ? -1 : card.layouts.findIndex(l => l.id === card.source?.choice)
        onSelectionChanged: (index, selected) => {
            if (selected && card.asking)
                card.source.choose(card.layouts[index].id, true);
        }
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: card.asking ? I18n.tr("Extends by itself in %1 s", "island screen bubble: seconds before the default").arg(Math.round((card.source?.waitMs ?? 0) / 1000)) : I18n.tr("Kept for this screen", "island screen bubble: the applied layout was remembered")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    actions: [
        IslandUndoButton {
            id: fuse

            role: card.asking ? "primary" : "plain"
            iconName: card.asking ? "width_full" : "undo"
            text: card.asking ? I18n.tr("Extend", "island screen bubble: one desktop across both screens") : I18n.tr("Undo")
            activeFocusOnTab: true
            onClicked: card.asking ? card.source.choose("extend", true) : card.source.undo()
        }
    ]
}
