pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandProgress.js" as P
import "../../Common/IslandActivities.js" as Activities

// The progress bubble (apps side, source "progress"): a notification carrying the freedesktop "value" hint (a copy, a
// download), updated in place by its app through replaces-id. Its level rides the wing like the volume's; when it ends the
// ring fills and turns into a check, which stays a moment. Reacts to NotificationService's list and each notification's
// hints only (no polling); the click opens the card: files done / total, time left, speed when the app says it.
QtObject {
    id: root

    property bool enabled: true

    readonly property var jobs: {
        if (!root.enabled)
            return [];
        const list = [];
        for (const w of NotificationService.notifications) {
            const r = P.ratio(w?.notification?.hints);
            if (r >= 0)
                list.push({
                    "id": String(w.notification.id),
                    "ratio": r,
                    "summary": w.summary,
                    "body": w.body,
                    "app": w.appName,
                    "image": w.displayImage || "",
                    "wrapper": w
                });
        }
        return list;
    }

    property var jobState: null
    property int remaining: -1
    property bool cardOpen: false
    onJobsChanged: root.advance(P.step(root.jobState, root.jobs, Date.now()))

    function advance(next) {
        const was = root.jobState?.current?.id;
        const cur = next.current;
        // Before the state: the wing keeps a face until a field it watches (detail, progress) changes.
        root.remaining = cur ? P.remaining(next.starts[cur.id], cur.ratio, Date.now()) : -1;
        if (!cur || cur.id !== was)
            root.cardOpen = false;
        root.jobState = next;
        if (next.startTimer)
            root.checkTimer.restart();
        else if (!cur)
            root.checkTimer.stop();
    }

    // The check stays this long once the job is done, then the next live job (if any) takes the bubble.
    property Timer checkTimer: Timer {
        interval: Activities.briefTimeoutMs
        onTriggered: root.advance(P.hide(root.jobState, root.jobs, Date.now()))
    }

    // Hovering the bubble holds the check.
    property bool held: false
    function hold(inside) {
        if (inside) {
            root.held = root.checkTimer.running;
            root.checkTimer.stop();
        } else if (root.held) {
            root.held = false;
            root.checkTimer.restart();
        }
    }

    // Right click: this job leaves the bubble (its notification stays in DMS's center).
    function dismiss() {
        root.checkTimer.stop();
        root.advance(P.hide(root.jobState, root.jobs, Date.now()));
    }

    // Wrappers this bubble shows, so they do not wait as a plain notification bubble too.
    function owns(wrapper) {
        return root.jobs.some(j => j.wrapper === wrapper);
    }

    readonly property var job: root.jobState?.current ?? null
    readonly property bool done: !!root.job && root.job.ratio >= 1
    readonly property var face: !root.job ? null : ({
            // A new id when it ends: the wing takes the check as a new arrival and morphs to it on its spring.
            "id": "progress:" + root.job.id + (root.done ? ":done" : ""),
            "source": "progress",
            "seq": 0,
            "image": root.done ? "" : root.job.image,
            "icon": root.done ? "check" : "downloading",
            "progress": root.done ? 1 : root.job.ratio,
            "text": root.done ? "" : Math.round(root.job.ratio * 100) + "%",
            "title": root.job.summary || root.job.app || I18n.tr("In progress", "island progress bubble title"),
            // The header's value stays short so the title fits; the app's own words go in the card's rows.
            "detail": root.done ? I18n.tr("Done", "island progress bubble: job finished") : Math.round(root.job.ratio * 100) + "%",
            "body": root.job.body || "",
            "accent": "primary",
            "open": root.cardOpen,
            "files": P.files(root.job.body),
            "speed": root.done ? "" : P.speed(root.job.body),
            "remaining": root.done ? -1 : root.remaining,
            "wrapper": root.job.wrapper ?? null
        })
}
