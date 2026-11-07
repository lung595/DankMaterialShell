pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Modals.DLauncherV2 as DLauncher
import qs.Modules.DBar
import qs.Modules.DIsland.Activities
import qs.Modules.Notifications
import qs.Services
import qs.Widgets
import "../../Common/LayoutResolver.js" as Resolver
import "../../Common/IslandActivities.js" as Activities
import "../../Common/IslandActivityInput.js" as Input
import "../../Common/IslandEcho.js" as Echo
import "../../Common/IslandArrival.js" as Arrival
import "../../Common/IslandReceived.js" as Received
import "../../Common/IslandKit.js" as Kit
import "../../Common/IslandLayer.js" as Layer

Item {
    id: root

    required property var barConfig
    required property var screen
    required property var hostWindow
    required property string barId
    property real originOffsetX: 0
    property real originOffsetY: 0
    // Set by FrameBarHost; a frame-hosted body cannot see its own slot offset.
    property real hostOffsetX: 0
    property real hostOffsetY: 0
    property string chrome: "own"
    readonly property bool embedded: root.chrome !== "own"
    readonly property bool connectedChrome: root.chrome === "none"
    property real bandThickness: 0
    // The visible band along the bar, in host coordinates; a percent-length or padded bar is shorter than its window.
    property real bandAlongStart: 0
    property real bandAlongEnd: root.isVertical ? root.height : root.width
    // The frame window never resizes for the sheet, whatever chrome the body wears.
    property bool frameHosted: false
    property color bandColor: Theme.hostSurface
    property Item anchorItem: null
    property Item slotItem: null
    property Item barBody: null
    property var leadingSectionRect: null
    property var centerSectionRect: null
    property var trailingSectionRect: null
    readonly property int hostLayer: root.hostWindow?.dBarLayer ?? WlrLayer.Top
    property point anchor
    property bool anchorSnaps: false
    property real freeScale: 1
    property real freeOpacity: 1

    readonly property alias islandController: controller
    readonly property alias surface: surface
    readonly property alias weatherSource: weatherSource
    readonly property int launcherResultCount: launcherController.flatModel?.length ?? 0
    readonly property var inputMaskItem: surface.inputMaskItem
    readonly property var fittsStripItem: root.embedded ? null : surface.fittsStripItem
    readonly property bool motionRunning: surface.motionRunning
    readonly property rect motionStartBounds: surface.motionStartBounds
    readonly property real targetAlongPos: surface.targetAlongPos
    readonly property real currentAlongPos: surface.currentAlongPos
    readonly property real currentVisualAlong: surface.currentVisualAlong
    readonly property real targetVisualAlong: surface.targetVisualAlong
    readonly property real currentVisualX: surface.currentVisualX
    readonly property real currentVisualY: surface.currentVisualY
    readonly property real currentVisualWidth: surface.currentVisualWidth
    readonly property real currentVisualHeight: surface.currentVisualHeight
    readonly property real currentSurfaceRadius: surface.currentSurfaceRadius
    readonly property color surfaceColor: surface.surfaceColor
    readonly property real surfaceOpacity: surface.surfaceOpacity
    readonly property bool inputSuspended: controller.inputSuspended
    readonly property bool expanded: controller.expanded
    readonly property bool transientActive: controller.transientActive
    // Held from expand until the collapse spring settles, so compact-to-compact morphs never resize the bar window.
    property bool sheetOut: false
    readonly property bool surfaceFits: (root.isVertical ? root.windowWidth : root.windowHeight) >= root.hostThickness - 1
    // A free host lifts to the whole output for the sheet; the expand waits for that size so no frame of the morph is clipped.
    property bool hostLifted: true
    readonly property bool hostReady: root.freeMode ? root.hostLifted : (!root.embedded || root.frameHosted || root.surfaceFits)
    // Layer surfaces glitch when they resize under a moving sheet: edit room waits for a frame at the grown size, and the grown size outlives the shrink spring.
    readonly property bool surfaceResizes: !root.freeMode && !root.frameHosted
    readonly property int editSurfaceHeight: controller.editSurfaceHeight
    property int heldEditSurfaceHeight: 0
    readonly property bool editRoomWaiting: controller.editRoom > 0 && !controller.editRoomGranted
    onEditSurfaceHeightChanged: {
        if (root.editSurfaceHeight >= root.heldEditSurfaceHeight) {
            root.heldEditSurfaceHeight = root.editSurfaceHeight;
            return;
        }
        Qt.callLater(root.releaseEditSurface);
    }
    onEditRoomWaitingChanged: {
        if (root.editRoomWaiting && !root.surfaceResizes)
            controller.editRoomGranted = true;
    }

    function releaseEditSurface() {
        if (!surface.motionRunning)
            root.heldEditSurfaceHeight = root.editSurfaceHeight;
    }
    readonly property real compactTargetSize: surface.descriptorAlong(controller.compactTarget)
    // Summed by hand so every ancestor offset is a binding dependency; mapToItem goes stale when a section re-centres.
    readonly property real slotCentre: {
        let item = root.slotItem;
        if (!root.embedded || !item || !root.anchorItem)
            return NaN;
        let pos = root.isVertical ? item.height / 2 : item.width / 2;
        for (; item && item !== root.anchorItem; item = item.parent)
            pos += root.isVertical ? item.y : item.x;
        return item ? pos : NaN;
    }
    readonly property real anchorAlong: isNaN(root.slotCentre) ? 0 : root.slotCentre - (root.isVertical ? root.height : root.width) / 2
    onExpandedChanged: {
        if (root.dotMode && root.expanded && !controller.transientActive && root.setting("islandNotificationBadgeClearOnOpen"))
            NotificationService.markNotificationsSeen();
        if (root.expanded) {
            root.sheetOut = true;
            root.closeSameEdgeSurfaces();
        } else if (!root.motionRunning && surface.surfaceMotion.matchesTarget(surface.resolveTarget(controller.compactTarget))) {
            // Already compact, so no step will come to clear the latch.
            root.sheetOut = false;
        }
        root.publishSurface();
        Qt.callLater(root.syncPluginActivity);
    }
    onMotionRunningChanged: root.publishSurface()
    onConnectedChromeChanged: root.publishSurface()
    onEdgeChanged: root.publishSurface()

    signal scrollWheel(var wheel)

    function setting(key) {
        return SettingsData.islandSetting(root.barConfig, key);
    }

    readonly property var islandMetrics: Resolver.islandMetrics(SettingsData.islandSettings(root.barConfig), SettingsData.islandDefaultsFor(root.barConfig))
    readonly property bool freeMode: SettingsData.islandFreePlacement(root.barConfig)
    readonly property bool dotMode: SettingsData.isDotBarConfig(root.barConfig)
    readonly property real dotSize: Math.max(24, Math.min(160, root.setting("islandFreeSize")))
    readonly property real freeMargin: Math.max(0, Math.min(64, root.setting("islandFreeEdgeMargin")))
    readonly property var bandFit: BarMetrics.islandBandFit(root.bandThickness, root.islandMetrics.gap)
    readonly property int compactThickness: root.embedded ? root.bandFit.compact : root.dotMode ? Math.max(24, Math.min(72, root.dotSize)) : root.islandMetrics.compact
    readonly property string screenName: root.screen?.name ?? ""
    readonly property bool floating: root.setting("islandFloating")
    readonly property bool notch: !root.embedded && !root.freeMode && !root.dotMode && root.setting("islandNotch")
    // An island hosted in a plain bar keeps the bar's layer, so only its own window rises for a fullscreen request.
    readonly property bool wantsOverlay: Layer.wantsOverlay(root.setting("islandUseOverlayLayer"), !root.embedded && root.setting("islandOverlayOnRequest"), root.pluginEntry)
    readonly property bool usesOverlayLayer: root.dotMode || CompositorService.framePeerSurfacesUseOverlayForScreen(root.screen) || LayerShell.envUsesOverlay("DMS_DANKISLAND_LAYER", root.wantsOverlay)
    // A free island's position only picks the orientation; a dot is always a circle.
    readonly property bool isVertical: !root.dotMode && SettingsData.islandVertical(root.barConfig)
    readonly property string edge: root.freeMode ? (root.isVertical ? "left" : "top") : SettingsData.islandEdge(root.barConfig)
    readonly property bool farEdge: root.edge === "bottom" || root.edge === "right"
    readonly property real windowWidth: root.hostWindow?.width ?? 0
    readonly property real windowHeight: root.hostWindow?.height ?? 0
    readonly property real windowMarginLeft: root.hostWindow?.margins?.left ?? 0
    readonly property real windowMarginRight: root.hostWindow?.margins?.right ?? 0
    readonly property real windowMarginTop: root.hostWindow?.margins?.top ?? 0
    readonly property real windowMarginBottom: root.hostWindow?.margins?.bottom ?? 0
    readonly property int hostOriginX: root.freeMode ? 0 : (root.isVertical && root.farEdge ? Math.max(0, (root.screen?.width ?? 0) - root.windowWidth - root.windowMarginRight) : root.windowMarginLeft) + root.hostOffsetX + root.originOffsetX
    readonly property int hostOriginY: root.freeMode ? 0 : (!root.isVertical && root.farEdge ? Math.max(0, (root.screen?.height ?? 0) - root.windowHeight - root.windowMarginBottom) : root.windowMarginTop) + root.hostOffsetY + root.originOffsetY
    // Screen position of the host window's origin; section rects and mapToItem(null) are window-relative.
    readonly property real sectionOriginX: root.hostOriginX - root.originOffsetX - root.hostOffsetX
    readonly property real sectionOriginY: root.hostOriginY - root.originOffsetY - root.hostOffsetY
    readonly property int outerGap: root.freeMode ? 0 : root.embedded ? root.bandFit.gap : root.islandMetrics.gap
    // An embedded sheet starts inside the band; its content begins past the fold so nothing sits on the bar.
    readonly property int nearInset: root.embedded ? Math.max(0, Math.round(root.bandThickness) - root.outerGap) : 0
    readonly property real crossInsetStart: root.freeMode ? 0 : root.frameHosted ? ShellLayout.frameReservation(root.screen, root.isVertical ? "left" : "top") : root.isVertical ? root.windowMarginLeft : root.windowMarginTop
    readonly property real crossInsetEnd: root.freeMode ? 0 : root.frameHosted ? ShellLayout.frameReservation(root.screen, root.isVertical ? "right" : "bottom") : root.isVertical ? root.windowMarginRight : root.windowMarginBottom
    readonly property real alongInset: root.freeMode ? 0 : root.isVertical ? root.windowMarginTop + root.windowMarginBottom : root.windowMarginLeft + root.windowMarginRight
    readonly property int destinationMinHeight: 560
    readonly property int destinationMaxHeightLimit: 680
    readonly property int activityMinWidth: 320
    readonly property int activityMaxWidth: 736
    readonly property int screenMargin: 200
    readonly property int referenceScreenWidth: 1920
    readonly property int referenceScreenHeight: 1080
    readonly property int maxHoverDelay: 1000
    readonly property var springStiffnessRange: [100, 1200]
    readonly property var springDampingRange: [10, 100]
    readonly property var springMassRange: [0.25, 3]
    // The island's spring follows DMS's animation speed like the launcher's (Theme.tunedSpring): 1 at the default speed, 4 at a quarter of it.
    readonly property real motionScale: Math.max(0.05, SettingsData.animationDuration / SettingsData.specDefault("animationDuration"))
    readonly property int destinationMaxHeight: Math.max(destinationMinHeight, Math.min(destinationMaxHeightLimit, (root.screen?.height ?? referenceScreenHeight) - screenMargin))
    readonly property int maxActivityHeight: Math.max(root.heldEditSurfaceHeight, controller.dashboardHeight, controller.controlCenterHeight, controller.launcherMaxHeight, controller.clipboardExpandedTarget.height, controller.powerMenuExpandedTarget.height, destinationMaxHeight)
    readonly property int maxActivityWidth: Math.max(controller.dashboardMaxWidth, controller.controlCenterMaxWidth, controller.launcherExpandedTarget.width, controller.clipboardExpandedTarget.width, controller.powerMenuExpandedTarget.width, Math.min(activityMaxWidth, Math.max(activityMinWidth, (root.screen?.width ?? referenceScreenWidth) - screenMargin)))
    readonly property real shadowPadding: surface.shadowEnabled ? Theme.elevationRenderPadding(Theme.elevationLevel2, surface.effectiveShadowDirection, Theme.spacingXS, Theme.spacingS, Theme.spacingL) : 0
    readonly property int hostThickness: outerGap + nearInset + (root.isVertical ? maxActivityWidth : maxActivityHeight) + Theme.spacingS + shadowPadding
    readonly property real maximumAlongOffset: root.isVertical ? Math.max(0, (height - maxActivityHeight) / 2 - Theme.spacingS - shadowPadding) : Math.max(0, (width - maxActivityWidth) / 2 - Theme.spacingS - shadowPadding)
    readonly property bool scrollEnabled: root.barConfig?.scrollEnabled ?? true
    property bool keyboardFocusArmed: true
    readonly property int keyboardFocusPolicy: KeyboardFocus.keyboardFocus(controller.keyboardDismissRequested && root.keyboardFocusArmed && !controller.keyboardYielded, null)
    readonly property bool wantsFocusGrab: KeyboardFocus.wantsGrab(controller.keyboardDismissRequested && !controller.keyboardYielded, null)
    readonly property var transientFocusWindows: islandTransientSurfaces.focusWindows
    property var dismissWindow: null
    readonly property string registryKey: IslandHostRegistry.key(root.screen?.name, root.barId)
    property string registeredKey: ""

    property int popoutRevision: 0
    readonly property bool satelliteSurfacesOpen: {
        root.popoutRevision;
        const screenName = root.screen?.name;
        if (!screenName)
            return false;
        return !!PopoutManager.currentPopoutsByScreen[screenName] || !!ModalManager.currentModalsByScreen[screenName];
    }

    // A non-embedded island follows popout rules: whatever would close a bar popout on this screen collapses it.
    readonly property QtObject screenPopout: {
        root.popoutRevision;
        return PopoutManager.currentPopoutsByScreen[root.screenName] ?? null;
    }
    readonly property QtObject screenModal: {
        const modal = ModalManager.currentModalsByScreen[root.screenName] ?? null;
        return modal?.keepPopoutsOpen ? null : modal;
    }
    onScreenPopoutChanged: root.collapseForSurface(root.screenPopout)
    onScreenModalChanged: root.collapseForSurface(root.screenModal)

    function collapseForSurface(surfaceObject) {
        if (root.embedded || !surfaceObject)
            return;
        // Otherwise the notification would re-expand the sheet over the new surface when it ends.
        if (controller.notificationActive) {
            if (controller.suspendedExpanded) {
                controller.suspendedActivity = "";
                controller.suspendedExpanded = false;
            }
            return;
        }
        if (controller.expanded)
            controller.requestDismiss();
    }

    // A reopened popout (new trigger, or mid close animation) keeps its identity, so screenPopout never changes.
    function collapseForOpenedPopout() {
        if (root.screenPopout?.shouldBeVisible)
            root.collapseForSurface(root.screenPopout);
    }

    // A card that wants the keyboard (the disk card, once clicked): the island's window takes it and hands it to that card;
    // null gives it back, unless the island is open on its own.
    property Item keyCard: null
    function cardKeyboard(item) {
        root.keyCard = item;
        controller.keyboardYielded = false;
        if (item) {
            controller.keyboardDismissRequested = true;
            item.forceActiveFocus();
        } else if (!controller.expanded) {
            controller.keyboardDismissRequested = false;
        }
    }

    function requestKeyboardFocus() {
        if (!controller.keyboardDismissRequested) {
            keyboardActivationTimer.stop();
            keyboardFocusArmed = false;
            keyboardRearmTimer.restart();
            return;
        }
        keyboardRearmTimer.stop();
        keyboardFocusArmed = true;
        keyboardActivationTimer.restart();
    }

    function containsGlobalPoint(gx, gy, padding) {
        const pad = padding !== undefined ? padding : Theme.spacingL;
        const items = [surface.inputMaskItem, root.fittsStripItem];
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (!item || item.width <= 0 || item.height <= 0)
                continue;
            const topLeft = item.mapToItem(null, 0, 0);
            if (!topLeft)
                continue;
            const left = topLeft.x + root.sectionOriginX;
            const top = topLeft.y + root.sectionOriginY;
            if (gx >= left - pad && gx < left + item.width + pad && gy >= top - pad && gy < top + item.height + pad)
                return true;
        }
        return false;
    }

    function syncRegistration() {
        if (root.registeredKey === root.registryKey)
            return;
        if (root.registeredKey)
            IslandHostRegistry.unregister(root.registeredKey, root);
        root.registeredKey = root.registryKey;
        IslandHostRegistry.register(root.registeredKey, root);
    }

    onRegistryKeyChanged: syncRegistration()
    Component.onCompleted: {
        syncRegistration();
        root.syncCrashRef();
    }
    Component.onDestruction: {
        if (root.crashRef)
            AppCrashService.refCount--;
        IslandHostRegistry.unregister(root.registeredKey, root);
        IslandActivityService.removeHost(controller);
    }

    readonly property var livePluginEntry: IslandActivityService.entry(controller.pluginToken)
    property var lastPluginEntry: null
    onLivePluginEntryChanged: {
        if (root.livePluginEntry)
            root.lastPluginEntry = root.livePluginEntry;
    }
    readonly property var pluginEntry: Activities.shownEntry(root.livePluginEntry, root.lastPluginEntry, surface.pluginShown)
    readonly property var pluginActivity: pluginLoader.item
    // A plugin that draws its own pill owns both faces; otherwise the shell draws them from its data.
    // update() swaps data inside the same entry object, so the face follows the revision rather than the entry.
    // ReadyActivityRing's stroke (its ringWidth): the ready sheet's ring is the icon and four of them.
    readonly property real readyRingWidth: 3
    readonly property var readyFace: root.pluginRevision >= 0 && root.pluginEntry && !root.pluginActivity?.compactContent ? Input.readyFace(root.pluginEntry.data) : null
    readonly property int pluginRevision: IslandActivityService.revision
    readonly property bool quiet: SessionData.doNotDisturb
    readonly property bool sessionLocked: SessionService.locked
    onSessionLockedChanged: Qt.callLater(root.syncPluginActivity)
    readonly property string activeActivity: controller.activeActivity
    onPluginRevisionChanged: Qt.callLater(root.syncPluginActivity)
    onQuietChanged: Qt.callLater(root.syncPluginActivity)
    onActiveActivityChanged: Qt.callLater(root.syncPluginActivity)

    // The plugin activity this island takes next, if any ("" when it keeps what it shows).
    function islandTaker() {
        if (root.sessionLocked)
            return "";
        const next = IslandActivityService.nextFor(controller);
        const occupant = {
            "activity": controller.activeActivity,
            "expanded": controller.expanded,
            "held": controller.userHeld,
            "critical": notificationSource.critical,
            "system": controller.systemActivityActive,
            "kind": controller.pluginKind
        };
        return Activities.takesIsland(next, occupant, controller.pluginToken, controller.pluginActive) ? next.token : "";
    }

    // Settles which plugin activity owns this island after any change on either side.
    function syncPluginActivity() {
        const held = controller.pluginToken;
        const outcome = held ? Activities.heldOutcome(!!IslandActivityService.entry(held), controller.pluginActive, root.sessionLocked) : "";
        if (outcome === "end")
            controller.endPluginActivity();
        else if (outcome === "shown")
            IslandActivityService.markShown(held, controller);
        else if (outcome === "interrupted")
            IslandActivityService.markInterrupted(held, controller);

        // Nothing starts behind the lock screen; it shows once the session is back.
        if (root.sessionLocked)
            return;
        notificationSource.retryHeld();
        const next = IslandActivityService.nextFor(controller);
        if (!next || root.islandTaker() !== next.token)
            return;
        if (controller.pluginToken && controller.pluginToken !== next.token)
            IslandActivityService.markInterrupted(controller.pluginToken, controller);
        controller.beginPluginActivity(next.token, next.kind, next.state === "waiting" && next.expanded, next.kind === "glance" ? next.timeoutMs : 0);
        IslandActivityService.markShown(next.token, controller);
    }

    // Bubbles show on the focused screen only, never behind the lock.
    readonly property bool bubblesShown: !root.sessionLocked && CompositorService.getFocusedScreen()?.name === root.screenName
    property bool mediaBubbleDismissed: false
    readonly property string heldPluginToken: controller.pluginToken
    onHeldPluginTokenChanged: root.mediaBubbleDismissed = false
    // The eye break while the island is busy (EyeBreakService): the eye on the pill (no track), the countdown under it
    // once upright (standText) and in its card.
    readonly property var eyesFace: ({
            "icon": "visibility",
            "progress": -1,
            "text": "",
            "title": I18n.tr("Eye break", "island eye break title"),
            "detail": EyeBreakService.countdown,
            "standLevel": EyeBreakService.progress,
            "standText": EyeBreakService.countdown,
            "accent": "primary"
        })
    // AppCrashService's journalctl runs only while some screen shows bubbles on a visible bar.
    readonly property bool watchesCrashes: root.bubblesShown && root.barConfig?.visible !== false
    property bool crashRef: false
    onWatchesCrashesChanged: root.syncCrashRef()
    function syncCrashRef() {
        if (root.crashRef === root.watchesCrashes)
            return;
        root.crashRef = root.watchesCrashes;
        AppCrashService.refCount += root.crashRef ? 1 : -1;
    }
    // An app that crashed (AppCrashService): the island's "frozen" face first, then its bubble ("frozen" all through:
    // id, source and kind).
    readonly property var frozenFace: {
        const crash = AppCrashService.crash;
        if (!crash)
            return null;
        return {
            "id": "frozen",
            "source": "frozen",
            "kind": "frozen",
            "seq": 1e6,
            "image": crash.image,
            "icon": "error",
            "progress": -1,
            "text": crash.name,
            "title": I18n.tr("%1 crashed", "island crash bubble: app name").arg(crash.name),
            "detail": I18n.tr("Unexpected stop · %1", "island crash bubble: signal that stopped the app").arg(crash.signal),
            "log": crash.log,
            "accent": "error"
        };
    }
    // A new frozen app (by kind and title) plays in the island first.
    readonly property string frozenKey: root.frozenFace ? root.frozenFace.kind + ":" + root.frozenFace.title : ""
    onFrozenKeyChanged: {
        if (root.frozenKey)
            root.playApp("frozen");
    }
    // A new job, and its end, play in the island first, unless its own notification is there already.
    readonly property string progressKey: progress.face?.id ?? ""
    onProgressKeyChanged: {
        if (root.progressKey && (!progress.face.wrapper || notificationSource.currentWrapper !== progress.face.wrapper))
            root.playApp("progress");
    }

    // The island faces of infos another source owns (IslandSystemSource.ownFace): icon, title, value, accent, and the
    // face's click when its value is an action, the same button its bubble's card offers.
    readonly property var islandFaces: ({
            // The check on its shape, the copy's kind or picture after it; hovered, the copy itself (its bubble's face).
            "copy": {
                "icon": "",
                "title": copySource.face.title,
                "value": "",
                "accent": "primary",
                "file": copySource.kind === "file",
                "copy": copySource.face
            },
            // The VPN that dropped and the incoming SSH session: their sources' own faces.
            "vpn": {
                "icon": root.vpn.face.icon || "vpn_key_off",
                "title": root.vpn.face.title,
                "value": root.vpn.face.detail,
                "accent": "primary"
            },
            "ssh": {
                "icon": "terminal",
                "title": root.ssh.face.title,
                "value": root.ssh.face.detail,
                "accent": "primary"
            },
            "trash": {
                "icon": "delete",
                "title": trashSource.label.others > 0 ? I18n.tr("%1 +%2", "island trash face: first file name, other files").arg(trashSource.label.name).arg(trashSource.label.others) : trashSource.label.name,
                "value": I18n.tr("Undo", "island trash bubble: restore the deleted files"),
                "accent": "primary",
                "file": true,
                "click": () => trashSource.undo()
            },
            "disk": {
                "icon": diskSource.face.icon,
                "title": diskSource.face.title,
                "value": diskSource.face.text,
                "accent": diskSource.face.accent
            },
            // The A1 battery with the device's badge leads the face: no second icon.
            "periph": periphSource.face ? {
                "icon": "",
                "title": periphSource.face.title,
                "value": periphSource.face.text,
                "accent": periphSource.face.accent,
                "shapeFamily": periphSource.face.shapeFamily,
                "battery": periphSource.face.battery
            } : null,
            // The laptop battery's infos: the A1 battery on its shape, its title and level (IslandChargeSource).
            "charging": charge.faceOf("charging"),
            "charged": charge.faceOf("charged"),
            "unplugged": charge.faceOf("unplugged"),
            "battery": charge.faceOf("battery"),
            "batterycritical": charge.faceOf("batterycritical"),
            // Its name and when; hovered, the island grows into its card (the phrase, the peak, the chart).
            "weatheralert": weatherSource.face ? {
                "icon": weatherSource.face.icon,
                "title": weatherSource.face.short,
                "value": weatherSource.face.text,
                "accent": weatherSource.face.accent
            } : null,
            "display": {
                "icon": screenSource.face.icon,
                "title": screenSource.face.title,
                // Choose opens the card with the three layouts (the face's end hands it to the machine bubble).
                "value": screenSource.phase === "applied" ? I18n.tr("Undo") : I18n.tr("Choose", "island screen face: opens the layout choice"),
                "accent": "primary",
                "click": () => screenSource.phase === "applied" ? screenSource.undo() : controller.finishTransient()
            },
            "progress": progress.face ? {
                "icon": progress.face.icon,
                "title": progress.face.title,
                "value": progress.face.detail,
                "accent": "primary"
            } : null,
            "frozen": root.frozenFace ? {
                "icon": root.frozenFace.icon,
                "title": root.frozenFace.title,
                "value": "",
                "accent": root.frozenFace.accent
            } : null
        })

    // An app-side info with its own source and bubble: its island face first, when the island is free to take it.
    function playApp(kind) {
        if (root.bubblesShown && systemSource.enabled && controller.requestSystemActivity(kind))
            systemSource.kind = kind;
    }
    // Whether an owned face's info still lives (its clock, its question, its state), so it may take the island back.
    function faceAlive(kind) {
        switch (kind) {
        case "copy":
            return copySource.shown;
        case "trash":
            return trashSource.shown;
        case "display":
            return screenSource.phase !== "";
        case "disk":
        case "periph":
        case "weatheralert":
            return controller.machineBubbleKind === kind;
        case "progress":
            return !!progress.face;
        case "frozen":
            return !!root.frozenFace;
        }
        return false;
    }
    // A face pushed out by the launcher, an alert or another face comes back once the island is idle.
    readonly property string returningFace: Activities.faceToReturn(controller.displacedSystemActivity, controller.activeActivity, controller.expanded, root.faceAlive(controller.displacedSystemActivity))
    onReturningFaceChanged: {
        if (root.returningFace)
            Qt.callLater(root.bringBack);
    }
    function bringBack() {
        const kind = root.returningFace;
        if (!kind)
            return;
        controller.displacedSystemActivity = "";
        if (kind === "disk" || kind === "display" || kind === "periph" || kind === "weatheralert")
            root.playMachine(kind);
        else
            root.playApp(kind);
    }

    // A machine info with no bubble of its own: the island face first, else the machine bubble.
    function playMachine(kind) {
        if (systemSource.enabled && controller.requestSystemActivity(kind)) {
            systemSource.kind = kind;
            systemSource.openedKind = kind;
        } else if (controller.bubblesEnabled) {
            controller.showMachineBubble(kind);
        }
    }

    // The machine bubble of a kind: its pill, and its card (in the wing, or in the island over its face).
    function machineEntry(kind) {
        const face = (kind === "disk" ? diskSource.face : null) ?? (kind === "eyes" ? root.eyesFace : null) ?? (kind === "display" ? screenSource.face : null) ?? (kind === "periph" ? periphSource.face : null) ?? (kind === "weatheralert" ? weatherSource.face : null) ?? (root.chargeKinds.indexOf(kind) !== -1 ? charge.faceOf(kind) : null);
        // Audio output: the island face's "Undo" is a button in this bubble's card.
        const value = face ? face.text : kind === "output" ? "" : kind === "openwifi" ? systemSource.wifi.label : systemSource.displayValue;
        return {
            "id": "system",
            "source": "system",
            "kind": kind,
            "seq": 0,
            "icon": face ? face.icon : systemSource.iconName,
            "progress": face ? face.progress : systemSource.trackRatio,
            // A valued state (the weather's "In 15 min") keeps its text whole beside the icon.
            "text": value.length <= 6 || face?.valued === true ? value : "",
            "valued": face?.valued ?? false,
            // A battery (IslandChargeSource, a device): the A1 glyph, its ramp's hue, its shape; the card reads the source.
            "battery": face?.battery ?? null,
            "charge": face?.charge ?? null,
            "hue": face?.hue,
            "shapeFamily": face?.shapeFamily ?? "",
            "screenSource": face?.screenSource ?? null,
            "blink": face?.blink ?? false,
            // A level shown only on the upright pill (the disk's used space), with its value and how far its liquid is alert.
            "standLevel": face?.standLevel ?? -1,
            "standText": face?.standText ?? "",
            "alertShare": face?.alertShare,
            "island": face?.island ?? false,
            "weather": face?.weather ?? null,
            "title": face ? face.title ?? kind.charAt(0).toUpperCase() + kind.slice(1) : kind === "powerprofile" ? value : systemSource.title,
            "detail": face?.detail ?? (kind === "powerprofile" ? "" : value),
            "accent": face ? face.accent ?? "primary" : systemSource.accent,
            // Power profile: the card (name + Undo) opens at once.
            "open": face?.open ?? (kind === "powerprofile"),
            // The disk card puts files on the shelf and takes the keyboard while used (arrows, Enter, Del).
            "shelf": kind === "disk" ? root.shelf : null,
            "keyboard": kind === "disk" ? root.cardKeyboard : null,
            "output": kind === "output" ? systemSource.output : null,
            "wifi": kind === "openwifi" ? systemSource.wifi : null
        };
    }

    // The bubble an island face stands for (copy, trash, disk, display, periph, progress, frozen, transfers): hovered or clicked,
    // the island grows into that bubble's own card, in place; null for the other faces.
    readonly property var faceBubble: {
        if (controller.pluginActive && transfer.token !== "" && controller.pluginToken === transfer.token)
            return transfer.info;
        if (!Activities.hasFaceCard(controller.activeActivity))
            return null;
        switch (controller.activeActivity) {
        case "copy":
            return copySource.face;
        case "trash":
            return trashSource.face;
        case "progress":
            return progress.face;
        case "frozen":
            return root.frozenFace;
        case "disk":
        case "display":
        case "periph":
        case "weatheralert":
            return root.machineEntry(controller.activeActivity);
        case "charging":
            // The open island's charge face; a click on it turns it into the charge card.
            return charge.detail ? charge.face : Object.assign({}, charge.face, {
                "kind": "chargeface"
            });
        }
        return null;
    }
    // Its card's header: the card is already open in place, so a source whose click only toggles its card in a bubble
    // keeps it here.
    function activateFace(bubble) {
        if (bubble?.source === "transfer" || bubble?.source === "progress")
            return;
        if (bubble?.id === "charge") {
            charge.detail = true;
            return;
        }
        root.bringBubble(bubble);
    }
    // The laptop battery's infos (IslandChargeSource.faceOf).
    readonly property var chargeKinds: ["charging", "charged", "unplugged", "battery", "batterycritical"]
    // Its card's close: the info goes (no bubble takes it over), and the island goes back.
    function dismissFace(bubble) {
        if (controller.activeActivity === "display")
            return screenSource.finish();
        root.dismissBubble(bubble);
        controller.finishTransient();
    }

    // The system source's title, icon and value follow its current kind only: a machine bubble whose kind it no longer
    // shows (another level took it, a card's output change) keeps what it said while it was that kind.
    property var machineHeld: null
    readonly property var machineShown: {
        const kind = controller.machineBubbleKind;
        if (!kind)
            return null;
        if (systemSource.kind !== kind && root.machineHeld?.kind === kind)
            return root.machineHeld;
        return root.machineEntry(kind);
    }
    onMachineShownChanged: {
        if (root.machineShown && systemSource.kind === root.machineShown.kind)
            root.machineHeld = root.machineShown;
    }

    readonly property var bubbleList: {
        if (!root.bubblesShown)
            return [];
        const list = [];
        if (root.machineShown)
            list.push(root.machineShown);
        // Sleep blocked stays while an app holds it, except while the island itself shows it.
        if (keepAwake.shown && controller.activeActivity !== "keepawake")
            list.push(keepAwake.face);
        // The charge stays while it charges, except while the island itself shows it or its settings keep the island silent.
        if (charge.lasting && systemSource.enabled && root.setting("islandChargingPulse") && controller.activeActivity !== "charging")
            list.push(charge.face);
        if (urgent.face)
            list.push(urgent.face);
        if (code2fa.face)
            list.push(code2fa.face);
        // A call stays while it lasts, except while the island itself shows it.
        if (callSource.shown && controller.activeActivity !== "call")
            list.push(callSource.face);
        // A job's progress, except while the island shows it, or its own notification there.
        if (progress.face && controller.activeActivity !== "progress" && (!progress.face.wrapper || notificationSource.currentWrapper !== progress.face.wrapper))
            list.push(progress.face);
        // Every transfer in one bubble (a browser's download still running among them), while the island is not showing
        // them; the finished download's own bubble comes after.
        if (transfer.face)
            list.push(transfer.face);
        if (shelf.face)
            list.push(shelf.face);
        // A copy just happened: a brief info, ahead of the other app bubbles, except while the island itself shows it.
        if (copySource.shown && !copySource.onIsland)
            list.push(copySource.face);
        // A file just went to the trash: its card offers Undo for a moment, except while the island itself offers it.
        if (trashSource.shown && !trashSource.onIsland)
            list.push(trashSource.face);
        // Printing stays while the job prints or the printer waits for a hand, except while the island itself shows it.
        if (printSource.shown && controller.activeActivity !== "print")
            list.push(printSource.face);
        if (usb.shown && controller.activeActivity !== "usb")
            list.push(usb.face);
        if (vpn.bubbleShown && controller.activeActivity !== "vpn")
            list.push(vpn.face);
        if (ssh.shown && controller.activeActivity !== "ssh")
            list.push(ssh.face);
        // The camera stays while an app films, except while the island itself shows it.
        if (cameraSource.shown && controller.activeActivity !== "camera")
            list.push(cameraSource.face);
        // An app that crashed stays, except while the island itself shows it.
        if (root.frozenFace && controller.activeActivity !== "frozen")
            list.push(root.frozenFace);
        // A finished download while the island is busy (DownloadService).
        if (DownloadService.face)
            list.push(DownloadService.face);
        // One the island is about to take (it does a moment later) is never a bubble, not even for a frame.
        const taker = root.islandTaker();
        for (const entry of IslandActivityService.waitingFor(controller, controller.pluginActive ? controller.pluginToken : "")) {
            if (entry.token === taker)
                continue;
            const face = Input.bubbleFace(entry.data);
            const ready = Input.readyFace(entry.data);
            list.push(Object.assign(face, {
                "id": entry.token,
                "source": "plugin",
                "kind": entry.kind,
                "token": entry.token,
                "seq": entry.seq,
                "icon": face.icon || "extension",
                "title": ready.title,
                "detail": ready.text
            }));
        }
        notificationSource.heldWrappers.filter(wrapper => !progress.owns(wrapper)).forEach((wrapper, index) => list.push({
                "id": "notification:" + index,
                "source": "notification",
                "critical": wrapper.urgency === NotificationUrgency.Critical || Arrival.ringing(wrapper.notification?.hints?.category),
                "call": Arrival.ringing(wrapper.notification?.hints?.category),
                "wrapper": wrapper,
                "seq": index,
                "app": wrapper.appName,
                "appIcon": wrapper.displayImage || "",
                "title": wrapper.summary || wrapper.appName,
                "detail": wrapper.body,
                "image": wrapper.displayImage || "",
                "icon": wrapper.fallbackIconName || "material:notifications",
                "received": Received.parse(wrapper.appName, wrapper.summary, wrapper.body, wrapper.notification?.hints, wrapper.desktopEntry),
                "progress": Received.parse(wrapper.appName, wrapper.summary, wrapper.body, wrapper.notification?.hints, wrapper.desktopEntry)?.progress ?? -1,
                "text": "",
                "accent": "primary"
            }));
        // Reopen a closed background app: not while the island itself shows it.
        if (reopen.shown && controller.activeActivity !== "reopen")
            reopen.faces.forEach(face => list.push(face));
        // Password copied: not while the island itself shows it.
        if (password.shown && controller.activeActivity !== "password")
            list.push(password.face);
        if (mediaSource.playing && controller.pluginActive && !root.mediaBubbleDismissed)
            list.push({
                "id": "media",
                "source": "media",
                "seq": 0,
                "image": mediaSource.artUrl || "",
                "icon": "music_note",
                "progress": -1,
                // Upright: how far the track played (the volume's liquid) and its time left; still while paused.
                "standLevel": mediaStand.level,
                "standText": mediaStand.text,
                "text": "",
                "accent": "primary"
            });
        return root.withoutEchoes(list);
    }
    // Never the same info twice: a bubble yields to the island's notification that says it, and a waiting notification
    // that only repeats a bubble, or what the island shows, is left out.
    function withoutEchoes(list) {
        const echo = !SettingsData.islandBriefBubbles && notificationSource.currentWrapper ? Echo.kind(notificationSource.appName, notificationSource.summary, notificationSource.body) : "";
        const told = new Set([echo, Echo.bubbleKind({
                "source": "system",
                "kind": controller.activeActivity
            }), DownloadService.shownIn === "island" ? "download" : ""]);
        list.forEach(face => told.add(face.source === "notification" ? "" : Echo.bubbleKind(face)));
        told.delete("");
        // A bubble with an Undo (the trash) never yields: its button must last its whole window.
        return list.filter(face => face.source === "notification" ? face.critical || !told.has(Echo.kind(face.app, face.title, face.detail)) : !echo || face.source === "trash" || Echo.bubbleKind(face) !== echo);
    }
    readonly property var bubbleSides: Activities.bubbleSides(root.bubbleList, root.quiet)

    function bringBubble(bubble) {
        if (bubble?.source === "progress") {
            progress.cardOpen = !progress.cardOpen;
            return;
        }
        if (bubble?.source === "transfer") {
            transfer.cardOpen = !transfer.cardOpen;
            return;
        }
        if (bubble?.source === "shelf") {
            // The shelf grows in the island, never in a card beside it (its face, Super+S).
            shelf.toggle();
            return;
        }
        if (bubble?.id === "keepawake") {
            keepAwake.cardOpen = !keepAwake.cardOpen;
            return;
        }
        if (bubble?.id === "charge") {
            charge.cardOpen = !charge.cardOpen;
            return;
        }
        if (bubble?.source === "call") {
            callSource.cardOpen = !callSource.cardOpen;
            return;
        }
        if (bubble?.source === "camera") {
            cameraSource.cardOpen = !cameraSource.cardOpen;
            return;
        }

        if (bubble?.source === "print") {
            printSource.cardOpen = !printSource.cardOpen;
            return;
        }
        switch (bubble?.source) {
        case "system":
            systemSource.open(bubble.kind, true);
            // A bubble that grows the island (weather): its card opens there at once, the pointer still on the bubble's spot.
            if (bubble.island === true && controller.activeActivity === bubble.kind)
                controller.faceCardPinned = true;
            return;
        case "urgent":
            urgent.go(urgent.call?.id ?? -1);
            return;
        case "notification":
            notificationSource.bringIn(bubble.wrapper);
            return;
        case "media":
            controller.requestActivity("media", true, false);
            return;
        case "trash":
            TrashService.openTrash();
            return;
        case "usb":
            usb.cardOpen = !usb.cardOpen;
            return;
        case "vpn":
            vpn.cardOpen = !vpn.cardOpen;
            return;
        case "ssh":
            ssh.cardOpen = !ssh.cardOpen;
            return;
        case "plugin":
            root.bringPlugin(bubble.token);
            return;
        case "reopen":
            reopen.reopen(bubble.app);
            return;
        case "password":
            password.clearNow();
        }
    }

    function bringPlugin(token) {
        const entry = IslandActivityService.entry(token);
        if (!entry)
            return;
        if (controller.pluginToken && controller.pluginToken !== token)
            IslandActivityService.markInterrupted(controller.pluginToken, controller);
        controller.beginPluginActivity(token, entry.kind, true, entry.kind === "glance" ? entry.timeoutMs : 0);
        controller.userHeld = true;
        IslandActivityService.markShown(token, controller);
    }

    function dismissBubble(bubble) {
        if (bubble?.source === "progress") {
            progress.dismiss();
            return;
        }
        if (bubble?.id === "keepawake") {
            keepAwake.dismissed = true;
            keepAwake.cardOpen = false;
            return;
        }
        // Closed from its card or the open island: hidden until the next plug.
        if (bubble?.id === "charge") {
            charge.dismissed = true;
            return;
        }
        if (bubble?.source === "call") {
            callSource.dismissed = true;
            callSource.cardOpen = false;
            return;
        }
        if (bubble?.source === "camera") {
            cameraSource.dismissed = true;
            cameraSource.cardOpen = false;
            return;
        }
        switch (bubble?.source) {
        case "system":
            if (bubble.kind === "eyes")
                EyeBreakService.skip();
            controller.hideMachineBubble();
            return;
        case "notification":
            notificationSource.dismissHeld(bubble.wrapper);
            return;
        case "media":
            root.mediaBubbleDismissed = true;
            return;
        case "urgent":
            urgent.clear();
            return;
        case "code2fa":
            code2fa.clear();
            return;
        case "transfer":
            transfer.dismiss();
            return;
        case "print":
            printSource.dismissed = true;
            printSource.cardOpen = false;
            return;
        case "frozen":
            AppCrashService.dismiss();
            return;
        case "download":
            DownloadService.clear();
            return;
        case "trash":
            trashSource.hide();
            return;
        case "copy":
            copySource.hide();
            return;
        case "usb":
            usb.dismiss();
            return;
        case "vpn":
            vpn.dismiss();
            return;
        case "ssh":
            ssh.dismiss();
            return;
        case "plugin":
            IslandActivityService.remove(bubble.token, "dismissed");
            return;
        case "reopen":
            reopen.forget(bubble.app);
            return;
        case "password":
            password.dismiss();
        }
    }

    // A card opened by a click closes like a hovered one once the pointer leaves it.
    function closeCard(bubble) {
        const owner = bubble?.id === "keepawake" ? keepAwake : bubble?.id === "charge" ? charge : ({
                "progress": progress,
                "call": callSource,
                "camera": cameraSource,
                "print": printSource,
                "usb": usb,
                "vpn": vpn,
                "ssh": ssh
            })[bubble?.source];
        if (owner)
            owner.cardOpen = false;
        if (bubble?.source === "transfer")
            transfer.closeCard();
        else if (bubble?.source === "shelf")
            shelf.closeCard();
    }

    function holdBubble(bubble, inside) {
        if (!inside)
            root.closeCard(bubble);
        if (bubble?.source === "system") {
            controller.machineBubbleHovered = inside;
            if (bubble.kind === "display")
                screenSource.hold(inside);
        } else if (bubble?.source === "progress")
            progress.hold(inside);
        else if (bubble?.source === "usb")
            usb.hold(inside);
        else if (bubble?.source === "vpn")
            vpn.hold(inside);
        else if (bubble?.source === "notification")
            notificationSource.holdTimeout(bubble.wrapper, inside);
        else if (bubble?.source === "reopen")
            reopen.hold(inside);
        else if (bubble?.source === "urgent")
            urgent.hold(inside);
        else if (bubble?.source === "download")
            DownloadService.hold(inside);
        else if (bubble?.source === "trash")
            trashSource.hold(inside);
        else if (bubble?.source === "copy")
            copySource.hold(inside);
        else if (bubble?.source === "code2fa")
            code2fa.hold(inside);
        else if (bubble?.source === "transfer")
            transfer.hold(inside);
        else if (bubble?.source === "shelf")
            shelf.hold(inside);
    }

    // The wheel on a level bubble sets it in place, like the wheel on the level face.
    function wheelBubble(bubble, wheel) {
        if (bubble?.id === "keepawake")
            return;
        // Reopen: the wheel walks back through older closes.
        if (bubble?.source === "reopen") {
            reopen.wheel(wheel.angleDelta.y > 0 ? 1 : wheel.angleDelta.y < 0 ? -1 : 0);
            return;
        }
        if (bubble?.source !== "system" || !systemSource.levelActivity)
            return;
        const step = wheel.angleDelta.y > 0 ? 0.05 : wheel.angleDelta.y < 0 ? -0.05 : 0;
        if (!step)
            return;
        systemSource.setRatio(systemSource.ratio + step);
        controller.showMachineBubble(bubble.kind);
    }

    Loader {
        id: pluginLoader

        readonly property string pluginId: root.pluginEntry?.pluginId ?? ""

        // The shell's own activities (polkit, the eye break, downloads...) ride the plugin path with a built-in face.
        readonly property var builtIn: ({
                "dms:auth": authActivityComponent,
                [EyeBreakService.sourceId]: eyesActivityComponent,
                [urgent.sourceId]: urgentActivityComponent,
                [DownloadService.sourceId]: downloadActivityComponent,
                [code2fa.sourceId]: code2faActivityComponent,
                [transfer.sourceId]: transferActivityComponent,
                [shelf.sourceId]: shelfActivityComponent
            })
        sourceComponent: builtIn[pluginId] ?? PluginService.pluginIslandComponents[pluginId] ?? null

        Component {
            id: authActivityComponent

            IslandAuthActivity {}
        }

        Component {
            id: eyesActivityComponent

            IslandEyesActivity {}
        }

        Component {
            id: urgentActivityComponent

            IslandUrgentActivity {}
        }

        Component {
            id: downloadActivityComponent

            IslandDownloadActivity {}
        }

        Component {
            id: code2faActivityComponent

            IslandCode2faActivity {}
        }

        Component {
            id: transferActivityComponent

            IslandTransferActivity {}
        }

        Component {
            id: shelfActivityComponent

            IslandShelfActivity {}
        }
        onLoaded: {
            // A face sets only the properties it declares (as DashWidgetGrid does): one it leaves out must not stop the rest.
            const give = (name, value) => {
                if (name in item)
                    item[name] = value;
            };
            give("pluginId", pluginId);
            give("pluginService", PluginService);
            give("token", Qt.binding(() => controller.pluginToken));
            give("kind", Qt.binding(() => root.pluginEntry?.kind ?? "live"));
            // update() swaps data inside the same entry object: follow the revision, not the entry.
            give("activityData", Qt.binding(() => root.pluginRevision >= 0 ? root.pluginEntry?.data ?? {} : {}));
            give("expanded", Qt.binding(() => controller.pluginActive && controller.expanded));
            give("interrupted", Qt.binding(() => !controller.pluginActive));
            give("screen", Qt.binding(() => root.screenName));
            give("edge", Qt.binding(() => root.edge));
            // Only while the plugin draws overflow; through face: item is null once the loader unloads.
            const face = item;
            give("islandRect", Qt.binding(() => !face.overflowContent ? Qt.rect(0, 0, 0, 0) : Qt.rect(root.hostOriginX + surface.currentVisualX, root.hostOriginY + surface.currentVisualY, surface.currentVisualWidth, surface.currentVisualHeight)));
            give("islandRadius", Qt.binding(() => controller.expanded ? controller.cornerRadius : Math.min(controller.compactFaceThickness / 2, controller.pillRadius)));
        }
    }

    readonly property var systemFaceChoice: IslandActivityService.systemFaceFor(systemSource.kind)

    Loader {
        id: systemFaceLoader

        active: !!root.systemFaceChoice
        sourceComponent: root.systemFaceChoice?.component ?? null
        onLoaded: {
            if ("pluginId" in item)
                item.pluginId = root.systemFaceChoice.pluginId;
            if ("pluginService" in item)
                item.pluginService = PluginService;
            if ("model" in item)
                item.model = systemSource;
        }
    }

    LazyLoader {
        active: !!root.pluginActivity?.overflowContent

        IslandOverflowWindow {
            screen: root.screen
            content: root.pluginActivity?.overflowContent ?? null
            // Hosted in a bar, the always-overlay setting does not apply: only a fullscreen request lifts it.
            layer: Layer.wantsOverlay(!root.embedded && root.setting("islandUseOverlayLayer"), root.setting("islandOverlayOnRequest"), root.pluginEntry) ? WlrLayer.Overlay : root.hostLayer
            shown: controller.pluginActive
        }
    }

    function sameEdgeSlots() {
        const stored = ConnectedModeState.surfaceDescriptors[root.screenName] ?? {};
        return ["popout", "modal"].filter(slot => (stored[slot]?.visible ?? false) && stored[slot].barSide === root.edge);
    }
    function ownBarPopout() {
        const popout = PopoutManager.currentPopoutsByScreen[root.screenName];
        return popout?.shouldBeVisible && popout.sourceRegistration?.context?.barId === root.barId ? popout : null;
    }
    // Connected chrome: the frame SDF draws the body, so a popout or modal presented on the same edge would share its silhouette.
    readonly property bool sameEdgeSurfacePresented: root.embedded && !!root.screenName && (root.connectedChrome ? root.sameEdgeSlots().length > 0 : (root.popoutRevision, root.ownBarPopout() !== null))
    onSameEdgeSurfacePresentedChanged: {
        if (root.sameEdgeSurfacePresented && controller.expanded)
            controller.requestCollapse();
    }

    // The guard runs both ways, but only for deliberate opens: a hover peek or an arriving notification must not take the user's popout away.
    function closeSameEdgeSurfaces() {
        if (!root.embedded || !root.screenName || !controller.keyboardDismissRequested)
            return;
        if (!root.connectedChrome) {
            if (root.ownBarPopout())
                PopoutManager.closePopoutForScreen(root.screen);
            return;
        }
        const slots = root.sameEdgeSlots();
        if (slots.includes("popout"))
            PopoutManager.closePopoutForScreen(root.screen);
        const modal = slots.includes("modal") ? ModalManager.currentModalsByScreen[root.screenName] : null;
        if (modal)
            ModalManager.closeModal(modal);
    }

    ConnectedSurfaceLease {
        id: lease

        claimPrefix: "island"
        slot: "island"
        retractsDock: true
        screenName: root.screenName
        enabled: root.connectedChrome
        active: root.connectedChrome
        presented: controller.expanded
        dockBlocked: controller.expanded
        dockSide: root.edge
        isCurrentOwner: name => name === root.screenName
        onRecoveryRequested: root.publishSurface()
    }

    function surfaceBodyRect() {
        return {
            "x": root.hostOriginX + surface.currentVisualX,
            "y": root.hostOriginY + surface.currentVisualY,
            "width": surface.currentVisualWidth,
            "height": surface.currentVisualHeight
        };
    }

    // Held while expanded or still springing back; a settled compact body sits inside the band and needs no slot.
    function publishSurface() {
        if (!root.connectedChrome || (!controller.expanded && !surface.motionRunning)) {
            lease.release();
            return;
        }
        lease.publish({
            "kind": "island",
            "barSide": root.edge,
            "visible": true,
            "presented": controller.expanded,
            "surfaceRadius": Theme.connectedSurfaceRadius,
            "bodyRect": root.surfaceBodyRect()
        }, false);
    }

    // A machine face another face replaced goes on in the machine bubble, its buttons with it (a screen's question
    // never settles unseen); app faces leave for their own bubble by themselves.
    Connections {
        target: controller

        function onSystemActivityReplaced(activityId) {
            if ((activityId === "disk" || activityId === "display" || activityId === "periph" || activityId === "weatheralert") && controller.bubblesEnabled)
                controller.showMachineBubble(activityId);
        }
    }

    Connections {
        target: root.Window.window
        enabled: root.editRoomWaiting && root.surfaceResizes && root.surfaceFits

        function onFrameSwapped() {
            controller.editRoomGranted = true;
        }
    }

    Connections {
        target: surface.surfaceMotion

        function onStepped() {
            // settle() emits after running drops, so the latch clears on the last step of the collapse spring.
            if (!controller.expanded && !surface.motionRunning)
                root.sheetOut = false;
            if (!surface.motionRunning)
                root.releaseEditSurface();
            if (!root.connectedChrome)
                return;
            const body = root.surfaceBodyRect();
            lease.updateBody(body.x, body.y, body.width, body.height);
        }
    }

    // A sheet waiting for the bar window (a frame at the grown size, or the band size) that never comes holds the island.
    Timer {
        interval: 3000
        running: root.editRoomWaiting || surface.targetPending
        onTriggered: {
            if (root.editRoomWaiting)
                controller.editRoomGranted = true;
            if (!surface.targetPending)
                return;
            surface.targetPending = false;
            surface.surfaceMotion.setTarget(surface.resolveTarget(controller.targetDescriptor));
        }
    }


    Timer {
        id: keyboardActivationTimer

        interval: 60
        onTriggered: {
            if (root.keyCard)
                root.keyCard.forceActiveFocus(Qt.PopupFocusReason);
            else if (controller.keyboardDismissRequested && !surface.requestActivityFocus())
                islandFocus.forceActiveFocus(Qt.PopupFocusReason);
        }
    }

    Timer {
        id: keyboardRearmTimer

        interval: 80
        onTriggered: root.keyboardFocusArmed = true
    }

    Connections {
        target: PopoutManager

        function onPopoutChanged() {
            root.popoutRevision++;
        }

        function onPopoutOpening() {
            Qt.callLater(root.collapseForOpenedPopout);
        }

        function onScreenshotActiveChanged() {
            if (!PopoutManager.screenshotActive && controller.keyboardDismissRequested)
                root.requestKeyboardFocus();
        }
    }

    IslandController {
        id: controller

        reducedMotion: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
        // The island holds the keyboard only when given it (keyboard or a deliberate open), never on a hover.
        arrivalFocused: islandFocus.activeFocus
        faceCardAvailable: !!root.faceBubble
        onKeyboardDismissRequestedChanged: root.requestKeyboardFocus()
        onPluginDismissed: (token, reason) => IslandActivityService.remove(token, reason)
        onLauncherSessionActiveChanged: {
            if (!launcherSessionActive)
                islandTransientSurfaces.closeAll();
        }

        barConfig: root.barConfig
        screen: root.screen
        bubblesEnabled: root.bubblesShown
        edge: root.edge
        sectionOriginX: root.sectionOriginX
        sectionOriginY: root.sectionOriginY
        transientSurfaces: islandTransientSurfaces
        freeMode: root.freeMode
        dotMode: root.dotMode
        embedded: root.embedded
        notch: root.notch
        dotSize: root.dotSize * root.freeScale
        interactionMode: !root.freeMode && root.setting("islandInteractionMode") === "hybrid" ? "hybrid" : "click"
        inputSuspended: PopoutManager.screenshotActive
        alongOffset: root.freeMode || root.embedded ? 0 : Math.max(-root.maximumAlongOffset, Math.min(root.maximumAlongOffset, root.setting("islandAlongOffset")))
        outerGap: root.outerGap
        compactThickness: root.compactThickness
        cornerRadius: root.connectedChrome ? Theme.connectedSurfaceRadius : Theme.windowRadius
        pillRadius: BarMetrics.pillRadius(root.compactThickness, root.barConfig?.widgetStyle ?? "pills")
        homeCompactTight: root.setting("islandHomeCompactTight")
        homeStatusContent: SettingsData.islandHomeStatusContent(root.barConfig)
        homeClockDisplay: SettingsData.islandClockDisplay(root.barConfig)
        homeVolumeDisplay: SettingsData.islandLevelDisplay(root.barConfig, "islandHomeVolumeDisplay")
        homeBrightnessDisplay: SettingsData.islandLevelDisplay(root.barConfig, "islandHomeBrightnessDisplay")
        batteryStyle: root.setting("islandBatteryStyle")
        mediaClockVisible: root.setting("islandMediaClockVisible")
        mediaLyrics: root.setting("islandMediaLyrics")
        dashTabs: root.setting("islandDashTabs")
        // Home and media share the dot face; see mediaFaceToggleAvailable.
        mediaAutoSwitch: !root.dotMode && root.setting("islandMediaAutoSwitch")
        launcherCycleEnabled: SettingsData.launcherStyle === "island"
        dashboardAvailableWidth: Math.max(0, (root.screen?.width ?? root.referenceScreenWidth) - (root.isVertical ? root.crossInsetStart + root.crossInsetEnd + root.outerGap + root.nearInset : root.alongInset) - Theme.spacingL * 2)
        dashboardAvailableHeight: Math.max(0, (root.screen?.height ?? root.referenceScreenHeight) - (root.isVertical ? root.alongInset : root.crossInsetStart + root.crossInsetEnd + root.outerGap + root.nearInset) - Theme.spacingL * 2)
        notificationExpandAllowed: root.setting("islandNotificationExpand")
        unreadNotificationCount: root.setting("islandNotificationBadgeClearOnOpen") ? NotificationService.unreadCount : NotificationService.notifications.length
        wingCountsNotifications: (root.bubbleSides?.apps ?? []).some(b => b.source === "notification")
        hoverOpenDelay: Math.max(0, Math.min(root.maxHoverDelay, root.setting("islandHoverOpenDelay")))
        hoverCloseDelay: Math.max(0, Math.min(root.maxHoverDelay, root.setting("islandHoverCloseDelay")))
        pluginExpandable: root.readyFace ? (root.readyFace.text !== "" || root.readyFace.actions.length > 0) : !!root.pluginActivity?.expandedContent
        systemFaceCompactLength: systemFaceLoader.item?.compactLength > 0 ? Input.faceSize(systemFaceLoader.item, "compactLength") : 0
        systemFaceExpandedWidth: systemFaceLoader.item?.expandedWidth > 0 ? Math.min(dashboardAvailableWidth, Input.faceSize(systemFaceLoader.item, "expandedWidth")) : 0
        systemFaceExpandedHeight: systemFaceLoader.item?.expandedHeight > 0 ? Math.min(dashboardAvailableHeight, Input.faceSize(systemFaceLoader.item, "expandedHeight")) : 0
        pluginCompactLength: Input.faceSize(root.pluginActivity, "compactLength")
        pluginExpandedWidth: Math.min(dashboardAvailableWidth, Input.faceSize(root.pluginActivity, "expandedWidth"))
        // The ready sheet on the card grid: margins, the header (one line each beside the ring, which is the icon and four
        // of its strokes: ReadyActivityRing.ringWidth, 3 px), then the button row.
        pluginExpandedHeight: Math.min(dashboardAvailableHeight, root.readyFace ? NotificationMetrics.cardPadding * 2 + Theme.iconSize + 4 * root.readyRingWidth + (root.readyFace.actions.length > 0 ? Theme.spacingS + Theme.buttonHeightS : 0) : Input.faceSize(root.pluginActivity, "expandedHeight"))
    }

    DLauncher.Controller {
        id: launcherController

        active: controller.launcherSessionActive
        retainResultsOnClose: !SettingsData.dankLauncherV2UnloadOnClose
        viewModeContext: "spotlight"
        forceLinearNavigation: true
    }

    TransientSurfaceTracker {
        id: islandTransientSurfaces
    }

    IslandMediaSource {
        id: mediaSource

        controller: controller
    }

    // The media bubble standing beside an open sheet: how far the track played and its time left. DMS polls the position
    // once a second only while it can be seen standing and the music plays; paused, nothing moves.
    QtObject {
        id: mediaStand

        readonly property var player: mediaSource.player
        readonly property bool watched: controller.expanded && controller.pluginActive && mediaSource.playing && !root.mediaBubbleDismissed
        readonly property var now: Kit.trackStand(mediaStand.player?.position ?? 0, mediaStand.player?.lengthSupported ? mediaStand.player.length : 0, I18n.tr("%1m"), I18n.tr("%1h", "hours abbreviation, %1 is a number"))
        readonly property real level: mediaStand.now.level
        readonly property string text: mediaStand.now.text
        onWatchedChanged: {
            if (!mediaStand.watched)
                return MprisController.removePositionRef();
            MprisController.addPositionRef();
            // Fresh at once, not a second late.
            mediaStand.player?.positionChanged();
        }
        Component.onDestruction: {
            if (mediaStand.watched)
                MprisController.removePositionRef();
        }
    }

    IslandSystemSource {
        id: systemSource

        controller: controller
        enabled: root.setting("islandSystemOsd") && root.barConfig?.visible !== false
        keepAwake: root.keepAwake
        reopen: root.reopen
        call: root.callSource
        printSource: root.printSource
        usb: root.usb
        password: root.password
        camera: root.cameraSource
        islandFaces: root.islandFaces
    }

    // The camera (source "camera"): an app that starts filming plays in the free island first, then stays as a bubble.
    readonly property IslandCameraSource cameraSource: IslandCameraSource {
        enabled: root.barConfig?.visible !== false
        onArrived: root.playApp("camera")
    }

    // A call (source "call"): its start plays in the free island first, then it stays as a bubble on the apps side.
    readonly property IslandCallSource callSource: IslandCallSource {
        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playApp("call")
    }

    // Sleep blocked (kind "keepawake"): an app that starts blocking plays in the free island first, then stays as a bubble.
    readonly property IslandKeepAwakeSource keepAwake: IslandKeepAwakeSource {
        enabled: root.barConfig?.visible !== false
        onArrived: {
            if (systemSource.enabled && controller.requestSystemActivity("keepawake"))
                systemSource.kind = "keepawake";
        }
    }

    // The laptop battery (IslandChargeSource): plugging in opens the island's charge face, full, unplugged, low and
    // critical are their own faces; the lasting bubble stays while it charges.
    readonly property IslandChargeSource charge: IslandChargeSource {
        controller: controller
        enabled: root.barConfig?.visible !== false
        onStepped: step => root.playCharge(step)
    }
    function playCharge(step) {
        const pulses = systemSource.enabled && root.setting("islandChargingPulse");
        switch (step) {
        case "plugged":
            // Levels in bubbles (rule 0 ter): the lasting bubble alone says it.
            if (pulses && !SettingsData.islandLevelBubbles)
                root.openChargeFace();
            // A plug the face did not show drops its ring: a later hover or ipc open is no plug.
            if (!root.charge.shown)
                root.charge.takeRing();
            return;
        case "full":
            if (pulses)
                root.playMachine("charged");
            return;
        case "unplugged":
            // The charge face goes at once (its sea would hold the bolt); the unplugged face takes the island.
            if (controller.activeActivity === "charging")
                controller.finishTransient();
            if (pulses)
                root.playMachine("unplugged");
            return;
        case "low":
            if (SettingsData.batteryNotifyLow)
                root.playMachine("battery");
            return;
        case "critical":
            if (SettingsData.batteryNotifyCritical)
                root.playMachine("batterycritical");
        }
    }
    // The open island's charge face, big its whole 5 s with no compact phase (mouvement.md §3, exception of 27/10); a
    // busy island leaves it to the lasting bubble.
    function openChargeFace() {
        if (!systemSource.enabled || !controller.requestSystemActivity("charging"))
            return;
        systemSource.kind = "charging";
        systemSource.openedKind = "charging";
        charge.detail = false;
        controller.faceCardPinned = true;
    }
    Connections {
        target: controller

        // Hovered while it charges, the island opens its charge face again (cartes.md §4, exception of 27/10).
        function onPointerInsideChanged() {
            if (controller.pointerInside && root.charge.live && !controller.expanded && (controller.activeActivity === "home" || controller.activeActivity === "media"))
                root.openChargeFace();
        }
    }

    // Reopen (apps side): a closed background app plays in the free island first, then waits as a bubble.
    readonly property IslandReopenSource reopen: IslandReopenSource {
        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playApp("reopen")
    }

    // A window calling for attention (niri urgent), apps side: the free island first, else a bubble for importantTimeoutMs.
    readonly property IslandUrgentSource urgent: IslandUrgentSource {
        controller: controller
        screenName: root.screenName
        enabled: root.bubblesShown && root.barConfig?.visible !== false
    }

    // A one-time code from a notification, apps side: the free island first, else its bubble (hidden until hovered).
    readonly property IslandCode2faSource code2fa: IslandCode2faSource {
        controller: controller
        screenName: root.screenName
        enabled: root.bubblesShown && root.barConfig?.visible !== false
    }

    // Transfers (downloads, torrents, copies, archives), apps side: the free island first, else one bubble for all.
    readonly property IslandTransferSource transfer: IslandTransferSource {
        controller: controller
        screenName: root.screenName
        enabled: root.bubblesShown && root.barConfig?.visible !== false
    }

    // The shelf (files dragged onto the island, kept as links): a bubble on the machine side, the island only for the drop.
    readonly property IslandShelfSource shelf: IslandShelfSource {
        controller: controller
        screenName: root.screenName
        enabled: root.bubblesShown && root.barConfig?.visible !== false
        shapeSize: surface.bubbles.unitPx
        iconSize: surface.bubbles.iconFit
    }
    Binding {
        target: controller
        property: "holdOpen"
        value: root.shelf.held && controller.pluginToken === root.shelf.token
    }

    // Progress (notifications with a "value" hint): apps side; click opens its card.
    readonly property IslandProgressSource progress: IslandProgressSource {
        enabled: root.barConfig?.visible !== false
    }

    // Printing (source "print", apps side): a new job or a printer error plays in the free island first, then stays a bubble.
    readonly property IslandPrintSource printSource: IslandPrintSource {
        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: {
            if (systemSource.enabled && controller.requestSystemActivity("print"))
                systemSource.kind = "print";
        }
    }

    // USB stick (source "usb", apps side): a plugged stick plays in the free island first, then stays as a bubble.
    readonly property IslandUsbSource usb: IslandUsbSource {
        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: {
            if (systemSource.enabled && controller.requestSystemActivity("usb"))
                systemSource.kind = "usb";
        }
    }

    // Password copied (source "password", apps side): plays in the free island first, then stays a bubble for its 30 s.
    readonly property IslandPasswordSource password: IslandPasswordSource {
        enabled: root.barConfig?.visible !== false
        onArrived: {
            if (systemSource.enabled && controller.requestSystemActivity("password"))
                systemSource.kind = "password";
        }
    }

    // VPN dropped (source "vpn", apps side): plays in the free island first; a wanted cut ends there, a lost one stays.
    readonly property IslandVpnSource vpn: IslandVpnSource {
        controller: controller
        enabled: root.barConfig?.visible !== false
        onDropped: {
            if (systemSource.enabled && controller.requestSystemActivity("vpn")) {
                systemSource.kind = "vpn";
                root.vpn.tookIsland = true;
            }
        }
    }

    // Incoming SSH (source "ssh", apps side): a new session plays in the free island first, then stays while one is open.
    readonly property IslandSshSource ssh: IslandSshSource {
        enabled: root.barConfig?.visible !== false
        onArrived: {
            if (systemSource.enabled && controller.requestSystemActivity("ssh"))
                systemSource.kind = "ssh";
        }
    }

    IslandDiskSource {
        id: diskSource

        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playMachine("disk")
    }

    IslandScreenSource {
        id: screenSource

        controller: controller
        screenName: root.screenName
        enabled: root.barConfig?.visible !== false
        onArrived: root.playMachine("display")
    }

    IslandPeriphSource {
        id: periphSource

        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playMachine("periph")
    }

    IslandWeatherSource {
        id: weatherSource

        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playMachine("weatheralert")
    }

    // Copy and trash: brief info, the free island first (unless brief info lives in bubbles), else their bubble.
    IslandCopySource {
        id: copySource

        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playApp("copy")
    }

    IslandTrashSource {
        id: trashSource

        controller: controller
        enabled: root.barConfig?.visible !== false
        onArrived: root.playApp("trash")
    }

    IslandNotificationSource {
        id: notificationSource

        controller: controller
        targetScreen: root.screen
        shownKinds: [Echo.bubbleKind({
                "source": "system",
                "kind": controller.activeActivity
            }), trashSource.shown ? "trash" : ""]
        enabled: !root.setting("islandNotificationPopups") && root.barConfig?.visible !== false
    }

    DIslandSurface {
        id: surface

        anchors.fill: parent
        controller: controller
        mediaModel: mediaSource
        systemModel: systemSource
        notificationModel: notificationSource
        launcherController: launcherController
        launcherTransientSurfaceTracker: islandTransientSurfaces
        effectiveScreen: root.screen
        hostOriginX: root.hostOriginX
        hostOriginY: root.hostOriginY
        freeMode: root.freeMode
        anchor: root.anchor
        anchorSnaps: root.anchorSnaps
        anchorAlong: root.anchorAlong
        nearInset: root.nearInset
        bandAlongStart: root.bandAlongStart
        bandAlongEnd: root.bandAlongEnd
        hostReady: root.hostReady
        freeMargin: root.freeMargin
        compactFaceOverride: root.dotMode ? dotFaceComponent : null
        pluginActivity: root.pluginActivity
        pluginFace: root.readyFace
        systemFace: systemFaceLoader.item
        chrome: root.chrome
        notch: root.notch
        notchRadius: BarMetrics.gothRadius(root.barConfig)
        bandColor: root.bandColor
        compactBackground: root.embedded && root.setting("islandWidgetBackground") === true && !(root.barConfig?.noBackground ?? false)
        compactBackgroundColor: BarMetrics.widgetFill(root.barConfig)
        opacity: root.freeOpacity
        reducedMotion: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
        springStiffness: Math.max(root.springStiffnessRange[0], Math.min(root.springStiffnessRange[1], root.setting("islandSpringStiffness"))) / (root.motionScale * root.motionScale)
        // An arrival sets its own bounce (damping ratio) on the island's stiffness and mass while it plays.
        springDamping: controller.arrivalDampingRatio > 0 ? 2 * controller.arrivalDampingRatio * Math.sqrt(springStiffness * springMass) : Math.max(root.springDampingRange[0], Math.min(root.springDampingRange[1], root.setting("islandSpringDamping"))) / root.motionScale
        springMass: Math.max(root.springMassRange[0], Math.min(root.springMassRange[1], root.setting("islandSpringMass")))
        palette: root.setting("islandPalette")
        highContrast: !root.embedded && root.setting("islandHighContrast")
        transparency: SettingsData.barTransparency(root.barConfig)
        surfaceBase: SettingsData.barSurfaceColor(root.barConfig)
        onScrollWheel: wheel => root.scrollWheel(wheel)
        bubbleSides: root.bubbleSides
        shelf: root.shelf
        onBubbleActivated: bubble => root.bringBubble(bubble)
        onBubbleDismissed: bubble => root.dismissBubble(bubble)
        onBubbleHovered: (bubble, inside) => root.holdBubble(bubble, inside)
        onBubbleWheeled: (bubble, wheel) => root.wheelBubble(bubble, wheel)
        faceBubble: root.faceBubble
        onFaceActivated: bubble => root.activateFace(bubble)
        onFaceDismissed: bubble => root.dismissFace(bubble)

        Behavior on opacity {
            NumberAnimation {
                duration: surface.reducedMotion ? 0 : Theme.mediumDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Component {
        id: dotFaceComponent

        DotCompact {
            controller: controller
            iconName: root.setting("islandFreeIcon")
            iconMode: root.setting("islandFreeIconMode")
            iconPath: root.setting("islandFreeIconPath")
            iconColor: root.setting("islandFreeIconColor")
        }
    }

    FocusScope {
        id: islandFocus

        anchors.fill: parent
        Keys.onEscapePressed: event => {
            controller.requestDismiss();
            event.accepted = true;
        }
        Keys.onLeftPressed: event => event.accepted = controller.arrivalStep(I18n.isRtl ? 1 : -1)
        Keys.onRightPressed: event => event.accepted = controller.arrivalStep(I18n.isRtl ? -1 : 1)
    }
}
