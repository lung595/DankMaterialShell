pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../../Common/IslandReopen.js" as Reopen

// Reopen bubble (source "reopen", apps side): the last niri window of an app that keeps running in the background
// (SettingsData.islandReopenApps) was closed; for a few seconds a click shows it again by launching its desktop entry,
// which a single-instance app (Signal, Discord, Steam) answers by raising its window. Reacts to NiriService.windows only;
// the countdown is one animation that runs only while the bubble shows.
// B9: coded step by step (source, card, island face).
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true
    readonly property int duration: root.controller.transientTimeout

    readonly property var apps: Reopen.parseApps(SettingsData.islandReopenApps)
    // App ids, newest close first.
    property var stack: []
    // The app the free island last showed, kept after the countdown so its face never goes blank.
    property string lastApp: ""
    // 1 to 0 over the countdown; the glyph's ring reads it, the faces do not (no list rebuild per frame).
    property real remaining: 1
    readonly property bool shown: root.enabled && root.stack.length > 0

    // A new close: the bar host gives it to the free island first.
    signal arrived

    property var known: []
    readonly property var windows: NiriService.windows
    onWindowsChanged: {
        const now = root.windows || [];
        const closed = Reopen.closedApps(root.known, now, root.apps);
        root.known = now;
        if (root.enabled)
            closed.forEach(appId => root.closed(appId));
    }

    readonly property NumberAnimation countdown: NumberAnimation {
        target: root
        property: "remaining"
        from: 1
        to: 0
        duration: root.duration
        onFinished: root.clear()
    }

    // While the free island shows the close itself, the bubble's wait; they start once the island lets it go.
    readonly property bool onIsland: root.controller.activeActivity === "reopen"
    onOnIslandChanged: {
        if (root.onIsland)
            root.countdown.stop();
        else if (root.stack.length)
            root.countdown.restart();
    }

    function closed(appId) {
        root.stack = Reopen.push(root.stack, appId, Reopen.depth);
        root.lastApp = appId;
        root.countdown.restart();
        root.arrived();
    }

    function clear() {
        root.countdown.stop();
        root.stack = [];
    }

    function forget(appId) {
        root.stack = root.stack.filter(other => other !== appId);
        if (!root.stack.length)
            root.countdown.stop();
    }

    // Hovering keeps the bubble; leaving gives it the time it had left.
    function hold(inside) {
        if (!root.countdown.running)
            return;
        if (inside)
            root.countdown.pause();
        else
            root.countdown.resume();
    }

    // The wheel walks back through older closes; each step gives the newly shown one the full time again.
    function wheel(dir) {
        if (root.stack.length < 2 || !dir)
            return;
        root.stack = Reopen.rotate(root.stack, dir);
        root.countdown.restart();
    }

    function entryOf(appId) {
        return appId ? DesktopEntries.heuristicLookup(Paths.moddedAppId(appId)) : null;
    }

    function nameOf(appId) {
        return root.entryOf(appId)?.name || appId;
    }

    function reopen(appId) {
        const id = appId || root.stack[0] || root.lastApp;
        if (!id)
            return;
        const entry = root.entryOf(id);
        if (entry)
            SessionService.launchDesktopEntry(entry);
        else
            ToastService.showError(I18n.tr("Could not reopen %1", "island reopen bubble: no desktop entry for the app").arg(id));
        root.forget(id);
    }

    // The island's own face (system kind "reopen").
    function titleOf(appId) {
        return I18n.tr("%1 closed", "island reopen bubble title: the app whose window was closed").arg(root.nameOf(appId));
    }
    readonly property string title: root.titleOf(root.stack[0] || root.lastApp)
    readonly property string action: I18n.tr("Reopen", "island reopen bubble: shows the closed app again")
    // One face per close, newest first: the wing shows the first and counts the others (+N).
    readonly property var faces: root.stack.map((appId, index) => ({
                "id": "reopen:" + appId,
                "source": "reopen",
                "kind": "reopen",
                "seq": 2e6 - index,
                "app": appId,
                "icon": "",
                "mark": "replay",
                "progress": -1,
                "text": root.action,
                "title": root.titleOf(appId),
                "detail": I18n.tr("Click to reopen", "island reopen bubble detail"),
                "accent": "primary",
                "reopen": root
            }))
}
