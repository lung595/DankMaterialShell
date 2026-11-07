pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var parentModal: null
    readonly property var islands: SettingsUiState.islandConfigs()
    // A hosted island has no edge of its own, and the dot has no home face either.
    readonly property var pageIds: {
        const ids = ["island_general", "island_home", "island_behavior", "island_bubbles", "island_notifications", "island_shelf", "island_appearance", "island_motion"];
        return island.layout ? ids : ids.slice(island.hosted ? 1 : 2);
    }
    readonly property var morePageIds: island.layout ? ["island_plugins", "island_advanced"] : ["island_plugins"]

    function pagesOf(ids) {
        return ids.map(id => SettingsTabs.page(id)).filter(page => page);
    }

    function titleFor(config) {
        if (SettingsData.isDotBarConfig(config))
            return I18n.tr("Dot", "bar layout: free-floating dot that opens island activities");
        return config?.name || I18n.tr("Bar", "fallback name for an unnamed bar");
    }

    function placementLabel(config) {
        if (SettingsData.islandFreePlacement(config))
            return I18n.tr("Floating", "island settings: island can be dragged anywhere on the display");
        if (SettingsData.islandSetting(config, "islandFloating"))
            return I18n.tr("Overlay", "island settings: island floats over windows along its edge without reserving space");
        return I18n.tr("Docked", "island settings: island reserves its edge strip");
    }

    function summaryFor(config) {
        if (SettingsData.isDotBarConfig(config))
            return I18n.tr("Floating companion", "island hub: summary of the dot");
        if (!SettingsData.isIslandBarConfig(config))
            return I18n.tr("Island widget", "island hub: summary of an island hosted as a bar widget");
        return [I18n.tr("Island layout", "island hub: summary of a bar in island layout"), bar.positionLabel(config.position ?? SettingsData.Position.Top), root.placementLabel(config)].join(" • ");
    }

    // The host page: Bar > Dot, Bar > General of this bar, or the options of its Island widget.
    function openHost(keyboard) {
        if (island.isDot) {
            root.parentModal?.navigateTo("dankbar_dot", keyboard);
            return;
        }
        SettingsUiState.selectedBarId = island.barId;
        if (island.layout) {
            root.parentModal?.navigateTo("dankbar_settings", keyboard);
            return;
        }
        const where = SettingsData.locateBarWidget("island", island.barId);
        if (!where)
            return;
        const widget = BarWidgetCatalog.get("island");
        SettingsUiState.selectedWidgetSection = where.section;
        SettingsUiState.selectedWidgetIndex = where.index;
        SettingsUiState.selectedDockId = "";
        SettingsUiState.selectedWidgetTitle = widget?.text ?? "island";
        SettingsUiState.selectedWidgetDescription = widget?.description ?? "";
        SettingsUiState.selectedWidgetIcon = widget?.icon ?? "widgets";
        root.parentModal?.navigateTo("bar_widget", keyboard);
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    Component.onCompleted: {
        SettingsUiState.normalizeIslandHubSelection();
        SettingsUiState.selectIsland(SettingsUiState.islandHubSelection);
    }

    IslandHubState {
        id: island
    }

    BarSelectionState {
        id: bar
    }

    SettingsCard {
        iconName: "blur_on"
        title: I18n.tr("Islands", "noun plural, settings card title listing the islands")
        settingKey: "islandHubIslands"
        tags: ["island", "islands", "dot", "widget", "bar", "select"]

        Repeater {
            model: root.islands

            delegate: SettingsInstanceRow {
                required property var modelData

                title: root.titleFor(modelData)
                summary: root.summaryFor(modelData)
                selected: modelData.id === SettingsUiState.islandHubSelection
                toggleVisible: false
                deletable: false
                onClicked: SettingsUiState.selectIsland(modelData.id)
            }
        }

        SettingsNoteRow {
            visible: root.islands.length === 0
            noteIconName: "info"
            tint: Theme.surfaceVariantText
            tintBackground: Theme.surfaceVariantAlpha
            text: I18n.tr("No island is on", "island hub: empty state")
        }

        SettingsNavRow {
            visible: root.islands.length === 0
            iconName: "toolbar"
            title: I18n.tr("Bar")
            hint: I18n.tr("Set a bar's layout to Island", "island hub: how to get an island from a bar")
            onClicked: keyboard => root.parentModal?.navigateTo("dankbar", keyboard)
        }

        SettingsNavRow {
            visible: root.islands.length === 0
            iconName: "widgets"
            title: I18n.tr("Bar widgets")
            hint: I18n.tr("Add the Island widget to a bar", "island hub: how to get an island from a bar widget")
            onClicked: keyboard => root.parentModal?.navigateTo("dankbar_widgets", keyboard)
        }

        SettingsNavRow {
            visible: root.islands.length === 0
            iconName: "blur_on"
            title: I18n.tr("Dot", "bar layout: free-floating dot that opens island activities")
            hint: I18n.tr("Turn on the floating Dot", "island hub: how to get the dot")
            onClicked: keyboard => root.parentModal?.navigateTo("dankbar_dot", keyboard)
        }
    }

    SettingsCard {
        iconName: "blur_on"
        title: island.hasIsland ? root.titleFor(island.config) : ""
        settingKey: "islandHubPages"
        visible: island.hasIsland

        SettingsNavRow {
            iconName: island.layout ? "toolbar" : (island.hosted ? "widgets" : "blur_on")
            title: island.layout ? I18n.tr("Bar") : (island.hosted ? I18n.tr("Widget settings") : root.titleFor(island.config))
            hint: island.layout ? I18n.tr("Displays, visibility, frame", "island hub: what the bar page of an island holds") : (island.hosted ? I18n.tr("Show in bar", "island hub: what the widget page of a hosted island holds") : I18n.tr("Size, icon, idle look", "island hub: what the dot page holds"))
            onClicked: keyboard => root.openHost(keyboard)
        }

        Repeater {
            model: root.pagesOf(root.pageIds)

            delegate: SettingsNavRow {
                required property var modelData

                iconName: modelData.icon
                title: modelData.text
                hint: modelData.hint ?? ""
                onClicked: keyboard => root.parentModal?.navigateTo(modelData.id, keyboard)
            }
        }
    }

    SettingsCard {
        title: I18n.tr("More", "hub group of rarely used pages")
        visible: island.hasIsland

        Repeater {
            model: root.pagesOf(root.morePageIds)

            delegate: SettingsNavRow {
                required property var modelData

                iconName: modelData.icon
                title: modelData.text
                hint: modelData.hint ?? ""
                onClicked: keyboard => root.parentModal?.navigateTo(modelData.id, keyboard)
            }
        }
    }
}
