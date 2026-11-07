pragma Singleton

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    property string selectedBarId: "default"
    property string selectedWallpaperScreen: ""
    // Which dock the Dock hub pages are editing.
    property string dockHubSelection: ""
    // Which island (bar, hosting bar or dot id) the Island hub pages are editing.
    property string islandHubSelection: ""
    // One-shot request for the bubble table filter, read once by the Each bubble page; empty means none.
    property string islandBubbleFilter: ""
    // Set only while the widget settings page is showing a dock-hosted widget; empty means bar-hosted.
    property string selectedDockId: ""
    property string selectedDockWidgetId: ""
    property string selectedDesktopWidgetId: ""
    property string selectedWidgetSection: ""
    property int selectedWidgetIndex: -1
    property string selectedWidgetTitle: ""
    property string selectedWidgetDescription: ""
    property string selectedWidgetIcon: ""

    // The dot has its own page, so bar selection never lands on it.
    function normalizeSelectedBar() {
        const config = SettingsData.getBarConfig(selectedBarId);
        if (config && !SettingsData.isDotBarConfig(config))
            return;
        selectedBarId = SettingsData.barConfigs.find(cfg => !SettingsData.isDotBarConfig(cfg))?.id ?? "default";
    }

    function islandConfigs() {
        return SettingsData.barConfigs.filter(cfg => SettingsData.hostsIsland(cfg));
    }

    // The bar pages follow an edge island; the dot has its own page, so it leaves the bar selection alone.
    function selectIsland(id) {
        islandHubSelection = id;
        const config = SettingsData.getBarConfig(id);
        if (config && !SettingsData.isDotBarConfig(config))
            selectedBarId = id;
    }

    function normalizeIslandHubSelection() {
        const islands = islandConfigs();
        if (islands.some(cfg => cfg.id === islandHubSelection))
            return;
        islandHubSelection = (islands.find(cfg => cfg.id === selectedBarId) ?? islands[0])?.id ?? "";
    }

    Component.onCompleted: normalizeIslandHubSelection()

    Connections {
        target: SettingsData

        function onBarConfigsChanged() {
            root.normalizeSelectedBar();
            root.normalizeIslandHubSelection();
        }
    }
}
