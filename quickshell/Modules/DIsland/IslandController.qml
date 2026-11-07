pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Clipboard
import qs.Modals.DLauncherV2.Components
import qs.Modules.ControlCenter
import qs.Modules.DBar
import qs.Modules.DDash
import qs.Modules.Notifications
import "../../Common/IslandActivities.js" as Activities
import "../../Common/IslandArrival.js" as Arrival
import "../../Common/IslandHover.js" as Hover
import "../../Common/IslandKit.js" as IslandKit

QtObject {
    id: root

    property string interactionMode: "click"
    property bool hoverExpanded: false
    property bool inputSuspended: false
    property bool expanded: false
    property bool pointerInside: false
    // A right-click face swap resizes the island under the pointer; hover stays off until it leaves.
    property bool hoverHeld: false
    property int slotHoverCount: 0
    readonly property bool slotHovered: slotHoverCount > 0
    property bool keyboardDismissRequested: false
    property string activeActivity: "home"
    property bool mediaAvailable: false
    property bool mediaPreferred: false
    property bool mediaAutoSwitch: false
    property bool launcherCycleEnabled: false
    property bool launcherSessionActive: false
    property bool launcherInputFocused: false
    onLauncherInputFocusedChanged: {
        if (launcherInputFocused)
            hoverExpanded = false;
    }
    property var transientSurfaces: null
    readonly property bool transientSurfacesActive: transientSurfaces?.active ?? false
    onTransientSurfacesActiveChanged: {
        if (!transientSurfacesActive)
            return;
        hoverExpanded = false;
        hoverCloseTimer.stop();
    }
    property string launcherPendingQuery: ""
    property string launcherPendingMode: ""
    property string controlCenterPendingSection: ""
    property bool notificationExpandAllowed: false
    property bool keyboardYielded: false
    property real alongOffset: 0
    property real outerGap: 8
    property var barConfig: null
    property var screen: null
    property string edge: "top"
    // Screen position of the host window origin; item coordinates inside the island are window-relative.
    property real sectionOriginX: 0
    property real sectionOriginY: 0
    readonly property bool isVertical: edge === "left" || edge === "right"
    readonly property bool farEdge: edge === "bottom" || edge === "right"
    property real cornerRadius: 34
    property real pillRadius: cornerRadius
    readonly property real edgeCornerRadius: Math.round(cornerRadius * 0.75)
    property bool freeMode: false
    property bool dotMode: false
    // Hosted in a bar: the sheet is flush with the band, so its near corners stay square.
    property bool embedded: false
    property bool notch: false
    property real dotSize: 48
    property real compactThickness: 38
    property string batteryStyle: "duo"
    property bool mediaClockVisible: true
    property bool mediaLyrics: false
    property bool dashTabs: false
    // Carries tab-bar focus across a face switch.
    property bool dashNavigationFocused: false
    property int transientTimeout: Activities.briefTimeoutMs
    readonly property int undoTimeout: Activities.undoTimeoutMs
    property int notificationTimeout: Activities.glanceTimeoutMs
    property string transientReturnActivity: ""
    // The last system face a destination, an alert or another face pushed out: the host brings it back once idle.
    // shortcut: only the latest one is kept, an older one pushed out meanwhile ends in its bubble; keep a list if it matters.
    property string displacedSystemActivity: ""
    property string suspendedActivity: ""
    property bool suspendedExpanded: false
    property bool suspendedKeyboardDismissRequested: false
    property int hoverOpenDelay: 150
    property int hoverCloseDelay: 150
    property int mediaReturnDelay: 1800
    readonly property real controlCenterMaxHeight: dashboardAvailableHeight
    property string editingActivity: ""
    property real editRoom: 0
    // The bar host grants the room once its surface has presented a frame at the grown size.
    property bool editRoomGranted: false
    readonly property real controlCenterSheetInset: CcMetrics.islandInset * 2
    readonly property int controlCenterColumnCap: CcMetrics.columnCapFor(dashboardAvailableWidth - controlCenterSheetInset - PopoutMetrics.editOverflow * 2)
    readonly property int controlCenterColumns: Math.min(CcMetrics.gridColumns, controlCenterColumnCap)
    readonly property real controlCenterSheetWidth: CcMetrics.sheetWidthFor(controlCenterColumns)
    readonly property real controlCenterMaxWidth: CcMetrics.sheetWidthFor(editingActivity === "controlcenter" ? controlCenterColumnCap : controlCenterColumns) + controlCenterSheetInset
    readonly property real controlCenterHeight: controlCenterHeightFor(editRoomGranted && editingActivity === "controlcenter")

    property bool homeCompactTight: false
    readonly property bool compactTight: homeCompactTight && !dotMode
    readonly property bool compactDense: compactTight || compactThickness < 40
    readonly property real compactFaceThickness: compactTight ? Math.max(16, Math.min(32, compactThickness - 8)) : BarMetrics.compactFaceThickness(compactThickness)
    readonly property real compactIconSize: Math.max(14, Math.min(32, (compactTight ? compactFaceThickness : compactThickness) - 8))

    property int unreadNotificationCount: 0
    // The apps wing already shows how many wait: one figure on screen, not two that disagree.
    property bool wingCountsNotifications: false
    readonly property bool homeNotificationBadge: (root.dotMode || SettingsData.islandHomeGroupEnabled(root.barConfig, "notifications")) && unreadNotificationCount > 0 && !wingCountsNotifications
    readonly property bool homeWeatherEnabled: SettingsData.weatherEnabled && SettingsData.islandHomeGroupEnabled(root.barConfig, "weather")
    readonly property real homeSlotMargin: homeCompactTight ? Theme.spacingS : Theme.spacingM
    property real homeContentLength: 200
    property real mediaContentLength: 360
    property real dashboardAvailableWidth: 1920
    property real dashboardAvailableHeight: 1080
    readonly property int dashboardColumnCap: DashMetrics.columnCapFor(dashboardAvailableWidth - PopoutMetrics.editOverflow * 2, SettingsData.showWeekNumber)
    readonly property real dashboardMaxWidth: Math.min(dashboardAvailableWidth, DashMetrics.widthFor(SettingsData.showWeekNumber, undefined, editingActivity !== "" ? dashboardColumnCap : DashRegistry.widestPanelColumns))
    property var dashboardContentHeights: ({})
    // Plugin tabs have no island face, and the media face needs a player.
    readonly property var dashTabIds: dashTabs ? DashRegistry.navigationIds.filter(id => DashRegistry.isAction(id) || dashActivityFor(id) !== "") : []
    readonly property var dashTabBarModel: dashTabIds.length === 0 ? [] : DashRegistry.tabBarModel.filter((_, index) => dashTabIds.indexOf(DashRegistry.navigationIds[index]) >= 0)
    readonly property real dashChromeHeight: DashMetrics.islandChromeHeight(dashTabIds.length > 1 ? Theme.navigationHeight : 0)
    readonly property real editSurfaceHeight: editRoom <= 0 ? 0 : editingActivity === "controlcenter" ? controlCenterHeightFor(true) : dashboardHeightFor(editingActivity, true)
    readonly property real dashboardHeight: Math.min(dashboardAvailableHeight, Math.max(DashMetrics.tabDefaultHeight + root.dashChromeHeight, ...Object.values(dashboardContentHeights)))
    readonly property int dashboardRowBudget: Math.max(DashMetrics.minimumTabRows, Math.floor((dashboardAvailableHeight - DashMetrics.islandEditChromeHeight + DashMetrics.gridGap) / (DashMetrics.gridRowUnit + DashMetrics.gridGap)))
    readonly property real mediaCompactMaxLength: 360
    property real notificationContentLength: 0
    readonly property real notificationCompactMinLength: isVertical ? compactFaceThickness : (compactDense ? 200 : 240)
    readonly property real notificationCompactMaxLength: mediaCompactMaxLength

    property string pluginToken: ""
    property string pluginKind: "live"
    property bool pluginExpandable: false
    property real pluginCompactLength: 240
    property real pluginExpandedWidth: 460
    property real pluginExpandedHeight: 200
    property int pluginTimeoutMs: 0
    property string pluginReturnActivity: ""
    property bool pluginReturnExpanded: false
    // The open card closes only from itself (the shelf: its close button, Super+S): clicks in or out and Escape keep it.
    property bool holdOpen: false
    readonly property bool pluginActive: activeActivity === "plugin"

    // Set while the island shows what the user brought in from a bubble; an activity it pushed aside waits for it.
    property bool userHeld: false
    onActiveActivityChanged: {
        userHeld = false;
        faceCardPinned = false;
        // A swell belongs to the face that arrived.
        arrivalSwelling = false;
    }
    onExpandedChanged: {
        if (expanded)
            return;
        userHeld = false;
        dashNavigationFocused = false;
        // Folding clears a keyboard handed back to the windows (a click outside, a launcher over the card): the next
        // open takes it again, whatever path closed the island.
        keyboardYielded = false;
    }
    // The machine bubble's card opened without a pointer (island card), until that bubble leaves.
    property bool machineCardOpen: false
    // Off behind the lock screen and on islands away from the focused screen.
    property bool bubblesEnabled: true
    onBubblesEnabledChanged: {
        if (!bubblesEnabled)
            hideMachineBubble();
    }
    // The leading bubble: a machine change the island could not show.
    property string machineBubbleKind: ""
    // A bubble that leaves under the pointer gets no hover exit: without this reset the next one would never time out.
    onMachineBubbleKindChanged: {
        if (!machineBubbleKind)
            machineBubbleHovered = false;
    }
    property bool machineBubbleHovered: false
    // A card opened over IPC holds its bubble as a dwelt hover does (IslandMachineCard.js).
    readonly property bool machineBubbleHeld: machineBubbleHovered || machineCardOpen
    // A held bubble stays while the pointer is on it, and gets its full time again once let go.
    onMachineBubbleHeldChanged: {
        if (machineBubbleHeld)
            machineBubbleTimer.stop();
        else if (machineBubbleKind)
            machineBubbleTimer.restart();
    }

    function showMachineBubble(activityId) {
        // "eyes" (EyeBreakService) has its own island activity and comes here only while the island is busy.
        if (!isSystemActivity(activityId) && activityId !== "eyes")
            return false;
        machineBubbleKind = activityId;
        if (!machineBubbleHeld)
            machineBubbleTimer.restart();
        return true;
    }

    function hideMachineBubble() {
        machineBubbleTimer.stop();
        machineBubbleKind = "";
    }

    // Arrival of infos (IslandArrival.js): the island swells as an info arrives, opens its card a while (the burst: infos
    // rolling over each other, a countdown dot each), then folds to compact until the notification's time is up.
    property bool reducedMotion: false
    readonly property real animationBase: Theme.currentAnimationBaseDuration
    readonly property string arrivalStyle: SettingsData.islandArrivalStyle
    property var burst: Arrival.emptyBurst()
    readonly property var arrivalCurrent: burst.items[burst.index] ?? null
    readonly property int arrivalCount: burst.items.length
    readonly property int arrivalTopTier: Arrival.topTier(burst.items)
    // Bumped each time the shown info changes, so the source can follow it.
    property int arrivalShown: 0
    // rest | big (the card) | compact (folded, until the notification's time is up)
    property string arrivalPhase: "rest"
    property var arrivalPulse: null
    property bool arrivalSwelling: false
    // Bumped per tint flash (arrivalTint its strength) and per small bounce of a newcomer rolling in (arrivalNudges).
    property int arrivalFlashes: 0
    property real arrivalTint: 0
    property int arrivalNudges: 0
    property var countdown: Arrival.freezeEmpty(Arrival.countdown(0, 0), 0, 0)
    property bool arrivalDragging: false
    property bool arrivalFocused: false
    readonly property bool arrivalHeld: arrivalPhase === "big" && (pointerInside || arrivalDragging || arrivalFocused || expanded)
    // The finger's pull on the island's height while it drags up or down.
    property real arrivalPull: 0
    property var arrivalWheelState: Arrival.wheelIdle()
    readonly property bool arrivalBrowsable: arrivalPhase === "big" && !expanded && arrivalCount > 1
    // Infos of a burst that ended: they leave the island for the notification list.
    signal arrivalReleased(var items)

    readonly property real arrivalDampingRatio: arrivalPhase !== "rest" || arrivalSwelling ? (arrivalPulse?.ratio ?? 0) : 0
    readonly property real arrivalCardWidth: Math.min(NotificationMetrics.popupWidth, Math.max(NotificationMetrics.popupMinWidth, dashboardAvailableWidth * NotificationMetrics.popupScreenRatio)) + (arrivalTopTier >= 2 ? Theme.spacingL * 2 : 0)
    readonly property real arrivalCardHeight: NotificationMetrics.cardPadding * 2 + NotificationMetrics.appIconSize + (arrivalCurrent?.action ? Theme.spacingS + Theme.buttonHeightS : 0) + (arrivalTopTier >= 2 ? Theme.spacingM : 0)
    readonly property var arrivalBigTarget: {
        const radius = Math.min(arrivalCardHeight / 2, NotificationMetrics.popupRadius);
        return Object.assign(pillTarget(arrivalCardWidth, arrivalCardHeight), cardRadii(radius));
    }
    readonly property bool arrivalCardShown: arrivalPhase === "big" && notificationActive && !isVertical

    // An island face whose info has a bubble (IslandBarHost.faceBubble): hovered (a click lands on a hovered face), the
    // island grows in place into that bubble's own card, like an arrival card, never a bubble beside it. Its clock is
    // frozen meanwhile (timeoutSuspended, the pointer is in) and starts over once it leaves. The surface measures the card.
    property bool faceCardAvailable: false
    property real faceCardHeight: 0
    // Opened from a bubble that grows the island (weather): held until the pointer has been in the island and left it.
    property bool faceCardPinned: false
    onPointerInsideChanged: {
        if (!pointerInside)
            faceCardPinned = false;
    }
    readonly property bool faceCardShown: faceCardAvailable && (pointerInside || faceCardPinned) && !expanded && !isVertical
    readonly property var faceCardTarget: {
        const height = Math.max(compactFaceThickness, faceCardHeight);
        const radius = Math.min(height / 2, NotificationMetrics.popupRadius);
        return Object.assign(pillTarget(Math.min(NotificationMetrics.popupWidth, Math.max(NotificationMetrics.popupMinWidth, dashboardAvailableWidth * NotificationMetrics.popupScreenRatio)), height), cardRadii(radius));
    }

    function arrivalPulseFor(tier, card) {
        return Arrival.pulse(arrivalStyle, tier, card === true && !isVertical, SettingsData.islandArrivalBounce, SettingsData.islandArrivalTint, reducedMotion);
    }

    // The compact target as an arrival shapes it: the card, a swell, the finger's pull.
    function arrivalShape(target) {
        let shaped = target;
        if (activeActivity === "notification" && arrivalCardShown)
            shaped = arrivalBigTarget;
        else if (faceCardShown && faceCardHeight > 0)
            shaped = faceCardTarget;
        else if ((arrivalSwelling && arrivalPulse) || faceHoverSwell) {
            const grow = (arrivalSwelling && arrivalPulse ? arrivalPulse : faceSwellPulse).swell;
            const thick = compactFaceThickness;
            shaped = Object.assign({}, target, isVertical ? {
                "width": target.width + grow[1] * thick,
                "height": target.height + grow[0] * thick
            } : {
                "width": target.width + grow[0] * thick,
                "height": target.height + grow[1] * thick
            });
        }
        return arrivalPulled(shaped);
    }

    // The finger's pull on the island's height: up toward the clock, down toward the full card.
    function arrivalPulled(target) {
        if (arrivalPull === 0 || isVertical || !notificationActive)
            return target;
        return Object.assign({}, target, {
            "height": Math.max(compactFaceThickness / 2, Math.min(Math.max(target.height, notificationExpandedTarget.height), target.height + arrivalPull))
        });
    }

    // Pulled down: the info stays open and grows into its full card (actions, quick reply), with no countdown; only a
    // gesture closes it (pushed up, Escape, a click elsewhere), even once the pointer has left.
    function arrivalOpen() {
        if (!notificationActive || expanded || inputSuspended)
            return false;
        arrivalPull = 0;
        hoverExpanded = false;
        hoverCloseTimer.stop();
        notificationTimer.stop();
        keyboardDismissRequested = true;
        expanded = true;
        return true;
    }

    function arrivalNow() {
        return Date.now();
    }

    function arrivalDrain() {
        return IslandKit.beat("drain", reducedMotion ? 0 : animationBase);
    }

    function setBurst(next) {
        const changed = next.items[next.index] !== burst.items[burst.index];
        burst = next;
        if (changed)
            arrivalShown++;
    }

    function arrivalFlash(amount) {
        if (amount <= 0 || reducedMotion)
            return;
        arrivalTint = amount;
        arrivalFlashes++;
    }

    function arrivalSwell(pulse) {
        arrivalPulse = pulse;
        arrivalSwelling = pulse.swell[0] > 0 || pulse.swell[1] > 0;
        arrivalSwellTimer.interval = pulse.holdMs;
        if (arrivalSwelling)
            arrivalSwellTimer.restart();
    }

    function arrivalStartCountdown() {
        const t = arrivalNow();
        // A page lives as long as its info is big (a brief one in a burst gets a notification's, to be read).
        const hold = Activities.bigMs(Math.max(1, arrivalCurrent?.tier ?? 1));
        // A ringing call stays big, with no countdown, until it is answered, refused or stops.
        const ringing = !Arrival.expires(arrivalCurrent);
        countdown = arrivalHeld || ringing ? Arrival.freezeEmpty(Arrival.countdown(hold, t), t, ringing ? 0 : arrivalDrain()) : Arrival.countdown(hold, t);
        arrivalCountdownTimer.stop();
        if (!arrivalHeld && !ringing) {
            arrivalCountdownTimer.interval = Math.max(1, Arrival.remaining(countdown, t));
            arrivalCountdownTimer.start();
        }
    }

    // The swell a face took on arrival, and whose: hovered once folded, that face swells again.
    property var faceSwellPulse: null
    property string faceSwellOwner: ""
    readonly property string faceOwner: activeActivity === "plugin" ? pluginToken : activeActivity
    readonly property bool faceHoverSwell: !!faceSwellPulse && Arrival.hoverSwell({
        "hovered": pointerInside,
        "owner": faceSwellOwner,
        "face": faceOwner,
        "notification": notificationActive,
        "expanded": expanded,
        "vertical": isVertical
    })

    // A face that takes the island (system, plugin) only swells: it has no card.
    function arrivalFace(tier) {
        if (arrivalPhase !== "rest")
            return;
        const pulse = arrivalPulseFor(tier, false);
        faceSwellPulse = pulse;
        faceSwellOwner = faceOwner;
        arrivalSwell(pulse);
        arrivalFlash(pulse.tint);
    }

    // item: {tier, app, title, detail, image, icon, fallbackText, action, critical, wrapper?, timeout}.
    function arrive(item) {
        const first = arrivalPhase === "rest";
        const held = !first && arrivalHeld;
        setBurst(Arrival.arrive(burst, item, held));
        if (held) {
            // The info being read keeps its place: one more dot, which pops in.
            arrivalFlash((arrivalPulseFor(item.tier, true).tint) * 0.3);
            return;
        }
        const pulse = arrivalPulseFor(item.tier, true);
        const big = arrivalPulseFor(Math.max(item.tier, arrivalTopTier), true);
        arrivalFlash(first ? pulse.tint : pulse.tint * 0.6);
        if (pulse.big || (!first && big.big && arrivalPhase === "big")) {
            arrivalPulse = big;
            arrivalSwelling = false;
            arrivalSwellTimer.stop();
            if (!first)
                arrivalNudges++;
            arrivalPhase = "big";
            notificationTimer.stop();
            arrivalStartCountdown();
            return;
        }
        arrivalPhase = "compact";
        arrivalSwell(pulse);
        syncNotificationTimeout(true);
    }

    function arrivalGo(index) {
        if (arrivalPhase !== "big")
            return false;
        const next = Arrival.go(burst, index);
        if (!next)
            return false;
        setBurst(next);
        arrivalStartCountdown();
        return true;
    }

    function arrivalStep(direction) {
        return arrivalBrowsable && arrivalGo(burst.index + direction);
    }

    function arrivalCountdownDone() {
        if (arrivalPhase !== "big" || arrivalHeld)
            return;
        const next = Arrival.afterCountdown(burst);
        if (next) {
            setBurst(next);
            arrivalStartCountdown();
            return;
        }
        arrivalPhase = "compact";
        countdown = Arrival.freezeEmpty(countdown, arrivalNow(), 0);
        syncNotificationTimeout(true);
    }

    // Hovered or pulled down once folded: the card opens again, its dot empty and still while held.
    function arrivalReopen() {
        if (arrivalPhase !== "compact" || arrivalCount === 0 || !notificationActive || expanded || isVertical)
            return false;
        arrivalSwelling = false;
        arrivalSwellTimer.stop();
        if (!arrivalPulse?.big)
            arrivalPulse = arrivalPulseFor(Math.max(1, arrivalTopTier), true);
        arrivalPhase = "big";
        notificationTimer.stop();
        arrivalStartCountdown();
        return true;
    }

    // Pushed up: straight back to the clock, every info to the notification list.
    function arrivalTidy() {
        if (!notificationActive)
            return false;
        return completeNotification();
    }

    function arrivalEnd() {
        if (arrivalPhase === "rest" && arrivalCount === 0)
            return;
        // Released while still in the burst, so a source never takes them back in as new.
        arrivalReleased(burst.items);
        arrivalCountdownTimer.stop();
        arrivalSwellTimer.stop();
        arrivalSwelling = false;
        arrivalPhase = "rest";
        arrivalPull = 0;
        burst = Arrival.emptyBurst();
        arrivalShown++;
    }

    // The wheel or a touchpad over the open card turns its pages; false leaves the wheel to the island.
    function arrivalWheel(delta) {
        if (!arrivalBrowsable || !SettingsData.islandArrivalWheel)
            return false;
        arrivalWheelState = Arrival.wheel(arrivalWheelState, SettingsData.islandArrivalWheelInverted ? -delta : delta, arrivalNow());
        if (arrivalWheelState.step !== 0)
            arrivalStep(arrivalWheelState.step);
        return true;
    }

    // A drag let go: sideways turns the page, toward the screen edge tidies away, away from it reopens.
    function arrivalSwipe(dx, dy) {
        arrivalPull = 0;
        switch (Arrival.swipe(dx, dy, undefined, farEdge)) {
        case "next":
            return arrivalStep(1);
        case "prev":
            return arrivalStep(-1);
        case "tidy":
            return arrivalTidy();
        case "open":
            return arrivalOpen();
        }
        return false;
    }

    // The read info goes (dismissed, acted on): the next one shows, or the island goes back to the clock.
    function arrivalDrop() {
        const items = burst.items.filter((_, i) => i !== burst.index);
        if (items.length === 0)
            return completeNotification();
        setBurst({
            "items": items,
            "index": Math.min(burst.index, items.length - 1),
            "dir": 0,
            "axis": "x"
        });
        if (arrivalPhase === "big")
            arrivalStartCountdown();
        return true;
    }

    // A burst lives as long as its notification face, or while a system face holds it.
    function arrivalCheckAlive() {
        if (!notificationActive && !notificationHeldForSystem)
            arrivalEnd();
    }
    onNotificationActiveChanged: arrivalCheckAlive()
    onNotificationHeldForSystemChanged: arrivalCheckAlive()

    onArrivalHeldChanged: {
        const t = arrivalNow();
        if (arrivalHeld) {
            arrivalCountdownTimer.stop();
            countdown = Arrival.freeze(countdown, t, arrivalDrain());
            return;
        }
        if (arrivalPhase === "big")
            arrivalStartCountdown();
    }

    property Timer arrivalCountdownTimer: Timer {
        onTriggered: root.arrivalCountdownDone()
    }

    property Timer arrivalSwellTimer: Timer {
        onTriggered: {
            root.arrivalSwelling = false;
            root.syncNotificationTimeout(true);
        }
    }

    signal sessionStarted(string activityId)
    // A destination or an alert opened over a system face; its source decides whether the face goes on in a bubble.
    signal systemActivityDisplaced(string activityId)
    // Another system face took this one's place in the island; a source that owns it goes on in its bubble.
    signal systemActivityReplaced(string activityId)
    // A system face's time in the island is over (before the island leaves it): a source that owns it ends its info too.
    signal systemActivityEnding(string activityId)
    signal pluginDismissed(string token, string reason)

    function setHomeContentLength(length) {
        const next = Math.ceil(length);
        if (!isFinite(next) || next <= 0 || Math.abs(next - homeContentLength) < 2)
            return;
        homeContentLength = next;
    }

    function setNotificationContentLength(length) {
        const next = Math.ceil(length);
        if (!isFinite(next) || next <= 0 || Math.abs(next - notificationContentLength) < 2)
            return;
        notificationContentLength = next;
    }

    function setDashboardContentHeight(activityId, height) {
        const next = Math.ceil(height);
        if (!isFinite(next) || next <= 0 || dashboardContentHeights[activityId] === next)
            return;
        dashboardContentHeights = Object.assign({}, dashboardContentHeights, {
            [activityId]: next
        });
    }

    function dashEntryIdFor(activityId) {
        switch (activityId) {
        case "home":
            return DashRegistry.overviewId;
        case "notificationcenter":
            return "notifications";
        }
        return activityId;
    }

    function dashActivityFor(entryId) {
        switch (entryId) {
        case DashRegistry.overviewId:
            return "home";
        case "notifications":
            return "notificationcenter";
        case "media":
            return mediaAvailable ? "media" : "";
        case "weather":
        case "wellbeing":
        case "wallpaper":
            return entryId;
        }
        return "";
    }

    function dashTabsShownFor(activityId) {
        return dashTabIds.length > 1 && dashTabIds.indexOf(dashEntryIdFor(activityId)) >= 0;
    }

    function requestDashTab(entryId, fromNavigation) {
        dashNavigationFocused = fromNavigation === true;
        if (entryId === "notifications")
            return requestNotificationCenter(false);
        const activityId = dashActivityFor(entryId);
        return activityId !== "" && requestActivity(activityId, true, true);
    }

    function cycleDashTab(direction, fromNavigation) {
        const ids = DashRegistry.visibleTabIds.filter(id => dashActivityFor(id) !== "");
        if (ids.length === 0)
            return false;
        const pos = ids.indexOf(dashEntryIdFor(activeActivity));
        const next = ids[pos < 0 ? (direction > 0 ? 0 : ids.length - 1) : (pos + direction + ids.length) % ids.length];
        return next === dashEntryIdFor(activeActivity) || requestDashTab(next, fromNavigation);
    }

    function dashboardWidthFor(activityId) {
        return Math.min(dashboardAvailableWidth, DashMetrics.widthFor(SettingsData.showWeekNumber, undefined, DashMetrics.panelColumnsFor(dashEntryIdFor(activityId))));
    }

    function dashboardHeightFor(activityId, withEditRoom) {
        const minimum = DashMetrics.panelHeightFor(dashEntryIdFor(activityId));
        const chrome = DashMetrics.islandChromeHeight(dashTabsShownFor(activityId) ? Theme.navigationHeight : 0);
        const height = Math.max(minimum + chrome, dashboardContentHeights[activityId] ?? 0);
        return Math.min(dashboardAvailableHeight, height + (withEditRoom ? root.editRoom : 0));
    }

    function controlCenterHeightFor(withEditRoom) {
        return Math.max(CcMetrics.minHeight + controlCenterSheetInset, Math.min(controlCenterMaxHeight, destinationContentHeight("controlcenter") + (withEditRoom ? root.editRoom : 0)));
    }

    function dashboardTargetFor(activityId) {
        return sheetTarget(dashboardWidthFor(activityId), dashboardHeightFor(activityId, root.editRoomGranted && root.editingActivity === activityId));
    }

    function setMediaContentLength(length) {
        const next = Math.ceil(Math.min(root.mediaCompactMaxLength, length));
        if (!isFinite(next) || next <= 0 || Math.abs(next - mediaContentLength) < 2)
            return;
        mediaContentLength = next;
    }

    property real powerMenuContentWidth: 0

    function setPowerMenuContentWidth(width) {
        const next = Math.ceil(width);
        if (!isFinite(next) || next <= 0 || Math.abs(next - powerMenuContentWidth) < 2)
            return;
        powerMenuContentWidth = next;
    }

    readonly property var destinations: ["launcher", "controlcenter", "wallpaper", "weather", "wellbeing", "notificationcenter", "clipboard", "powermenu"]
    readonly property var blankClickOwners: ["launcher", "controlcenter", "wallpaper", "notificationcenter", "clipboard", "powermenu"]
    readonly property var destinationDefaults: ({
            "launcher": {
                "contentLength": 160,
                "contentHeight": 0
            },
            "controlcenter": {
                "contentLength": 180,
                "contentHeight": 420
            },
            "wallpaper": {
                "contentLength": 150,
                "contentHeight": 0
            },
            "weather": {
                "contentLength": 130,
                "contentHeight": 0
            },
            "wellbeing": {
                "contentLength": 130,
                "contentHeight": 0
            },
            "notificationcenter": {
                "contentLength": 170,
                "contentHeight": 320
            },
            "clipboard": {
                "contentLength": 150,
                "contentHeight": 0
            },
            "powermenu": {
                "contentLength": 150,
                "contentHeight": 0
            }
        })
    property var destinationState: root.freshDestinationState()
    property int destinationRevision: 0
    property int requestedRevision: 0

    function freshDestinationState() {
        const state = {};
        for (const id of destinations) {
            state[id] = {
                "requested": false,
                "ready": false,
                "pending": false,
                "pendingKeyboardFocus": false,
                "contentLength": destinationDefaults[id].contentLength,
                "contentHeight": destinationDefaults[id].contentHeight
            };
        }
        return state;
    }

    function destinationEntry(activityId) {
        destinationRevision;
        return destinationState[activityId] ?? null;
    }

    function isDestination(activityId) {
        return destinations.indexOf(activityId) !== -1;
    }

    function visualsRequested(activityId) {
        requestedRevision;
        return destinationState[activityId]?.requested ?? false;
    }

    function visualsReady(activityId) {
        return destinationEntry(activityId)?.ready ?? false;
    }

    function destinationContentLength(activityId) {
        return destinationEntry(activityId)?.contentLength ?? 0;
    }

    function destinationContentHeight(activityId) {
        return destinationEntry(activityId)?.contentHeight ?? 0;
    }

    function setDestinationContentLength(activityId, length) {
        if (isSystemActivity(activityId)) {
            setSystemStateContentLength(length);
            return;
        }
        const entry = destinationState[activityId];
        const next = Math.ceil(length);
        if (!entry || !isFinite(next) || next <= 0 || Math.abs(next - entry.contentLength) < 2)
            return;
        entry.contentLength = next;
        destinationRevision++;
    }

    function setEditing(activityId, editing, room = 0) {
        if (editing) {
            editRoomGranted = false;
            editingActivity = activityId;
            editRoom = room;
            // Option sheets open child popups; a hover peek would collapse under them
            hoverExpanded = false;
            hoverCloseTimer.stop();
        } else if (editingActivity === activityId) {
            editRoomGranted = false;
            editRoom = 0;
            editingActivity = "";
        }
    }

    function setDestinationContentHeight(activityId, height) {
        const entry = destinationState[activityId];
        const next = Math.round(height);
        if (!entry || !isFinite(next) || Math.abs(next - entry.contentHeight) < 1)
            return;
        entry.contentHeight = next;
        destinationRevision++;
    }

    function setVisualsReady(activityId, ready) {
        const entry = destinationState[activityId];
        if (!entry || entry.ready === ready)
            return;
        entry.ready = ready;
        destinationRevision++;
    }

    function markVisualsReady(activityId) {
        const entry = destinationState[activityId];
        if (!entry)
            return;
        const pending = entry.pending;
        entry.ready = true;
        entry.pending = false;
        destinationRevision++;
        if (!pending)
            return;
        requestActivity(activityId, true, entry.pendingKeyboardFocus);
    }

    function clearPendingRequests(exceptId) {
        let changed = false;
        for (const id of destinations) {
            const entry = destinationState[id];
            if (id === exceptId || !entry.pending)
                continue;
            entry.pending = false;
            changed = true;
        }
        if (changed)
            destinationRevision++;
    }

    // The launcher stays loaded once built, so reopening never waits on a rebuild.
    function keepsVisuals(activityId) {
        return activityId === "launcher" && !SettingsData.dankLauncherV2UnloadOnClose && destinationState[activityId].ready;
    }

    function releaseIdleVisuals() {
        for (const id of destinations) {
            if (expanded && activeActivity === id)
                continue;
            const entry = destinationState[id];
            if (root.keepsVisuals(id) || (!entry.requested && !entry.ready))
                continue;
            visualsReleaseTimer.restart();
            return;
        }
        visualsReleaseTimer.stop();
    }

    function dropIdleVisuals() {
        for (const id of destinations) {
            if (expanded && activeActivity === id)
                continue;
            if (destinationState[id].pending || root.keepsVisuals(id))
                continue;
            dropVisuals(id);
        }
    }

    function dropVisuals(activityId) {
        const entry = destinationState[activityId];
        entry.requested = false;
        entry.ready = false;
        entry.pending = false;
        entry.contentHeight = destinationDefaults[activityId].contentHeight;
        destinationRevision++;
        requestedRevision++;
        switch (activityId) {
        case "launcher":
            launcherSessionActive = false;
            launcherInputFocused = false;
            launcherPendingQuery = "";
            launcherPendingMode = "";
            return;
        case "controlcenter":
            controlCenterPendingSection = "";
            return;
        case "wallpaper":
        case "clipboard":
            keyboardYielded = false;
            return;
        }
    }

    readonly property real destinationCompactEndPad: root.isVertical ? Theme.spacingS : Math.max(root.compactFaceThickness / 2, Theme.spacingM) + Theme.spacingS

    function destinationCompactLength(activityId) {
        return Math.ceil(Math.max(root.compactFaceThickness, destinationContentLength(activityId) + root.destinationCompactEndPad * 2));
    }

    function homeGroups(side) {
        const layout = SettingsData.getIslandHomeLayout(root.barConfig);
        const clock = layout.findIndex(g => g.id === "clock");
        const groups = side === "left" ? layout.slice(0, clock) : layout.slice(clock + 1);
        return groups.filter(g => g.enabled).map(g => g.id);
    }

    readonly property var homeLeftGroups: homeGroups("left")
    readonly property var homeRightGroups: homeGroups("right")
    property string homeStatusContent: "battery"
    property string homeClockDisplay: "both"
    property string homeVolumeDisplay: "both"
    property string homeBrightnessDisplay: "both"

    readonly property real homeCompactLength: Math.ceil(homeSlotMargin * 2 + Math.max(homeContentLength, 1))
    readonly property real mediaCompactLength: Math.ceil(Math.max(1, mediaContentLength))

    // Corners touching the attached screen edge stay tighter than the ones facing the desktop.
    function sheetRadii() {
        if (root.freeMode)
            return [root.cornerRadius, root.cornerRadius, root.cornerRadius, root.cornerRadius];
        return root.edgeRadii(root.embedded || root.notch ? 0 : root.edgeCornerRadius, root.cornerRadius);
    }

    // [topLeft, topRight, bottomLeft, bottomRight] with `near` on the corners touching the edge.
    function edgeRadii(near, far) {
        switch (root.edge) {
        case "bottom":
            return [far, far, near, near];
        case "left":
            return [near, far, near, far];
        case "right":
            return [far, near, far, near];
        }
        return [near, near, far, far];
    }

    // A card's corners: `radius` all round, but square on the edge a notch hangs from.
    function cardRadii(radius) {
        const radii = root.edgeRadii(root.notch ? 0 : radius, radius);
        return {
            "topLeftRadius": radii[0],
            "topRightRadius": radii[1],
            "bottomLeftRadius": radii[2],
            "bottomRightRadius": radii[3]
        };
    }

    function pillTarget(alongSize, crossSize) {
        const radius = Math.min(crossSize / 2, root.pillRadius);
        const radii = root.edgeRadii(root.notch ? 0 : radius, radius);
        return {
            "width": root.isVertical ? crossSize : alongSize,
            "height": root.isVertical ? alongSize : crossSize,
            "offsetAlong": root.alongOffset,
            "offsetCross": root.outerGap,
            "topLeftRadius": radii[0],
            "topRightRadius": radii[1],
            "bottomLeftRadius": radii[2],
            "bottomRightRadius": radii[3]
        };
    }

    function sheetTarget(width, height) {
        const radii = root.sheetRadii();
        return {
            "sheet": true,
            "width": width,
            "height": height,
            "offsetAlong": root.alongOffset,
            "offsetCross": root.outerGap,
            "topLeftRadius": radii[0],
            "topRightRadius": radii[1],
            "bottomLeftRadius": radii[2],
            "bottomRightRadius": radii[3]
        };
    }

    readonly property var dotCompactTarget: ({
            "width": root.dotSize,
            "height": root.dotSize,
            "offsetAlong": root.alongOffset,
            "offsetCross": root.outerGap,
            "topLeftRadius": root.dotSize / 2,
            "topRightRadius": root.dotSize / 2,
            "bottomLeftRadius": root.dotSize / 2,
            "bottomRightRadius": root.dotSize / 2
        })
    readonly property var systemLevelActivities: ["volume", "brightness", "mic"]
    readonly property var systemStateActivities: ["capslock", "powerprofile", "idleinhibitor", "charging", "charged", "unplugged", "battery", "batterycritical", "network", "keepawake", "dnd", "output", "reopen", "call", "print", "usb", "password", "vpn", "openwifi", "ssh", "camera", "copy", "trash", "disk", "display", "periph", "progress", "frozen", "weatheralert"]
    readonly property var systemActivities: systemLevelActivities.concat(systemStateActivities)
    readonly property var dotTransientActivities: ["notification", "plugin"].concat(systemActivities)
    function isSystemActivity(activityId) {
        return root.systemActivities.indexOf(activityId) !== -1;
    }
    // Transients keep their island pill so the dot can still show a notification or a level.
    function usesDotFace(activityId) {
        return root.dotMode && root.dotTransientActivities.indexOf(activityId) === -1;
    }
    readonly property var homeCompactTarget: pillTarget(homeCompactLength, compactFaceThickness)
    readonly property var mediaCompactTarget: pillTarget(mediaCompactLength, compactFaceThickness)
    readonly property var homeExpandedTarget: dashboardTargetFor("home")
    readonly property var mediaExpandedTarget: dashboardTargetFor("media")
    readonly property real launcherMaxHeight: Math.min(dashboardAvailableHeight, LauncherMetrics.sizeHeight(SettingsData.dankLauncherV2Size, LauncherMetrics.islandEdgeInset, false))
    readonly property real launcherContentHeight: destinationContentHeight("launcher")
    readonly property var launcherExpandedTarget: sheetTarget(Math.min(dashboardAvailableWidth, LauncherMetrics.sizeWidth(SettingsData.dankLauncherV2Size)), launcherContentHeight > 0 ? Math.min(launcherMaxHeight, launcherContentHeight) : launcherMaxHeight)
    readonly property var controlCenterExpandedTarget: sheetTarget(controlCenterSheetWidth + controlCenterSheetInset, controlCenterHeight)
    // A plugin drawing the system face may size it; zero keeps the shell's size.
    property real systemFaceCompactLength: 0
    property real systemFaceExpandedWidth: 0
    property real systemFaceExpandedHeight: 0
    readonly property var systemCompactTarget: pillTarget(systemFaceCompactLength > 0 ? systemFaceCompactLength : root.isVertical ? 240 : (SettingsData.osdAlwaysShowValue ? 330 : 282), compactFaceThickness)
    property real systemStateContentLength: 0
    readonly property var systemStateCompactTarget: systemFaceCompactLength > 0 ? systemCompactTarget : pillTarget(Math.ceil(Math.max(compactFaceThickness, systemStateContentLength + destinationCompactEndPad * 2)), compactFaceThickness)
    readonly property var systemExpandedTarget: sheetTarget(systemFaceExpandedWidth > 0 ? systemFaceExpandedWidth : 460, systemFaceExpandedHeight > 0 ? systemFaceExpandedHeight : 176)
    readonly property var notificationCompactTarget: pillTarget(Math.ceil(Math.max(notificationCompactMinLength, Math.min(notificationCompactMaxLength, notificationContentLength))), compactFaceThickness)
    // Opened from a burst it keeps the arrival card's width, as every card does.
    readonly property var notificationExpandedTarget: sheetTarget(arrivalCount > 0 ? arrivalCardWidth : 520, 220)
    readonly property var notificationCenterExpandedTarget: dashboardTargetFor("notificationcenter")
    readonly property var clipboardExpandedTarget: sheetTarget(Math.min(dashboardAvailableWidth, ClipboardConstants.sizeWidth(SettingsData.clipboardSize)), Math.min(dashboardAvailableHeight, ClipboardConstants.sizeHeight(SettingsData.clipboardSize)))
    readonly property var powerMenuExpandedTarget: sheetTarget(Math.max(1, Math.min(dashboardAvailableWidth, powerMenuContentWidth)), Math.max(1, Math.min(dashboardAvailableHeight, destinationContentHeight("powermenu"))))

    readonly property bool systemActivityActive: isSystemActivity(activeActivity)
    readonly property bool notificationActive: activeActivity === "notification"
    readonly property bool outsideClickCollapses: expanded && !notificationActive
    readonly property bool notificationHeldForSystem: root.systemActivityActive && root.transientReturnActivity === "notification"
    readonly property bool transientActive: systemActivityActive || notificationActive || pluginActive
    readonly property bool timeoutSuspended: pointerInside || (expanded && !notificationActive)
    readonly property bool activityOwnsBlankClicks: blankClickOwners.indexOf(activeActivity) !== -1
    readonly property bool hoverExpandEnabled: root.interactionMode === "hybrid" && !root.systemActivityActive
    function compactTargetFor(activityId) {
        if (root.usesDotFace(activityId))
            return dotCompactTarget;
        switch (activityId) {
        case "notification":
            return notificationCompactTarget;
        case "plugin":
            return pillTarget(pluginCompactLength, compactFaceThickness);
        case "media":
            return mediaCompactTarget;
        case "home":
            return homeCompactTarget;
        }
        if (systemLevelActivities.indexOf(activityId) !== -1)
            return systemCompactTarget;
        if (systemStateActivities.indexOf(activityId) !== -1)
            return systemStateCompactTarget;
        return isDestination(activityId) ? pillTarget(destinationCompactLength(activityId), compactFaceThickness) : homeCompactTarget;
    }

    readonly property var compactTarget: arrivalShape(compactTargetFor(activeActivity))
    function expandedTargetFor(activityId) {
        switch (activityId) {
        case "home":
            return homeExpandedTarget;
        case "notification":
            return notificationExpandedTarget;
        case "plugin":
            return sheetTarget(pluginExpandedWidth, pluginExpandedHeight);
        case "launcher":
            return launcherExpandedTarget;
        case "controlcenter":
            return controlCenterExpandedTarget;
        case "notificationcenter":
            return notificationCenterExpandedTarget;
        case "clipboard":
            return clipboardExpandedTarget;
        case "powermenu":
            return powerMenuExpandedTarget;
        case "media":
            return mediaExpandedTarget;
        }
        return isSystemActivity(activityId) ? systemExpandedTarget : dashboardTargetFor(activityId);
    }

    readonly property var expandedTarget: expandedTargetFor(activeActivity)
    readonly property var targetDescriptor: expanded ? arrivalPulled(expandedTarget) : compactTarget

    function syncNotificationTimeout(restart) {
        // The time in compact starts once the card has folded.
        if (!notificationActive || timeoutSuspended || notificationTimeout <= 0 || arrivalPhase === "big" || arrivalSwelling || !Arrival.expires(arrivalCurrent)) {
            notificationTimer.stop();
            return;
        }
        if (restart === true || !notificationTimer.running)
            notificationTimer.restart();
    }

    onNotificationTimeoutChanged: syncNotificationTimeout(true)

    function syncPluginTimeout(restart) {
        if (!pluginActive || timeoutSuspended || pluginTimeoutMs <= 0) {
            pluginTimer.stop();
            return;
        }
        if (restart === true || !pluginTimer.running)
            pluginTimer.restart();
    }

    function syncTransientTimeout(restart) {
        if (!systemActivityActive || timeoutSuspended) {
            transientTimer.stop();
            return;
        }
        if (restart === true || !transientTimer.running)
            transientTimer.restart();
    }

    function updateMediaAvailability(available) {
        if (available) {
            // A return inside the delay is a blip (track change, player switch), not a new start.
            const blip = !mediaAvailable && mediaReturnTimer.running;
            const started = !mediaAvailable && !blip;
            mediaReturnTimer.stop();
            mediaAvailable = true;
            if (started && mediaAutoSwitch)
                autoSwitchToMedia();
            else if (blip && mediaPreferred && !expanded && activeActivity === "home")
                activeActivity = "media";
            return;
        }

        if (!mediaAvailable)
            return;
        mediaAvailable = false;
        mediaReturnTimer.restart();
    }

    // Set directly: requestActivity would drop a destination open still waiting for its visuals.
    function autoSwitchToMedia() {
        if (activeActivity === "home" && !expanded && !(pointerInside && hoverExpandEnabled))
            activeActivity = "media";
        else if (systemActivityActive && transientReturnActivity === "home")
            transientReturnActivity = "media";
        else if ((notificationActive || notificationHeldForSystem) && suspendedActivity === "home" && !suspendedExpanded)
            suspendedActivity = "media";
        else
            return;
        mediaPreferred = true;
    }

    onInputSuspendedChanged: {
        if (!inputSuspended)
            return;
        hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        keyboardDismissRequested = false;
        expanded = false;
        keyboardYielded = false;
        launcherSessionActive = false;
        clearPendingRequests("");
        if (!transientActive)
            activeActivity = idleActivity();
    }

    // The face a closed sheet lands on: media only when the user picked the media face.
    function idleActivity() {
        return mediaAvailable && mediaPreferred ? "media" : "home";
    }

    // A dot draws the same face for home and media, so a toggle would only change what the next click opens.
    readonly property bool mediaFaceToggleAvailable: !dotMode && !expanded && mediaAvailable && (activeActivity === "home" || activeActivity === "media")

    function toggleMediaFace() {
        if (!mediaFaceToggleAvailable)
            return false;
        hoverHeld = true;
        hoverOpenTimer.stop();
        return requestActivity(activeActivity === "media" ? "home" : "media", false, false);
    }

    function requestHoverExpand() {
        if (!Hover.hoverExpandAllowed(root))
            return false;
        if (notificationActive) {
            hoverExpanded = true;
            keyboardDismissRequested = false;
            expanded = true;
            hoverCloseTimer.stop();
            notificationTimer.stop();
            return true;
        }
        if (!requestExpand(false))
            return false;
        hoverExpanded = true;
        return true;
    }

    function requestHoverCollapse() {
        if (!hoverExpanded)
            return false;
        if (notificationActive) {
            hoverExpanded = false;
            expanded = false;
            keyboardDismissRequested = false;
            syncNotificationTimeout(true);
            return true;
        }
        return requestCollapse();
    }

    function requestExpand(requestKeyboardFocus) {
        if (inputSuspended)
            return false;
        if (systemActivityActive) {
            syncTransientTimeout(true);
            return false;
        }
        if (isDestination(activeActivity))
            return requestActivity(activeActivity, true, requestKeyboardFocus);
        if (pluginActive && !pluginExpandable)
            return false;
        // An info in the island grows where it is: its card again, or whole.
        const click = notificationActive ? Arrival.click(arrivalPhase, arrivalCount) : "";
        if (click === "reopen")
            return arrivalReopen();
        if (click === "open")
            return arrivalOpen();
        if (notificationActive && !notificationExpandAllowed)
            return requestNotificationCenter(false);
        hoverExpanded = false;
        clearPendingRequests("");
        hoverCloseTimer.stop();
        transientTimer.stop();
        notificationTimer.stop();
        keyboardDismissRequested = requestKeyboardFocus === true;
        expanded = true;
        return true;
    }

    // A click outside or Escape: closes the sheet, unless a card holds it open; then a click outside only hands the
    // keyboard back to the windows (a click in the card takes it again, IslandShelfSource.wake).
    function requestDismiss() {
        if (expanded && holdOpen) {
            keyboardYielded = true;
            return false;
        }
        return requestCollapse();
    }

    function requestCollapse() {
        hoverExpanded = false;
        hoverOpenTimer.stop();
        transientTimer.stop();
        notificationTimer.stop();
        keyboardDismissRequested = false;
        keyboardYielded = false;
        expanded = false;
        launcherSessionActive = false;
        clearPendingRequests("");
        if (notificationActive) {
            resumeAfterNotification(false);
            return true;
        }
        if (systemActivityActive) {
            finishTransient();
            return true;
        }
        // Alerts and live activities fold back to their pill; only a glance goes away.
        if (pluginActive) {
            syncPluginTimeout(true);
            if (pluginKind === "glance")
                pluginDismissed(pluginToken, "dismissed");
            return true;
        }
        activeActivity = idleActivity();
        return true;
    }

    function resolvedReturnActivity(activityId) {
        switch (activityId) {
        case "notification":
        case "home":
            return activityId;
        case "media":
            return mediaAvailable ? "media" : "home";
        case "plugin":
            return pluginToken ? "plugin" : idleActivity();
        }
        if (isDestination(activityId))
            return activityId;
        return idleActivity();
    }

    // Whether activityId may open: home, media while it plays, or a destination that is turned on; none while input is
    // suspended, if it would expand.
    function activityAllowed(activityId, shouldExpand) {
        if (activityId !== "home" && activityId !== "media" && !isDestination(activityId))
            return false;
        if (inputSuspended && shouldExpand === true)
            return false;
        if (activityId === "media" && !mediaAvailable)
            return false;
        if (activityId === "weather" && !SettingsData.weatherEnabled)
            return false;
        return activityId !== "wellbeing" || SettingsData.wellbeingEnabled;
    }

    // A system face pushed aside by a destination or a plugin: kept, to take the island back once it is idle.
    function displaceSystem(displaced) {
        if (!displaced)
            return;
        displacedSystemActivity = displaced;
        systemActivityDisplaced(displaced);
    }

    function requestActivity(activityId, shouldExpand, requestKeyboardFocus) {
        const destination = isDestination(activityId);
        if (!activityAllowed(activityId, shouldExpand))
            return false;

        if (activityId !== "launcher")
            launcherSessionActive = false;
        clearPendingRequests(activityId);

        if (activeActivity === activityId && expanded && shouldExpand === true) {
            if (requestKeyboardFocus === true) {
                keyboardDismissRequested = true;
                hoverExpanded = false;
            }
            return true;
        }

        if (destination && shouldExpand === true && !visualsReady(activityId)) {
            const entry = destinationState[activityId];
            entry.pending = true;
            entry.pendingKeyboardFocus = requestKeyboardFocus === true;
            entry.requested = true;
            destinationRevision++;
            requestedRevision++;
            return true;
        }

        if (requestKeyboardFocus === true)
            hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        transientTimer.stop();
        consumeTransientNotification();
        keyboardDismissRequested = shouldExpand === true && requestKeyboardFocus === true;
        const displaced = destination && shouldExpand === true && systemActivityActive ? activeActivity : "";
        expanded = shouldExpand === true;
        activeActivity = activityId;
        displaceSystem(displaced);
        if ((activityId === "media" || activityId === "home") && shouldExpand !== true)
            mediaPreferred = activityId === "media";
        launcherSessionActive = activityId === "launcher" && expanded;
        if (destination && expanded)
            sessionStarted(activityId);
        return true;
    }

    function requestLauncher(query, mode, shouldToggle) {
        const open = activeActivity === "launcher" && expanded;
        if (shouldToggle === true && open)
            return requestCollapse();
        launcherPendingQuery = query || "";
        launcherPendingMode = mode || "";
        const handled = requestActivity("launcher", true, true);
        // An open launcher applies a new query or mode in place.
        if (handled && open && (launcherPendingQuery || launcherPendingMode))
            sessionStarted("launcher");
        // Only a launcher that is still loading reads these later.
        if (!destinationState.launcher.pending) {
            launcherPendingQuery = "";
            launcherPendingMode = "";
        }
        return handled;
    }

    function requestControlCenter(section, shouldToggle) {
        if (shouldToggle === true && activeActivity === "controlcenter" && expanded)
            return requestCollapse();
        controlCenterPendingSection = section || "";
        return requestActivity("controlcenter", true, true);
    }

    function requestWallpaper(shouldToggle) {
        if (shouldToggle === true && activeActivity === "wallpaper" && expanded)
            return requestCollapse();
        return requestActivity("wallpaper", true, true);
    }

    function requestWeather(shouldToggle) {
        if (shouldToggle === true && activeActivity === "weather" && expanded)
            return requestCollapse();
        return requestActivity("weather", true, true);
    }

    function requestNotificationCenter(shouldToggle) {
        if (shouldToggle === true && activeActivity === "notificationcenter" && expanded)
            return requestCollapse();
        root.consumeTransientNotification();
        return requestActivity("notificationcenter", true, true);
    }

    function requestClipboard(shouldToggle) {
        if (shouldToggle === true && activeActivity === "clipboard" && expanded)
            return requestCollapse();
        return requestActivity("clipboard", true, true);
    }

    function requestPowerMenu(shouldToggle) {
        if (shouldToggle === true && activeActivity === "powermenu" && expanded)
            return requestCollapse();
        return requestActivity("powermenu", true, true);
    }

    function cycleActivity(direction, shouldExpand) {
        const activities = ["home"];
        if (mediaAvailable)
            activities.push("media");
        if (launcherCycleEnabled)
            activities.push("launcher");
        activities.push("controlcenter");
        activities.push("wallpaper");
        if (SettingsData.weatherEnabled)
            activities.push("weather");
        activities.push("notificationcenter");
        const currentIndex = Math.max(0, activities.indexOf(activeActivity));
        const step = direction < 0 ? -1 : 1;
        const nextIndex = (currentIndex + step + activities.length) % activities.length;
        const next = activities[nextIndex];
        if (!requestActivity(next, shouldExpand, shouldExpand))
            return false;
        if (next === "home" || next === "media")
            mediaPreferred = next === "media";
        return true;
    }

    function finishTransient() {
        if (!systemActivityActive)
            return;

        transientTimer.stop();
        systemActivityEnding(activeActivity);
        const returnActivity = resolvedReturnActivity(transientReturnActivity);
        transientReturnActivity = "";
        if (returnActivity === "notification") {
            hoverExpanded = false;
            keyboardDismissRequested = false;
            expanded = notificationExpandAllowed;
            activeActivity = "notification";
            syncNotificationTimeout(true);
            return;
        }
        activeActivity = returnActivity;
    }

    function setSystemStateContentLength(length) {
        const next = Math.ceil(length);
        if (!isFinite(next) || next <= 0 || Math.abs(next - systemStateContentLength) < 2)
            return;
        systemStateContentLength = next;
    }

    // force: the user clicked the machine bubble, so the island makes room while they adjust.
    function requestSystemActivity(activityId, force) {
        if (!isSystemActivity(activityId))
            return false;
        if (force !== true && (Activities.levelInBubble(activityId, SettingsData.islandLevelBubbles) || Activities.briefInBubble(activityId, SettingsData.islandBriefBubbles)))
            return false;
        if (force !== true && pluginActive && Activities.kindRank(pluginKind) >= Activities.occupantRank({
                "system": true
            }))
            return false;

        launcherSessionActive = false;
        clearPendingRequests("");

        // An open alert folds to its pill while the user adjusts; any other open sheet keeps the island.
        const foldsPlugin = force === true && pluginActive && expanded;
        if (expanded && !notificationActive && !foldsPlugin) {
            if (activeActivity !== activityId)
                return false;
            transientTimer.stop();
            return true;
        }

        if (notificationActive || foldsPlugin) {
            notificationTimer.stop();
            hoverExpanded = false;
            hoverOpenTimer.stop();
            hoverCloseTimer.stop();
            keyboardDismissRequested = false;
            expanded = false;
        }

        const replaced = systemActivityActive && activeActivity !== activityId ? activeActivity : "";
        const arriving = activeActivity !== activityId;
        if (!systemActivityActive)
            transientReturnActivity = activeActivity;
        activeActivity = activityId;
        // A repeat (another volume step) never swells again.
        if (arriving && force !== true)
            arrivalFace(Activities.faceTier(activityId));
        userHeld = force === true;
        if (machineBubbleKind === activityId)
            hideMachineBubble();
        syncTransientTimeout(true);
        if (replaced) {
            displacedSystemActivity = replaced;
            systemActivityReplaced(replaced);
        }
        return true;
    }

    function canRequestNotification(critical) {
        if (pluginActive)
            return Activities.occupantRank({
                "activity": "notification",
                "critical": critical === true
            }) > Activities.kindRank(pluginKind);
        return Arrival.takesIsland(notificationActive, expanded, critical, activeActivity);
    }

    function consumeTransientNotification() {
        if (transientReturnActivity === "notification")
            transientReturnActivity = "";
        if (!notificationActive)
            return;
        notificationTimer.stop();
        suspendedActivity = "";
        suspendedExpanded = false;
        suspendedKeyboardDismissRequested = false;
    }

    // force: brought in from its bubble, so it opens with the keyboard for a reply.
    function requestNotification(critical, force) {
        if (force !== true && !canRequestNotification(critical))
            return false;

        if (notificationActive)
            return refreshNotification();

        clearPendingRequests("");
        transientTimer.stop();
        suspendedActivity = activeActivity;
        suspendedExpanded = expanded;
        suspendedKeyboardDismissRequested = keyboardDismissRequested;
        launcherSessionActive = false;
        keyboardDismissRequested = force === true;
        expanded = force === true || notificationExpandAllowed;
        activeActivity = "notification";
        userHeld = force === true;
        syncNotificationTimeout(true);
        return true;
    }

    function refreshNotification() {
        if (!notificationActive)
            return false;
        syncNotificationTimeout(true);
        return true;
    }

    function resumeAfterNotification(restoreExpanded) {
        if (!notificationActive)
            return;

        notificationTimer.stop();
        arrivalEnd();
        const nextExpanded = restoreExpanded === true && suspendedExpanded;
        const suspendedFace = suspendedActivity === "home" || suspendedActivity === "media";
        const nextActivity = !suspendedActivity || (suspendedFace && !nextExpanded) ? idleActivity() : suspendedActivity === "media" && !mediaAvailable ? "home" : suspendedActivity;
        const nextKeyboardDismissRequested = nextExpanded && suspendedKeyboardDismissRequested;
        suspendedActivity = "";
        suspendedExpanded = false;
        suspendedKeyboardDismissRequested = false;
        expanded = nextExpanded;
        keyboardDismissRequested = nextKeyboardDismissRequested;
        activeActivity = nextActivity;
        launcherSessionActive = nextActivity === "launcher" && nextExpanded;
        if (nextExpanded && isDestination(nextActivity))
            sessionStarted(nextActivity);
        if (systemActivityActive && !expanded)
            transientTimer.restart();
    }

    function completeNotification() {
        if (transientReturnActivity === "notification")
            transientReturnActivity = "";
        if (!notificationActive)
            return false;
        resumeAfterNotification(true);
        return true;
    }

    function beginPluginActivity(token, kind, expand, timeoutMs) {
        if (!pluginActive) {
            pluginReturnActivity = activeActivity;
            pluginReturnExpanded = expanded;
        }
        clearPendingRequests("");
        launcherSessionActive = false;
        hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        transientTimer.stop();
        notificationTimer.stop();
        keyboardDismissRequested = false;
        pluginKind = kind;
        pluginTimeoutMs = timeoutMs;
        // The host loads the plugin's faces from the token, so expandability is known only after it is set.
        pluginToken = token;
        const displaced = systemActivityActive ? activeActivity : "";
        const arriving = !pluginActive && kind !== "live";
        expanded = expand === true && pluginExpandable;
        activeActivity = "plugin";
        if (arriving && !expanded)
            arrivalFace(Arrival.tierOf({
                "urgent": kind === "alert"
            }));
        syncPluginTimeout(true);
        displaceSystem(displaced);
    }

    function endPluginActivity() {
        pluginToken = "";
        pluginTimer.stop();
        if (suspendedActivity === "plugin") {
            suspendedActivity = idleActivity();
            suspendedExpanded = false;
        }
        if (transientReturnActivity === "plugin")
            transientReturnActivity = "";
        const back = pluginReturnActivity;
        const backExpanded = pluginReturnExpanded;
        pluginReturnActivity = "";
        pluginReturnExpanded = false;
        if (!pluginActive)
            return;
        expanded = false;
        keyboardDismissRequested = false;
        activeActivity = idleActivity();
        // A sheet the user had open comes back once the activity is done.
        if (backExpanded && isDestination(back))
            requestActivity(back, true, true);
    }

    function requestToggle(requestKeyboardFocus) {
        if (notificationActive && hoverExpanded && expanded)
            return requestNotificationCenter(false);
        // Opened on purpose (Super+S, a click): it takes the keyboard even if a click beside had let it go.
        if (requestKeyboardFocus === true)
            keyboardYielded = false;
        // An alert opens without taking the keyboard from what the user is typing in; a click hands it over.
        if (pluginActive && expanded && !keyboardDismissRequested && requestKeyboardFocus === true) {
            keyboardDismissRequested = true;
            return true;
        }
        // A card held open (the shelf) closes only by its own close button or shortcut, never by a click.
        if (expanded && holdOpen)
            return true;
        if (expanded)
            return requestCollapse();
        return requestExpand(requestKeyboardFocus);
    }

    function slotHoverEntered() {
        slotHoverCount++;
    }

    function slotHoverExited() {
        slotHoverCount = Math.max(0, slotHoverCount - 1);
    }

    onSlotHoveredChanged: {
        if (slotHovered) {
            hoverOpenTimer.stop();
            return;
        }
        if (pointerInside && hoverExpandEnabled && !expanded)
            hoverOpenTimer.restart();
    }

    function updatePointerInside(inside) {
        pointerInside = inside === true;
        if (pointerInside)
            arrivalReopen();
        syncNotificationTimeout(!pointerInside);
        syncTransientTimeout(!pointerInside);
        syncPluginTimeout(!pointerInside);
        if (!pointerInside) {
            hoverHeld = false;
            slotHoverCount = 0;
            hoverOpenTimer.stop();
            if (hoverExpanded && expanded)
                hoverCloseTimer.restart();
            return;
        }
        hoverCloseTimer.stop();
        if (hoverExpandEnabled && !expanded && !slotHovered)
            hoverOpenTimer.restart();
    }

    property Timer hoverOpenTimer: Timer {
        interval: root.hoverOpenDelay
        onTriggered: {
            if (!root.pointerInside || !root.hoverExpandEnabled || root.inputSuspended || root.slotHovered)
                return;
            root.requestHoverExpand();
        }
    }

    property Timer hoverCloseTimer: Timer {
        interval: root.hoverCloseDelay
        onTriggered: {
            if (!root.pointerInside && root.hoverExpanded)
                root.requestHoverCollapse();
        }
    }

    property Timer mediaReturnTimer: Timer {
        interval: root.mediaReturnDelay
        onTriggered: {
            if (root.mediaAvailable)
                return;
            root.mediaPreferred = false;
            if (root.activeActivity !== "media")
                return;
            root.keyboardDismissRequested = false;
            root.expanded = false;
            root.activeActivity = "home";
        }
    }

    property Timer transientTimer: Timer {
        interval: Activities.faceTimeoutMs(root.activeActivity)
        onTriggered: {
            if (!root.transientActive || root.expanded)
                return;
            root.finishTransient();
        }
    }

    property Timer notificationTimer: Timer {
        interval: root.notificationTimeout
        onTriggered: root.completeNotification()
    }

    property Timer pluginTimer: Timer {
        interval: Math.max(1, root.pluginTimeoutMs)
        onTriggered: root.pluginDismissed(root.pluginToken, "timeout")
    }

    property Timer machineBubbleTimer: Timer {
        // A bubble with an Undo keeps it for an Undo's lifetime.
        interval: Activities.faceTimeoutMs(root.machineBubbleKind)
        onTriggered: root.machineBubbleKind = ""
    }

    property Timer visualsReleaseTimer: Timer {
        interval: 260
        onTriggered: root.dropIdleVisuals()
    }
}
