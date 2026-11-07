import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandWifi.js" as Wifi

// Open Wi-Fi (kind "openwifi"): a new connection to a network without security asks for the VPN (any NetworkManager VPN,
// the last used one first); a network marked "always" connects the VPN at once, without a bubble.
// Reacts to NetworkService's SSID changes, then one network.info request when the scan list does not know the network;
// no timer, no polling.
QtObject {
    id: root

    signal openNetwork

    readonly property string connectedSsid: NetworkService.wifiConnected ? NetworkService.currentWifiSSID : ""
    // The open network the bubble is about, kept while the bubble shows.
    property string ssid: ""
    readonly property bool vpnReady: DMSNetworkService.vpnAvailable && DMSNetworkService.vpnProfiles.length > 0
    readonly property bool canVpn: root.vpnReady && !DMSNetworkService.vpnConnected
    // The network's name stays off the screen while it is shared.
    readonly property string label: PrivacyService.screensharingActive ? "" : root.ssid

    onConnectedSsidChanged: {
        const ssid = root.connectedSsid;
        if (!ssid)
            return;
        const known = NetworkService.wifiNetworks.find(n => n.ssid === ssid && n.connected) ?? NetworkService.wifiNetworks.find(n => n.ssid === ssid);
        if (known && known.secured !== undefined) {
            root.act(ssid, known.secured === true);
            return;
        }
        if (!DMSService.isConnected)
            return;
        DMSService.sendRequest("network.info", {
            "ssid": ssid
        }, response => {
            if (!response.error && root.connectedSsid === ssid)
                root.act(ssid, Wifi.securedFromInfo(response.result));
        });
    }

    function act(ssid, secured) {
        switch (Wifi.decide(ssid, secured, SessionData.vpnAutoNetworks, root.vpnReady, DMSNetworkService.vpnConnected)) {
        case "vpn":
            DMSNetworkService.toggleVpn();
            break;
        case "bubble":
            root.ssid = ssid;
            root.openNetwork();
            break;
        }
    }

    // always: next time on this network the VPN connects by itself.
    function enableVpn(always) {
        if (always)
            SessionData.set("vpnAutoNetworks", Wifi.remember(SessionData.vpnAutoNetworks, root.ssid));
        if (!DMSNetworkService.vpnConnected)
            DMSNetworkService.toggleVpn();
    }
}
