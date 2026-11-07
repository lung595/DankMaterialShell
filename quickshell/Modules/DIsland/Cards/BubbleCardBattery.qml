import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// Battery bubble's open card (kinds "battery" and "charging"): time to empty/full, power draw, and the power profile,
// built like the bar's battery popout (BatteryPopoutContent) from BatteryService and PowerProfileWatcher.
BubbleCardBase {
    id: card

    // Same line as the popout: "Discharging · 3h 12m (17:40) · -8.4 W"; parts that are unknown are left out.
    readonly property string timeInfo: {
        const parts = [BatteryService.batteryStatus];
        const time = BatteryService.formatTimeRemaining();
        if (time !== "Unknown") {
            const estimated = BatteryService.formatEstimatedTime();
            parts.push(estimated ? `${time} (${estimated})` : time);
        }
        const rate = BatteryService.signedChangeRate;
        if (rate !== 0)
            parts.push((rate > 0 ? "+" : "") + rate.toFixed(1) + " W");
        return parts.join(" · ");
    }

    StyledText {
        width: parent.width
        visible: BatteryService.batteryAvailable
        text: card.timeInfo
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    DButtonGroup {
        readonly property var profiles: PowerProfileWatcher.availableProfiles

        width: parent.width
        visible: PowerProfileWatcher.available
        fillWidth: true
        labelOnlySelected: true
        checkEnabled: false
        Accessible.role: Accessible.Grouping
        Accessible.name: I18n.tr("Power profile")
        model: profiles.map(profile => ({
                    text: Theme.getPowerProfileLabel(profile),
                    icon: ["eco", "speed", "bolt"][profile]
                }))
        currentIndex: profiles.indexOf(PowerProfileWatcher.currentProfile)
        onSelectionChanged: (index, selected) => {
            if (selected && !PowerProfileWatcher.applyProfile(profiles[index]))
                ToastService.showError(I18n.tr("Failed to set power profile"));
        }
    }
}
