pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Notifications
import "../../../Common/IslandDownload.js" as Download

// Open card of a finished download (DownloadService): the header names the file and its size, then Show / Open. The
// header's icon drags out as the file itself (text/uri-list), to drop it anywhere.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var file: card.bubble?.file ?? null
    readonly property string fileUrl: Download.fileUrl(card.file?.path ?? "")

    // Over the header's icon box: the file to drag.
    readonly property Item handle: Item {
        parent: card
        z: 2
        width: NotificationMetrics.appIconSize
        height: width
        Accessible.role: Accessible.Graphic
        Accessible.name: I18n.tr("Download finished", "island download bubble: the falling file glyph")

        DragHandler {
            id: dragHandler

            enabled: card.fileUrl !== ""
            target: null
            onActiveChanged: {
                DownloadService.dragging = active;
                DownloadService.hold(active);
            }
        }
        Drag.active: dragHandler.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: ({
                "text/uri-list": card.fileUrl
            })
        HoverHandler {
            enabled: card.fileUrl !== ""
            cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
    }

    BubbleActions {
        layoutDirection: Qt.RightToLeft

        BubbleAction {
            role: "primary"
            text: I18n.tr("Open", "island download bubble: open the file")
            iconName: "open_in_new"
            onClicked: DownloadService.open()
        }
        BubbleAction {
            text: I18n.tr("Show", "island download bubble: show the file in its folder")
            iconName: "folder_open"
            onClicked: DownloadService.show()
        }
    }
}
