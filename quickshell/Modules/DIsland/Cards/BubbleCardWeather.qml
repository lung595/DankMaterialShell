pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit

// Weather alert (kind "weather"), grown in the island: the key phrase ("Heavy rain until 10:45"), the peak ("max 6 mm/h
// around 10:15"), then one small chart: eight bars of 15 min over two hours, tinted by force, the now and end marks.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var weather: card.bubble?.weather ?? null
    // One ramp by force, so the strongest quarters read first in any scheme; the strongest in the error color.
    readonly property var tints: [Theme.withAlpha(Theme.primary, 0.4), Theme.withAlpha(Theme.primary, 0.7), Theme.primary, Theme.error]

    Item {
        id: chart

        readonly property real barsHeight: NotificationMetrics.appIconSize
        // A line one theme hair wide (the marks, an empty quarter).
        readonly property real hair: Math.max(1, Math.round(Theme.spacingXS / 2))
        readonly property real step: width / Math.max(1, card.weather?.bars?.length ?? 8)

        width: parent.width
        height: chart.barsHeight + Theme.spacingXS + nowLabel.implicitHeight
        visible: !!card.weather
        Accessible.role: Accessible.Graphic
        Accessible.name: card.weather?.label ?? ""

        Repeater {
            model: card.weather?.bars ?? []

            Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: modelData.level >= 0

                x: Math.round(index * chart.step + chart.step * 0.14)
                width: Math.round(chart.step * 0.72)
                height: on ? Math.max(Theme.spacingXS, Math.round(chart.barsHeight * modelData.frac)) : chart.hair
                y: chart.barsHeight - height
                radius: Math.min(Theme.cornerRadius / 2, width / 2)
                color: on ? card.tints[modelData.level] : Theme.withAlpha(Theme.surfaceText, 0.22)
            }
        }

        // Now, inside the current quarter.
        Rectangle {
            x: Math.round(chart.width * (card.weather?.now ?? 0))
            width: chart.hair
            height: chart.barsHeight + Theme.spacingXS
            color: Theme.surfaceText
        }

        // The end, while it is on the chart.
        Rectangle {
            visible: (card.weather?.end ?? -1) >= 0
            x: Math.round(chart.width * (card.weather?.end ?? 0)) - 1
            width: Math.max(1, chart.hair / 2)
            height: chart.barsHeight + Theme.spacingXS
            color: Theme.surfaceVariantText
        }

        StyledText {
            id: nowLabel

            y: chart.barsHeight + Theme.spacingXS
            text: I18n.tr("now", "island weather chart: the now mark")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            readonly property real at: chart.width * (card.weather?.end ?? 1)
            readonly property bool off: (card.weather?.end ?? -1) < 0

            y: nowLabel.y
            x: off ? chart.width - width : Math.max(nowLabel.width + Theme.spacingS, Math.min(chart.width - width, at - width / 2))
            text: off ? I18n.tr("ends %1 ›", "island weather chart: end past the chart").arg(card.weather?.endAt ?? "") : I18n.tr("ends %1", "island weather chart: the end mark").arg(card.weather?.endAt ?? "")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
