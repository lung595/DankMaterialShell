pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../Common/IslandActivities.js" as Activities
import "../Common/IslandActivityInput.js" as Input

Singleton {
    id: root

    readonly property var log: Log.scoped("IslandActivityService")
    property var requests: ({})
    property int revision: 0
    property int nextSeq: 1

    signal shown(string token)
    signal interrupted(string token)
    signal resumed(string token)
    signal dropped(string token, string reason)
    signal action(string token, string actionId)

    // Permanent bubbles, one per owner: { pluginId: { pluginId, side: "left" | "right", label, image (the app's one-colour
    // icon), dropText, receiving, seq } }. Each side shows its newest plugin entry (Input.permanentOn).
    property var permanent: ({})
    // options: { side, image, label, dropText, receiving }, or null to clear it. Gone when the plugin unloads or is blocked.
    function setPermanent(pluginId, options): bool {
        if (!Input.permanentAllowed(pluginId, PluginService.isPluginLoaded(pluginId), root.pluginAllowed(pluginId)))
            return false;
        root.permanent = Input.withPermanent(root.permanent, pluginId, options, root.nextSeq++);
        return true;
    }

    function clearPermanent(pluginId) {
        root.permanent = Input.withPermanent(root.permanent, pluginId, null, 0);
    }

    function permanentOn(side) {
        return Input.permanentOn(root.permanent, side);
    }

    function request(pluginId, options): string {
        if (!Input.pluginIdAllowed(pluginId) || !PluginService.isPluginLoaded(pluginId) || !PluginService.pluginIslandComponents[pluginId] || !root.pluginAllowed(pluginId))
            return "";
        return root.add(pluginId, options);
    }

    // Scripts over IPC; they always get the ready face, within the limits of Input.scriptAllowed.
    function requestScript(id, options): string {
        const name = String(id ?? "").trim();
        const live = Object.values(root.requests).filter(r => r.pluginId.startsWith("script:")).map(r => r.pluginId.slice(7));
        return Input.scriptAllowed(name, live, options?.notifyApp) ? root.add("script:" + name, options) : "";
    }

    // shortcut: "*" covers the islands present at request time; a screen plugged in later stays empty.
    function islandsFor(screenName) {
        const router = PopoutService.dankIslandRouter;
        if (!router)
            return [];
        const names = screenName === "*" ? Quickshell.screens.map(s => s.name) : [screenName];
        return names.map(name => router.hostForScreenName(name, "")?.islandController ?? null).filter(island => !!island);
    }

    function add(sourceId, options): string {
        const opts = Activities.normalizeOptions(options);
        // An unknown kind shows as a live activity; its plugin or script reads why in the log.
        if (typeof options?.kind === "string" && options.kind !== opts.kind)
            root.log.warn("unknown activity kind, shown as live:", options.kind, sourceId);
        opts.notifyApp = opts.notifyApp || String(PluginService.availablePlugins[sourceId]?.island?.notifyApp ?? "").trim();
        const screenName = opts.screen || CompositorService.getFocusedScreenName();
        const islands = root.islandsFor(screenName);
        if (islands.length === 0)
            return "";
        const previous = Object.values(root.requests).find(r => r.pluginId === sourceId);
        if (previous)
            root.remove(previous.token, "replaced");
        const seq = root.nextSeq++;
        const token = sourceId + ":" + seq;
        root.requests = Object.assign({}, root.requests, {
            [token]: Object.assign(opts, {
                "token": token,
                "pluginId": sourceId,
                "screen": screenName,
                "hosts": islands,
                "shownOn": [],
                "seq": seq,
                "state": "waiting",
                "lastAction": ""
            })
        });
        root.revision++;
        return token;
    }

    function trigger(token, actionId) {
        const entry = root.requests[token];
        if (!entry || !actionId)
            return;
        entry.lastAction = actionId;
        root.revision++;
        root.action(token, actionId);
    }

    function update(token, data): bool {
        const entry = root.requests[token];
        if (!entry)
            return false;
        entry.data = data && typeof data === "object" ? data : {};
        root.revision++;
        return true;
    }

    function release(token): bool {
        return root.remove(token, "released");
    }

    function state(token): string {
        return root.requests[token]?.state ?? "";
    }

    function entry(token) {
        root.revision;
        return root.requests[token] ?? null;
    }

    function nextFor(island) {
        root.revision;
        return Activities.nextRequest(Object.values(root.requests), island, SessionData.doNotDisturb);
    }

    // Requests for this island other than the one it shows: they wait in its trailing bubble.
    function waitingFor(island, shownToken) {
        root.revision;
        return Object.values(root.requests).filter(r => r.token !== shownToken && r.hosts.indexOf(island) !== -1);
    }

    // Whether a notification's app is a plugin that already has an activity in the island: the island shows that plugin
    // once, not again as a notification. The app is the one the plugin declared (notifyApp), else its name or id.
    function holdsApp(appName): bool {
        return Activities.holdsApp(Object.values(root.requests), appName, id => PluginService.availablePlugins[id]?.name);
    }

    function pluginAllowed(pluginId): bool {
        return SettingsData.islandPluginAllowed(pluginId);
    }

    function systemFacesOf(pluginId) {
        const faces = PluginService.availablePlugins[pluginId]?.island?.systemFaces;
        return Array.isArray(faces) ? faces : [];
    }

    function systemFaceProviders(kind) {
        return Object.keys(PluginService.availablePlugins).filter(id => root.systemFacesOf(id).indexOf(kind) !== -1);
    }

    // The user's pick stays saved while its plugin is away; the shell's face stands in.
    function systemFaceFor(kind) {
        const pluginId = SettingsData.islandSystemFace(kind);
        if (!pluginId || root.systemFacesOf(pluginId).indexOf(kind) === -1)
            return null;
        const component = PluginService.pluginIslandSystemComponents[pluginId];
        return component ? {
            "pluginId": pluginId,
            "component": component
        } : null;
    }

    function markShown(token, island) {
        root.markShowing(token, island, true);
    }

    function markInterrupted(token, island) {
        root.markShowing(token, island, false);
    }

    function markShowing(token, island, showing) {
        const entry = root.requests[token];
        if (!entry || (entry.shownOn.indexOf(island) !== -1) === showing)
            return;
        const change = Activities.shownChange(entry, island, showing);
        entry.shownOn = change.shownOn;
        entry.state = change.state;
        if (!change.signal)
            return;
        root.revision++;
        root[change.signal](token);
    }

    function remove(token, reason): bool {
        if (!root.requests[token])
            return false;
        const next = Object.assign({}, root.requests);
        delete next[token];
        root.requests = next;
        root.revision++;
        root.dropped(token, reason);
        return true;
    }

    function removePlugin(pluginId, reason) {
        for (const entry of Object.values(root.requests)) {
            if (entry.pluginId === pluginId)
                root.remove(entry.token, reason);
        }
    }

    // An island that goes away takes its activities with it; the plugin falls back on its own.
    function removeHost(island) {
        for (const entry of Object.values(root.requests)) {
            if (entry.hosts.indexOf(island) === -1)
                continue;
            entry.hosts = entry.hosts.filter(host => host !== island);
            if (entry.hosts.length === 0)
                root.remove(entry.token, "unavailable");
            else
                root.markInterrupted(entry.token, island); // shown there: back to waiting once no island shows it
        }
    }

    Connections {
        target: PluginService

        function onPluginUnloaded(pluginId) {
            root.removePlugin(pluginId, "unloaded");
            root.clearPermanent(pluginId);
        }
    }

    Connections {
        target: SettingsData

        function onIslandPluginsBlockedChanged() {
            for (const pluginId of SettingsData.islandPluginsBlocked) {
                root.removePlugin(pluginId, "disabled");
                root.clearPermanent(pluginId);
            }
        }
    }
}
