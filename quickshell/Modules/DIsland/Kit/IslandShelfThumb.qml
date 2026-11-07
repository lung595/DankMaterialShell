import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets
import "../../../Common/IslandShelf.js" as Shelf

// One kept file, square: a picture decoded at the size it is shown (crisp at the screen's scale), else its type's icon.
// A3: a category the kit lacked (a kept file's thumbnail), added to it.
ClippingRectangle {
    id: root

    property string path: ""
    property real iconSize: Theme.iconSize
    // The kept folders (stat), so a folder shows its icon.
    property var dirs: []

    readonly property bool picture: Shelf.isImage(root.path)
    readonly property bool shown: thumb.status === Image.Ready

    radius: Theme.cornerRadius / 2
    color: Theme.surfaceContainerHighest

    Image {
        id: thumb

        anchors.fill: parent
        source: root.picture ? Shelf.url(root.path) : ""
        sourceSize: Qt.size(Math.ceil(root.width * Screen.devicePixelRatio), Math.ceil(root.height * Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.shown
    }

    DIcon {
        anchors.centerIn: parent
        visible: !root.shown
        name: Shelf.icon(root.path, root.dirs)
        size: root.iconSize
        color: Theme.surfaceVariantText
    }
}
