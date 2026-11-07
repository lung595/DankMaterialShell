pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/IslandKit.js" as Kit
import "../../../Common/IslandCharge.js" as Charge

// The open island's charge face (kind "chargeface"; his mockup B "Expressive" of 29/10,
// projects/dms/notes/maquettes-charge/maquettes-charge-2910.html): on the left a bordered well (a liquid in the island
// lives in a well) with the level's sea and the bolt on its Material cookie (Kit/IslandChargeSea: three swells, bubbles
// that burst at the surface, the cookie dug and turned by the power, one clock); at the plug one ripple of the level's
// colour leaves the mark (Kit/IslandAlertWave). On the right the level large on digit wheels (Kit/IslandOdometer,
// counted on the island's growth: the content follows the island), the power chip (watts and the speed word), the
// kit's wavy progress, then three chips (time left, full at, the session's gain; Cards/BubbleChargeChips). Each piece
// arrives in turn on the island's growth (IslandCharge.revealAt, no timer). Reduced motion: the final state, nothing
// runs. A click turns the face into the charge card.
Item {
    id: face

    property var bubble: null
    readonly property var charge: face.bubble?.charge ?? null
    // How far the island has grown into this face (DIslandSurface.faceBigness, through the source).
    readonly property real grow: Math.max(0, Math.min(1, face.charge?.grow ?? 1))
    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    readonly property real shown: face.still ? 1 : face.grow
    readonly property color hue: face.charge?.hue ?? Theme.success
    readonly property color container: Theme.withAlpha(face.hue, Charge.tonalAlpha)
    // The power chip's text (4.5:1) and bolt (3:1) on the tonal chip itself, else the surface's text.
    readonly property color powerInk: Kit.inkOnTonal(face.hue, Theme.surfaceText, Theme.hostSurface, Charge.tonalAlpha, Kit.textMin)
    readonly property color boltInk: Kit.inkOnTonal(face.hue, Theme.surfaceText, Theme.hostSurface, Charge.tonalAlpha, Kit.legibleMin)
    readonly property real level: face.charge?.level ?? 0
    readonly property real watts: face.charge?.watts ?? 0
    // The well: two avatars wide (the column keeps two chips on a row at the island's width), the content's height, the
    // mark half its width (C28: even sizes, the bolt inside the cookie's hollow). The chips: an icon or a line of text
    // and their padding high (they follow the font scale), their text never past the column (elided).
    readonly property real wellWidth: Theme.avatarSize * 2
    readonly property real markSize: Theme.avatarSize
    readonly property real chipHeight: Math.max(Theme.iconSizeSmall, powerText.implicitHeight) + Theme.spacingS
    readonly property real chipPad: Theme.spacingS + Theme.spacingXS
    readonly property real chipText: Math.max(0, column.width - Theme.iconSizeSmall - Theme.spacingXS - face.chipPad)
    // The pieces arriving in turn: well, number, power and wave, then the three chips.
    readonly property int pieces: 6
    // The level shown, a whole percent (the wheels come to rest on whole digits, as the accessible names say): counted on
    // the growth, then rolled from one percent to the next.
    readonly property int percent: Charge.percent(face.level)
    property real count: face.percent * face.shown

    function reveal(d) {
        return face.still ? 1 : Charge.revealAt(face.grow, d, face.pieces);
    }

    signal activated(var bubble)
    signal dismissed(var bubble)

    implicitHeight: column.implicitHeight

    Behavior on count {
        enabled: !face.still && face.shown >= 1

        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }
    }

    // Without a pointer: the island's charge IPC (island charge card|hide, DIsland.qml) does what the click does.
    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("Charging %1%, open the charge card", "island charge face: accessible name of the clickable face").arg(face.percent)
    Accessible.onPressAction: face.activated(face.bubble)

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (point, button) => button === Qt.RightButton ? face.dismissed(face.bubble) : face.activated(face.bubble)
    }

    // The well: bordered (outline variant), the sea inset in it, the bolt over its mark.
    Rectangle {
        id: well

        readonly property real r: face.reveal(0)

        width: face.wellWidth
        height: column.implicitHeight
        radius: Theme.cornerRadiusXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.outlineWidth
        border.color: Theme.outlineVariant
        opacity: well.r
        transform: Translate {
            y: (1 - well.r) * Theme.spacingS
        }

        IslandChargeSea {
            id: sea

            anchors.fill: parent
            anchors.margins: Theme.spacingXS
            radius: Math.max(0, well.radius - Theme.spacingXS - Theme.outlineWidth)
            level: face.level
            grow: face.grow
            watts: face.watts
            color: face.hue
            markSize: face.markSize
        }
        DIcon {
            anchors.centerIn: parent
            name: "bolt"
            filled: true
            size: Theme.iconSize
            color: face.hue
            scale: sea.markScale
        }
        // At the plug, one ripple of the level's colour leaves the mark; never red, a low level ripples in warning.
        IslandAlertWave {
            id: ring

            anchors.centerIn: parent
            base: face.markSize
            rings: 1
            color: face.charge ? face.charge.hueAt(Math.max(face.charge.level, Kit.batterySteps[1])) : face.hue
        }
    }

    Column {
        id: column

        x: face.wellWidth + Theme.spacingL
        width: face.width - x
        spacing: Theme.spacingS

        // The level on its wheels and the power chip: beside it when both fit, else under it, so the speed word is
        // never cut ("ultra fast" at a large font scale).
        Item {
            id: head

            readonly property real powerWidth: Theme.iconSizeSmall + Theme.spacingXS + powerText.implicitWidth + face.chipPad
            // Read on the final level's wheels, never the counted ones: the count follows the island's growth, which
            // follows this row's height (a polish loop that froze the shell at the threshold).
            readonly property real bigWidth: levelWide.advanceWidth + big.spacing + percentText.implicitWidth
            readonly property bool beside: head.bigWidth + Theme.spacingS + head.powerWidth <= head.width

            TextMetrics {
                id: levelWide

                font: odometer.font
                text: Charge.wheels(face.percent) === 3 ? "888" : "88"
            }

            width: parent.width
            height: head.beside ? Math.max(big.implicitHeight, power.height) : big.implicitHeight + Theme.spacingXS + power.height

            Row {
                id: big

                readonly property real r: face.reveal(1)

                y: head.beside ? (head.height - big.implicitHeight) / 2 : 0
                spacing: Theme.spacingXXS
                opacity: big.r
                transform: Translate {
                    y: (1 - big.r) * Theme.spacingS
                }
                Accessible.role: Accessible.StaticText
                Accessible.name: I18n.tr("Battery level %1%", "island charging card: battery gauge").arg(face.percent)

                IslandOdometer {
                    id: odometer

                    value: face.count
                    to: face.percent
                    font.pixelSize: Theme.fontSizeDisplay
                    font.weight: Theme.fontWeightBold
                    font.features: {
                        "tnum": 1
                    }
                    color: Theme.surfaceText
                }
                StyledText {
                    id: percentText

                    anchors.baseline: odometer.baseline
                    text: "%"
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceVariantText
                }
            }
            Rectangle {
                id: power

                readonly property real r: face.reveal(2)

                x: head.beside ? head.width - power.width : 0
                y: head.beside ? (head.height - power.height) / 2 : big.implicitHeight + Theme.spacingXS
                width: Math.min(head.powerWidth, head.width)
                height: face.chipHeight
                radius: height / 2
                color: face.container
                visible: (face.charge?.wattsText ?? "") !== ""
                opacity: power.r
                transform: Translate {
                    y: (1 - power.r) * Theme.spacingS
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bolt"
                        filled: true
                        size: Theme.iconSizeSmall
                        color: face.boltInk
                    }
                    StyledText {
                        id: powerText

                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(powerText.implicitWidth, power.width - face.chipPad - Theme.iconSizeSmall - Theme.spacingXS)
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        text: (face.charge?.wattsText ?? "") + ((face.charge?.speedText ?? "") !== "" ? " · " + face.charge.speedText : "")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        font.features: {
                            "tnum": 1
                        }
                        color: face.powerInk
                        Accessible.role: Accessible.StaticText
                        Accessible.name: I18n.tr("Charging power %1", "island charge face: accessible name of the power chip").arg(powerText.text)
                    }
                }
            }
        }

        // The wavy progress, the level's colour, livelier with the power, a stop dot at the end of its track.
        Item {
            id: progress

            readonly property real r: face.reveal(2)

            width: parent.width
            height: Theme.spacingL
            opacity: progress.r

            IslandWaveProgress {
                anchors.fill: parent
                value: face.level * face.shown
                // On the sea's clock: still once its first seconds are over.
                moving: !face.still && sea.awake && (face.charge?.charging ?? false)
                fillColor: face.hue
                trackColor: Theme.withAlpha(face.hue, Charge.trackAlpha)
                // No playhead bar: the wave simply ends, round, and the dot marks the track's end.
                playheadColor: "transparent"
                lineWidth: Theme.spacingXS
                wavelength: Theme.spacingXL + Theme.spacingS
                amp: Charge.waveAmp(face.watts, Theme.spacingXXS)
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.spacingXS
                height: width
                radius: width / 2
                color: face.hue
            }
        }

        BubbleChargeChips {
            width: parent.width
            charge: face.charge
            grow: face.grow
            still: face.still
            from: 3
            pieces: face.pieces
            chipHeight: face.chipHeight
            chipPad: face.chipPad
            textWidth: face.chipText
        }
    }

    // bubble comes through a Binding once the loader is ready, after onCompleted: the charge is read when it arrives.
    onChargeChanged: {
        if ((face.charge?.takeRing() ?? false) && !face.still)
            ring.play();
    }
}
