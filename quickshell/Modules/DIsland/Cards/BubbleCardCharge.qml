pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Notifications

// The charge bubble's card (kind "charging", his choice of 27/10): the A1 battery in the header ("Plugged in",
// "Charging · 64%"), then the power taken over time since it was plugged in (a thin line, primary to tertiary along it,
// on its baseline; the average power and the energy received above it; the start, "Power / Time" and the end under it),
// three figures (left, full at, health), and the power profiles. The chart repaints only when a point comes in.
BubbleCardBase {
    id: card

    readonly property var charge: card.bubble?.charge ?? null
    readonly property var history: card.charge?.history ?? []
    readonly property var stats: card.charge?.stats ?? null
    // The chart spans from the plug to the clock time it is full at, else to its last point.
    readonly property real endMs: card.charge && card.charge.seconds > 0 ? card.charge.now + card.charge.seconds * 1000 : card.stats?.end ?? 0

    function number(v, decimals) {
        return Number(v).toLocaleString(Qt.locale(), "f", decimals);
    }

    iconComponent: Component {
        BubbleChargeGlyph {
            battery: card.bubble?.battery ?? null
            iconSize: Theme.iconSize
            lineColor: Theme.primary
        }
    }

    Rectangle {
        id: chart

        width: parent.width
        height: chartColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: chartColumn

            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: Math.max(avg.implicitHeight, energy.implicitHeight)

                Column {
                    id: avg

                    StyledText {
                        text: I18n.tr("%1 W", "island charge card: watts").arg(card.number(card.stats?.avg ?? 0, 1))
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: I18n.tr("average power", "island charge card: the mean charging power")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                Column {
                    id: energy

                    anchors.right: parent.right

                    StyledText {
                        anchors.right: parent.right
                        text: I18n.tr("%1 Wh", "island charge card: watt-hours").arg(card.number(card.stats?.wh ?? 0, 1))
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        anchors.right: parent.right
                        text: I18n.tr("energy received", "island charge card: the energy taken since plugged in")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Canvas {
                id: plot

                readonly property color from: Theme.primary
                readonly property color to: Theme.tertiary
                readonly property color base: Theme.outlineVariant

                width: parent.width
                height: NotificationMetrics.appIconSize * 2
                Accessible.role: Accessible.Graphic
                Accessible.name: I18n.tr("Charging power over time", "island charge card: chart")

                onWidthChanged: requestPaint()
                onFromChanged: requestPaint()
                onToChanged: requestPaint()
                Connections {
                    target: card
                    function onHistoryChanged() {
                        plot.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const h = card.history;
                    const lw = Theme.outlineWidth;
                    ctx.strokeStyle = plot.base;
                    ctx.lineWidth = lw;
                    ctx.beginPath();
                    ctx.moveTo(0, height - lw / 2);
                    ctx.lineTo(width, height - lw / 2);
                    ctx.stroke();
                    if (h.length < 2)
                        return;
                    const t0 = h[0][0];
                    const span = Math.max(1, Math.max(card.endMs, h[h.length - 1][0]) - t0);
                    const peak = Math.max(1, card.stats?.peak ?? 1);
                    const top = Theme.spacingS;
                    const bottom = height - lw * 2;
                    const grad = ctx.createLinearGradient(0, 0, width, 0);
                    grad.addColorStop(0, plot.from);
                    grad.addColorStop(1, plot.to);
                    ctx.strokeStyle = grad;
                    ctx.lineWidth = lw * 1.5;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    for (let i = 0; i < h.length; i++) {
                        const x = (h[i][0] - t0) / span * width;
                        const y = bottom - h[i][1] / peak * (bottom - top);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
            }

            Item {
                width: parent.width
                height: axisMid.implicitHeight

                StyledText {
                    // The charge leaves before the history bound to it is read again (the card closing).
                    text: card.history.length ? card.charge?.clockText(card.history[0][0]) ?? "" : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    id: axisMid

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Power / Time", "island charge card: chart axes")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.right: parent.right
                    text: card.endMs > 0 ? card.charge?.clockText(card.endMs) ?? "" : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    // Three figures: the time left, the clock time it is full at, the pack's health.
    Row {
        id: tiles

        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: [
                {
                    "value": card.charge?.leftText || "–",
                    "label": I18n.tr("Left").toLocaleLowerCase()
                },
                {
                    "value": card.charge?.fullAt || "–",
                    "label": I18n.tr("full at", "island charge card: clock time the battery is full")
                },
                {
                    "value": card.charge?.health || "–",
                    "label": I18n.tr("Health").toLocaleLowerCase()
                }
            ]

            Rectangle {
                id: tile

                required property var modelData

                width: (tiles.width - tiles.spacing * 2) / 3
                height: tileColumn.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                Accessible.role: Accessible.StaticText
                Accessible.name: tile.modelData.label + " " + tile.modelData.value

                Column {
                    id: tileColumn

                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2

                    StyledText {
                        width: parent.width
                        text: tile.modelData.value
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }
                    StyledText {
                        width: parent.width
                        text: tile.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // The power profiles, full width, equal parts, as in the battery card.
    DButtonGroup {
        readonly property var profiles: PowerProfileWatcher.availableProfiles

        width: parent.width
        visible: PowerProfileWatcher.available
        fillWidth: true
        checkEnabled: false
        labelOnlySelected: true
        Accessible.role: Accessible.Grouping
        Accessible.name: I18n.tr("Power profile")
        model: profiles.map(profile => ({
                    text: Theme.getPowerProfileLabel(profile),
                    icon: ["eco", "bolt", "speed"][profile]
                }))
        currentIndex: profiles.indexOf(PowerProfileWatcher.currentProfile)
        onSelectionChanged: (index, selected) => {
            if (selected && !PowerProfileWatcher.applyProfile(profiles[index]))
                ToastService.showError(I18n.tr("Failed to set power profile"));
        }
    }
}
