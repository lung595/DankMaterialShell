pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.Settings.Widgets

// Picker for the Material shape behind island app logos: "cycle" (a new shape on each click) or one fixed shape.
// Tiles follow SettingsSwatchGrid; the shape names come from DCommon/Widgets/MaterialShapeData.js.
Flow {
    id: root

    property string currentValue: "cycle"
    signal selected(string value)

    // Without puffy, flower, clover4, cookie4 and verySunny: the icon does not fit every step of their morph (IslandBubbles.flowShapes).
    readonly property var shapes: ["cycle", "circle", "square", "slanted", "arch", "fan", "arrow", "semiCircle", "oval", "pill", "triangle", "diamond", "clamShell", "pentagon", "gem", "sunny", "cookie6", "cookie7", "cookie9", "cookie12", "ghostish", "clover8", "burst", "softBurst", "boom", "softBoom", "puffyDiamond", "pixelCircle", "pixelTriangle", "bun", "heart"]

    // "softBurst" -> "Soft burst", "cookie9" -> "Cookie 9"
    function shapeName(value) {
        if (value === "cycle")
            return I18n.tr("Cycle on click", "island settings: logo shape choice, a new shape each time a bubble is clicked");
        const words = value.replace(/([A-Z])/g, " $1").replace(/(\d+)/, " $1").toLowerCase();
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingS

    Repeater {
        model: root.shapes

        Rectangle {
            id: tile

            required property string modelData
            readonly property bool isActive: root.currentValue === modelData

            width: Theme.iconSize * 2
            height: width
            radius: Theme.cornerRadiusM
            color: SettingsMetrics.controlColor
            border.width: isActive ? Theme.outlineWidthFocused : Theme.layerOutlineWidth
            border.color: isActive ? Theme.primary : Theme.outlineMedium

            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: root.shapeName(modelData)
            Accessible.checkable: true
            Accessible.checked: isActive
            Accessible.onPressAction: root.selected(modelData)
            Keys.onSpacePressed: root.selected(modelData)
            Keys.onEnterPressed: root.selected(modelData)
            Keys.onReturnPressed: root.selected(modelData)

            FocusRing {
                id: tileRing
            }

            StateLayer {
                anchors.fill: parent
                stateColor: Theme.primary
                focused: tileRing.visible
                tooltipText: root.shapeName(tile.modelData)
                onClicked: {
                    tileRing.pointerFocused = true;
                    tile.forceActiveFocus(Qt.MouseFocusReason);
                    root.selected(tile.modelData);
                }
            }

            DMaterialShape {
                anchors.centerIn: parent
                // Even size: the shape centers on a whole pixel in an even tile (C28).
                width: Math.round(parent.width * 0.3) * 2
                height: width
                shape: tile.modelData === "cycle" ? "cookie9" : tile.modelData
                color: tile.isActive ? Theme.primary : Theme.surfaceVariantText
            }

            DIcon {
                anchors.centerIn: parent
                visible: tile.modelData === "cycle"
                name: "autorenew"
                size: Theme.iconSizeSmall
                color: tile.isActive ? Theme.onPrimary : Theme.surfaceContainerHighest
            }
        }
    }
}
