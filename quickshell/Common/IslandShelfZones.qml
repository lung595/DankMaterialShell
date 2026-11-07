import QtQuick

// The shelf's drop zones by name, one table for the shelf's card and its settings card.
QtObject {
    function name(id) {
        return ({
                "convert": I18n.tr("Convert", "island shelf drop zone: change a file's format"),
                "share": I18n.tr("Share", "island shelf drop zone: send to a device"),
                "cloud": I18n.tr("Cloud", "island shelf drop zone: copy into a synced folder")
            })[id] ?? id;
    }
}
