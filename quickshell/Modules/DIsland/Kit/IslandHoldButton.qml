import QtQuick
import qs.Common
import "../../../Common/IslandKit.js" as Kit

// Kit category: danger held 2 s (a real Hang up, Force quit, Cut the network, Disconnect SSH).
// Interior's hold-to-confirm on a still tile: a click does nothing; holding raises the volume's live liquid to the top in
// holdMs; released early it drains 2.5 times faster and the next press resumes from what is left.
IslandButton {
    id: root

    property int holdMs: 2000
    property real progress: 0

    signal confirmed
    // Let go before the end (a plain click among them): the card says how long to hold.
    signal letGoEarly

    role: "danger"
    sinks: false
    // Reduced motion keeps the delay (it is the guard) and shows the liquid full at once.
    level: root.still ? (root.progress > 0 ? 1 : 0) : root.progress
    Accessible.description: I18n.tr("Hold to confirm", "island kit: a destructive button that must be held")

    onDownChanged: {
        if (root.progress >= 1)
            return;
        drain.stop();
        fill.stop();
        if (root.down) {
            fill.duration = Kit.holdRemaining(root.progress, root.holdMs);
            fill.start();
            return;
        }
        drain.duration = Kit.drainTime(root.progress, root.holdMs);
        drain.start();
        root.letGoEarly();
    }
    onFeedbackChanged: {
        if (root.feedback === "")
            root.progress = 0;
    }

    NumberAnimation {
        id: fill

        target: root
        property: "progress"
        to: 1
        easing.type: Easing.Linear
        onFinished: {
            if (root.progress < 1)
                return;
            root.flash(true);
            root.confirmed();
        }
    }

    NumberAnimation {
        id: drain

        target: root
        property: "progress"
        to: 0
        easing.type: Easing.OutQuint
    }
}
