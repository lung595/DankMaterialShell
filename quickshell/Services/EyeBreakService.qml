pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../Common/IslandEyes.js" as Eyes
import "../Common/IslandKit.js" as Kit

// Eye break (20-20-20): off unless the user turns it on in the island settings. One timer, stopped while off or locked:
// it waits the interval, then ticks each second through the break. A free island takes the break whole (activity
// "dms:eyes"); a busy one, or one that gets busy meanwhile, leaves it to its machine bubble (kind "eyes", left side).
// Never over a fullscreen window nor during a call (mic, camera or screen share in use): the break waits one interval.
Singleton {
    id: root

    readonly property string sourceId: "dms:eyes"
    readonly property bool enabled: SettingsData.islandEyeBreak
    property bool resting: false
    property int remaining: 0
    property int length: 0
    // "island" or "bubble" while resting.
    property string shownIn: ""
    property string token: ""
    property string screen: ""
    readonly property string countdown: Kit.standClock(root.remaining, I18n.tr("%1m"), I18n.tr("%1h", "hours abbreviation, %1 is a number"))
    readonly property real progress: root.length > 0 ? root.remaining / root.length : 0

    function begin() {
        const screen = CompositorService.getFocusedScreenName();
        if (SessionService.locked || Eyes.deferred(CompositorService.fullscreenToplevelOnScreen(screen), PrivacyService.microphoneActive, PrivacyService.cameraActive, PrivacyService.screensharingActive)) {
            return false;
        }
        root.finish();
        root.screen = screen;
        root.length = Eyes.durationSec(SettingsData.islandEyeBreakDuration);
        root.remaining = root.length;
        root.resting = true;
        if (Eyes.route(IslandActivityService.islandsFor(screen)) === "island")
            root.token = IslandActivityService.add(root.sourceId, {
                "kind": "live",
                "screen": screen,
                "data": {
                    "icon": "visibility",
                    "title": I18n.tr("Eye break", "island eye break title")
                }
            });
        root.shownIn = root.token ? "island" : "bubble";
        root.keepBubble();
        return true;
    }

    function skip() {
        root.finish();
    }

    function finish() {
        const token = root.token;
        root.token = "";
        root.resting = false;
        root.remaining = 0;
        if (token)
            IslandActivityService.remove(token, "released");
        if (root.shownIn === "bubble")
            for (const island of IslandActivityService.islandsFor(root.screen))
                if (island.machineBubbleKind === "eyes")
                    island.hideMachineBubble();
        root.shownIn = "";
    }

    // The machine bubble fades after a few seconds: each tick shows it again, also after another bubble took its place.
    function keepBubble() {
        if (root.shownIn !== "bubble")
            return;
        for (const island of IslandActivityService.islandsFor(root.screen))
            if (island.bubblesEnabled && (island.machineBubbleKind === "" || island.machineBubbleKind === "eyes"))
                island.showMachineBubble("eyes");
    }

    function tick() {
        if (--root.remaining <= 0) {
            root.skip();
            return;
        }
        root.keepBubble();
    }

    Timer {
        id: clock

        running: (root.enabled && !SessionService.locked) || root.resting
        interval: root.resting ? 1000 : Eyes.intervalMs(SettingsData.islandEyeBreakInterval)
        repeat: true
        onTriggered: root.resting ? root.tick() : root.begin()
    }

    // PrivacyService only watches the streams while someone holds a ref.
    onEnabledChanged: root.enabled ? PrivacyService.addRef() : PrivacyService.removeRef()
    Component.onCompleted: {
        if (root.enabled)
            PrivacyService.addRef();
    }

    Connections {
        target: IslandActivityService

        // Something else took the island: the break goes on in the machine bubble.
        function onInterrupted(token) {
            if (token !== root.token)
                return;
            root.token = "";
            IslandActivityService.remove(token, "released");
            root.shownIn = "bubble";
            root.keepBubble();
        }

        function onDropped(token, reason) {
            if (token === root.token && reason !== "released")
                root.skip();
        }
    }
}
