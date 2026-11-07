import QtQuick
import qs.Common
import qs.Modules.DIsland.Kit

// VPN dropped bubble's open card (source "vpn"): under the header (VPN off / lost, its name), a cut that happened on its
// own offers Cut the network (held 2 s) and Reconnect. Read live from the bubble's source (IslandVpnSource).
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var vpn: card.bubble?.vpn ?? null

    BubbleActions {
        visible: !(card.vpn?.wanted ?? true)

        IslandHoldButton {
            iconName: "wifi_off"
            text: I18n.tr("Cut network", "island vpn bubble: disconnect Wi-Fi and wired so nothing leaves without the VPN")
            activeFocusOnTab: true
            Accessible.name: text
            onConfirmed: card.vpn?.cutNetwork()
        }

        BubbleAction {
            role: "primary"
            iconName: "vpn_key"
            text: I18n.tr("Reconnect", "island VPN card: action")
            busy: card.vpn?.busy ?? false
            enabled: (card.vpn?.canReconnect ?? false) && !(card.vpn?.busy ?? true)
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Reconnect %1", "island vpn bubble: reconnect button").arg(card.bubble?.detail ?? "")
            onClicked: card.vpn?.reconnect()
        }
    }
}
