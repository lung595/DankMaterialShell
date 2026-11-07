import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// Brightness bubble's open card (kind "brightness"): the screen's name, DMS's brightness slider (its icon before the track)
// and the night mode toggle in the bottom row, on the same services and device as the bubble and the brightness OSD
// (BrightnessService.getCurrentDeviceInfo()).
BubbleCardBase {
    id: card

    readonly property var device: BrightnessService.getCurrentDeviceInfo()
    readonly property string screenName: Screen.name
    readonly property var shellScreen: Quickshell.screens.find(s => s.name === card.screenName) ?? null

    StyledText {
        width: parent.width
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        // Same naming as the Control Center's brightness detail: the screen's display name, else the device's title.
        text: card.shellScreen ? SettingsData.getScreenDisplayName(card.shellScreen) : (card.screenName || BrightnessService.deviceTitle(card.device))
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        visible: text.length > 0
    }

    DSlider {
        id: slider

        width: parent.width
        enabled: BrightnessService.brightnessAvailable && !!card.device
        minimum: BrightnessService.brightnessMinimum(card.device)
        maximum: BrightnessService.brightnessMaximum(card.device)
        unit: BrightnessService.brightnessUnit(card.device)
        startIcon: BrightnessService.brightnessIconName(card.device)
        Accessible.name: I18n.tr("Brightness")
        onSliderValueChanged: newValue => BrightnessService.setBrightness(newValue, BrightnessService.lastIpcDevice, true)

        Binding {
            target: slider
            property: "value"
            value: BrightnessService.brightnessLevel
            restoreMode: Binding.RestoreNone
            when: !slider.isDragging
        }
    }

    actions: [
        BubbleAction {
            toggle: true
            isOn: NightModeService.nightModeEnabled
            enabled: NightModeService.automationAvailable
            iconName: "nightlight"
            text: I18n.tr("Night mode")
            activeFocusOnTab: true
            Accessible.name: text
            onClicked: NightModeService.toggleNightMode()
        }
    ]
}
