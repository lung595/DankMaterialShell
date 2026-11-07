import QtQuick
import qs.Common
import qs.DCommon.Widgets

// A plugin's ready-made face, compact: the ring on the left, the title, the value on the right, centered as one group
// with the same margin on both sides.
Item {
    id: root

    required property var face
    property bool isVertical: false

    readonly property color accent: Theme[root.face.accent] ?? Theme.primary
    // The detail beside the title takes at most this share of the pill, so the title stays readable.
    readonly property real detailShare: 1 / 3

    ReadyActivityRing {
        anchors.centerIn: parent
        visible: root.isVertical
        iconName: root.face.icon
        image: root.face.image
        progress: root.face.progress
        accent: root.accent
    }

    Row {
        id: row

        anchors.centerIn: parent
        visible: !root.isVertical
        spacing: Theme.spacingS

        ReadyActivityRing {
            id: ring

            anchors.verticalCenter: parent.verticalCenter
            iconName: root.face.icon
            image: root.face.image
            progress: root.face.progress
            accent: root.accent
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, root.width - Theme.spacingM * 2 - ring.width - (detail.visible ? detail.width + row.spacing : 0) - row.spacing))
            text: root.face.title
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        StyledText {
            id: detail

            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width * root.detailShare)
            visible: text !== ""
            text: root.face.detail
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
            font.features: {
                "tnum": 1
            }
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
}
