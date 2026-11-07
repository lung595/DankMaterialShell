import QtQuick
import qs.Common

// A bubble's level gauge blinking a few times (low peripheral, 15 % then 5 %): value is the gauge's opacity factor,
// 1 at rest. One finite run each time it turns on or its level moves; reduced motion keeps it lit.
QtObject {
    id: root

    property bool on: false
    property real level: -1
    property real value: 1

    readonly property bool reduced: SettingsData.reduceMotion || SettingsData.animationDuration <= 0

    function flash() {
        root.pulse.stop();
        root.value = 1;
        if (root.on && root.level >= 0 && !root.reduced)
            root.pulse.start();
    }
    onOnChanged: root.flash()
    onLevelChanged: root.flash()

    property SequentialAnimation pulse: SequentialAnimation {
        loops: 3
        onStopped: root.value = 1

        NumberAnimation {
            target: root
            property: "value"
            to: 0.15
            duration: Theme.mediumDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "value"
            to: 1
            duration: Theme.mediumDuration
            easing.type: Easing.InOutQuad
        }
    }
}
