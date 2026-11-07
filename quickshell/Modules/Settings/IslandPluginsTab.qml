import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

// Which plugins may show activities in the island and who draws each system face. Shared by every island.
Item {
    id: root

    property var parentModal: null

    SettingsPage {
        IslandPluginsCard {
            id: pluginsCard

            headerActions: IslandSharedBadge {}
        }

        // The card hides itself while no plugin has anything for the island.
        SettingsNoteRow {
            visible: !pluginsCard.visible
            paintBackground: false
            noteIconName: "info"
            tint: Theme.surfaceVariantText
            tintBackground: Theme.surfaceVariantAlpha
            text: I18n.tr("No plugin shows activities in the island yet", "island settings: plugins page empty state")
        }
    }
}
