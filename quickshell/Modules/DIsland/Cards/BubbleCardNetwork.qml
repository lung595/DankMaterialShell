import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Notifications

// Network bubble's open card (kind "network"): the link (Wi-Fi SSID and signal, or Ethernet), the VPN state, and a link
// to DMS's network settings in the bottom row. Labels and states mirror the Control Center's NetworkTile and VpnWidget.
// Each row's icon sits in the header icon's column, its label in the title's.
BubbleCardBase {
    id: card

    readonly property bool vpnActivating: DMSNetworkService.vpnIsBusy || DMSNetworkService.activeState === "activating"
    readonly property bool vpnActivated: DMSNetworkService.connected && DMSNetworkService.activeState === "activated"
    readonly property var rows: [
        {
            icon: NetworkService.ethernetConnected ? "settings_ethernet" : NetworkService.wifiSignalIcon,
            label: NetworkService.ethernetConnected ? I18n.tr("Ethernet", "network status") : (NetworkService.wifiConnected && NetworkService.currentWifiSSID) || (NetworkService.wifiEnabled ? I18n.tr("Not connected", "network status") : I18n.tr("WiFi is off", "network status")),
            value: NetworkService.ethernetConnected ? I18n.tr("Connected", "network status") : NetworkService.wifiConnected && NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : ""
        },
        {
            icon: "vpn_key",
            label: I18n.tr("VPN", "virtual private network, widget and page title"),
            value: card.vpnActivating ? I18n.tr("Connecting...") : !card.vpnActivated ? I18n.tr("Disconnected") : (DMSNetworkService.activeNames || [])[0] || I18n.tr("Connected"),
            hidden: !DMSNetworkService.vpnAvailable
        }
    ]

    Repeater {
        model: card.rows.filter(row => !row.hidden)

        Item {
            required property var modelData

            width: parent.width
            height: Theme.buttonHeightS
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.label + (modelData.value ? ", " + modelData.value : "")

            DIcon {
                anchors.horizontalCenter: parent.left
                anchors.horizontalCenterOffset: NotificationMetrics.appIconSize / 2
                anchors.verticalCenter: parent.verticalCenter
                name: parent.modelData.icon
                size: Theme.iconSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: NotificationMetrics.appIconSize + NotificationMetrics.iconSpacing
                anchors.right: rowValue.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: parent.modelData.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
            }

            StyledText {
                id: rowValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.value
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    actions: [
        BubbleAction {
            role: "quiet"
            iconName: "settings"
            text: I18n.tr("Network settings", "island network card: action")
            activeFocusOnTab: true
            onClicked: PopoutService.openSettingsWithTab(NetworkService.ethernetConnected ? "network_ethernet" : "network_wifi")
        }
    ]
}
