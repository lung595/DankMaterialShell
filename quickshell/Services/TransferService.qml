pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services

// Transfers the core sees (dms server, "transfers"): file copies and archive extractions read from /proc/<pid>/fdinfo, and
// qBittorrent's torrents when its Web UI listens on 127.0.0.1. [{"id", "kind", "name", "app", "appId", "done", "total",
// "paused", "canPause", "canCancel", "error", "path"}]. Subscribed only while something wants them.
Singleton {
    id: root

    readonly property bool available: DMSService.isConnected && DMSService.capabilities.includes("transfers")
    // How many islands' transfers sources are on (one per screen and the free island).
    property int wanters: 0
    readonly property bool wanted: root.wanters > 0
    property var transfers: []

    onAvailableChanged: root.ensureSubscription()
    onWantedChanged: root.ensureSubscription()

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected)
                root.ensureSubscription();
        }

        function onTransfersStateUpdate(data) {
            root.transfers = data?.transfers ?? [];
        }
    }

    function ensureSubscription() {
        const subscribed = DMSService.activeSubscriptions.includes("transfers");
        if (!root.wanted || !root.available) {
            if (subscribed)
                DMSService.removeSubscription("transfers");
            // Not wanted, or the service went: no row stays on show from before.
            root.transfers = [];
            return;
        }
        if (!subscribed && !DMSService.activeSubscriptions.includes("all"))
            DMSService.addSubscription("transfers");
    }

    // done(ok), when given: whether the core took the action; without DMS's transfers service it cannot (false at once).
    function act(method, ids, done) {
        if (!ids.length)
            return;
        if (!root.available) {
            done?.(false);
            return;
        }
        DMSService.sendRequest(method, {
            "ids": ids
        }, response => done?.(!response?.error));
    }
    function pause(ids, done) {
        root.act("transfers.pause", ids, done);
    }
    function resume(ids, done) {
        root.act("transfers.resume", ids, done);
    }
    // A torrent is removed (its files kept); the user's own copy or archive tool gets SIGTERM (canCancel says which).
    function cancel(ids, done) {
        root.act("transfers.cancel", ids, done);
    }
}
