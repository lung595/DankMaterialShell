pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../../Common/IslandTransfer.js" as Transfer
import "../../Common/IslandEyes.js" as Eyes
import "../../Common/IslandActivities.js" as Activities

// Everything that downloads or moves files, apps side: one bubble for all of them. Its liquid is the total, its value the
// time left (smoothed), the "more" dot says there are several; a change of speed kicks the liquid (surge), a steady flow
// lies still. Sources: the core's TransferService (copies, archives, downloaders, sends and image writers through /proc
// fdinfo, qBittorrent on 127.0.0.1) and the browsers' partial files in the downloads folder (DownloadService.live, no
// total, so no liquid). Lives in the free island (IslandTransferActivity, "dms:transfer"); goes to the bubble with brief
// bubbles on, on an error, or while the island is busy (the launcher), and back once it is free. A finished row stays as
// long as a notification does, its time frozen while hovered and started over after.
// B9: coded step by step (source, glyph, card).
QtObject {
    id: root

    required property IslandController controller
    property string screenName: ""
    property bool enabled: true

    readonly property string sourceId: "dms:transfer"

    // [{"id", "category", "name", "app", "image", "done", "total", "paused", "canPause", "canCancel", "finished",
    // "finishedAt", "error", "path", torrents: "peers", "upSpeed", "shareRatio"}]
    property var list: []
    property var sample: null
    property var rows: []
    // The card's sections (IslandTransfer.sections): the moving one first, rows by time left, finished last.
    readonly property var sections: Transfer.sections(root.rows)
    // Hovered (bubble, card or island face): finished rows stay; since is when it was last let go.
    property bool holding: false
    property real since: 0
    property var total: null
    property real surge: 0
    property int surgeAt: 0
    property bool cardOpen: false
    property string token: ""
    // Opened from the island: stays a bubble until its card closes.
    property bool held: false
    // Ids the user cancelled: gone, not finished.
    property var cancelled: ({})

    readonly property bool active: root.enabled && root.list.length > 0
    readonly property int running: root.total?.running ?? 0
    readonly property bool failed: (root.total?.failed ?? 0) > 0
    readonly property bool allDone: root.active && root.running === 0 && !root.failed
    readonly property bool paused: root.total?.paused ?? false
    readonly property var lead: root.rows.find(r => !r.finished && !r.error) ?? root.rows[0] ?? null
    // Closed from its card: hidden while every transfer is one it already showed; they go on, a new one brings it back.
    property var hidden: ({})
    readonly property bool dismissed: root.list.length > 0 && root.list.every(t => root.hidden[t.id] === true)
    // Its words (time left, amounts, sections), the card's too.
    readonly property IslandTransferText texts: IslandTransferText {}
    // What its card's buttons do (pause, resume, cancel, open).
    readonly property IslandTransferActions actions: IslandTransferActions {
        source: root
    }
    readonly property bool wantsIsland: root.active && !root.dismissed && !SettingsData.islandBriefBubbles && !root.failed && !root.held && !root.cardOpen

    // The value on the pill: time left, else the state; with no total at all, what came in so far.
    readonly property string valueText: root.failed ? I18n.tr("Failed", "island transfers bubble: a transfer failed") : root.allDone ? I18n.tr("Done", "island transfers bubble: everything finished") : root.paused ? I18n.tr("Paused", "island transfers bubble: everything paused") : (root.total?.eta ?? -1) >= 0 ? root.texts.timeText(root.total.eta) : root.total ? root.texts.bytesText(root.total.done) + " " + root.texts.unitText(root.total.done) : ""
    readonly property string titleText: root.running > 1 ? I18n.tr("%1 transfers", "island transfers bubble: card title, several running").arg(root.running) : root.lead?.name ?? ""
    // Under the title: the app, or for several the whole amount ("2.3 / 7.5 GB · 102 MB/s").
    readonly property string detailText: root.running > 1 && root.total ? root.texts.amountText({
            "done": root.total.done,
            "total": root.total.ratio >= 0 ? root.total.size : 0,
            "speed": root.total.speed
        }) : root.lead?.app ?? ""
    // The liquid's tone: primary (done too: primaryContainer would fall under 3:1 on the pill), error on a failure (on an
    // errorContainer track, for contrast); paused or done, the badge says so.
    readonly property color hue: root.failed ? Theme.error : Theme.primary

    // The bubble while the island is not showing them; info is also the card the island grows into over its own face.
    readonly property var face: root.token || root.dismissed ? null : root.info
    readonly property var info: root.active ? {
        "id": "transfer",
        "source": "transfer",
        "kind": "transfer",
        "seq": 1e5 + 10,
        "image": root.lead?.image ?? "",
        "icon": (root.lead?.image ?? "") !== "" ? "" : "downloading",
        "progress": root.allDone ? 1 : root.total?.ratio ?? -1,
        "text": root.valueText,
        "valued": true,
        "title": root.titleText,
        "detail": root.detailText,
        "accent": root.failed ? "error" : "primary",
        // A badge takes the icon's corner over the dot.
        "more": root.running > 1 && !root.paused && !root.failed,
        // A live level: it follows its samples without the step pulse, only a change of speed sloshes it.
        "stream": true,
        "aside": true,
        // The bubble's track is DMS's wave progress, waving while something moves.
        "waveBar": true,
        "flowing": root.total?.flowing === true && !root.failed,
        "hue": root.hue,
        "trackHue": root.failed ? Theme.errorContainer : undefined,
        "surge": root.paused ? 0 : root.surge,
        "surgeAt": root.surgeAt,
        "paused": root.paused,
        "done": root.allDone,
        "failed": root.failed,
        "open": root.cardOpen,
        "transfer": root
    } : null

    // The live list: the core's transfers and the browsers' partial files; one gone without a cancel is finished.
    readonly property var feeds: {
        // A downloader the core reads already (yt-dlp into the downloads folder): its partial file shows once.
        const named = {};
        const out = TransferService.transfers.map(t => {
            named[t.name ?? ""] = true;
            return Transfer.coreRow(t, t.appId ? Quickshell.iconPath(t.appId, true) : "");
        });
        const browser = I18n.tr("Browser", "island transfers bubble: a browser's download, app unknown");
        for (const d of DownloadService.live.filter(d => !named[d.part]))
            out.push(Transfer.partRow(d, browser, DownloadService.folder));
        return out;
    }
    onFeedsChanged: root.sync()
    function sync() {
        if (!root.enabled)
            return;
        const now = {};
        for (const t of root.feeds)
            now[t.id] = true;
        // A browser's download gone without its file finished was cancelled or failed there: it leaves, never Done. A row
        // already finished is judged once, when it goes: justFinished only names the last scan's files.
        const gone = root.list.filter(t => !now[t.id] && !root.cancelled[t.id] && !t.error && (t.finished || !t.id.startsWith("part:") || DownloadService.justFinished.indexOf(t.name) !== -1)).map(t => Object.assign({}, t, {
                "done": t.total || t.done,
                "finished": true,
                "paused": false
            }));
        root.list = root.feeds.concat(gone);
        if (!root.list.length) {
            root.clear();
            return;
        }
        root.measure(Date.now());
    }
    property bool counted: false
    onEnabledChanged: root.want(root.enabled)
    Component.onCompleted: root.want(root.enabled)
    Component.onDestruction: root.want(false)

    function want(yes) {
        if (yes === root.counted)
            return;
        root.counted = yes;
        TransferService.wanters += yes ? 1 : -1;
        // Wanted again, the list comes back from what the service holds: it pushes only what changes.
        if (yes)
            root.sync();
        else
            root.clear();
    }

    function measure(now) {
        // A row's own clock starts when it finishes (the wall clock).
        const at = Date.now();
        root.list = root.list.map(t => t.finished && !t.finishedAt ? Object.assign({}, t, {
                "finishedAt": at
            }) : t);
        const r = Transfer.step(root.sample, root.list, now);
        root.sample = r.state;
        root.rows = r.rows;
        root.total = r.total;
        if (r.surge > 0) {
            root.surge = r.surge;
            root.surgeAt++;
        }
        root.expire();
        root.route();
    }

    // Finished rows leave one by one after a notification's time (none while hovered); none left, it goes.
    function expire() {
        if (root.holding || !root.list.length) {
            root.leaveTimer.stop();
            return;
        }
        const r = Transfer.expire(root.list, Date.now(), Activities.glanceTimeoutMs, root.since);
        if (r.list.length < root.list.length) {
            if (!r.list.length) {
                root.clear();
                return;
            }
            // Only finished rows leave: the running total stays as it was.
            const kept = {};
            for (const t of r.list)
                kept[t.id] = true;
            root.list = r.list;
            root.rows = root.rows.filter(t => kept[t.id]);
        }
        if (r.next > 0) {
            root.leaveTimer.interval = r.next;
            root.leaveTimer.restart();
        } else {
            root.leaveTimer.stop();
        }
    }

    function route() {
        if (root.wantsIsland && !root.token && Eyes.islandFree(root.controller))
            root.token = IslandActivityService.add(root.sourceId, {
                "kind": "live",
                "screen": root.screenName,
                "data": {
                    "transfer": root
                }
            });
        else if (!root.wantsIsland && root.token)
            root.release();
    }
    onWantsIslandChanged: root.route()

    function release() {
        const token = root.token;
        root.token = "";
        if (token)
            IslandActivityService.remove(token, "released");
    }

    // A busy island gives it back once free (the launcher closed).
    readonly property bool islandFree: Eyes.islandFree(root.controller)
    onIslandFreeChanged: root.route()
    property Timer leaveTimer: Timer {
        onTriggered: root.expire()
    }
    // Hovered on the island's face: the same freeze as on the bubble.
    readonly property bool islandHeld: root.token !== "" && root.controller.timeoutSuspended
    onIslandHeldChanged: root.hold(root.islandHeld)

    property Connections activities: Connections {
        target: IslandActivityService

        function onInterrupted(token) {
            if (token === root.token)
                root.release();
        }
        function onDropped(token, reason) {
            if (token !== root.token)
                return;
            root.token = "";
            // Dismissed from the island: it stays a bubble.
            if (reason === "dismissed")
                root.held = true;
        }
    }

    function hold(inside) {
        root.holding = inside;
        if (!inside)
            root.since = Date.now();
        root.expire();
    }
    // The island's face was clicked: its card opens in the bubble.
    function showCard() {
        root.held = true;
        root.cardOpen = true;
        root.release();
    }
    function dismiss() {
        const hidden = {};
        for (const t of root.list)
            hidden[t.id] = true;
        root.hidden = hidden;
        root.closeCard();
        root.release();
    }
    function closeCard() {
        root.cardOpen = false;
        root.held = false;
    }

    function clear() {
        root.leaveTimer.stop();
        root.release();
        root.list = [];
        root.rows = [];
        root.total = null;
        root.sample = null;
        root.cardOpen = false;
        root.held = false;
        root.cancelled = ({});
        root.hidden = ({});
    }
}
