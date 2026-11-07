pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications

// The printing bubble's open card (source "print"): the job and its printer under the header, then Resume when the
// printer is in error and Cancel. Read live from the bubble's source (IslandPrintSource).
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var source: card.bubble?.printSource ?? null
    readonly property var job: card.source?.job ?? null

    StyledText {
        width: parent?.width ?? 0
        visible: text !== ""
        elide: Text.ElideMiddle
        wrapMode: Text.NoWrap
        text: [card.job?.name ?? "", card.job?.printer ?? ""].filter(s => s !== "").join(" · ")
        font.pixelSize: NotificationMetrics.bodySize
        color: Theme.surfaceVariantText
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    actions: [
        BubbleAction {
            visible: card.source?.error === true
            iconName: "play_arrow"
            text: I18n.tr("Resume", "island print bubble: restart a stopped printer")
            onClicked: card.source?.resume()
        },
        BubbleAction {
            role: "danger"
            iconName: "close"
            text: I18n.tr("Cancel", "island print bubble: cancel the print job")
            Accessible.name: I18n.tr("Cancel printing %1", "island print bubble: cancel button for a job").arg(card.job?.name ?? "")
            onClicked: card.source?.cancel()
        }
    ]
}
