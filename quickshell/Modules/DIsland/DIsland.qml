pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../../Common/IslandActivityInput.js" as Input
import "../../Common/IslandMachineCard.js" as MachineCard

Item {
    id: root

    property var hyprlandOverviewLoader: null

    readonly property var hostSlots: ShellLayout.islandKeys

    readonly property bool launcherOpen: root.activityOpen("launcher")
    readonly property bool controlCenterOpen: root.activityOpen("controlcenter")

    function hosts() {
        return (islandVariants.instances || []).concat(freeIslandVariants.instances || []);
    }

    function freeHostForScreen(screenName, kind) {
        const requested = (screenName || "").trim() || CompositorService.getFocusedScreenName();
        const instance = (ShellLayout.forScreen(requested)?.instances ?? []).find(instance => instance.free && root.matchesKind(instance, kind));
        if (!instance)
            return null;
        return hosts().find(host => host?.free && host.screen?.name === requested && host.barId === instance.barId) ?? null;
    }

    function ipcMove(x, y, screen, kind) {
        const host = root.freeHostForScreen(screen, kind);
        if (!host)
            return `${root.ipcTag(kind)}_NOT_FREE`;
        if (!isFinite(x) || !isFinite(y))
            return `${root.ipcTag(kind)}_INVALID_POSITION`;
        host.moveTo(x, y);
        return `${root.ipcTag(kind)}_MOVED: ${Math.round(host.anchorX)}\t${Math.round(host.anchorY)}\t${host.screen?.name ?? ""}`;
    }

    function ipcCenter(screen, kind) {
        const host = root.freeHostForScreen(screen, kind);
        if (!host)
            return `${root.ipcTag(kind)}_NOT_FREE`;
        return root.ipcMove(host.screenWidth / 2, host.screenHeight / 2, screen, kind);
    }

    function hostWithActivity(activityId, screenName) {
        for (const host of hosts()) {
            if (host?.islandController?.activeActivity === activityId && host.islandController.expanded && (!screenName || host.screen?.name === screenName))
                return host;
        }
        return null;
    }

    function activityOpen(activityId) {
        return root.hostWithActivity(activityId) !== null;
    }

    function hostForExactScreen(screen, barId, kind) {
        return screen ? hostForScreenName(screen.name, barId, kind) : null;
    }

    function matchesKind(instance, kind) {
        return !kind || (kind === "dot") === !!instance.dot;
    }

    function hostForScreenName(screenName, barId, kind) {
        const instances = ShellLayout.forScreen(screenName)?.instances ?? [];
        const ordered = instances.filter(instance => instance.hostsIsland && (!barId || instance.barId === barId) && root.matchesKind(instance, kind)).sort((a, b) => Number(!!a.free) - Number(!!b.free) || Number(["left", "right"].includes(a.edge)) - Number(["left", "right"].includes(b.edge)) || a.configOrder - b.configOrder);
        for (const instance of ordered) {
            const host = hosts().find(host => host?.screen?.name === screenName && host.barId === instance.barId && host.islandController);
            if (host)
                return host;
        }
        return null;
    }

    function focusedHost(kind) {
        const focused = hostForScreenName(CompositorService.getFocusedScreenName(), "", kind);
        if (focused)
            return focused;
        for (const screen of Quickshell.screens) {
            const host = hostForScreenName(screen.name, "", kind);
            if (host)
                return host;
        }
        return null;
    }

    function focusedIslandScreen() {
        return focusedHost()?.screen ?? null;
    }

    function hasHostForScreen(screen, barId) {
        return screen ? hostForExactScreen(screen, barId) !== null : focusedHost() !== null;
    }

    function hostForScreenOrFocused(screen, barId) {
        if (barId && !screen)
            return null;
        return screen ? hostForExactScreen(screen, barId) : focusedHost();
    }

    function hostForScreen(screenName, barId, kind) {
        const requested = (screenName || "").trim();
        return requested ? hostForScreenName(requested, barId, kind) : barId ? null : focusedHost(kind);
    }

    function ipcTag(kind) {
        return kind === "dot" ? "DANK_DOT" : "DANK_ISLAND";
    }

    function activityName(activity) {
        const requested = (activity || "home").trim().toLowerCase();
        switch (requested) {
        case "media":
        case "launcher":
        case "controlcenter":
        case "wallpaper":
        case "weather":
        case "wellbeing":
        case "notificationcenter":
        case "clipboard":
        case "powermenu":
            return requested;
        case "power-menu":
            return "powermenu";
        case "control-center":
        case "cc":
            return "controlcenter";
        case "notifications":
        case "notification-center":
        case "notification":
        case "nc":
            return "notificationcenter";
        }
        return "home";
    }

    function openActivityOn(host, activityId, section) {
        switch (activityId) {
        case "media":
            if (!host.islandController.mediaAvailable)
                return host.islandController.requestActivity("home", true, true);
            return host.islandController.requestActivity("media", true, true);
        case "launcher":
            return host.islandController.requestLauncher("", "", false);
        case "controlcenter":
            return host.islandController.requestControlCenter(section || "", false);
        case "wallpaper":
            return host.islandController.requestWallpaper(false);
        case "weather":
            return host.islandController.requestWeather(false);
        case "notificationcenter":
            return host.islandController.requestNotificationCenter(false);
        case "clipboard":
            return host.islandController.requestClipboard(false);
        case "powermenu":
            return host.islandController.requestPowerMenu(false);
        }
        return host.islandController.requestActivity(activityId, true, true);
    }

    function openActivity(activityId, screen, section, barId): bool {
        const host = root.hostForScreenOrFocused(screen, barId);
        return host ? root.openActivityOn(host, activityId, section) === true : false;
    }

    function toggleActivity(activityId, screen, section, barId): bool {
        const host = root.hostForScreenOrFocused(screen, barId);
        if (!host)
            return false;
        const resolved = activityId === "media" && !host.islandController.mediaAvailable ? "home" : activityId;
        const openHost = barId ? (host.islandController.activeActivity === resolved && host.islandController.expanded ? host : null) : root.hostWithActivity(resolved);
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openActivity(activityId, screen, section, barId);
    }

    // An IPC close takes down everything that shows the activity, on every monitor.
    function closeActivity(activityId): bool {
        let closed = false;
        for (const host of hosts()) {
            if (host?.islandController?.activeActivity !== activityId || !host.islandController.expanded)
                continue;
            host.islandController.requestCollapse();
            closed = true;
        }
        return closed;
    }

    function openLauncher(query, mode, screen, barId): bool {
        const target = screen ?? CompositorService.getFocusedScreen();
        const config = barId ? null : SettingsData.islandLauncherHostConfig(target);
        const host = barId ? root.hostForExactScreen(target, barId) : config ? root.hostForExactScreen(target, config.id) : null;
        return host ? host.islandController.requestLauncher(query || "", mode || "", false) : false;
    }

    function toggleLauncher(query, mode, screen, barId): bool {
        const target = screen ?? CompositorService.getFocusedScreen();
        const host = barId ? root.hostForExactScreen(target, barId) : root.hostWithActivity("launcher", target?.name);
        if (host?.islandController.expanded && host.islandController.activeActivity === "launcher") {
            host.islandController.requestCollapse();
            return true;
        }
        return root.openLauncher(query, mode, screen, barId);
    }

    function ipcOpen(activity, screen, barId, kind) {
        const host = root.hostForScreen(screen, barId, kind);
        if (!host)
            return `${root.ipcTag(kind)}_UNAVAILABLE`;
        const requested = root.activityName(activity);
        if (!root.openActivityOn(host, requested, ""))
            return `${root.ipcTag(kind)}_ACTIVITY_UNAVAILABLE: ${requested}`;
        return `${root.ipcTag(kind)}_OPEN: ${requested}\t${host.screen?.name ?? ""}`;
    }

    function ipcToggle(activity, screen, barId, kind) {
        const host = root.hostForScreen(screen, barId, kind);
        if (!host)
            return `${root.ipcTag(kind)}_UNAVAILABLE`;
        if (host.islandController.expanded && !host.islandController.notificationActive) {
            host.islandController.requestCollapse();
            return `${root.ipcTag(kind)}_CLOSED: ${host.screen?.name ?? ""}`;
        }
        return ipcOpen(activity, screen, barId, kind);
    }

    function ipcShow(activity, screen, barId, kind) {
        const host = root.hostForScreen(screen, barId, kind);
        if (!host)
            return `${root.ipcTag(kind)}_UNAVAILABLE`;
        const requested = root.activityName(activity);
        if (!host.islandController.requestActivity(requested, false, false))
            return `${root.ipcTag(kind)}_ACTIVITY_UNAVAILABLE: ${requested}`;
        return `${root.ipcTag(kind)}_SHOW: ${requested}\t${host.screen?.name ?? ""}`;
    }

    function ipcClose(screen, barId, kind) {
        const host = root.hostForScreen(screen, barId, kind);
        if (!host)
            return `${root.ipcTag(kind)}_UNAVAILABLE`;
        host.islandController.requestCollapse();
        return `${root.ipcTag(kind)}_CLOSED: ${host.screen?.name ?? ""}`;
    }

    function ipcCycle(screen, barId, kind) {
        const host = root.hostForScreen(screen, barId, kind);
        if (!host)
            return `${root.ipcTag(kind)}_UNAVAILABLE`;
        host.islandController.cycleActivity(1, host.islandController.expanded);
        return `${root.ipcTag(kind)}_ACTIVITY: ${host.islandController.activeActivity}\t${host.screen?.name ?? ""}`;
    }

    function ipcStatus(screen, barId, kind) {
        const host = root.hostForScreen(screen, barId, kind);
        if (!host)
            return JSON.stringify({
                "available": false,
                "enabled": true,
                "launcherAvailable": false
            });
        return JSON.stringify({
            "available": true,
            "enabled": true,
            "screen": host.screen?.name ?? "",
            "activity": host.islandController.activeActivity,
            "expanded": host.islandController.expanded,
            "mediaAvailable": host.islandController.mediaAvailable,
            "launcherAvailable": true,
            "controlCenterAvailable": true,
            "wallpaperAvailable": true,
            "weatherAvailable": true,
            "notificationCenterAvailable": true,
            "clipboardAvailable": true,
            "powerMenuAvailable": true,
            "launcherInputFocused": host.islandController.launcherInputFocused,
            "launcherResultCount": host.launcherResultCount,
            "compactHeight": host.islandController.compactThickness,
            "free": !!host.free,
            "idle": host.free ? host.idle : false,
            "x": host.free ? Math.round(host.anchorX) : null,
            "y": host.free ? Math.round(host.anchorY) : null,
            "plugin": root.pluginStatus(host.islandController.pluginToken),
            "bubbles": {
                "machine": host.body?.bubbleSides?.machine?.kind ?? "",
                "apps": (host.body?.bubbleSides?.apps ?? []).map(b => b.kind ? b.source + ":" + b.kind : b.source)
            }
        });
    }

    // Prints the bare token so a script can keep it: tok=$(dms ipc call island activity ...); the other answers are
    // listed at IslandActivityInput.ipcRefusal.
    function ipcActivity(id, kind, screen, data) {
        const parsed = Input.parseIpcData(data);
        const refused = Input.ipcRefusal(parsed);
        if (refused)
            return refused;
        const token = IslandActivityService.requestScript(id, {
            "kind": kind,
            "screen": screen,
            "expanded": parsed.expanded,
            "timeoutMs": parsed.timeoutMs,
            "notifyApp": parsed.notifyApp,
            "data": parsed
        });
        return token || "ISLAND_ACTIVITY_REFUSED";
    }

    function ipcActivityUpdate(token, data) {
        if (!Input.ipcOwns(token))
            return "ISLAND_ACTIVITY_UNKNOWN";
        const parsed = Input.parseIpcData(data);
        // Empty data would blank the face: an update always says what to show.
        if (!parsed || Object.keys(parsed).length === 0)
            return "ISLAND_ACTIVITY_BAD_DATA";
        return IslandActivityService.update(token, parsed) ? "ISLAND_ACTIVITY_UPDATED" : "ISLAND_ACTIVITY_UNKNOWN";
    }

    function ipcActivityEnd(token) {
        return Input.ipcOwns(token) && IslandActivityService.release(token) ? "ISLAND_ACTIVITY_ENDED" : "ISLAND_ACTIVITY_UNKNOWN";
    }

    function ipcActivityStatus(token) {
        const entry = Input.ipcOwns(token) ? IslandActivityService.entry(token) : null;
        return entry ? JSON.stringify({
            "state": entry.state,
            "action": entry.lastAction
        }) : "ISLAND_ACTIVITY_UNKNOWN";
    }

    function pluginStatus(token) {
        const entry = IslandActivityService.entry(token);
        return entry ? {
            "token": Input.ipcOwns(token) ? token : "",
            "pluginId": entry.pluginId,
            "kind": entry.kind,
            "state": entry.state
        } : null;
    }

    Component.onCompleted: PopoutService.dankIslandRouter = root
    Component.onDestruction: {
        if (PopoutService.dankIslandRouter === root)
            PopoutService.dankIslandRouter = null;
    }

    Variants {
        id: islandVariants

        model: root.hostSlots

        delegate: DIslandHostWindow {
            required property var modelData

            readonly property var identity: JSON.parse(modelData)
            screen: ShellLayout.screenForName(identity[0])
            barId: identity[1]
            hyprlandOverviewLoader: root.hyprlandOverviewLoader
        }
    }

    Variants {
        id: freeIslandVariants

        model: ShellLayout.freeIslandKeys

        delegate: IslandFreeHostWindow {
            required property var modelData

            readonly property var identity: JSON.parse(modelData)
            screen: ShellLayout.screenForName(identity[0])
            barId: identity[1]
        }
    }

    // Polkit requests open the island while it is on; the dialog takes them otherwise.
    IslandAuthSource {
        id: authSource
    }

    // Reading the eye break service creates it (singletons are lazy): its one timer runs only while the setting is on.
    readonly property bool eyeBreakOn: EyeBreakService.enabled

    IpcHandler {
        target: "island"

        function open(activity: string): string {
            return root.ipcOpen(activity, "", "", "island");
        }

        function toggle(activity: string): string {
            return root.ipcToggle(activity, "", "", "island");
        }

        function show(activity: string): string {
            return root.ipcShow(activity, "", "", "island");
        }

        function close(): string {
            return root.ipcClose("", "", "island");
        }

        // The charge face without a pointer: "open" opens it (as a hover does), "card" turns it into its card (as a click
        // does), "hide" hides the charge until the next plug (as a right click does).
        function charge(action: string): string {
            const host = root.hostForScreen("", "", "island");
            if (!host?.body)
                return "ISLAND_UNAVAILABLE";
            const body = host.body;
            if (action === "hide") {
                body.dismissBubble({
                    "id": "charge"
                });
                if (host.islandController.activeActivity === "charging")
                    host.islandController.finishTransient();
                return "ISLAND_CHARGE: hidden";
            }
            if (action !== "open" && action !== "card")
                return "ISLAND_CHARGE_UNKNOWN_ACTION";
            if (!body.charge.live)
                return "ISLAND_CHARGE_UNAVAILABLE: not charging";
            if (!body.charge.shown)
                body.openChargeFace();
            // Refused (island open, a plugin of higher rank, level infos in bubbles): say so, nothing shows.
            if (!body.charge.shown)
                return "ISLAND_CHARGE_UNAVAILABLE: island busy";
            if (action === "card") {
                body.charge.detail = true;
                // The card shows while the pointer is in or the card is pinned: without a pointer, pin it.
                host.islandController.faceCardPinned = true;
            }
            return "ISLAND_CHARGE: " + (body.charge.detail ? "card" : "face");
        }

        // The machine bubble's card without a pointer: open, close or toggle (IslandMachineCard.js).
        function card(action: string): string {
            const host = root.hostForScreen("", "", "island");
            const open = MachineCard.ipc(host, action);
            if (typeof open === "string")
                return open;
            host.islandController.machineCardOpen = open;
            return "ISLAND_CARD: " + (open ? "open" : "closed");
        }

        function cycle(): string {
            return root.ipcCycle("", "", "island");
        }

        function status(): string {
            return root.ipcStatus("", "", "island");
        }

        // Super+S (niri-binds.kdl): "toggle" opens the shelf's card in the focused island, or closes it where it shows.
        // The key runs without a terminal: with no island to show it, a toast says so rather than nothing.
        function shelf(action: string): string {
            if (action !== "toggle")
                return "ISLAND_SHELF_UNKNOWN_ACTION";
            const s = root.hostForScreen("", "", "island")?.body?.shelf;
            if (!s) {
                ToastService.showInfo(I18n.tr("No island on this screen to show the shelf", "island shelf: its shortcut pressed where no island is"));
                return "ISLAND_UNAVAILABLE";
            }
            const done = s.toggle();
            return done === "open" ? "ISLAND_SHELF_OPEN" : done === "closed" ? "ISLAND_SHELF_CLOSED" : "ISLAND_SHELF_REFUSED";
        }

        function openOn(activity: string, screen: string): string {
            return root.ipcOpen(activity, screen, "", "island");
        }

        function toggleOn(activity: string, screen: string): string {
            return root.ipcToggle(activity, screen, "", "island");
        }

        function showOn(activity: string, screen: string): string {
            return root.ipcShow(activity, screen, "", "island");
        }

        function closeOn(screen: string): string {
            return root.ipcClose(screen, "", "island");
        }

        function cycleOn(screen: string): string {
            return root.ipcCycle(screen, "", "island");
        }

        function statusOn(screen: string): string {
            return root.ipcStatus(screen, "", "island");
        }

        function openInstance(activity: string, screen: string, barId: string): string {
            return root.ipcOpen(activity, screen, barId);
        }

        function toggleInstance(activity: string, screen: string, barId: string): string {
            return root.ipcToggle(activity, screen, barId);
        }

        function notifications(): string {
            return root.ipcToggle("notificationcenter", "", "", "island");
        }

        function notificationsOn(screen: string): string {
            return root.ipcToggle("notificationcenter", screen, "", "island");
        }

        function move(x: string, y: string): string {
            return root.ipcMove(parseFloat(x), parseFloat(y), "", "island");
        }

        function moveOn(screen: string, x: string, y: string): string {
            return root.ipcMove(parseFloat(x), parseFloat(y), screen, "island");
        }

        function center(): string {
            return root.ipcCenter("", "island");
        }

        function centerOn(screen: string): string {
            return root.ipcCenter(screen, "island");
        }

        function activity(id: string, kind: string, data: string): string {
            return root.ipcActivity(id, kind, "", data);
        }

        // screen "*" shows it on every island.
        function activityOn(id: string, kind: string, screen: string, data: string): string {
            return root.ipcActivity(id, kind, screen, data);
        }

        function activityUpdate(token: string, data: string): string {
            return root.ipcActivityUpdate(token, data);
        }

        function activityEnd(token: string): string {
            return root.ipcActivityEnd(token);
        }

        // The last action the user picked stays readable until the activity ends.
        function activityStatus(token: string): string {
            return root.ipcActivityStatus(token);
        }
    }

    IpcHandler {
        target: "dot"

        function open(activity: string): string {
            return root.ipcOpen(activity, "", "", "dot");
        }

        function toggle(activity: string): string {
            return root.ipcToggle(activity, "", "", "dot");
        }

        function show(activity: string): string {
            return root.ipcShow(activity, "", "", "dot");
        }

        function close(): string {
            return root.ipcClose("", "", "dot");
        }

        function cycle(): string {
            return root.ipcCycle("", "", "dot");
        }

        function status(): string {
            return root.ipcStatus("", "", "dot");
        }

        function notifications(): string {
            return root.ipcToggle("notificationcenter", "", "", "dot");
        }

        function openOn(activity: string, screen: string): string {
            return root.ipcOpen(activity, screen, "", "dot");
        }

        function toggleOn(activity: string, screen: string): string {
            return root.ipcToggle(activity, screen, "", "dot");
        }

        function showOn(activity: string, screen: string): string {
            return root.ipcShow(activity, screen, "", "dot");
        }

        function closeOn(screen: string): string {
            return root.ipcClose(screen, "", "dot");
        }

        function cycleOn(screen: string): string {
            return root.ipcCycle(screen, "", "dot");
        }

        function statusOn(screen: string): string {
            return root.ipcStatus(screen, "", "dot");
        }

        function notificationsOn(screen: string): string {
            return root.ipcToggle("notificationcenter", screen, "", "dot");
        }

        function openInstance(activity: string, screen: string, barId: string): string {
            return root.ipcOpen(activity, screen, barId, "dot");
        }

        function toggleInstance(activity: string, screen: string, barId: string): string {
            return root.ipcToggle(activity, screen, barId, "dot");
        }

        function move(x: string, y: string): string {
            return root.ipcMove(parseFloat(x), parseFloat(y), "", "dot");
        }

        function moveOn(screen: string, x: string, y: string): string {
            return root.ipcMove(parseFloat(x), parseFloat(y), screen, "dot");
        }

        function center(): string {
            return root.ipcCenter("", "dot");
        }

        function centerOn(screen: string): string {
            return root.ipcCenter(screen, "dot");
        }
    }
}
