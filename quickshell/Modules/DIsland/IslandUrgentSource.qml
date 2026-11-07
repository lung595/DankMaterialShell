pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../../Common/IslandUrgent.js" as Urgent
import "../../Common/IslandActivities.js" as Activities
import "../../Common/IslandEyes.js" as Eyes

// A window calling for attention (niri's urgent flag), apps side: its icon and title for importantTimeoutMs, a click goes to it.
// The free island shows it whole first (IslandUrgentActivity, "dms:urgent"); a busy one leaves it to the bubble.
// Reacts to NiriService's window list only; its timer runs only while a call shows.
// B9: coded step by step (source, card, island face).
QtObject {
    id: root

    required property IslandController controller
    property string screenName: ""
    // The host's bubblesShown: only the focused screen's island answers a call.
    property bool enabled: true

    readonly property string sourceId: "dms:urgent"
    property var known: []
    // {id, title, image}.
    property var call: null
    property string token: ""

    readonly property var face: root.call && !root.token ? {
        "id": "urgent",
        "source": "urgent",
        "kind": "urgent",
        // Ahead of the other app bubbles: it is the newest and leaves first.
        "seq": 2e6,
        "image": root.call.image,
        "icon": "notifications_active",
        "progress": -1,
        "text": "",
        "title": root.call.title,
        "detail": I18n.tr("Wants your attention", "island urgent window bubble detail"),
        "accent": "primary",
        // Opened for its whole time so the title shows without a hover.
        "open": true
    } : null

    property Connections niri: Connections {
        target: NiriService

        // Only urgency flips, not every focus or layout change.
        function onWindowUrgentChanged() {
            root.refresh();
        }
    }

    property Connections activities: Connections {
        target: IslandActivityService

        // The island let go of the call (its time up, dismissed): it is over.
        function onDropped(token, reason) {
            if (token === root.token) {
                root.token = "";
                root.call = null;
            }
        }
        // Something else took the island: the rest of the call goes to the bubble.
        function onInterrupted(token) {
            if (token !== root.token)
                return;
            root.token = "";
            IslandActivityService.remove(token, "released");
            if (root.call)
                root.brief.restart();
        }
    }

    property Timer brief: Timer {
        interval: Activities.importantTimeoutMs
        onTriggered: root.clear()
    }

    function refresh() {
        const windows = NiriService.windows;
        const next = Urgent.fresh(windows, root.known);
        root.known = Urgent.urgentIds(windows);
        // Answered (focused) or closed: the call ends.
        if (root.call && root.known.indexOf(root.call.id) === -1)
            root.clear();
        if (next)
            root.show(next.id, next.title || next.app_id || "", next.app_id || "");
    }

    function show(id, title, appId) {
        if (!root.enabled)
            return;
        root.clear();
        const image = appId ? Paths.getAppIcon(appId, DesktopEntries.heuristicLookup(appId)) : "";
        root.call = {
            "id": id,
            "title": title,
            "image": image
        };
        if (Eyes.islandFree(root.controller))
            root.token = IslandActivityService.add(root.sourceId, {
                "kind": "glance",
                "timeoutMs": Activities.importantTimeoutMs,
                "screen": root.screenName,
                "data": {
                    "icon": "notifications_active",
                    "title": title,
                    "image": image,
                    "windowId": id
                }
            });
        if (!root.token)
            root.brief.restart();
    }

    function clear() {
        root.brief.stop();
        const token = root.token;
        root.token = "";
        if (token)
            IslandActivityService.remove(token, "released");
        root.call = null;
    }

    // Click: to the window (its workspace and monitor follow), and the call is over.
    function go(windowId) {
        if (windowId >= 0)
            NiriService.focusWindow(windowId);
        root.clear();
    }

    // Hover keeps the bubble; leaving gives it its whole time again.
    function hold(inside) {
        if (inside)
            root.brief.stop();
        else if (root.call && !root.token)
            root.brief.restart();
    }
}
