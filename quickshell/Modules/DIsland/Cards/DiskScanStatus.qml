pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskUsage.js" as DiskUsage
import "../../../Common/IslandKit.js" as Kit

// The disk card's scan line (BubbleCardDisk): a dot breathing while du runs, what is scanned and how far, the time
// it took.
Item {
    id: scanLine

    required property BubbleCardDisk card

    width: parent.width
    height: status.implicitHeight

    Rectangle {
        id: dot

        anchors.verticalCenter: parent.verticalCenter
        width: Theme.spacingS
        height: width
        radius: width / 2
        color: Theme.primary
        opacity: !card.svc.scanning ? 0.4 : card.reduce ? 1 : 0.25 + 0.75 * Math.round(16 * Math.abs(Math.cos(Math.PI * dot.step / dot.steps))) / 16

        // Breathes only while du runs and the card is seen (K1), in 1/16 steps pushed by a Timer (K8).
        readonly property int steps: 32
        property int step: 0
        Timer {
            running: card.svc.scanning && !card.reduce && card.visible && (card.Window.window?.visible ?? false)
            repeat: true
            interval: Math.max(1, Math.round(Kit.beat("breath", Theme.currentAnimationBaseDuration) / dot.steps))
            onTriggered: dot.step = (dot.step + 1) % dot.steps
        }
    }

    StyledText {
        id: status

        anchors.left: dot.right
        anchors.leftMargin: Theme.spacingS
        anchors.right: progress.left
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        text: {
            card.svc.revision;
            const t = card.svc.tree;
            const files = t.files.toLocaleString(Qt.locale(), "f", 0);
            if (!card.svc.scanning && t.files === 0)
                return I18n.tr("Not scanned yet", "island disk card: scan status");
            return card.svc.scanning ? I18n.tr("Scanning · %1 readers · %2 files · %3", "island disk card: reader count, file count, size so far").arg(card.svc.readers).arg(files).arg(DiskUsage.fmt(t.size)) : I18n.tr("Scanned in %1 s · %2 files · %3", "island disk card: seconds, file count, size").arg((card.svc.elapsed / 1000).toFixed(1)).arg(files).arg(DiskUsage.fmt(t.size));
        }
    }

    // What the scan found against what statfs says is used.
    Rectangle {
        id: progress

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.28
        height: Theme.spacingXS
        radius: height / 2
        color: Theme.surfaceContainerHigh

        Rectangle {
            height: parent.height
            radius: parent.radius
            color: Theme.primary
            width: {
                card.svc.revision;
                return card.svc.scanning ? parent.width * Math.min(1, card.svc.tree.size / Math.max(1, card.svc.fsUsed)) : parent.width;
            }
        }
    }
}
