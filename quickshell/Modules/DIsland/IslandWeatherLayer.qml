import QtQuick
import qs.Common
import qs.Modules.DIsland.Kit
import qs.Modules.SurfaceWidgets

// The weather alert in the island (DIslandSurface; K6: its painters pick their cadence on the kit's clock). It rains
// (snows, storms...) in the whole island under its face, by force; grown into its card, a quieter, richer sky under the
// text (the mockup's two painters, crossfading).
Item {
    id: layer

    // While the island shows the alert: its weather (the face's), whether the island is open, whether its card shows.
    property bool active: false
    property var weather: null
    property bool expanded: false
    property bool cardShown: false
    // The island's shape, whose corners the sky follows.
    required property MorphSurface shape

    Repeater {
        model: layer.active ? 2 : 0

        IslandWeatherFx {
            required property int index
            readonly property var weather: layer.active && !layer.expanded ? layer.weather : null

            anchors.fill: parent
            event: weather?.event ?? ""
            level: weather?.level ?? 0
            rich: index === 1
            strength: !weather ? 0 : (layer.cardShown === rich) ? (rich ? 0.5 : 1) : 0
            topLeftRadius: layer.shape.topLeftRadius
            topRightRadius: layer.shape.topRightRadius
            bottomRightRadius: layer.shape.bottomRightRadius
            bottomLeftRadius: layer.shape.bottomLeftRadius
            color: Theme.primary
            color2: Theme.surfaceText
            accent: Theme.warning
        }
    }
}
