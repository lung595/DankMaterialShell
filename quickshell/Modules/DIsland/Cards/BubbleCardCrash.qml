pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit

// Open card of an app that crashed (kind "frozen", told by systemd-coredump): the crash's mark on the header icon's
// corner, then Details and Relaunch with the end of the log above them.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property bool reducedMotion: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    property bool showDetails: false
    onBubbleChanged: card.showDetails = false

    function act(id) {
        if (id === "relaunch")
            AppCrashService.relaunch();
        card.dismissed(card.bubble);
    }

    // Over the header's icon box (BubbleCardBase: at the card's corner, appIconSize square).
    readonly property Item hero: Item {
        parent: card
        z: 2
        width: NotificationMetrics.appIconSize
        height: width

        IslandStatusBadge {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            name: "cancel"
            color: Theme.error
            Accessible.name: I18n.tr("Crashed", "island frozen bubble: the app stopped")
        }
    }

    // The end of the app's log, unfolding above the buttons.
    Rectangle {
        width: parent?.width ?? 0
        height: card.showDetails ? log.implicitHeight + 2 * Theme.spacingS : 0
        visible: height > 0.5
        clip: true
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        Behavior on height {
            enabled: !card.reducedMotion
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        StyledText {
            id: log

            x: Theme.spacingS
            y: Theme.spacingS
            width: parent.width - 2 * Theme.spacingS
            wrapMode: Text.WrapAnywhere
            font.family: Theme.monoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            text: card.bubble?.log ?? ""
        }
    }

    // A dialog's action row, the main one on the right.
    BubbleActions {
        layoutDirection: Qt.RightToLeft

        BubbleAction {
            role: "primary"
            iconName: "restart_alt"
            text: I18n.tr("Relaunch", "island frozen app card: action")
            onClicked: card.act("relaunch")
        }

        BubbleAction {
            toggle: true
            isOn: card.showDetails
            iconName: "description"
            text: I18n.tr("Details", "island frozen app card: action")
            onClicked: card.showDetails = !card.showDetails
        }
    }
}
