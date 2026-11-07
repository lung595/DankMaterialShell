pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandKeepAwake.js" as KeepAwake
import "../../Common/IslandCall.js" as Call

// The sleep blocked bubble (machine side, kind "keepawake", its row in B8's machine table): a cup with an infinity, or
// the countdown of DMS's own timed toggle (K1: nothing runs at rest). It stays while an app holds the session awake
// through the freedesktop ScreenSaver inhibitors DMS serves, or while DMS's own idle inhibitor is on. It reacts to
// DMSService's screensaver state and SessionService's toggle only; an arrival plays in the free island first (arrived()).
QtObject {
    id: root

    property bool enabled: true

    readonly property var blockers: KeepAwake.blockers(DMSService.screensaverInhibitors, SessionService.idleInhibited)
    readonly property var lead: KeepAwake.lead(root.blockers)
    // Right click hides the bubble until another app starts blocking; a click on the bubble opens its card.
    property bool dismissed: false
    property bool cardOpen: false
    // Published as the shell's permanent bubble ("dms:keepawake", machine side), drawn by this source with its own card.
    // Every island's source writes the same entry from the same services, so any of them can set or clear it.
    readonly property bool holding: root.blockers.length > 0
    onHoldingChanged: root.publish()
    Component.onCompleted: {
        KeepAwake.join();
        root.lastKey = KeepAwake.key(root.blockers);
        if (root.holding)
            root.publish();
    }
    // The last island's source gone (a screen unplugged, a reload): the permanent entry goes with it.
    Component.onDestruction: {
        if (KeepAwake.leave() === 0)
            IslandActivityService.clearPermanent("dms:keepawake");
    }
    function publish() {
        if (root.holding)
            IslandActivityService.setPermanent("dms:keepawake", {
                "side": "left",
                "kind": "keepawake"
            });
        else
            IslandActivityService.clearPermanent("dms:keepawake");
    }
    readonly property bool shown: root.enabled && root.holding && !!IslandActivityService.permanent["dms:keepawake"] && !root.dismissed

    signal arrived

    property string lastKey: ""
    onBlockersChanged: {
        const next = KeepAwake.key(root.blockers);
        if (next === root.lastKey)
            return;
        const isNew = KeepAwake.arrived(root.lastKey, root.blockers);
        root.lastKey = next;
        if (!root.blockers.length)
            root.cardOpen = false;
        if (isNew) {
            root.dismissed = false;
            if (root.enabled)
                root.arrived();
        }
    }

    function nameOf(row) {
        if (!row)
            return "";
        if (row.own)
            return I18n.tr("Keep Awake", "island sleep blocked bubble: DMS's own idle inhibitor");
        return row.app || I18n.tr("Unknown App", "island sleep blocked bubble: inhibitor without an app name");
    }

    // Only DMS's own timed toggle has an end; apps hold the session for as long as they like.
    readonly property bool timed: root.blockers.length === 1 && !!root.lead?.own && SessionData.idleInhibitedUntil > 0
    property real now: Date.now()
    readonly property int secondMs: 1000
    readonly property int minuteMs: 60 * root.secondMs
    readonly property int hourMs: 60 * root.minuteMs
    readonly property Timer tick: Timer {
        // Past an hour the countdown says hours and minutes only: one tick a minute, else one a second.
        interval: SessionData.idleInhibitedUntil - root.now > root.hourMs ? root.minuteMs : root.secondMs
        repeat: true
        running: root.shown && root.timed
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    readonly property string summary: root.blockers.length > 1 ? I18n.tr("%1 apps", "island sleep blocked bubble: apps keeping the session awake").arg(root.blockers.length) : root.nameOf(root.lead)
    readonly property var face: ({
            "id": "keepawake",
            "source": "system",
            "kind": "keepawake",
            // Under any passing machine bubble (seq 0): it comes back once that one leaves.
            "seq": -1,
            "icon": "coffee",
            "app": root.lead && !root.lead.own ? root.lead.app : "",
            "progress": -1,
            "text": root.timed ? Call.duration((SessionData.idleInhibitedUntil - root.now) / 1000) : "",
            "infinite": !root.timed,
            "title": I18n.tr("Sleep blocked", "island sleep blocked bubble title"),
            "detail": root.summary,
            "accent": "primary",
            "open": root.cardOpen,
            "keepAwake": root
        })

    // Lets go of every cookie the app holds (the server does not check who asks), or turns DMS's own toggle off.
    function release(row) {
        if (!row)
            return;
        if (row.own) {
            SessionService.disableIdleInhibit();
            return;
        }
        // An inhibitor the server lists without a cookie cannot be let go from here: say so rather than do nothing.
        if (!(row.cookies?.length > 0))
            return root.releaseFailed(row);
        for (const cookie of row.cookies)
            DMSService.dbusCall("session", "org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver", "UnInhibit", [cookie], response => {
                if (response?.error)
                    root.releaseFailed(row);
            });
    }

    function releaseFailed(row) {
        ToastService.showError(I18n.tr("Could not release %1", "island sleep blocked bubble: release failed").arg(root.nameOf(row)));
    }
}
