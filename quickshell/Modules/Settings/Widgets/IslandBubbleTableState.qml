import QtQuick
import qs.Common
import "../../../Common/IslandBubbleTable.js" as BubbleTable

// One island's bubble table (the islandBubbleTable setting, see Common/IslandBubbleTable.js) and the names shown for it.
// Shared by the Each bubble page, its family cards and the bubble editor.
QtObject {
    id: root

    required property var store
    // Brief, Normal, Important (IslandHubState.tierLabels)
    required property var tierLabels

    readonly property var table: root.store.setting("islandBubbleTable") ?? ({})
    readonly property var sideLabels: [I18n.tr("Left", "island bubble side"), I18n.tr("Right", "island bubble side")]
    readonly property var sideValues: ["machine", "apps"]
    readonly property var soundLabels: [I18n.tr("None", "island bubble sound"), I18n.tr("Notification", "island bubble sound"), I18n.tr("Alert", "island bubble sound")]
    readonly property var soundValues: ["none", "normal", "critical"]
    readonly property var labels: ({
            volume: I18n.tr("Volume", "island bubble name"),
            mic: I18n.tr("Microphone", "island bubble name"),
            micmute: I18n.tr("Microphone muted", "island bubble name"),
            brightness: I18n.tr("Brightness", "island bubble name"),
            output: I18n.tr("Output device", "island bubble name"),
            powerprofile: I18n.tr("Power profile", "island bubble name"),
            keepawake: I18n.tr("Stay awake", "island bubble name"),
            network: I18n.tr("Wi-Fi", "island bubble name"),
            openwifi: I18n.tr("Open Wi-Fi", "island bubble name"),
            dnd: I18n.tr("Do not disturb", "island bubble name"),
            capslock: I18n.tr("Caps lock", "island bubble name"),
            charging: I18n.tr("Charging", "island bubble name"),
            battery: I18n.tr("Battery (charged, unplugged, low)", "island bubble name"),
            periph: I18n.tr("Devices (Bluetooth included)", "island bubble name"),
            display: I18n.tr("Display connected", "island bubble name"),
            disk: I18n.tr("Disk almost full", "island bubble name"),
            eyes: I18n.tr("Eye breaks", "island bubble name"),
            shelf: I18n.tr("Shelf", "island bubble name"),
            notification: I18n.tr("Notifications", "island bubble name"),
            progress: I18n.tr("Progress", "island bubble name"),
            transfer: I18n.tr("Transfers and downloads", "island bubble name"),
            copy: I18n.tr("Copied to clipboard", "island bubble name"),
            password: I18n.tr("Password copied", "island bubble name"),
            trash: I18n.tr("Trash", "island bubble name"),
            reopen: I18n.tr("Reopen", "island bubble name"),
            frozen: I18n.tr("App crashed", "island bubble name"),
            media: I18n.tr("Media", "island bubble name"),
            call: I18n.tr("Call in progress", "island bubble name"),
            camera: I18n.tr("Camera in use", "island bubble name"),
            vpn: I18n.tr("VPN", "island bubble name"),
            ssh: I18n.tr("SSH session", "island bubble name"),
            usb: I18n.tr("USB drive", "island bubble name"),
            print: I18n.tr("Printing", "island bubble name"),
            plugin: I18n.tr("Plugin activities", "island bubble name"),
            callincoming: I18n.tr("Incoming call", "island bubble name"),
            code2fa: I18n.tr("2FA code", "island bubble name"),
            auth: I18n.tr("Authentication", "island bubble name"),
            urgent: I18n.tr("Attention request", "island bubble name"),
            batterycritical: I18n.tr("Battery critical", "island bubble name"),
            weatheralert: I18n.tr("Weather alert", "island bubble name"),
            pluginalert: I18n.tr("Plugin alerts", "island bubble name")
        })

    function scaleFor(family) {
        return root.store.setting(BubbleTable.scaleKeys[family]) || 1;
    }

    // A bubble whose Show already has a setting (charging, eye breaks) reads that one: one value behind both rows.
    function stateOf(bubble) {
        const state = BubbleTable.effective(root.table, bubble.id, root.scaleFor(bubble.family));
        if (bubble.showKey)
            state.enabled = bubble.showShared ? SettingsData[bubble.showKey] : root.store.setting(bubble.showKey);
        return state;
    }

    function setField(id, field, value) {
        root.store.apply("islandBubbleTable", BubbleTable.withField(root.table, id, field, value));
    }

    function setShow(bubble, on) {
        if (!bubble.showKey)
            root.setField(bubble.id, "enabled", on);
        else if (bubble.showShared)
            SettingsData.set(bubble.showKey, on);
        else
            root.store.apply(bubble.showKey, on);
    }

    function resetBubble(id) {
        root.store.apply("islandBubbleTable", BubbleTable.without(root.table, id));
    }

    // Always the real value, never "Auto".
    function lifeLabel(ms) {
        if (ms > 0)
            return I18n.duration(ms / 1000);
        return ms === 0 ? I18n.tr("While active", "island bubble lifetime: as long as its state lasts") : I18n.tr("Set by the plugin", "island bubble lifetime: the plugin decides");
    }
}
