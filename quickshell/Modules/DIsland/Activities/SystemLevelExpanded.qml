pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.OSD
import qs.Modules.Notifications
import qs.DCommon.Widgets

// A level (volume, brightness) open in the island, on the notification popup's grid: the title and
// its hint stacked, left aligned; under them DMS's own level row, its icon in front of the track (a click mutes) and the
// value at the end, so the icon is not drawn twice.
Item {
    id: root

    required property var systemModel

    readonly property int maximum: Math.max(root.systemModel.minimum + 1, Math.round(root.systemModel.maximum))

    Column {
        id: texts

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: NotificationMetrics.cardPadding
        spacing: NotificationMetrics.contentSpacing / 2

        StyledText {
            width: parent.width
            text: root.systemModel.title
            color: Theme.surfaceText
            font.pixelSize: NotificationMetrics.summarySize
            font.weight: Theme.fontWeightMedium
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.systemModel.mutable ? I18n.tr("Click the icon to mute", "island volume face: hint under the title") : I18n.tr("Display brightness control", "island brightness face: hint under the title")
            color: Theme.surfaceVariantText
            font.pixelSize: NotificationMetrics.bodySize
            elide: Text.ElideRight
        }
    }

    OsdLevelRow {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: texts.bottom
        anchors.topMargin: Theme.spacingS
        anchors.leftMargin: NotificationMetrics.cardPadding
        anchors.rightMargin: NotificationMetrics.cardPadding
        height: Theme.buttonHeightS
        horizontalPadding: 0
        visible: root.systemModel.levelActivity
        Accessible.name: root.systemModel.title
        iconName: root.systemModel.iconName
        tonalIcon: false
        iconInteractive: root.systemModel.mutable
        iconLabel: root.systemModel.muted ? I18n.tr("Unmute") : I18n.tr("Mute")
        value: Math.round(root.systemModel.value)
        minimum: root.systemModel.minimum
        maximum: root.maximum
        unit: root.systemModel.unit
        displayText: root.systemModel.displayValue
        sliderEnabled: root.systemModel.available
        onIconClicked: root.systemModel.toggleMute()
        onSliderValueChanged: newValue => root.systemModel.setRatio(newValue / Math.max(1, root.maximum))
    }
}
