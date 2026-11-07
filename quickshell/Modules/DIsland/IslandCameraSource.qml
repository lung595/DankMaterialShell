pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../Common/IslandCamera.js" as Camera
import "../../Common/IslandCall.js" as Call

// The camera bubble (apps side, source "camera", rule B8: its app's logo on the flat pill, a green dot while it films).
// Reads PipeWire's nodes and links only (IslandCamera.js), like the microphone's privacy indicator; no polling.
// A start is told by arrived(); the camera stays as a bubble. Coded as B9 says (source, glyph, card).
QtObject {
    id: root

    property bool enabled: true

    // Video streams are not bound by the audio backend: bind them so their app properties arrive.
    // Quickshell types a stream from its first registry props: one created before its format (Chromium, gst) stays type 0.
    // Capture streams only: IslandCamera.apps reads nothing else.
    readonly property var videoStreams: root.enabled ? Pipewire.nodes.values.filter(n => (n?.isStream && (n.type & PwNodeType.Video)) || n?.properties?.["media.class"] === "Stream/Input/Video") : []
    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: root.videoStreams
    }

    function nodeRow(node) {
        const p = node?.properties ?? {};
        return {
            "cls": p["media.class"] ?? "",
            "stream": node?.isStream ?? false,
            "screen": PrivacyService.looksLikeScreencast(node)
        };
    }
    readonly property var rows: {
        const links = Pipewire.linkGroups.values;
        return root.videoStreams.map(node => {
            const p = node.properties ?? {};
            return {
                "id": node.id,
                "cls": p["media.class"] ?? "",
                "role": p["media.role"] ?? "",
                "screen": PrivacyService.looksLikeScreencast(node),
                "camera": links.some(g => g?.target?.id === node.id && Camera.isCamera(root.nodeRow(g.source))),
                "app": p["application.name"] ?? "",
                "binary": p["application.process.binary"] ?? "",
                "icon": p["application.icon-name"] ?? "",
                "pid": p["application.process.id"] ?? ""
            };
        });
    }
    readonly property var apps: Camera.apps(root.rows)
    readonly property var lead: root.apps.length > 0 ? root.apps[0] : null

    // Right click hides the bubble until an app starts filming; a click on the bubble opens its card.
    property bool dismissed: false
    property bool cardOpen: false
    readonly property bool shown: !!root.lead && !root.dismissed

    signal arrived

    property var lastKeys: []
    // Apps that stopped filming a moment ago, by key: when they left (IslandCamera.arrivals).
    property var left: ({})
    onAppsChanged: {
        const keys = root.apps.map(a => a.key);
        const step = Camera.arrivals(root.lastKeys, keys, root.left, Date.now());
        root.lastKeys = keys;
        root.left = step.left;
        if (!keys.length) {
            root.cardOpen = false;
            return;
        }
        if (step.fresh) {
            root.dismissed = false;
            root.arrived();
        }
    }

    readonly property string unknownApp: I18n.tr("Unknown App", "island camera bubble: app without a name")
    readonly property string appName: root.lead ? root.lead.app || root.unknownApp : ""
    readonly property string names: root.apps.map(a => a.app || root.unknownApp).join(", ")
    readonly property var window: root.lead ? (CompositorService.sortedToplevels ?? []).find(t => Call.sameApp(root.lead, t?.appId)) ?? null : null
    readonly property bool canGoTo: !!root.window

    readonly property var face: ({
            "id": "camera",
            "source": "camera",
            "kind": "camera",
            // Rank among the apps side (B3): ahead of the other app bubbles, after a call: the camera is on the user.
            "seq": Camera.rank,
            "image": root.lead ? Quickshell.iconPath(root.lead.icon, true) : "",
            "icon": root.lead && Quickshell.iconPath(root.lead.icon, true) !== "" ? "" : "videocam",
            "cardIcon": "videocam",
            "progress": -1,
            // No count on the pill (C15): the card's header names every app filming.
            "text": "",
            "title": root.apps.length > 1 ? root.names : root.appName,
            "detail": I18n.tr("Camera", "island camera bubble detail"),
            "accent": "primary",
            "open": root.cardOpen,
            "camera": root
        })

    function goTo() {
        root.cardOpen = false;
        CompositorService.activateToplevel(root.window);
    }
}
