import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/IslandCode2fa.js" as Code

// One-time code bubble's card (source "code2fa", IslandCode2faSource): the code, centered, stays hidden (••• •••) until
// the card is hovered; Copy at the bottom (the kit's copy feedback); once copied, its liquid drains over the 30 s before
// the code leaves the clipboard.
BubbleCardBase {
    id: card

    readonly property var source: card.bubble?.code2fa ?? null
    // Kept as the card folds: the source empties its code the moment the code leaves.
    property string code: ""
    Binding on code {
        value: card.source?.entry?.code ?? ""
        when: (card.source?.entry?.code ?? "") !== ""
        restoreMode: Binding.RestoreNone
    }
    property bool copied: false
    Binding on copied {
        value: card.source?.copied ?? false
        when: !!card.source?.entry
        restoreMode: Binding.RestoreNone
    }

    HoverHandler {
        id: hover
    }

    IslandCodeDigits {
        id: digits

        readonly property bool sharing: card.source?.sharing ?? false

        width: parent.width
        text: Code.shown(card.code, hover.hovered, sharing)
        pixelSize: Theme.fontSizeXLarge
        Accessible.role: Accessible.StaticText
        Accessible.name: sharing ? I18n.tr("Hidden code, the screen is shared", "island 2FA code bubble: the code stays masked during a screen share") : hover.hovered ? Code.grouped(card.code) : I18n.tr("Hidden code, hover to show it", "island 2FA code bubble: the masked code")
    }

    BubbleActions {
        BubbleAction {
            id: copyButton

            role: "primary"
            iconName: "content_copy"
            text: I18n.tr("Copy", "island 2FA code bubble: copy the code")
            feedbackText: I18n.tr("Copied · cleared in 30 s", "island 2FA code bubble: the code is on the clipboard, wiped 30 s later")
            activeFocusOnTab: true
            keepFeedback: card.copied
            Accessible.name: card.copied ? I18n.tr("Copied, cleared in 30 seconds", "island 2FA code bubble: screen reader") : text
            onClicked: {
                card.source?.copy();
                copyButton.flash(true);
                digits.hop();
            }
        }
    }
}
