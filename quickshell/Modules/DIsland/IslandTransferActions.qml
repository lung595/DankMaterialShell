import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandDownload.js" as Download

// What the transfers card's buttons do (IslandTransferSource holds the rows): pause, resume and cancel through the core,
// open a row's folder or file. B9: one file per role of the bubble (source, words, actions, card).
QtObject {
    id: actions

    // The transfers source (IslandTransferSource) whose rows these act on.
    required property var source

    // Rows that may pause, resume or cancel: the given ones (a row or a section's rows), or all of them.
    function targets(r, can) {
        return (r ? [].concat(r) : actions.source.list).filter(t => t[can] && !t.finished && !t.error);
    }
    function setPaused(yes, r) {
        const ids = actions.targets(r, "canPause").map(t => t.id);
        const said = yes ? I18n.tr("Could not pause the transfer", "island transfers: the core refused a pause") : I18n.tr("Could not resume the transfer", "island transfers: the core refused a resume");
        const done = ok => {
            if (!ok)
                ToastService.showError(said);
        };
        if (yes)
            TransferService.pause(ids, done);
        else
            TransferService.resume(ids, done);
    }
    // A row shows cancelled once the core took the cancel, never before.
    function cancel(r) {
        const ids = actions.targets(r, "canCancel").map(t => t.id);
        TransferService.cancel(ids, ok => {
            if (!ok) {
                ToastService.showError(I18n.tr("Could not cancel the transfer", "island transfers: the core refused a cancel"));
                return;
            }
            const next = Object.assign({}, actions.source.cancelled);
            for (const id of ids)
                next[id] = true;
            actions.source.cancelled = next;
        });
    }
    // The folder a row lands in, or the file itself once finished.
    function openFolder(r) {
        const path = (r ?? actions.source.lead)?.path ?? "";
        const folder = path.slice(0, path.lastIndexOf("/")) || DownloadService.folder;
        Qt.openUrlExternally(String(folder).startsWith("file:") ? folder : Download.fileUrl(folder));
        actions.source.closeCard();
    }
    function openFile(r) {
        const path = (r ?? actions.source.lead)?.path ?? "";
        if (path)
            Qt.openUrlExternally(Download.fileUrl(path));
        actions.source.closeCard();
    }
}
