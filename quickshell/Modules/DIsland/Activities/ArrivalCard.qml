pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit
import "../../../Common/IslandArrival.js" as Arrival
import "../../../Common/IslandKit.js" as Kit

// The island's card while infos arrive: the shown info rolls over the last one sideways, page dots top right with the
// countdown dot. Sized by the controller (arrivalBigTarget); the surface fades it in with the island's growth.
Item {
    id: root

    required property var controller
    required property var notificationModel
    property bool reducedMotion: false
    // The finger's way sideways while it drags the card.
    property real dragX: 0

    readonly property real pad: NotificationMetrics.cardPadding
    readonly property real reach: Theme.spacingXL * Arrival.rollReach
    readonly property int rollMs: root.reducedMotion ? 0 : Kit.beat("roll", Theme.currentAnimationBaseDuration)
    readonly property int rollOutMs: root.reducedMotion ? 0 : Kit.beat("rollOut", Theme.currentAnimationBaseDuration)

    width: root.controller.arrivalCardWidth
    height: root.controller.arrivalCardHeight

    // How far the island has grown into this card (IslandArrival.grow) and the compact face's places of the icon and
    // title: they fly from there on the island's spring while the compact face hands them over; the card's own lines
    // (detail, buttons, dots, close) come in late and leave first.
    property real grow: 1
    property real reveal: 0.35
    property var from: null
    readonly property var hand: Arrival.handover(root.grow, root.reveal)
    // While the card's own rows below (the buttons) are hidden, what is left sits in the middle of the card, then rises
    // to its place as they come in: the visible content stays centred in the island.
    readonly property real lift: (1 - root.hand.cardOwn) * (root.height / 2 - root.pad - NotificationMetrics.appIconSize / 2)
    readonly property var places: ({
            "icon": {
                "x": root.pad + NotificationMetrics.appIconSize / 2,
                "y": root.pad + NotificationMetrics.appIconSize / 2 + root.lift,
                "size": NotificationMetrics.appIconSize,
                "w": root.width,
                "h": root.height
            },
            "title": {
                "x": root.pad + NotificationMetrics.appIconSize + NotificationMetrics.iconSpacing,
                "y": incoming.titleCenter + root.lift,
                "size": NotificationMetrics.summarySize,
                "w": root.width,
                "h": root.height
            }
        })
    readonly property var iconFly: root.from && root.grow !== 1 ? Arrival.fly(root.places.icon, root.from.icon, 1 - root.grow) : null
    readonly property var titleFly: root.from && root.grow !== 1 ? Arrival.fly(root.places.title, root.from.title, 1 - root.grow) : null

    // An important info's rings reach this many times its icon, inside the card's padding.
    readonly property real ringReach: 1 + 2 * root.pad / NotificationMetrics.appIconSize
    // What its pages read of the roll and of the close button.
    readonly property bool rollVertical: roll.vertical
    readonly property real closeWidth: closeButton.width
    // The spring a ringing call's shape rocks back on (IslandAlertWave.spring), the wing's.
    property var ringSpring: null

    property var shownInfo: root.controller.arrivalCurrent
    property var leavingInfo: null
    readonly property int shownRevision: root.controller.arrivalShown
    Component.onCompleted: incoming.announce()
    onShownRevisionChanged: {
        const next = root.controller.arrivalCurrent;
        if (!next) {
            incoming.silence();
            return;
        }
        Qt.callLater(incoming.announce);
        const dir = root.controller.burst.dir;
        root.leavingInfo = dir !== 0 && root.shownInfo !== next ? root.shownInfo : null;
        root.shownInfo = next;
        if (!root.leavingInfo || root.rollMs <= 0) {
            roll.stop();
            incoming.shift = 0;
            incoming.opacity = 1;
            root.leavingInfo = null;
            return;
        }
        roll.dir = dir;
        roll.vertical = root.controller.burst.axis === "y";
        roll.restart();
    }

    ArrivalPage {
        id: outgoing

        card: root
        info: root.leavingInfo
        visible: !!root.leavingInfo
        enabled: false
    }

    ArrivalPage {
        id: incoming

        card: root
        info: root.shownInfo
        x: (roll.vertical ? 0 : incoming.shift) + root.dragX * Arrival.follow
    }

    ParallelAnimation {
        id: roll

        property int dir: 1
        property bool vertical: false

        onFinished: root.leavingInfo = null

        NumberAnimation {
            target: incoming
            property: "shift"
            from: roll.dir * root.reach
            to: 0
            duration: root.rollMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: incoming
            property: "opacity"
            from: 0
            to: 1
            duration: root.rollMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: outgoing
            property: "shift"
            from: 0
            to: -roll.dir * root.reach * Arrival.rollOutReach
            duration: root.rollOutMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: outgoing
            property: "opacity"
            from: 1
            to: 0
            duration: root.rollOutMs
            easing.type: Easing.InCubic
        }
    }

    // As on every open card (BubbleCardBase): closes it and the info goes.
    IslandButton {
        id: closeButton

        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: Math.round(incoming.titleCenter + root.lift - height / 2)
        opacity: root.hand.cardOwn
        role: "quiet"
        iconName: "close"
        buttonHeight: Theme.iconSize + Theme.spacingXS
        activeFocusOnTab: true
        Accessible.name: I18n.tr("Close", "island arrival card: close button, dismisses the info")
        onClicked: root.notificationModel.dismiss()
    }

    IslandPager {
        id: pager

        anchors {
            right: closeButton.left
            top: parent.top
            rightMargin: Theme.spacingXS
            topMargin: (root.pad - height) / 2
        }
        opacity: root.hand.cardOwn
        count: root.controller.arrivalCount
        index: root.controller.burst.index
        countdown: root.controller.arrivalPhase === "big" ? root.controller.countdown : null
        reducedMotion: root.reducedMotion
        onPicked: index => root.controller.arrivalGo(index)
    }
}
