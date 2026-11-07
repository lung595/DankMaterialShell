import QtQuick
import qs.Common
import qs.DCommon.Widgets

// What a copy was (a copy face's typeIcon and thumb): a copied image's own picture, round, or its kind's icon (lines,
// link, file, key). The same on the standing bubble and the card's rows.
Item {
    id: root

    property var face: null
    property real size: Theme.iconSize
    property color color: Theme.surfaceText
    readonly property string thumb: root.face?.thumb ?? ""
    readonly property bool pictured: root.thumb !== ""

    implicitWidth: root.size
    implicitHeight: root.size

    DIcon {
        anchors.centerIn: parent
        visible: !root.pictured
        name: root.face?.typeIcon ?? ""
        size: root.size
        color: root.color
    }

    // Decoded small (to its own size) only while shown, never kept in the image cache.
    DCircularImage {
        anchors.fill: parent
        visible: root.pictured
        cacheImages: false
        fallbackIcon: "material:image"
        imageSource: visible ? root.thumb : ""
    }
}
