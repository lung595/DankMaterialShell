pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandCharge.js" as Charge

// Kit category: counter. A whole number on digit wheels (the charge face, his mockup B of 29/10): each wheel rolls to
// its next digit as the value passes it (IslandCharge.rollAt: the units with the fraction, a higher wheel only from 9 to
// 0), over an invisible "88" (three digits for a final value from 99.5) that holds the width and the baseline; no
// leading zero, a higher wheel fades in from its 9 (the tens from 9, the hundreds from 99). The caller sets `font`, the
// final value `to`, and moves `value` toward it (a growth, a Behavior): the wheels only move by y, the width never jumps.
Item {
    id: odo

    property real value: 0
    // The value counted to: the wheels and the width are decided on it, as the face's head reads its width.
    property real to: odo.value
    property alias font: ghost.font
    property color color: Theme.surfaceText
    readonly property int count: Charge.wheels(odo.to)

    implicitWidth: ghost.implicitWidth
    implicitHeight: ghost.implicitHeight
    baselineOffset: ghost.baselineOffset

    StyledText {
        id: ghost

        text: odo.count === 3 ? "888" : "88"
        opacity: 0
        Accessible.ignored: true
    }

    Row {
        Repeater {
            model: odo.count

            Item {
                id: wheel

                required property int index
                readonly property real place: Math.pow(10, odo.count - 1 - wheel.index)
                readonly property real pos: Charge.rollAt(odo.value, wheel.place)
                readonly property int digit: Math.floor(wheel.pos) % 10
                readonly property real roll: wheel.pos - Math.floor(wheel.pos)

                width: ghost.implicitWidth / odo.count
                height: ghost.implicitHeight
                clip: true
                opacity: wheel.place > 1 ? Math.max(0, Math.min(1, odo.value - wheel.place + 1)) : 1

                StyledText {
                    width: wheel.width
                    y: -wheel.roll * wheel.height
                    horizontalAlignment: Text.AlignHCenter
                    text: wheel.digit
                    font: ghost.font
                    color: odo.color
                    Accessible.ignored: true
                }
                StyledText {
                    width: wheel.width
                    y: (1 - wheel.roll) * wheel.height
                    horizontalAlignment: Text.AlignHCenter
                    text: (wheel.digit + 1) % 10
                    font: ghost.font
                    color: odo.color
                    visible: wheel.roll > 0
                    Accessible.ignored: true
                }
            }
        }
    }
}
