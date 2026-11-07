import QtQuick
import qs.Common
import qs.Modules.Notifications

// Copied bubble's card (source "copy", IslandCopySource), the same in its wing and in the island: the copy's kind as the
// header icon, the title always "Copied!", what was copied under it (its first line, a secret masked, or the file's
// name); a copied image shows its own picture, round, at the header's end instead.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property bool pictured: (card.bubble?.thumb ?? "") !== ""

    headerEndRoom: card.pictured ? NotificationMetrics.appIconSize + Theme.spacingXS : 0

    // Over the header's end, left of its close button (BubbleCardBase: icon box at the card's corner, appIconSize square).
    readonly property Item picture: BubbleCopyType {
        parent: card
        z: 2
        visible: card.pictured
        face: card.bubble
        size: NotificationMetrics.appIconSize
        x: card.width - Theme.iconSize - Theme.spacingXS * 2 - width
        y: 0
    }
}
