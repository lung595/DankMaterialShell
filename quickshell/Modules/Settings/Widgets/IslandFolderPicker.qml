import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser

// One folder chooser for the shelf's settings rows: open() asks, chosen(path) answers with an absolute path.
LazyLoader {
    id: root

    signal chosen(string path)

    function open() {
        root.active = true;
        root.item?.open();
    }

    active: false

    FileBrowserModal {
        browserTitle: I18n.tr("Choose a folder", "island shelf: folder picker title")
        mode: "openFolder"
        onAccepted: paths => {
            const p = String(paths?.[0] ?? "").replace(/^file:\/\//, "");
            if (p.startsWith("/"))
                root.chosen(p);
        }
        onDialogClosed: Qt.callLater(() => root.active = false)
    }
}
