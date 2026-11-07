import QtQuick
import qs.Common
import "../../../Common/IslandActivities.js" as Activities

// Kit category: undo with a countdown (Trash 5 s, screen layout, power, audio output).
// Undo for as long as the volume's live liquid drains (IslandLiquid, the same as the hold button's), then expired().
IslandButton {
    id: root

    property int countdownMs: Activities.undoTimeoutMs
    property real remaining: 0

    signal expired

    function start() {
        countdown.stop();
        root.remaining = 1;
        countdown.duration = root.countdownMs;
        countdown.start();
    }

    iconName: "undo"
    text: I18n.tr("Undo", "island undo button: revert the last action before its countdown runs out")
    // Reduced motion: the window still runs, the meter just does not drain.
    level: root.remaining > 0 ? (root.still ? 1 : root.remaining) : -1
    onClicked: {
        countdown.stop();
        root.remaining = 0;
    }

    NumberAnimation {
        id: countdown

        target: root
        property: "remaining"
        to: 0
        easing.type: Easing.Linear
        onFinished: {
            if (root.remaining <= 0)
                root.expired();
        }
    }
}
