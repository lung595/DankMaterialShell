import QtQuick
import qs.Common

// A bubble's status dot (B8): a dot with a thin rim on its pill icon's lower outer corner (the badge corner, clear of
// the +N count), shown while its source's state lasts. The camera's green dot and the SSH session's red one.
Item {
    id: root

    property var bubble: null
    property color ringColor: Theme.surface
    // The bubble source it marks, its colour and what it says to a screen reader.
    property string source: ""
    property color dotColor: Theme.success
    property string label: ""
    // The dot's diameter, as a share of the pill's icon.
    readonly property real dotShare: 0.15

    visible: root.bubble?.source === root.source

    Rectangle {
        id: mark

        // Even sizes keep the dot on whole pixels; the rim is one pixel all round.
        readonly property int dot: 2 * Math.round(root.width * root.dotShare)

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: mark.dot + 2
        height: width
        radius: width / 2
        color: root.dotColor
        border.width: 1
        border.color: root.ringColor
        Accessible.role: Accessible.Indicator
        Accessible.name: root.label
    }
}
