import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandKit.js" as Kit

// Kit category: app icon. A notification's icon in the island (arrival card, compact face, open face): the sender's round
// picture; an important one (a call, a critical alert) sits on the filled alert shape instead, as an alert bubble's does,
// so it reads by its shape, not its colour alone. alert: "" | "critical" | "important" (a low battery's warning).
Item {
    id: root

    property string imageSource: ""
    property string fallbackIcon: "material:notifications"
    property string fallbackText: ""
    property string alert: ""
    readonly property bool alarmed: root.alert !== ""
    readonly property bool critical: root.alert === "critical"
    readonly property string materialPrefix: "material:"
    readonly property bool material: root.fallbackIcon.startsWith(root.materialPrefix)
    // An important one's shape: the warning tone mixed this far into the raised surface.
    readonly property real warningMix: 0.35
    // On the folded face: a critical one turns full error on a light theme (IslandKit.alertRoles).
    property bool folded: false
    readonly property var roles: Kit.alertRoles(root.alert, root.folded, Theme.isLightMode)

    // Without a logo: the sender's initial or symbol in the round fallback.
    DCircularImage {
        anchors.fill: parent
        visible: !shape.visible
        imageSource: root.imageSource
        fallbackIcon: root.fallbackIcon
        fallbackText: root.fallbackText
        cacheImages: false
    }

    // A logo sits on the filled shape; plain, the shape takes the tone that contrasts with the logo (31/10: a white
    // Android silhouette from the phone was lost on the light theme's round picture).
    IslandAppIcon {
        id: shape

        anchors.fill: parent
        visible: root.alarmed || shape.hasImage
        size: root.width
        source: root.imageSource
        iconName: root.alarmed && root.material ? root.fallbackIcon.substring(root.materialPrefix.length) : ""
        smoothGlyph: true
        shapeColor: root.roles ? Theme[root.roles[0]] : root.alarmed ? Theme.blend(Theme.surfaceContainerHigh, Theme.warning, root.warningMix) : shape.logoShapeColor
        iconColor: root.roles ? Theme[root.roles[1]] : Theme.surfaceText
    }

    AppIconRenderer {
        anchors.centerIn: parent
        width: Math.round(parent.width * shape.glyphShare)
        height: width
        visible: root.alarmed && !shape.hasImage && root.fallbackIcon !== "" && !root.material
        iconValue: root.fallbackIcon
        iconSize: width
        iconColor: shape.iconColor
        materialIconSizeAdjustment: 0
        fallbackText: root.fallbackText
        fallbackBackgroundColor: "transparent"
        fallbackTextColor: shape.iconColor
    }
}
