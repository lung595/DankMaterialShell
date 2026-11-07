import QtQuick
import qs.Common
import "../../../Common/IslandKit.js" as Kit

// Kit category: row of buttons (every card's actions, at the bottom). Full width, split by each button's weight (equal by
// default, 1 1 2 2 for the call card), whole pixels, the notification popup's gap. Hidden buttons give their share to the
// others.
Item {
    id: row

    property real spacing: Theme.spacingXS
    // Qt.RightToLeft lays the first button at the end (the main action declared first).
    property int layoutDirection: Qt.LeftToRight
    readonly property bool mirrored: I18n.isRtl !== (row.layoutDirection === Qt.RightToLeft)

    readonly property var shown: {
        const out = [];
        for (let i = 0; i < row.children.length; i++) {
            if (row.children[i].visible)
                out.push(row.children[i]);
        }
        return out;
    }
    readonly property var cells: Kit.rowLayout(row.width, row.shown.map(item => item.weight ?? 1), row.spacing)

    implicitHeight: Theme.buttonHeightS

    // Placed from here, not by bindings: the buttons are any items a card declares, and a binding written onto a child
    // would be dropped by the first x or width the card sets on it.
    function place() {
        row.shown.forEach((item, i) => {
            item.x = row.mirrored ? row.width - row.cells[i].x - row.cells[i].width : row.cells[i].x;
            item.width = row.cells[i].width;
            item.height = row.height;
        });
    }
    onCellsChanged: row.place()
    onHeightChanged: row.place()
    onMirroredChanged: row.place()
}
