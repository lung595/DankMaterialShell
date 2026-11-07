import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Marks a card whose settings every island shares; one island needs no reminder.
DBadge {
    visible: SettingsUiState.islandConfigs().length > 1
    text: I18n.tr("All islands", "island settings: badge on a card shared by every island")
    color: Theme.secondaryContainer
    textColor: Theme.onSecondaryContainer
}
