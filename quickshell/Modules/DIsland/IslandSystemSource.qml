pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/Format.js" as Format

QtObject {
    id: root

    required property IslandController controller

    property string kind: "volume"
    // The last kind this source opened itself; the host also sets kind for faces owned by other sources.
    property string openedKind: ""
    // Off: system levels and state changes keep their OSDs and only the face's own controls open this activity.
    property bool enabled: true
    // The sleep blocked source (IslandKeepAwakeSource), for the island's own "keepawake" face.
    property var keepAwake: null
    property var reopen: null
    // The call source (IslandCallSource), for the island's own "call" face.
    property var call: null
    property var printSource: null
    property var usb: null
    // The password copied source (IslandPasswordSource), for the island's own "password" face.
    property var password: null
    // The camera source (IslandCameraSource), for the island's own "camera" face.
    property var camera: null
    // Faces whose info another source owns (copy, trash, disk, display, periph, progress, frozen, vpn, ssh), by kind:
    // { icon, title, value, accent, click (optional, the value's action) }; IslandBarHost builds them.
    property var islandFaces: ({})
    readonly property var ownFace: islandFaces[kind] ?? null

    readonly property bool volumeActivity: kind === "volume"
    readonly property bool micActivity: kind === "mic"
    readonly property bool brightnessActivity: kind === "brightness"
    readonly property bool levelActivity: volumeActivity || micActivity || brightnessActivity
    readonly property var audio: volumeActivity ? AudioService.sink?.audio : (micActivity ? AudioService.source?.audio : null)
    readonly property bool available: levelActivity ? (brightnessActivity ? BrightnessService.brightnessAvailable : !!audio) : true
    readonly property bool muted: !!audio && (audio.muted ?? false)
    readonly property bool mutable: volumeActivity || micActivity
    readonly property real value: {
        switch (kind) {
        case "volume":
            return AudioService.sinkVolumePercent;
        case "mic":
            return AudioService.sourceVolumePercent;
        case "brightness":
            return BrightnessService.brightnessLevel;
        }
        return 0;
    }
    readonly property var brightnessDevice: BrightnessService.getCurrentDeviceInfo()
    readonly property real maximum: {
        switch (kind) {
        case "volume":
            return AudioService.sinkMaxVolume;
        case "brightness":
            return BrightnessService.brightnessMaximum(brightnessDevice);
        }
        return 100;
    }
    readonly property int minimum: brightnessActivity ? BrightnessService.brightnessMinimum(brightnessDevice) : 0
    readonly property real ratio: maximum > 0 ? Math.max(0, Math.min(1, value / maximum)) : 0
    readonly property bool batteryActivity: kind === "battery"
    // -1 hides the bubble's track.
    readonly property real trackRatio: levelActivity ? (muted ? -1 : ratio) : (batteryActivity ? Math.max(0, Math.min(1, BatteryService.batteryLevel / 100)) : -1)
    readonly property string accent: ownFace ? ownFace.accent : batteryActivity && BatteryService.isCriticalBattery ? "error" : kind === "openwifi" ? "warning" : "primary"
    readonly property string title: {
        if (ownFace)
            return ownFace.title;
        switch (kind) {
        case "volume":
            return I18n.tr("Volume", "island system face: volume title");
        case "mic":
            return I18n.tr("Microphone", "island system face: microphone title");
        case "brightness":
            return I18n.tr("Brightness", "island system face: brightness title");
        case "capslock":
            return I18n.tr("Caps lock", "island system face: caps lock title");
        case "powerprofile":
            return I18n.tr("Power profile", "island system face: power profile title");
        case "idleinhibitor":
            return I18n.tr("Idle inhibitor", "island system face: idle inhibitor title");
        case "charging":
            return BatteryService.isPluggedIn ? I18n.tr("Plugged in", "island system face: power connected title") : I18n.tr("Discharging", "island system face: power disconnected title");
        case "battery":
            return BatteryService.isCriticalBattery ? I18n.tr("Critical Battery") : I18n.tr("Low Battery");
        case "network":
            return I18n.tr("Network");
        case "keepawake":
            return I18n.tr("Sleep blocked", "island sleep blocked bubble title");
        case "reopen":
            return root.reopen?.title ?? "";
        case "call":
            return root.call?.appName ?? "";
        case "print":
            return root.printSource?.title ?? "";
        case "dnd":
            return I18n.tr("Do not disturb");
        case "output":
            return root.output.name;
        case "usb":
            return root.usb?.face.title ?? "";
        case "password":
            return root.password?.title ?? "";
        case "openwifi":
            return I18n.tr("Open network", "island open wifi bubble title: the Wi-Fi has no security");
        case "camera":
            return root.camera?.face.title ?? "";
        }
        return "";
    }
    readonly property string unit: brightnessActivity ? BrightnessService.brightnessUnit(brightnessDevice) : "%"
    readonly property string displayValue: {
        if (ownFace)
            return ownFace.value;
        switch (kind) {
        case "capslock":
            return DMSService.capsLockState ? I18n.tr("On") : I18n.tr("Off");
        case "powerprofile":
            return Theme.getPowerProfileLabel(PowerProfileWatcher.currentProfile);
        case "idleinhibitor":
            return SessionService.idleInhibited ? I18n.tr("On") : I18n.tr("Off");
        case "charging":
            return root.chargingValue();
        case "battery":
            return Math.round(BatteryService.batteryLevel) + "%";
        case "network":
            if (NetworkService.ethernetConnected)
                return I18n.tr("Ethernet");
            if (NetworkService.wifiConnected)
                return NetworkService.currentWifiSSID || I18n.tr("Connected");
            return I18n.tr("Disconnected");
        case "keepawake":
            return root.keepAwake?.summary ?? "";
        case "reopen":
            return root.reopen?.action ?? "";
        case "call":
            return root.call?.durationText ?? "";
        case "print":
            return root.printSource?.summary ?? "";
        case "dnd":
            if (!SessionData.doNotDisturb)
                return I18n.tr("Off");
            return SessionData.doNotDisturbUntil > 0 ? Format.formatUntil(SessionData.doNotDisturbUntil, SettingsData.use24HourClock) : I18n.tr("On");
        case "output":
            // The island face's action; the bubble's card has its own button.
            return root.output.canUndo ? I18n.tr("Undo") : "";
        case "usb":
            return root.usb?.face.detail ?? "";
        case "password":
            return I18n.tr("Clear now", "island password face: clears the copied password");
        case "openwifi":
            // The island face's action; the bubble shows the network's name and its card both buttons.
            return root.wifi.canVpn ? I18n.tr("Turn on VPN", "island open wifi bubble: connect the VPN") : root.wifi.label;
        case "camera":
            return I18n.tr("Camera on", "island camera face value");
        }
        return muted ? I18n.tr("Muted", "island system face: muted value label") : Math.round(value) + unit;
    }
    readonly property string iconName: {
        if (ownFace)
            return ownFace.icon;
        switch (kind) {
        case "volume":
            return AudioService.sinkVolumeIconName;
        case "mic":
            return muted ? "mic_off" : "mic";
        case "brightness":
            return BrightnessService.brightnessIconName(brightnessDevice, value);
        case "capslock":
            return DMSService.capsLockState ? "shift_lock" : "shift_lock_off";
        case "powerprofile":
            // Leaf, balance, bolt: saver, balanced, performance.
            return ["eco", "balance", "bolt"][PowerProfileWatcher.currentProfile] ?? "settings";
        case "idleinhibitor":
            return "local_cafe";
        case "charging":
        case "battery":
            return BatteryService.getBatteryIcon();
        case "network":
            if (NetworkService.ethernetConnected)
                return "lan";
            return NetworkService.wifiSignalIcon;
        case "keepawake":
            return "coffee";
        case "reopen":
            return "replay";
        case "call":
            return root.call?.muted ? "mic_off" : "call";
        case "print":
            return root.printSource?.iconName ?? "print";
        case "dnd":
            return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off";
        case "output":
            return root.output.icon;
        case "usb":
            return root.usb?.face.icon ?? "usb";
        case "password":
            // The face's leading glyph draws the manager's icon in its ring.
            return "";
        case "openwifi":
            return "no_encryption";
        case "camera":
            return "videocam";
        }
        return "";
    }
    // Level pulses carry their own controls, so only state pulses link out.
    readonly property string controlCenterSection: {
        switch (kind) {
        case "mic":
            return "audioInput";
        case "powerprofile":
        case "charging":
        case "battery":
            return "battery";
        case "network":
            return "network";
        case "idleinhibitor":
            return "idleInhibitor";
        case "dnd":
            return "doNotDisturb";
        }
        return "";
    }

    function chargingValue() {
        const level = Math.round(BatteryService.displayBatteryLevel) + "%";
        const seconds = BatteryService.estimatedSeconds();
        if (!seconds)
            return level;
        return level + " · " + BatteryService.formatTimeRemaining();
    }

    function show(activityKind) {
        if (!enabled || SessionData.suppressOSD)
            return;
        open(activityKind);
    }

    // What the island cannot show waits in the machine bubble; nothing else reads this source meanwhile.
    function open(activityKind, force) {
        if (controller.requestSystemActivity(activityKind, force) || (controller.bubblesEnabled && !controller.systemActivityActive && controller.showMachineBubble(activityKind))) {
            kind = activityKind;
            openedKind = activityKind;
        }
    }

    function setRatio(nextRatio) {
        const clampedRatio = Math.max(0, Math.min(1, nextRatio));
        SessionData.suppressOSDTemporarily();
        switch (kind) {
        case "volume":
            AudioService.setVolume(Math.round(clampedRatio * maximum));
            return;
        case "mic":
            AudioService.setMicVolume(Math.round(clampedRatio * maximum));
            return;
        case "brightness":
            BrightnessService.setGroupBrightness(Math.round(clampedRatio * maximum), BrightnessService.lastIpcTargets(), true);
            return;
        }
    }

    function toggleMute() {
        if (!mutable || !available)
            return;
        SessionData.suppressOSDTemporarily();
        if (micActivity) {
            AudioService.toggleMicMute();
            return;
        }
        AudioService.toggleMute();
    }

    // An opened launcher or panel takes the island over this face: the rest of it waits in the machine bubble.
    property Connections displacedConnection: Connections {
        target: root.controller

        function onSystemActivityDisplaced(activityId) {
            // Faces with their own source (call, usb, camera...) already go on in that source's bubble; so does the charge.
            if (activityId === root.openedKind && activityId !== "charging" && root.controller.bubblesEnabled)
                root.controller.showMachineBubble(activityId);
        }
    }

    property Connections audioConnection: Connections {
        target: AudioService.sink?.audio ?? null
        enabled: root.enabled

        function onVolumeChanged() {
            if (SettingsData.osdVolumeEnabled)
                root.show("volume");
        }

        function onMutedChanged() {
            if (SettingsData.osdVolumeEnabled)
                root.show("volume");
        }
    }

    property Connections micConnection: Connections {
        target: AudioService.source?.audio ?? null
        enabled: root.enabled

        function onMutedChanged() {
            if (SettingsData.osdMicMuteEnabled)
                root.show("mic");
        }
    }

    property Connections micServiceConnection: Connections {
        target: AudioService
        enabled: root.enabled

        function onMicVolumeChanged() {
            if (SettingsData.osdMicVolumeEnabled)
                root.show("mic");
        }
    }

    property Connections brightnessConnection: Connections {
        target: BrightnessService
        enabled: root.enabled

        function onBrightnessChanged(showOsd) {
            if (showOsd && SettingsData.osdBrightnessEnabled)
                root.show("brightness");
        }
    }

    property Connections capsLockConnection: Connections {
        target: DMSService
        enabled: root.enabled

        function onCapsLockStateChanged() {
            if (SettingsData.osdCapsLockEnabled)
                root.show("capslock");
        }
    }

    property Connections powerProfileConnection: Connections {
        target: PowerProfileWatcher
        enabled: root.enabled
        // Not over the charge's face or card (it has the profile buttons): it would close them.
        function onProfileChanged() {
            if (SettingsData.osdPowerProfileEnabled && root.controller.activeActivity !== "charging")
                root.show("powerprofile");
        }
    }

    property Connections idleInhibitorConnection: Connections {
        target: SessionService
        enabled: root.enabled

        function onInhibitorChanged() {
            if (SettingsData.osdIdleInhibitorEnabled)
                root.show("idleinhibitor");
        }
    }

    // The battery's infos (plugged, full, unplugged, low, critical) come from IslandChargeSource.

    // shortcut: the first network states land a few seconds after start; a fixed grace keeps them silent, upgrade if the service gains a "first state received" flag.
    readonly property double createdAt: Date.now()
    readonly property string networkStatus: NetworkService.networkStatus
    onNetworkStatusChanged: {
        if (Date.now() - createdAt > 10000)
            show("network");
    }

    // Brief pulse on each switch (user, timer or screen share), never a standing bubble; the session load itself stays silent.
    property Connections dndConnection: Connections {
        target: SessionData
        enabled: root.enabled

        function onDoNotDisturbChanged() {
            if (SessionData._hasLoaded)
                root.show("dnd");
        }
    }

    // Audio output changed: its name, its icon and Undo, back to the one before.
    property IslandOutputSource output: IslandOutputSource {
        onSwitched: {
            if (root.enabled && SettingsData.osdAudioOutputEnabled)
                root.show("output");
        }
    }

    // Open Wi-Fi: the warning and Turn on VPN (IslandWifiSource).
    property IslandWifiSource wifi: IslandWifiSource {
        onOpenNetwork: root.show("openwifi")
    }
}
