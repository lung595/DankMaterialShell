# Island network bubbles: VPN dropped, incoming SSH, open Wi-Fi

Status: working prototype

## What it does
- VPN dropped: when the last NetworkManager VPN (OpenVPN, WireGuard and others) goes down, the free island shows it first. A cut that the user asked for leaves after 3 seconds. A cut that happened to the user stays as a bubble, with the buttons "Reconnect" and "Cut network", until the VPN is back or the bubble is dismissed. Hovering the bubble holds a short wanted cut.
- "Cut network" drops Wi-Fi and every wired link, so nothing leaves in the clear without the VPN.
- Incoming SSH: when a remote session opens on this machine, the island plays it first, then a bubble stays as long as a session lasts (terminal icon, red dot, address). The card shows one line per session, who and since when, and a "Disconnect" button (held for 2 seconds) that cuts the sessions. The address is hidden while the screen is shared.
- Open Wi-Fi: when you join a network without security, a bubble says others on the network can see your traffic and offers "Turn on VPN" (the last used one first) and "Always for this network". A network marked "Always" turns the VPN on by itself next time, with no bubble. If there is no VPN, it says "No VPN to turn on."

## Why
- These are warnings about things that happen to the user without a clear sign: a VPN that falls, a login from outside, an unsafe network. The author listed VPN and SSH in the table of island bubbles as lasting states.
- The wanted and the unwanted VPN cut are told apart so that a normal disconnect does not leave a bubble behind.

## How it is built
- [`quickshell/Common/IslandVpn.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandVpn.js): plain JavaScript logic. It detects a drop from the connection lists (a connection still "activating" never was up) and remembers the connections last seen up.
- [`quickshell/Modules/DIsland/IslandVpnSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandVpnSource.qml): the source (apps side, `vpn`). It follows `vpnActive` of the DMS network service. "Asked for" means DMS was disconnecting it, or NetworkManager said the user deactivated a connection. The VPN's uuid is read when it drops, so it can be brought back. Card: [`BubbleCardVpn.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardVpn.qml).
- [`quickshell/Common/IslandSsh.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandSsh.js) and [`quickshell/Modules/DIsland/IslandSshSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandSshSource.qml): the sessions come from `loginctl`, re-read when logind sends SessionNew or SessionRemoved (through the DMS D-Bus bridge, or `gdbus monitor` without it). No polling. Sessions already open at start do not "arrive". Cards: [`BubbleCardSsh.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardSsh.qml) and [`BubbleSshGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleSshGlyph.qml).
- [`quickshell/Common/IslandWifi.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandWifi.js) and [`quickshell/Modules/DIsland/IslandWifiSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandWifiSource.qml): the open Wi-Fi bubble (kind `openwifi`). It reacts to SSID changes of the network service, with one `network.info` request when the scan list does not know the network. No timer. Card: [`BubbleCardWifi.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardWifi.qml). The "Always" networks are stored in the session setting `vpnAutoNetworks` ([`quickshell/Common/settings/SessionSpec.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/settings/SessionSpec.js) declares it).
- [`quickshell/Modules/DIsland/IslandBarHost.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBarHost.qml) and [`quickshell/Modules/DIsland/IslandBubbles.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBubbles.qml): the wiring.
- Tests: [`island-vpn.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-vpn.test.mjs), [`island-ssh.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-ssh.test.mjs) and [`island-wifi.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-wifi.test.mjs).

## Known limits
- Never seen running on a test bench: the bench has no NetworkManager and no logind, and there is no command to simulate them. No capture exists.
- Only the pure JavaScript is unit tested. The three sources, the cards and the host wiring are not.
- The open Wi-Fi part was taken out of the first branch of this work (it came back in the system faces branch), so older branches do not have it all in the same place.
- No animation measurement was made.

## Images
No screenshot yet.

