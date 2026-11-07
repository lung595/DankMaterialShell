pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/IslandKit.js" as Kit

// The battery glyph: an upright battery, thin outline with its terminal on top, its liquid in
// the level's ramp colour (IslandKit.levelTone), a full bolt in its middle while it charges. Drawn at the one icon size in
// the middle of the box it fills. While it charges the liquid rises to the level on the kit's FILL spring, its front a
// wave that settles flat (IslandLiquid); otherwise it shows flat at once. Nothing runs at rest.
// A device's own icon (a mouse, a headset) sits as a badge on the box's lower corner, as a call's microphone does.
Item {
    id: root

    // {level: 0..1, bolt: charging, badge: the device's icon name or ""}
    property var battery: null
    property real iconSize: Theme.iconSize
    property color lineColor: Theme.surfaceText
    // The surface under the badge, for its rim.
    property color ringColor: Theme.surface

    readonly property real level: Math.max(0, Math.min(1, root.battery?.level ?? 0))
    readonly property bool bolt: root.battery?.bolt === true
    readonly property string badge: root.battery?.badge ?? ""
    // The level's ramp (IslandKit.batteryHue), legible on the surface the battery sits on; a step change eases over.
    readonly property var hueRgb: Kit.batteryHue(root.level, {
        "error": Theme.error,
        "warning": Theme.warning,
        "success": Theme.success,
        "surface": root.ringColor,
        "ink": root.lineColor
    })
    property color hue: Qt.rgba(root.hueRgb.r, root.hueRgb.g, root.hueRgb.b, 1)
    Behavior on hue {
        ColorAnimation {
            duration: SettingsData.reduceMotion ? 0 : Theme.expressiveDurations.expressiveSlowEffects
        }
    }
    readonly property color ink: Kit.inkOn(root.hue, Theme.surface, Theme.surfaceText)
    // The glyph in units of its 19 high box: terminal 2, body 17 (outline 1.5), liquid inset 2, bolt 9 high.
    readonly property real u: root.iconSize / Kit.batteryBoxUnits
    // Charging, the liquid starts empty and rises once shown; otherwise it stands at its level from the start.
    property bool risen: !root.bolt

    implicitWidth: root.iconSize
    implicitHeight: root.iconSize
    Component.onCompleted: Qt.callLater(() => root.risen = true)

    Item {
        id: pile

        anchors.centerIn: parent
        width: Kit.batteryPileUnits * root.u
        height: Kit.batteryBoxUnits * root.u

        Rectangle {
            x: 2.5 * root.u
            width: 5 * root.u
            height: 2 * root.u
            radius: 0.8 * root.u
            color: root.lineColor
        }

        Rectangle {
            id: body

            y: 2 * root.u
            width: pile.width
            height: 17 * root.u
            radius: 2.95 * root.u
            color: "transparent"
            border.width: 1.5 * root.u
            border.color: root.lineColor
        }

        IslandLiquid {
            id: liquid

            x: 2 * root.u
            y: body.y + 2 * root.u
            width: pile.width - 4 * root.u
            height: body.height - 4 * root.u
            radius: root.u
            level: root.risen ? root.level : 0
            color: root.hue
            // While it charges the front waves with the power.
            wave: root.bolt ? root.battery?.wave ?? null : null
        }

        // The bolt: the outline's colour over the empty part, the liquid's ink over the liquid (cut at its mean line).
        DIcon {
            id: boltIcon

            anchors.horizontalCenter: body.horizontalCenter
            y: body.y + (body.height - height) / 2
            visible: root.bolt
            name: "bolt"
            filled: true
            // Material's bolt inks 20 of its 24 units: 9 units of bolt.
            size: 9 * root.u * 24 / 20
            color: root.lineColor
        }

        Item {
            x: boltIcon.x
            y: liquid.y + liquid.line
            width: boltIcon.width
            height: Math.max(0, boltIcon.y + boltIcon.height - y)
            visible: root.bolt && liquid.visible
            clip: true

            DIcon {
                y: boltIcon.y - parent.y
                name: "bolt"
                filled: true
                size: boltIcon.size
                color: root.ink
            }
        }
    }

    IslandStatusBadge {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.badge !== ""
        // The badge: 13 of the shape's 28, so the battery stays readable beside it.
        size: Math.round(root.width * 13 / 28)
        name: root.badge
        color: root.lineColor
        rimColor: root.ringColor
    }
}
