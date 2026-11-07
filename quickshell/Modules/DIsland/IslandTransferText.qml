import QtQuick
import qs.Common
import "../../Common/IslandTransfer.js" as Transfer

// The transfers bubble's words (IslandTransferSource reads them, its card too): time left, amounts and speeds, a
// torrent's swarm, the card's section titles and totals. B9: one file per role of the bubble (source, words, card).
QtObject {
    id: root

    function timeText(seconds) {
        const t = Transfer.timeLeft(seconds);
        if (!t)
            return "";
        if (t.unit === "s")
            return I18n.tr("%1 s", "island transfers bubble: time left in seconds").arg(t.value);
        if (t.unit === "min")
            return I18n.tr("%1 min", "island transfers bubble: time left in minutes").arg(t.value);
        return I18n.tr("%1 h %2", "island transfers bubble: time left in hours and minutes").arg(t.value).arg(String(t.minutes).padStart(2, "0"));
    }
    function bytesText(n, ref) {
        const b = Transfer.bytes(n, ref);
        return b.value.toLocaleString(Qt.locale(), "f", b.decimals);
    }
    function unitText(n) {
        const unit = Transfer.bytes(n).unit;
        return unit === "B" ? I18n.tr("B", "island transfers bubble: bytes unit") : unit === "kB" ? I18n.tr("kB", "island transfers bubble: kilobytes unit") : unit === "MB" ? I18n.tr("MB", "island transfers bubble: megabytes unit") : unit === "GB" ? I18n.tr("GB", "island transfers bubble: gigabytes unit") : I18n.tr("TB", "island transfers bubble: terabytes unit");
    }
    // "312 / 850 MB · 12.4 MB/s" (unknown size: "312 MB · 12.4 MB/s").
    function amountText(r) {
        const pair = r.total > 0 ? I18n.tr("%1 / %2 %3", "island transfers bubble: received of total, unit").arg(root.bytesText(r.done, r.total)).arg(root.bytesText(r.total)).arg(root.unitText(r.total)) : root.bytesText(r.done) + " " + root.unitText(r.done);
        if (!(r.speed > 0))
            return pair;
        return pair + " · " + I18n.tr("%1 %2/s", "island transfers bubble: speed, unit").arg(root.bytesText(r.speed)).arg(root.unitText(r.speed));
    }
    // A torrent's swarm: "12 peers · ↑ 1.2 MB/s · ratio 0.42".
    function swarmText(r) {
        const up = Number(r.upSpeed) || 0;
        return [I18n.tr("%1 peers", "island transfers bubble: connected peers of a torrent").arg(Number(r.peers) || 0), I18n.tr("↑ %1 %2/s", "island transfers bubble: a torrent's upload speed, unit").arg(root.bytesText(up)).arg(root.unitText(up)), I18n.tr("ratio %1", "island transfers bubble: a torrent's share ratio").arg((Number(r.shareRatio) || 0).toLocaleString(Qt.locale(), "f", 2))].join(" · ");
    }
    function sectionTitle(category) {
        switch (category) {
        case "download":
            return I18n.tr("Downloads", "island transfers card: section of downloads");
        case "torrent":
            return I18n.tr("Torrents", "island transfers card: section of torrents");
        case "archive":
            return I18n.tr("Archives", "island transfers card: section of archives being packed or extracted");
        case "send":
            return I18n.tr("Sent and received", "island transfers card: section of files sent to or received from other devices");
        case "disk":
            return I18n.tr("Keys and drives", "island transfers card: section of images written to keys and drives");
        default:
            return I18n.tr("Copies and moves", "island transfers card: section of copied and moved files");
        }
    }
    // A section's total: "2 of 3 · 4 min".
    function sectionTotal(s) {
        const count = I18n.tr("%1 of %2", "island transfers card: finished of all transfers in a section").arg(s.finished).arg(s.count);
        const time = s.eta >= 0 ? root.timeText(s.eta) : "";
        return time ? count + " · " + time : count;
    }
}
