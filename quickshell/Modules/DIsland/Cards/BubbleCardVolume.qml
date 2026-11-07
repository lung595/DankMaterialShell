pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets
import qs.DCommon.Widgets

// Volume bubble's open card (kind "volume"): the output's name (and a Bluetooth headset's battery), its volume (DMS's
// slider, its icon before the track), the other outputs as chips, each playing app's own volume, and the mute toggle in
// the bottom row. Same services as the Control Center's Audio Output page (AudioSliderRow's volume rules).
Item {
    id: root

    property var bubble: null

    signal activated(var bubble)
    signal dismissed(var bubble)

    readonly property var sink: AudioService.sink
    readonly property var audio: root.sink?.audio ?? null
    readonly property bool muted: root.audio?.muted ?? false
    // The sink's Bluetooth device, matched by the address PipeWire's bluez5 plugin puts on the node.
    readonly property var btDevice: {
        const address = (sink?.properties?.["api.bluez5.address"] ?? "").toUpperCase();
        return address ? BluetoothService.pairedDevices.find(dev => (dev.address ?? "").toUpperCase() === address) ?? null : null;
    }
    // Same lookup as the Control Center's Bluetooth page: BlueZ's own level, else UPower's by name.
    readonly property string batteryText: {
        if (!btDevice)
            return "";
        if (btDevice.batteryAvailable)
            return Math.round(btDevice.battery * 100) + "%";
        const lowered = (btDevice.name || btDevice.deviceName || "").toLowerCase();
        const upower = lowered ? BatteryService.bluetoothDevices.find(dev => dev.name.toLowerCase().includes(lowered) || lowered.includes(dev.name.toLowerCase())) : null;
        return upower ? upower.percentage + "%" : "";
    }
    readonly property var outputs: {
        const hidden = SessionData.hiddenOutputDeviceNames ?? [];
        return AudioService.allNodes.filter(node => node.audio && node.isSink && !node.isStream && !hidden.includes(node.name));
    }
    readonly property var streams: AudioService.pipewireNodes.filter(node => node.audio && node.isSink && node.isStream)

    // AudioSliderRow's rules: a move unmutes, plays the feedback sound, and keeps the volume OSD quiet.
    function setVolume(node, percent) {
        if (!node?.audio)
            return;
        SessionData.suppressOSDTemporarily();
        node.audio.volume = percent / 100;
        if (percent > 0 && node.audio.muted)
            node.audio.muted = false;
        AudioService.playVolumeChangeSoundIfEnabled();
    }

    implicitHeight: base.implicitHeight

    component VolumeSlider: DSlider {
        id: volumeSlider

        property var node: null
        readonly property int percent: volumeSlider.node?.audio ? Math.round(volumeSlider.node.audio.volume * 100) : 0

        width: parent?.width ?? 0
        enabled: !!volumeSlider.node?.audio
        minimum: 0
        unit: "%"
        startIcon: AudioService.volumeIconName(volumeSlider.node)
        wheelStep: AudioService.wheelVolumeStep
        valueOverride: volumeSlider.percent
        onSliderValueChanged: newValue => root.setVolume(volumeSlider.node, newValue)

        Binding {
            target: volumeSlider
            property: "value"
            value: Math.min(volumeSlider.maximum, volumeSlider.percent)
            restoreMode: Binding.RestoreNone
            when: !volumeSlider.isDragging
        }
    }

    BubbleCardBase {
        id: base

        width: parent.width
        bubble: root.bubble ? Object.assign({}, root.bubble, {
            "title": [AudioService.displayName(root.sink) || root.bubble.title, root.batteryText].filter(part => part).join(" • ")
        }) : null
        onActivated: b => root.activated(b)
        onDismissed: b => root.dismissed(b)

        VolumeSlider {
            node: root.sink
            maximum: AudioService.sinkMaxVolume
            // Above 100 % the fill takes the theme's alert colour.
            fillColor: percent > 100 ? Theme.error : Theme.primary
            Accessible.name: AudioService.displayName(root.sink) || I18n.tr("Volume")
        }

        DButtonGroup {
            width: parent.width
            visible: root.outputs.length > 1
            fillWidth: true
            checkEnabled: false
            labelOnlySelected: true
            Accessible.role: Accessible.Grouping
            Accessible.name: I18n.tr("Output device", "island volume card: device picker")
            model: root.outputs.map(node => ({
                        "text": AudioService.displayName(node),
                        "icon": AudioService.sinkIcon(node)
                    }))
            currentIndex: root.outputs.indexOf(root.sink)
            onSelectionChanged: (index, selected) => {
                const name = root.outputs[index]?.name;
                if (selected && name)
                    AudioService.setDefaultSinkByName(name);
            }
        }

        Repeater {
            model: root.streams

            Column {
                id: streamItem

                required property var modelData
                readonly property var props: modelData?.properties ?? {}
                readonly property string appName: props["application.name"] || AudioService.displayName(modelData)

                width: parent?.width ?? 0
                spacing: Theme.spacingXS

                Row {
                    spacing: Theme.spacingS

                    CcAppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        appId: streamItem.props["application.icon-name"] || streamItem.props["application.process.binary"] || ""
                        iconSize: Theme.iconSizeSmall
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: streamItem.width - Theme.iconSizeSmall - Theme.spacingS
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        text: [streamItem.appName, streamItem.props["media.name"]].filter(part => part).join(" • ")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                VolumeSlider {
                    node: streamItem.modelData
                    maximum: 100
                    Accessible.name: streamItem.appName
                }
            }
        }

        actions: [
            BubbleAction {
                toggle: true
                isOn: root.muted
                enabled: !!root.audio
                iconName: "volume_up"
                iconOn: "volume_off"
                text: I18n.tr("Mute")
                textOn: I18n.tr("Unmute")
                activeFocusOnTab: true
                onClicked: {
                    SessionData.suppressOSDTemporarily();
                    root.audio.muted = !root.muted;
                }
            }
        ]
    }
}
