pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../Common/IslandCall.js" as Call
import "../../Common/IslandKit.js" as Kit

// The call bubble (apps side, source "call"): an app in a call (it records the microphone and plays back, or tags its
// stream as a phone call; IslandCall.js), its icon, how long and whether its microphone is cut. Reacts to PipeWire's
// node list only; the duration ticks once a second only while a call is on. A new call emits arrived()
// for the host, then the call stays as a bubble.
//
// API for the card (every action touches the call app's own PipeWire streams, never the system microphone or output):
// - appName, face.image: from the app's desktop entry, found by its binary (Discord's streams say "WEBRTC VoiceEngine").
// - muted / toggleMute(): the app's recording streams. The app's own mute button doesn't know.
// - deafened / toggleDeafen(), deafen(), undeafen(): the app's playback streams.
// - canHangUp / hangUp(): only through the app's own "Hang up" notification action. No desktop API ends a call, and
//   Discord's local RPC needs an approved client for voice control, so for Discord the card offers canGoTo / goTo().
// B9: coded step by step (source, glyph, card); B2: apps side.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    readonly property var streamRows: {
        const rows = [];
        for (const node of AudioService.pipewireNodes) {
            const cls = node?.properties?.["media.class"] ?? "";
            const input = cls === "Stream/Input/Audio";
            if (!input && cls !== "Stream/Output/Audio")
                continue;
            if (input && PrivacyService.looksLikeSystemVirtualMic(node))
                continue;
            const p = node.properties;
            rows.push({
                "id": node.id,
                "input": input,
                "app": p["application.name"] ?? "",
                "binary": p["application.process.binary"] ?? "",
                "icon": p["application.icon-name"] ?? "",
                "pid": p["application.process.id"] ?? "",
                "role": p["media.role"] ?? "",
                "muted": node.audio?.muted ?? false
            });
        }
        return rows;
    }
    readonly property var calls: root.enabled && AudioService.pipewireReady ? Call.calls(root.streamRows) : []
    readonly property var lead: root.calls.length > 0 ? root.calls[0] : null
    readonly property var entry: {
        for (const name of Call.entryNames(root.lead)) {
            const e = DesktopEntries.heuristicLookup(name);
            if (e)
                return e;
        }
        return null;
    }
    readonly property string appIcon: root.entry?.icon || (root.lead?.icon ?? "")
    function nodesOf(ids) {
        return (ids ?? []).map(id => AudioService.pipewireNodes.find(n => n?.id === id)).filter(n => !!n);
    }
    readonly property var inputNodes: root.nodesOf(root.lead?.inputs)
    readonly property var outputNodes: root.nodesOf(root.lead?.outputs)
    // Stream nodes only carry their mute once bound.
    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: root.inputNodes.concat(root.outputNodes)
    }
    readonly property bool muted: !!root.lead && root.lead.muted
    readonly property bool deafened: !!root.lead && !!root.lead.deafened

    // Video capture streams, only while a call is on (the audio backend doesn't bind them).
    // Right click hides the bubble until the next call; a click on the bubble opens its card.
    property bool dismissed: false
    property bool cardOpen: false
    readonly property bool shown: !!root.lead && !root.dismissed

    signal arrived

    // When each app's call started (key -> ms), kept across PipeWire's stream churn while the app stays in the call.
    property var started: ({})
    property string lastKey: ""
    onCallsChanged: {
        const keys = root.calls.map(c => c.key);
        const next = {};
        let isNew = false;
        for (const c of root.calls) {
            next[c.key] = c.startedAt ?? root.started[c.key] ?? Date.now();
            if (root.started[c.key] === undefined)
                isNew = true;
        }
        root.started = next;
        root.now = Date.now();
        const joined = keys.join("|");
        if (joined === root.lastKey)
            return;
        root.lastKey = joined;
        if (!keys.length)
            root.cardOpen = false;
        if (isNew) {
            root.dismissed = false;
            root.arrived();
        }
    }

    property real now: Date.now()
    readonly property Timer tick: Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        // Frozen behind the lock and with the screens off: nobody reads the duration then.
        running: !SessionService.locked && !IdleService.monitorsOff && (root.shown || root.controller.activeActivity === "call")
        onTriggered: root.now = Date.now()
    }
    readonly property string durationText: root.lead ? Call.duration((root.now - (root.started[root.lead.key] ?? root.now)) / 1000) : ""
    readonly property string appName: root.lead ? root.entry?.name || root.lead.app || I18n.tr("Unknown App", "island call bubble: call without an app name") : ""

    // The app's window, to bring the call forward.
    readonly property var window: root.lead ? (CompositorService.sortedToplevels ?? []).find(t => Call.sameApp(root.lead, t?.appId)) ?? null : null
    // The app's own "Hang up" / "Decline" from its call notification, when it offers one; no desktop API ends a call.
    readonly property var hangUpAction: {
        if (!root.lead)
            return null;
        for (const w of NotificationService.notifications) {
            if (!w || !Call.sameApp(root.lead, w.appName))
                continue;
            const i = Call.hangUpAction(w.actions);
            if (i >= 0)
                return w.actions[i];
        }
        return null;
    }
    readonly property bool canHangUp: !!root.hangUpAction
    readonly property bool canGoTo: !!root.window

    readonly property var face: ({
            "id": "call",
            "source": "call",
            "kind": "call",
            // Ahead of the other app bubbles of its rank: a call is what the user is doing.
            "seq": 2e6,
            "app": root.appIcon,
            "image": root.lead ? Quickshell.iconPath(root.appIcon, true) : "",
            // Without an app icon, the phone (the pill draws icon over image); the card's header always has its glyph.
            "icon": root.lead && Quickshell.iconPath(root.appIcon, true) !== "" ? "" : "call",
            "cardIcon": root.muted ? "mic_off" : "call",
            "muted": root.muted,
            "deafened": root.deafened,
            "progress": -1,
            "text": root.durationText,
            "valued": true,
            // Upright the pill is one icon wide: past ten minutes the duration says whole minutes ("12m").
            "standText": root.lead ? Kit.standClock((root.now - (root.started[root.lead.key] ?? root.now)) / 1000, I18n.tr("%1m"), I18n.tr("%1h", "hours abbreviation, %1 is a number")) : "",
            "title": root.appName,
            "detail": root.muted ? I18n.tr("Call · microphone off", "island call bubble detail") : I18n.tr("Call in progress", "island call bubble detail"),
            "accent": "primary",
            "open": root.cardOpen,
            "call": root
        })

    function setStreams(field, nodes, on) {
        if (!root.lead)
            return;
        for (const node of nodes)
            if (node.audio)
                node.audio.muted = on;
    }
    // Turning the microphone back on while deafened ends the deafen too (as Discord does): the badge never says "muted"
    // over an open microphone, and undeafen never takes back a microphone turned on by hand.
    function toggleMute() {
        const next = !root.muted;
        root.mutedBeforeDeafen = next;
        if (root.deafened && !next)
            return root.undeafen();
        root.setStreams("muted", root.inputNodes, next);
    }
    // Deafened cuts the call's sound and its microphone (the badge says both); undeafened, the microphone goes back as it was.
    property bool mutedBeforeDeafen: false
    function deafen() {
        if (!root.deafened)
            root.mutedBeforeDeafen = root.muted;
        root.setStreams("deafened", root.outputNodes, true);
        root.setStreams("muted", root.inputNodes, true);
    }
    function undeafen() {
        root.setStreams("deafened", root.outputNodes, false);
        root.setStreams("muted", root.inputNodes, root.mutedBeforeDeafen);
    }
    function toggleDeafen() {
        if (root.deafened)
            root.undeafen();
        else
            root.deafen();
    }

    function hangUp() {
        root.hangUpAction?.invoke();
    }

    function goTo() {
        root.cardOpen = false;
        CompositorService.activateToplevel(root.window);
    }
}
