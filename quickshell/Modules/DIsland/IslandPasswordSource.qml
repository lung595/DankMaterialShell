pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import "../../Common/IslandPassword.js" as Password
import "../../Common/IslandActivities.js" as Activities

// Password copied bubble (source "password", apps side): a password manager put a secret on the clipboard (its
// x-kde-passwordManagerHint, which DMS never stores). It plays in the free island first (arrived()), then stays as a
// bubble: the manager's icon (a padlock when unknown) in a ring that empties over 30 s, never the copied text. A click
// clears it now; after 30 s DMS clears the clipboard, only if it still holds that copy. Hidden while the screen is shared.
// Reacts to DMS's clipboard state only; the countdown runs only while a copy is held.
QtObject {
    id: root

    property bool enabled: true
    readonly property int duration: Activities.secretWipeMs // C6

    // The clipboard holds a password copy.
    property bool held: false
    // The password manager it came from (the focused app at copy time), "" = unknown.
    property string app: ""
    property bool dismissed: false
    // 1 to 0 over the 30 s, in steps of stepShare; the glyph's ring reads it, the faces do not (no list rebuild per step).
    property real remaining: 1
    readonly property real stepShare: 0.01
    // When the copy came (ms): the steps are read off it, so a hidden spell skips ahead instead of pausing the ring.
    property real copiedAt: 0
    property int last: -1
    readonly property bool sharing: PrivacyService.screensharingActive
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    readonly property bool shown: root.enabled && root.held && !root.dismissed && !root.sharing

    signal arrived

    readonly property Connections clipboard: Connections {
        target: DMSService
        function onClipboardStateUpdate(data) {
            const s = Password.step(data, root.last);
            root.last = s.last;
            if (s.copied)
                root.copied(Password.managerOf(ToplevelManager.activeToplevel?.appId));
            else if (s.gone)
                root.release();
        }
    }

    // The deadline: one shot, the clipboard is cleared even with reduced motion (the ring then stays full).
    readonly property Timer deadline: Timer {
        interval: root.duration
        onTriggered: root.clearNow()
    }
    // Upright beside the launcher: the time left before the clipboard is cleared drains the volume's liquid, in steps of
    // about a pixel of the tile (the liquid's own spring smooths them), never a new face per frame.
    readonly property real standLevel: Math.ceil(root.remaining * 100) / 100
    // One step every 300 ms (1 % of 30 s), only while the bubble shows and moves: nothing ticks while it is hidden,
    // shared away or in reduced motion (the ring then stays full).
    readonly property Timer countdown: Timer {
        interval: root.duration * root.stepShare
        repeat: true
        triggeredOnStart: true
        running: root.shown && !root.still && root.remaining > 0
        onTriggered: root.remaining = Math.max(0, Math.ceil((1 - (Date.now() - root.copiedAt) / root.duration) / root.stepShare) * root.stepShare)
    }

    function copied(appId) {
        root.app = appId;
        root.held = true;
        root.dismissed = false;
        root.remaining = 1;
        root.copiedAt = Date.now();
        root.deadline.restart();
        if (root.enabled && !root.sharing)
            root.arrived();
    }

    function release() {
        root.held = false;
        root.deadline.stop();
    }

    // "Clear now": DMS empties the clipboard only if it still holds the password copy, never a later one.
    function clearNow() {
        if (!root.held)
            return;
        DMSService.sendRequest("clipboard.clearSecret", null, null);
        root.release();
    }

    // Right click: the bubble goes, the 30 s clear still happens.
    function dismiss() {
        root.dismissed = true;
    }

    // The bubble's own texts (its card and its pill's label): the island has no password face.
    readonly property string title: I18n.tr("Password copied", "island password bubble title")
    readonly property string detail: I18n.tr("Clears in 30 s · click to clear now", "island password bubble detail")
    // The pill shows the manager's icon alone (the kit's flower outline), else a padlock; never a gauge.
    readonly property string image: root.app ? Paths.getAppIcon(root.app, DesktopEntries.heuristicLookup(root.app)) : ""
    // Its place on the apps side (B3): with a copy's (3e6), above a call's (2e6) and the plugins' bubbles.
    readonly property real seq: 3e6
    readonly property var face: ({
            "id": "password",
            "source": "password",
            "kind": "password",
            "seq": root.seq,
            "app": root.app,
            "image": root.image,
            "icon": root.image === "" ? "lock" : "",
            "progress": -1,
            "text": "",
            "title": root.title,
            "detail": root.detail,
            "accent": "primary",
            "standLevel": root.standLevel,
            "password": root
        })
}
