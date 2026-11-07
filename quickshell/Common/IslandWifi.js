.pragma library

// Open Wi-Fi bubble (island, kind "openwifi"): what a new Wi-Fi connection asks of the island.

// "" nothing, "vpn" connect the VPN at once (the network is in the "always" list), "bubble" the open network warning.
// secured: true / false, or null while unknown (nothing is shown on a guess).
function decide(ssid, secured, always, vpnReady, vpnOn) {
    if (!ssid || secured !== false || vpnOn)
        return "";
    return vpnReady && (always || []).indexOf(ssid) !== -1 ? "vpn" : "bubble";
}

// The connected band's security from a `network.info` result; null when the network is not found.
function securedFromInfo(info) {
    const bands = (info && info.bands) || [];
    const band = bands.find(b => b.connected) || bands[0];
    return band ? band.secured === true : null;
}

// The "always use the VPN" list with ssid in it, once.
function remember(always, ssid) {
    const list = always || [];
    return !ssid || list.indexOf(ssid) !== -1 ? list : list.concat([ssid]);
}
