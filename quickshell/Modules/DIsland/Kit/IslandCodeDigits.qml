import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandKit.js" as Kit

// Kit category: a one-time code shown digit by digit (same look as one mono text); hop() makes the digits jump one after
// the other, as if they left for the clipboard, and nothing moves between hops (K1). Reduced motion: no hop.
Item {
    id: root

    property string text: ""
    property real pixelSize: Theme.fontSizeMedium
    property color color: Theme.surfaceText

    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion

    function hop() {
        if (root.still)
            return;
        for (let i = 0; i < digits.count; i++)
            digits.itemAt(i).start(i * Kit.beat("hopStep", Theme.currentAnimationBaseDuration));
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            id: digits

            model: root.text.length

            StyledText {
                id: digit

                required property int index

                function start(delay) {
                    wait.interval = Math.max(1, delay);
                    wait.restart();
                }

                text: root.text.charAt(digit.index)
                font.family: Theme.monoFontFamily
                font.pixelSize: root.pixelSize
                font.weight: Theme.fontWeightMedium
                color: root.color
                y: -Math.sin(Math.PI * rise.value) * Kit.hopLift * Theme.spacingXS

                Timer {
                    id: wait

                    onTriggered: {
                        rise.snapTo(0);
                        rise.retarget(1);
                    }
                }

                SpringMotion {
                    id: rise

                    readonly property var spec: Kit.spring("cell", Theme.currentAnimationBaseDuration)
                    enabled: !root.still
                    stiffness: spec.stiffness
                    damping: spec.damping
                    mass: spec.mass
                    Component.onCompleted: snapTo(1)
                }
            }
        }
    }
}
