pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandVpn.js" as Vpn

// The VPN dropped bubble (apps side, source "vpn"): when the last VPN goes down it plays in the free island first
// (dropped()), then a cut the user asked for leaves after 3 s, and one that happened to them stays with Reconnect /
// Cut the network until the VPN is back or the bubble is dismissed. Any NetworkManager VPN, from DMSNetworkService's
// vpnActive; "asked for" = DMS was disconnecting it, or NetworkManager said the user deactivated a connection.
// B9: coded step by step (source, card); B2: apps side.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    property string name: ""
    property bool wanted: false
    // A wanted cut that already played in the island needs no bubble after it.
    property bool tookIsland: false
    property bool dismissed: false
    property bool cardOpen: false
    readonly property bool shown: root.enabled && root.name !== "" && !root.dismissed
    readonly property bool bubbleShown: root.shown && !(root.wanted && root.tookIsland)
    readonly property bool busy: DMSNetworkService.vpnIsBusy

    signal dropped

    readonly property var face: ({
            "id": "vpn",
            "source": "vpn",
            "kind": "vpn",
            "seq": 1e5,
            "icon": root.wanted ? "vpn_key_off" : "vpn_key_alert",
            "progress": -1,
            "text": "",
            "title": root.wanted ? I18n.tr("VPN off", "island vpn bubble: the user disconnected the VPN") : I18n.tr("VPN lost", "island vpn bubble: the VPN dropped on its own"),
            "detail": root.name,
            "accent": root.wanted ? "primary" : "error",
            "critical": !root.wanted,
            "open": root.cardOpen,
            "vpn": root
        })

    // The VPNs last seen up (Vpn.lastUp). Not a binding: it must still hold the old list when onVpnActiveChanged runs.
    property var _up: []
    property string _uuid: ""
    // The dropped VPN can be brought back: its uuid was read when it dropped.
    readonly property bool canReconnect: root._uuid !== ""
    property real _droppedAt: 0
    property real _userAt: 0

    function update(now) {
        const before = root._up;
        root._up = Vpn.lastUp(before, now);
        const name = Vpn.dropped(before, now);
        if (name)
            root.drop(name, Vpn.wanted(DMSNetworkService.vpnIsBusy, root._userAt, Date.now()), Vpn.reconnectUuid(before, DMSNetworkService.lastConnectedVpnUuid));
        else if (Vpn.backUp(now) && root.name)
            root.clear();
    }

    function drop(name, wanted, uuid) {
        root.name = name;
        root.wanted = wanted;
        root._uuid = uuid;
        root._droppedAt = Date.now();
        root.dismissed = false;
        root.cardOpen = false;
        root.tookIsland = false;
        if (wanted)
            root.brief.restart();
        else
            root.brief.stop();
        if (root.enabled)
            root.dropped();
    }

    function clear() {
        root.brief.stop();
        root.name = "";
        root.cardOpen = false;
        root.tookIsland = false;
    }

    function dismiss() {
        root.dismissed = true;
        root.cardOpen = false;
    }

    function reconnect() {
        // The bubble goes once vpnActive has the VPN again (update()).
        if (root.canReconnect && !root.busy)
            DMSNetworkService.connectVpn(root._uuid);
    }

    // Without the VPN, nothing should leave in the clear: drop Wi-Fi and every wired link (DMS's own calls).
    function cutNetwork() {
        if (NetworkService.wifiConnected)
            NetworkService.disconnectWifi();
        (NetworkService.ethernetDevices || []).filter(d => d.connected).forEach(d => NetworkService.disconnectEthernetDevice(d.name));
        root.clear();
    }

    // A wanted cut is said briefly.
    readonly property Timer brief: Timer {
        interval: root.controller.transientTimeout
        onTriggered: {
            if (root.wanted)
                root.clear();
        }
    }

    // Hovering the bubble holds a wanted cut.
    function hold(inside) {
        if (!root.shown || !root.wanted)
            return;
        if (inside)
            root.brief.stop();
        else
            root.brief.restart();
    }

    readonly property Connections network: Connections {
        target: DMSNetworkService
        enabled: root.enabled

        function onVpnActiveChanged() {
            root.update(DMSNetworkService.vpnActive);
        }
    }

    Component.onCompleted: root._up = Vpn.lastUp([], DMSNetworkService.vpnActive)

    // NetworkManager tells why a connection went down (nmcli, the Proton VPN app...), through DMS's D-Bus bridge.
    readonly property IslandDbusSignals bus: IslandDbusSignals {
        enabled: root.enabled
        service: "org.freedesktop.NetworkManager"
        matches: [["org.freedesktop.NetworkManager.Connection.Active", "StateChanged", ""]]

        onReceived: data => {
            if (!Vpn.userDown(data?.body))
                return;
            root._userAt = Date.now();
            // The reason can come just after the drop: the cut was wanted after all.
            if (root.name && !root.wanted && Math.abs(root._userAt - root._droppedAt) <= Vpn.userWindow) {
                root.wanted = true;
                root.brief.restart();
            }
        }
    }
}
