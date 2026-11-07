import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications

// Open Wi-Fi bubble's open card (kind "openwifi"): Always (the VPN now and by itself on this network next time) and Turn
// on VPN. Without a NetworkManager VPN only the warning shows. Read live from IslandWifiSource.
BubbleCardBase {
    id: card

    readonly property var wifi: card.bubble?.wifi ?? null

    StyledText {
        width: parent.width
        text: card.wifi?.canVpn ? I18n.tr("Others on this network can see your traffic.", "island open wifi bubble: why the VPN") : I18n.tr("No VPN to turn on.", "island open wifi bubble: no NetworkManager VPN profile")
        font.pixelSize: NotificationMetrics.bodySize
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    BubbleActions {
        visible: card.wifi?.canVpn ?? false

        BubbleAction {
            iconName: "repeat"
            text: I18n.tr("Always", "island open wifi bubble: turn on the VPN now and on every next connection to this network")
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Always for this network", "island open wifi bubble: turn on the VPN now and on every next connection")
            onClicked: {
                card.wifi.enableVpn(true);
                card.dismissed(card.bubble);
            }
        }

        BubbleAction {
            role: "primary"
            iconName: "vpn_lock"
            text: I18n.tr("Turn on VPN", "island open wifi bubble: connect the VPN")
            activeFocusOnTab: true
            Accessible.name: text
            onClicked: {
                card.wifi.enableVpn(false);
                card.dismissed(card.bubble);
            }
        }
    }
}
