import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Modules.ControlCenter.Widgets
// Sleep blocked bubble's pill (kind "keepawake"): the app keeping the session awake, small, on the cup's lower corner,
// with no backdrop: a thin halo of the shape's color (a MultiEffect shadow, where the other badges draw a rim) keeps it
// readable.
// backdrop: a thin halo of the shape's color (a MultiEffect shadow, where the other badges draw a rim) keeps it readable.
Item {
    id: root

    property var bubble: null
    property color ringColor: Theme.surface
    // The app's icon as a share of the pill's, and its halo's spread.
    readonly property real iconShare: 0.5
    readonly property real haloScale: 1.2

    visible: root.bubble?.source === "system" && root.bubble?.kind === "keepawake" && (root.bubble?.app ?? "") !== ""

    CcAppIcon {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        iconSize: Math.round(root.width * root.iconShare)
        appId: root.visible ? root.bubble.app : ""
        layer.enabled: root.visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            autoPaddingEnabled: false
            paddingRect: Qt.rect(Theme.spacingXS, Theme.spacingXS, Theme.spacingXS, Theme.spacingXS)
            shadowColor: root.ringColor
            shadowBlur: 0
            shadowScale: root.haloScale
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
