pragma ComponentBehavior: Bound

import QtQuick
import qs.Services

// System bus signals through DMS's D-Bus bridge, written once for every source: subscribed while `enabled` and DMS has
// the bridge, dropped when either goes and when the source goes. Each signal received comes out as received(data).
QtObject {
    id: root

    property bool enabled: false
    property string service: ""
    // [interface, member, object path ("" for any object)] per signal.
    property var matches: []
    signal received(var data)

    readonly property bool bridge: root.enabled && DMSService.isConnected && DMSService.capabilities.includes("dbus")
    property var _subs: []
    // Each subscribe or drop starts a round: an answer from an older round (the bridge went and came back before it) is
    // dropped, so a signal is never subscribed twice.
    property int _round: 0
    onBridgeChanged: root.bridge ? root.subscribe() : root.unsubscribe()
    Component.onCompleted: {
        if (root.bridge)
            root.subscribe();
    }
    Component.onDestruction: root.unsubscribe()

    function subscribe() {
        const round = ++root._round;
        const keep = response => {
            const id = response.result?.subscriptionId;
            if (response.error || !id)
                return;
            if (!root.bridge || round !== root._round) {
                DMSService.dbusUnsubscribe(id, null);
                return;
            }
            root._subs = root._subs.concat([id]);
        };
        for (const m of root.matches)
            DMSService.dbusSubscribe("system", root.service, m[2], m[0], m[1], keep);
    }

    function unsubscribe() {
        const ids = root._subs;
        root._subs = [];
        root._round++;
        if (DMSService.isConnected)
            ids.forEach(id => DMSService.dbusUnsubscribe(id, null));
    }

    readonly property Connections bus: Connections {
        target: DMSService
        enabled: root._subs.length > 0

        function onDbusSignalReceived(subscriptionId, data) {
            if (root._subs.indexOf(subscriptionId) !== -1)
                root.received(data);
        }
    }
}
