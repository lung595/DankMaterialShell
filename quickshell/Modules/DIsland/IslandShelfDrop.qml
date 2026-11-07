import QtQuick
import "../../Common/IslandShelf.js" as Shelf

// Files dragged onto the island (DIslandSurface) land on its shelf (IslandShelfSource): the drop reaches past the island
// to the screen's edge and its Fitts strip. B9: the shelf's own file, out of the surface.
DropArea {
    id: drop

    // The shelf to hand the files to (null: no drop), the island's side and its edge strip's gap (0 without one).
    property var shelf: null
    property bool vertical: false
    property bool farEdge: false
    property real edgeGap: 0
    readonly property var reach: Shelf.dropReach(drop.vertical, drop.farEdge, drop.edgeGap)

    anchors.topMargin: -drop.reach.top
    anchors.bottomMargin: -drop.reach.bottom
    anchors.leftMargin: -drop.reach.left
    anchors.rightMargin: -drop.reach.right
    enabled: !!drop.shelf
    onEntered: drag => {
        drag.accepted = Shelf.takesDrag(drag.formats, drag.hasUrls) && drop.shelf.enter();
        drop.shelf.dragMove(mapToItem(null, drag.x, drag.y));
    }
    onExited: drop.shelf.leave()
    // The card under the pointer (a drop zone grows, a row held on makes a folder), in the window's coordinates.
    onPositionChanged: drag => drop.shelf.dragMove(mapToItem(null, drag.x, drag.y))
    onDropped: event => {
        if (drop.shelf.drop(Shelf.dropUris(event.urls, event.getDataAsString("text/uri-list"), event.text)))
            // Never Move: the source app would delete the file the shelf only links to.
            event.accept(event.supportedActions & Qt.LinkAction ? Qt.LinkAction : Qt.CopyAction);
    }
}
