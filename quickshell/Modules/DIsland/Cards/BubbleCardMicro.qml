pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.Common
import qs.Modules.ControlCenter.Widgets
import qs.Services
import qs.DCommon.Widgets

// Microphone bubble's open card (kind "mic"): the input's name, a live level meter, the apps recording (PrivacyService's
// filter), chips for the other inputs (Control Center's AudioInputDetail list), and the mute toggle in the bottom row.
BubbleCardBase {
    id: card

    readonly property var source: AudioService.source
    readonly property bool muted: source?.audio?.muted ?? false
    readonly property var inputs: {
        const hidden = SessionData.hiddenInputDeviceNames ?? [];
        return AudioService.allNodes.filter(node => node.audio && !node.isSink && !node.isStream && !hidden.includes(node.name));
    }
    readonly property var listeners: AudioService.pipewireNodes.filter(node => node?.properties?.["media.class"] === "Stream/Input/Audio" && !PrivacyService.looksLikeSystemVirtualMic(node))

    // Quickshell's own peak meter on the default source; the loader only keeps the card alive while it is open.
    PwNodePeakMonitor {
        id: meter

        node: AudioService.pipewireReady ? card.source : null
        enabled: !card.muted
    }

    StyledText {
        width: parent.width
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        text: card.source ? AudioService.displayName(card.source) : I18n.tr("No input device")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    M3WaveProgress {
        width: parent.width
        height: Theme.spacingL
        value: card.muted ? 0 : meter.peak
        isPlaying: !card.muted && meter.peak > 0.02
        fillColor: card.muted ? Theme.error : Theme.primary
        playheadColor: fillColor
        Accessible.role: Accessible.ProgressBar
        Accessible.name: I18n.tr("Input level", "island microphone card: level meter")
    }

    Row {
        spacing: Theme.spacingS
        visible: card.listeners.length > 0

        Repeater {
            model: card.listeners

            CcAppIcon {
                required property var modelData

                readonly property string app: modelData.properties?.["application.name"] ?? ""

                appId: modelData.properties?.["application.process.binary"] ?? app
                iconSize: Theme.iconSize
                Accessible.role: Accessible.Graphic
                Accessible.name: app
            }
        }
    }

    DButtonGroup {
        width: parent.width
        visible: card.inputs.length > 1
        fillWidth: true
        checkEnabled: false
        labelOnlySelected: true
        Accessible.role: Accessible.Grouping
        Accessible.name: I18n.tr("Input device", "island microphone card: device picker")
        model: card.inputs.map(node => ({
                    "text": AudioService.displayName(node),
                    "icon": "mic"
                }))
        currentIndex: card.inputs.indexOf(card.source)
        onSelectionChanged: (index, selected) => {
            if (selected)
                AudioService.setDefaultSourceByName(card.inputs[index].name);
        }
    }

    actions: [
        BubbleAction {
            toggle: true
            isOn: card.muted
            enabled: !!card.source?.audio
            iconName: "mic"
            iconOn: "mic_off"
            text: I18n.tr("Mute")
            textOn: I18n.tr("Unmute")
            activeFocusOnTab: true
            onClicked: {
                SessionData.suppressOSDTemporarily();
                card.source.audio.muted = !card.muted;
            }
        }
    ]
}
