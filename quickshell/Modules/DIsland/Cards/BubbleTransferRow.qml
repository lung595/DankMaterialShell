import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit
import "../../../Common/IslandTransfer.js" as Transfer

// One row of the transfers card (BubbleCardTransfers): its name (cut in its stem, the extension kept) and app, DMS's
// wave progress, "312 / 850 MB · 12.4 MB/s" and its time left, a torrent's swarm under it; hovered or focused, its own
// actions. K10: its wave moves only while the row moves.
Item {
    id: row

    // The card the row sits in (BubbleCardTransfers): its sizes and its source.
    required property BubbleCardTransfers owner

    required property var modelData
    readonly property bool failed: row.modelData.error === true
    readonly property bool finished: row.modelData.finished === true
    readonly property bool live: !row.failed && !row.finished
    readonly property bool known: row.finished || (row.modelData.ratio ?? -1) >= 0
    readonly property bool torrent: row.modelData.category === "torrent" && !row.finished
    readonly property var split: Transfer.splitName(row.modelData.name ?? "")
    // Hovered or focused, the row's own actions take the app's place.
    readonly property bool acting: hover.hovered || pauseOne.activeFocus || cancelOne.activeFocus || folderOne.activeFocus || openOne.activeFocus

    height: row.owner.rowHeight + (row.torrent ? row.owner.lineGap + row.owner.detailHeight : 0)
    Accessible.role: Accessible.ListItem
    Accessible.name: [row.modelData.name, row.modelData.app, status.text, left.text, swarm.text].filter(t => t).join(", ")

    HoverHandler {
        id: hover
    }

    Item {
        id: nameLine

        anchors.left: parent.left
        anchors.right: row.acting ? actions.left : app.left
        anchors.rightMargin: Theme.spacingS
        height: row.owner.nameHeight

        StyledText {
            id: stem

            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(0, nameLine.width - ext.implicitWidth))
            text: row.split.stem
            elide: Text.ElideMiddle
            wrapMode: Text.NoWrap
            font.pixelSize: NotificationMetrics.bodySize
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
        StyledText {
            id: ext

            // Right after the stem's drawn text: once elided it is narrower than its box.
            x: stem.contentWidth
            anchors.baseline: stem.baseline
            text: row.split.ext
            wrapMode: Text.NoWrap
            font: stem.font
            color: Theme.surfaceText
        }
    }
    StyledText {
        id: app

        anchors.right: parent.right
        anchors.verticalCenter: nameLine.verticalCenter
        visible: !row.acting
        text: row.modelData.app ?? ""
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
    Row {
        id: actions

        anchors.right: parent.right
        anchors.verticalCenter: nameLine.verticalCenter
        spacing: Theme.spacingXS
        visible: row.acting

        IslandButton {
            id: pauseOne

            visible: row.live && row.modelData.canPause === true
            iconName: row.modelData.paused ? "play_arrow" : "pause"
            text: ""
            activeFocusOnTab: true
            Accessible.name: row.modelData.paused ? I18n.tr("Resume", "island transfers bubble: resume the paused transfers") : I18n.tr("Pause", "island transfers bubble: pause the transfers that allow it")
            onClicked: row.owner.transfer?.actions.setPaused(!row.modelData.paused, row.modelData)
        }
        IslandHoldButton {
            id: cancelOne

            visible: row.live && row.modelData.canCancel === true
            iconName: "close"
            text: ""
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Cancel", "island transfers bubble: stop the transfer")
            onConfirmed: row.owner.transfer?.actions.cancel(row.modelData)
        }
        IslandButton {
            id: folderOne

            visible: (row.modelData.path ?? "") !== ""
            iconName: "folder_open"
            text: ""
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Open folder", "island transfers bubble: show the files in their folder")
            onClicked: {
                folderOne.flash(true);
                row.owner.transfer?.actions.openFolder(row.modelData);
            }
        }
        IslandButton {
            id: openOne

            visible: row.finished
            role: "primary"
            iconName: "open_in_new"
            text: ""
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Open", "island transfers bubble: open the finished file")
            onClicked: {
                openOne.flash(true);
                row.owner.transfer?.actions.openFile(row.modelData);
            }
        }
    }

    // DMS's own wave progress, at the kit's cadence: it waves only while the row moves.
    IslandWaveProgress {
        y: nameLine.height + row.owner.lineGap
        width: parent.width
        height: row.owner.barHeight
        visible: row.known || row.failed
        value: row.finished ? 1 : Math.max(0, row.modelData.ratio ?? 0)
        moving: row.modelData.flowing === true
        fillColor: row.failed ? Theme.error : Theme.primary
        playheadColor: row.failed ? Theme.error : Theme.primary
    }

    StyledText {
        id: status

        anchors.left: parent.left
        anchors.right: left.left
        anchors.rightMargin: Theme.spacingS
        y: row.owner.rowHeight - height
        text: row.failed ? (row.modelData.reason === "missing-files" ? I18n.tr("Missing files", "island transfers bubble: a torrent's files are gone") : I18n.tr("Failed", "island transfers bubble: a transfer failed")) : row.owner.transfer ? row.owner.transfer.texts.amountText(row.modelData) : ""
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeSmall
        font.features: {
            "tnum": 1
        }
        color: row.failed ? Theme.error : Theme.surfaceVariantText
    }
    StyledText {
        id: left

        anchors.right: parent.right
        anchors.baseline: status.baseline
        text: row.failed ? "" : row.finished ? I18n.tr("Done", "island transfers bubble: this transfer finished") : row.modelData.paused ? I18n.tr("Paused", "island transfers bubble: this transfer is paused") : row.modelData.eta >= 0 ? I18n.tr("%1 left", "island transfers bubble: time left of one transfer").arg(row.owner.transfer?.texts.timeText(row.modelData.eta) ?? "") : ""
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Theme.fontWeightMedium
        font.features: {
            "tnum": 1
        }
        color: Theme.surfaceText
    }
    // A torrent's swarm: peers, upload, ratio.
    StyledText {
        id: swarm

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: row.torrent
        text: row.torrent && row.owner.transfer ? row.owner.transfer.texts.swarmText(row.modelData) : ""
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeSmall
        font.features: {
            "tnum": 1
        }
        color: Theme.surfaceVariantText
    }
}
