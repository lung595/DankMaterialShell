pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "../../Common/IslandCode2fa.js" as Code
import "../../Common/IslandEyes.js" as Eyes
import "../../Common/IslandActivities.js" as Activities
import "../../Common/IslandCopy.js" as Copy

// A one-time code (2FA) that just came in a notification, apps side: hidden (••• •••) until hovered, then Copy; the copy
// leaves the clipboard 30 s later and never enters its history, or without the DMS server goes after one paste
// (Code.copyPlan). The sending app shows as the icon; a shared screen keeps it masked.
// The free island shows it whole first (IslandCode2faActivity, "dms:code2fa"); a busy one leaves it to the bubble, and
// takes it back once free (its row "Code 2FA" in B8's apps table, coded as B9 says).
// Reacts to NotificationService's new notifications only; its two timers run only while a code is there.
QtObject {
    id: root

    required property IslandController controller
    property string screenName: ""
    // The host's bubblesShown: only the focused screen's island takes a code.
    property bool enabled: true

    readonly property string sourceId: "dms:code2fa"
    readonly property int lifeMs: Activities.importantTimeoutMs
    readonly property int wipeMs: Activities.secretWipeMs // C6

    // {code, app, image}; never logged, never written anywhere but the clipboard on Copy.
    property var entry: null
    property string token: ""
    property var lastWrapper: null
    // A notification older than this is no new code (at startup the newest one can be old).
    readonly property int freshMs: 10000
    // The code put on the clipboard, until the wipe takes it back.
    property string copiedCode: ""
    readonly property bool copied: !!root.entry && root.copiedCode === root.entry.code
    // While the screen is shared the code still comes, but its digits stay masked, even hovered.
    readonly property bool sharing: PrivacyService.screensharingActive

    readonly property var face: root.entry && !root.token ? {
        "id": "code2fa",
        "source": "code2fa",
        "kind": "code2fa",
        "seq": 2e6 + 1,
        "image": root.entry.image,
        "icon": "password",
        "cardIcon": "password",
        "progress": -1,
        "text": "",
        "title": I18n.tr("One-time code", "island 2FA code bubble title"),
        "detail": root.entry.app,
        "accent": "error",
        // The card opens at once on the hidden code; hovering it shows the digits.
        "open": true,
        "copied": root.copied,
        "code2fa": root
    } : null

    // The newest notification DMS took in (its wrappers are appended).
    readonly property QtObject newest: {
        const all = NotificationService.allWrappers;
        return all.length ? all[all.length - 1] : null;
    }
    onNewestChanged: {
        const w = root.newest;
        if (!root.enabled || !w || w === root.lastWrapper)
            return;
        root.lastWrapper = w;
        // At startup the newest one can be old; and a dismissal can bring an older one back to the end.
        if (Date.now() - (w.time?.getTime?.() ?? 0) > root.freshMs)
            return;
        const code = Code.find(w.summary, w.body);
        if (code)
            root.show(code, w.appName || "", w.displayImage || "");
    }

    property Connections activities: Connections {
        target: IslandActivityService

        // The island let go of the code (its time up, dismissed): it is over.
        function onDropped(token, reason) {
            if (token === root.token) {
                root.token = "";
                root.clear();
            }
        }
        // Something else took the island: the rest of the code's time goes to the bubble.
        function onInterrupted(token) {
            if (token === root.token)
                root.release();
        }
    }

    property Timer life: Timer {
        interval: root.lifeMs
        onTriggered: root.clear()
    }
    // When life runs out: a Timer does not tell its time left.
    property real lifeEnd: 0
    property bool hovered: false

    function restartLife() {
        root.life.restart();
        root.lifeEnd = Date.now() + root.life.interval;
    }

    readonly property bool islandFree: Eyes.islandFree(root.controller)
    onIslandFreeChanged: {
        const ms = Code.backToIsland({
            "free": root.islandFree && root.enabled,
            "entry": !!root.entry,
            "token": root.token,
            "copied": root.copied,
            "hovered": root.hovered,
            "left": root.lifeEnd - Date.now()
        });
        if (ms > 0 && root.toIsland(ms))
            root.life.stop();
    }

    // The wipe outlives the bubble: closing the bubble never leaves the code on the clipboard.
    property Timer wipe: Timer {
        interval: root.wipeMs
        onTriggered: root.wipeNow()
    }

    // Holds the code only until wl-copy has read it.
    property Process pasteOnce: Process {
        property string code: ""

        onStarted: {
            write(code);
            code = "";
            stdinEnabled = false;
        }
    }

    // Copied: the info stays a brief info's time (frozen while hovered, from zero once left), then leaves; the wipe goes on unseen.
    property Timer leave: Timer {
        interval: Activities.briefTimeoutMs
        onTriggered: root.clear()
    }

    // PrivacyService only watches the streams while someone holds a ref.
    Component.onCompleted: PrivacyService.addRef()
    Component.onDestruction: PrivacyService.removeRef()

    function show(code, app, image) {
        if (!root.enabled)
            return;
        root.clear();
        root.entry = {
            "code": code,
            "app": app,
            "image": image
        };
        if (!(Eyes.islandFree(root.controller) && root.toIsland(root.lifeMs)))
            root.restartLife();
    }

    function toIsland(ms) {
        root.token = IslandActivityService.add(root.sourceId, {
            "kind": "glance",
            "timeoutMs": ms,
            "screen": root.screenName,
            "data": {
                "icon": "password",
                "image": root.entry.image,
                "code2fa": root
            }
        });
        return root.token !== "";
    }

    // The island gives the code back (taken): what is left of it goes to the bubble.
    function release() {
        const token = root.token;
        if (!token)
            return;
        root.token = "";
        IslandActivityService.remove(token, "released");
        if (root.entry)
            root.restartLife();
    }

    function clear() {
        root.life.stop();
        root.leave.stop();
        root.hovered = false;
        const token = root.token;
        root.token = "";
        if (token)
            IslandActivityService.remove(token, "released");
        root.entry = null;
    }

    function copy() {
        const code = root.entry?.code ?? "";
        if (!code)
            return;
        // The island's own copy: no "copied" bubble for it.
        Copy.markOwnCopy();
        const plan = Code.copyPlan(code, ClipboardService.clipboardAvailable);
        if (plan.request) {
            DMSService.sendRequest(plan.request, plan.params, response => {
                if (response.error)
                    ToastService.showError(I18n.tr("Failed to copy entry", "island 2FA code bubble: the copy failed"));
            });
        } else {
            root.pasteOnce.code = plan.stdin;
            root.pasteOnce.command = plan.command;
            root.pasteOnce.stdinEnabled = true;
            root.pasteOnce.running = true;
        }
        root.copiedCode = code;
        root.wipe.restart();
        root.life.stop();
        // On the island its own timer decides (it freezes on hover): it starts over with the same time.
        if (root.token && root.controller.pluginToken === root.token) {
            root.controller.pluginTimeoutMs = Activities.briefTimeoutMs;
            root.controller.syncPluginTimeout(true);
        } else
            // Clicked from the bubble, the pointer is still on it: it stays while hovered, as hold() says.
            if (root.hovered)
                root.leave.stop();
            else
                root.leave.restart();
    }

    // The core wipes the copy itself (clipboard.copy "secret"), even across a shell restart: here the code just goes.
    function wipeNow() {
        const code = root.copiedCode;
        root.copiedCode = "";
        if (root.entry?.code === code)
            root.clear();
    }

    // Hover keeps the bubble; leaving gives it its time again from zero (after Copy: the leave countdown).
    function hold(inside) {
        root.hovered = inside;
        const timer = Code.heldTimer(!!root.entry, root.token, root.copied);
        if (timer === "leave")
            if (inside)
                root.leave.stop();
            else
                root.leave.restart();
        else if (timer === "life")
            if (inside)
                root.life.stop();
            else
                root.restartLife();
    }
}
