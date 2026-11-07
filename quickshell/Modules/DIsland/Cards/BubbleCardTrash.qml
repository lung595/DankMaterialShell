import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit

// Trash bubble's card (source "trash", IslandTrashSource): the header names the file (and how many went with it) while a
// page drops into the trash icon; Undo puts them back for as long as its liquid drains (the source's own Undo window).
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var trash: card.bubble?.trash ?? null
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    // 0 → 1: the page falls from above into the header's trash icon.
    property real fall: 1
    readonly property int count: card.bubble?.count ?? 0
    onCountChanged: card.drop()
    Component.onCompleted: card.drop()

    function drop() {
        dropAnim.stop();
        if (card.still) {
            card.fall = 1;
            return;
        }
        card.fall = 0;
        dropAnim.start();
    }
    NumberAnimation {
        id: dropAnim

        target: card
        property: "fall"
        to: 1
        duration: Theme.extraLongDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
    }

    // The page's fall into the bin, as shares of `fall`: it drops and shrinks until landAt, from liftShare of the icon
    // box above it; it fades out from fadeAt over fadeSpan.
    readonly property real landAt: 0.7
    readonly property real liftShare: 0.6
    readonly property real fadeAt: 0.55
    readonly property real fadeSpan: 0.2
    // Over the header's icon box (BubbleCardBase: at the card's corner, appIconSize square).
    readonly property Item page: DIcon {
        parent: card
        z: 2
        x: (NotificationMetrics.appIconSize - width) / 2
        y: (NotificationMetrics.appIconSize - height) / 2 - NotificationMetrics.appIconSize * card.liftShare * (1 - Math.min(1, card.fall / card.landAt))
        name: "draft"
        size: Theme.iconSizeSmall
        color: Theme.surfaceVariantText
        scale: 1 - 0.5 * Math.min(1, card.fall / card.landAt)
        opacity: 1 - Math.max(0, (card.fall - card.fadeAt) / card.fadeSpan)
        visible: opacity > 0.01
    }

    actions: [
        IslandUndoButton {
            // The source owns the window: the card only shows what is left of it (the card is rebuilt on each hover).
            remaining: card.trash?.left ?? 0
            text: I18n.tr("Undo", "island trash bubble: restore the deleted files")
            activeFocusOnTab: true
            Accessible.name: text
            onClicked: card.trash?.undo()
        }
    ]
}
