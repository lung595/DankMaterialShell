.pragma library

// VPN dropped bubble (island, source "vpn"): which VPN went down, and whether the user asked for it.
// Any NetworkManager VPN (OpenVPN, WireGuard, Proton VPN...) as DMSNetworkService lists it in vpnActive.
// A4: this bubble's pure logic, tested by vm (tests/island-vpn.test.mjs).

// How close (ms) a "user disconnected" from NetworkManager must be to the drop to count as wanted.
var userWindow = 5000;

// The name of the VPN that was up when none is any more, "" when nothing dropped. vpnActive also lists connections
// still "activating": one that fails to come up never was up, so it is no drop.
function dropped(before, now) {
    var up = (before || []).filter(function (c) {
        return c && c.state === "activated";
    });
    if ((now || []).length > 0 || up.length === 0)
        return "";
    return up[0].name || up[0].uuid || "?";
}

// The connections last seen up, to judge the next list by: now's activated ones, else (a VPN going down passes through
// "deactivating", one coming back through "activating") the ones seen up before, and none once the list is empty.
function lastUp(last, now) {
    var list = now || [];
    var up = list.filter(function (c) {
        return c && c.state === "activated";
    });
    return up.length > 0 ? up : list.length > 0 ? (last || []) : [];
}

// Whether a VPN is up again: only an activated one, not one still trying.
function backUp(now) {
    return (now || []).some(function (c) {
        return c && c.state === "activated";
    });
}

// The uuid to reconnect to: the dropped one, else DMS's last connected.
function reconnectUuid(before, last) {
    return ((before || [])[0] || {}).uuid || last || "";
}

// busy: DMS itself was disconnecting (its VPN widget, toggle). userAt: when NetworkManager last said an active
// connection was deactivated by the user (nmcli, the Proton VPN app...), 0 = never.
function wanted(busy, userAt, at) {
    return busy === true || (userAt > 0 && Math.abs(at - userAt) <= userWindow);
}

// NetworkManager's Connection.Active StateChanged body: [state, reason]; 4 = deactivated, 2 = user disconnected.
function userDown(body) {
    return !!body && body[0] === 4 && body[1] === 2;
}
