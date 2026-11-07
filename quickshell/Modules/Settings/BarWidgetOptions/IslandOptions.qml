import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

// A hosted island is set up on the Island hub; this page only leads there.
Column {
    id: root

    property var page: null

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    IslandHubLink {
        parentModal: root.page?.parentModal ?? null
        barId: root.page?.barId ?? ""
    }
}
