import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import "../../../Common/IslandProgress.js" as Progress

// Progress bubble's open card (source "progress"): files done / total, time left at the pace seen so far, and the speed,
// each only when known (files and speed are what the app writes in its notification's body), on one line under the header.
BubbleCardBase {
    id: card

    readonly property var files: card.bubble?.files ?? null
    readonly property int remaining: card.bubble?.remaining ?? -1
    readonly property string speed: card.bubble?.speed ?? ""

    function timeLeft(s) {
        const t = Progress.clock(s);
        if (t.s >= 0)
            return I18n.tr("%1 s left", "island progress card: time left").arg(t.s);
        if (t.h === 0)
            return I18n.tr("%1 min left", "island progress card: time left").arg(t.m);
        return I18n.tr("%1 h %2 min left", "island progress card: time left").arg(t.h).arg(t.m);
    }

    readonly property var known: [card.files ? I18n.tr("%1 / %2 files", "island progress card: files done of total").arg(card.files.done).arg(card.files.total) : "", card.remaining > 0 ? card.timeLeft(card.remaining) : "", card.speed].filter(r => r !== "")
    // Nothing the card can read in the app's words: show them as they are.
    readonly property var rows: card.files || card.speed ? card.known : card.known.concat([card.bubble?.body ?? ""].filter(r => r !== ""))

    StyledText {
        width: parent?.width ?? 0
        visible: text !== ""
        text: card.rows.join(" · ")
        wrapMode: Text.Wrap
        maximumLineCount: NotificationMetrics.collapsedLines
        elide: Text.ElideRight
        font.pixelSize: NotificationMetrics.bodySize
        color: Theme.surfaceVariantText
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
