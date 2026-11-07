import QtQuick
import qs.Common

// The island the Island hub pages are editing, and how it is hosted.
QtObject {
    id: root

    readonly property string barId: SettingsUiState.islandHubSelection
    readonly property var config: {
        SettingsData.barConfigs;
        return SettingsData.getBarConfig(root.barId);
    }
    readonly property bool hasIsland: !!root.config && SettingsData.hostsIsland(root.config)
    readonly property bool isDot: SettingsData.isDotBarConfig(root.config)
    readonly property bool layout: root.hasIsland && root.config.island === true
    readonly property bool hosted: root.hasIsland && !SettingsData.isIslandBarConfig(root.config)
    readonly property bool free: root.layout && SettingsData.islandFreePlacement(root.config)
    // A hosted island sits in its bar like a docked one; the dot never docks.
    readonly property bool docked: root.hosted || (root.layout && !root.free)
    readonly property bool vertical: {
        const position = root.config?.position ?? SettingsData.Position.Top;
        return position === SettingsData.Position.Left || position === SettingsData.Position.Right;
    }
    readonly property var tierLabels: [I18n.tr("Brief", "island importance: a 2 s info such as a copy"), I18n.tr("Normal", "island importance: notifications, glances, an Undo"), I18n.tr("Important", "island importance: a call or a critical alert")]

    readonly property IslandSettingsStore store: IslandSettingsStore {
        barId: root.barId
    }
}
