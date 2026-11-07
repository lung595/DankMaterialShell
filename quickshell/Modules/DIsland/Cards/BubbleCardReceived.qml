pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import "../../../Common/IslandDownload.js" as Download

// Open card of a file another device sent (LocalSend, Warpinator...: IslandReceived.js reads the sender's notification).
// On the card grid: the file's thumbnail (an image), else the sender's icon, else its kind's; the file's name, the device
// it came from; a wave while a big file is still coming; then Folder / Open. The header's icon drags out as the file.
Item {
    id: card

    property var bubble: null

    signal activated(var bubble)
    signal dismissed(var bubble)

    readonly property var received: card.bubble?.received ?? null
    readonly property string path: card.received?.path ?? ""
    readonly property bool coming: (card.received?.progress ?? -1) >= 0
    readonly property var wrapperActions: card.bubble?.wrapper?.actions ?? []
    readonly property url fileUrl: Download.fileUrl(card.path)
    readonly property string from: {
        const device = card.received?.device ?? "";
        const app = card.bubble?.app ?? "";
        if (device && app)
            return I18n.tr("From %1 · %2", "island received bubble: device · sending app").arg(device).arg(app);
        return device ? I18n.tr("From %1", "island received bubble: device").arg(device) : app;
    }
    readonly property string image: card.received?.isImage ? card.fileUrl.toString() : card.bubble?.image ?? ""

    function folderUrl() {
        const folder = card.received?.folder ?? "";
        // Without a path in the notification, the senders' default: the user's Downloads.
        return folder ? Download.fileUrl(folder) : StandardPaths.writableLocation(StandardPaths.DownloadLocation);
    }

    function act(id) {
        if (id === "open") {
            if (card.path)
                Qt.openUrlExternally(card.fileUrl);
            else if (card.wrapperActions.length > 0)
                card.wrapperActions[0].invoke();
        } else
            Qt.openUrlExternally(card.folderUrl());
        card.dismissed(card.bubble);
    }

    implicitHeight: base.implicitHeight

    BubbleCardBase {
        id: base

        width: parent.width
        // The notification's own words make way for the file and where it came from.
        bubble: card.bubble ? Object.assign({}, card.bubble, {
            "title": card.received?.file || card.bubble.title || "",
            "detail": card.coming ? I18n.tr("Receiving a file", "island received bubble: transfer still coming") : card.from,
            "image": card.image,
            "cardIcon": card.image === "" ? (card.received?.icon || "draft") : ""
        }) : null
        onActivated: card.activated(card.bubble)
        onDismissed: card.dismissed(card.bubble)

        M3WaveProgress {
            width: parent?.width ?? 0
            height: Theme.spacingL
            visible: card.coming
            value: Math.max(0, card.received?.progress ?? 0)
            isPlaying: card.coming
            Accessible.role: Accessible.ProgressBar
            Accessible.name: I18n.tr("Receiving a file", "island received bubble: transfer still coming")
        }

        BubbleActions {
            layoutDirection: Qt.RightToLeft

            BubbleAction {
                role: "primary"
                text: I18n.tr("Open", "island received bubble: open the file")
                iconName: "open_in_new"
                enabled: !card.coming && (card.path !== "" || card.wrapperActions.length > 0)
                onClicked: card.act("open")
            }
            BubbleAction {
                text: I18n.tr("Folder", "island received bubble: open the folder holding the file")
                iconName: "folder_open"
                onClicked: card.act("folder")
            }
        }
    }

    // Over the header's icon box: the file to drag.
    Item {
        z: 2
        width: NotificationMetrics.appIconSize
        height: width
        Accessible.role: Accessible.Graphic
        Accessible.name: card.received?.file || I18n.tr("Received file", "island received file card: file without a name")

        // A drag out of the card holds the notification: the pointer leaves the bubble while it carries the file, and the
        // bubble (with this card and its drag) must not time out under it.
        DragHandler {
            id: dragHandler

            enabled: card.path !== ""
            target: null
            onActiveChanged: {
                const w = card.bubble?.wrapper;
                if (!w?.timer || !w.popup || w.timer.interval <= 0)
                    return;
                if (dragHandler.active)
                    w.timer.stop();
                else
                    w.timer.restart();
            }
        }
        // Leaving the bubble restarts its timer (IslandBarHost.holdBubble): not while the drag lasts (active is already false
        // when the drag's own restart above fires this, before enabled follows).
        Connections {
            id: dragHold

            target: card.bubble?.wrapper?.timer ?? null
            enabled: dragHandler.active
            function onRunningChanged() {
                if (dragHandler.active && dragHold.target.running)
                    dragHold.target.stop();
            }
        }
        Drag.active: dragHandler.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: ({
                "text/uri-list": card.fileUrl.toString()
            })
        // A thumbnail, decoded at icon size, for an image only: anything else drags without a picture.
        Drag.imageSource: card.received?.isImage ? card.fileUrl : ""
        Drag.imageSourceSize: Qt.size(NotificationMetrics.appIconSize, NotificationMetrics.appIconSize)
        HoverHandler {
            enabled: card.path !== ""
            cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
    }
}
