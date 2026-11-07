import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Services

// A Scope, not a PluginComponent: the service parents daemons to itself, and an Item there is never placed in a scene.
Scope {
    id: root

    property string pluginId: ""
    property var pluginService: null
    property string token: ""

    // notifyApp: the app name of this request's notifications; empty keeps the manifest's island.notifyApp.
    function show(kind, notifyApp) {
        root.token = IslandActivityService.request(root.pluginId, {
            "kind": kind,
            "notifyApp": notifyApp ?? "",
            "data": {
                "label": kind === "alert" ? "Pasta" : kind === "live" ? "Tea" : "Connected"
            }
        });
        return root.token || "REFUSED";
    }

    function pin(side, face) {
        return IslandActivityService.setPermanent(root.pluginId, side === "off" ? null : {
            "side": side === "left" ? "left" : "right",
            "label": "Send to Example",
            "image": Qt.resolvedUrl("jellyfish.svg"),
            "bubbleContent": face
        }) ? "PERMANENT: " + side : "REFUSED";
    }

    // Sized by the bubble, from its mini size to a full bubble while a file is held over it.
    property Component drawnFace: Rectangle {
        id: drawn

        readonly property real iconShare: 0.6

        radius: width / 2
        color: Theme.primary

        DIcon {
            anchors.centerIn: parent
            name: "timer"
            size: drawn.width * drawn.iconShare
            color: Theme.onPrimary
        }
    }

    Connections {
        target: IslandActivityService

        function onDropped(token, reason) {
            if (token === root.token)
                root.token = "";
        }
    }

    IpcHandler {
        target: "islandActivityExample"

        function request(kind: string): string {
            return root.show(kind);
        }

        function requestNotifying(kind: string, notifyApp: string): string {
            return root.show(kind, notifyApp);
        }

        function release(): string {
            return IslandActivityService.release(root.token) ? "RELEASED" : "NONE";
        }

        // A permanent bubble: "left", "right" or "off"; "drag on|off" stands in for a file dragged over the bar.
        function permanent(side: string): string {
            return root.pin(side, null);
        }

        // The same bubble with a face the plugin draws itself.
        function permanentDrawn(side: string): string {
            return root.pin(side, root.drawnFace);
        }

        function drag(on: string): string {
            const p = IslandActivityService.permanent[root.pluginId];
            if (!p)
                return "NONE";
            return IslandActivityService.setPermanent(root.pluginId, Object.assign({}, p, {
                "receiving": on === "on"
            })) ? "DRAG: " + on : "REFUSED";
        }

        function state(): string {
            return IslandActivityService.state(root.token) || "NONE";
        }
    }
}
