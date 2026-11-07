pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandPrint.js" as Print

// The printing bubble (apps side, source "print"): the job printing now ("page 3/12" when CUPS gives pages), or a
// printer in error with jobs waiting (orange, stays until fixed or dismissed). Reads CupsService.printers, which DMS's
// server pushes on each CUPS event (D-Bus subscription, no polling); a new job or error plays in the free island first.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    readonly property var printers: CupsService.printers
    readonly property var liveJob: root.enabled ? Print.current(root.printers) : null
    // CUPS rebuilds its printers with no jobs, then fetches them: a job only leaves once it stayed gone a moment.
    property var job: null
    onLiveJobChanged: {
        if (root.liveJob) {
            leaveTimer.stop();
            root.job = root.liveJob;
        } else {
            leaveTimer.restart();
        }
    }
    readonly property Timer leaveTimer: Timer {
        interval: 1500
        onTriggered: root.job = root.liveJob
    }
    readonly property bool error: !!root.job?.error
    property bool dismissed: false
    property bool cardOpen: false
    readonly property bool shown: !!root.job && !root.dismissed

    signal arrived

    // CUPS pushes its state only while someone subscribes; the island is one more subscriber.
    Component.onCompleted: {
        CupsService.refCount++;
        root.job = root.liveJob;
    }
    Component.onDestruction: CupsService.refCount--

    property string lastKey: ""
    onJobChanged: {
        const next = Print.key(root.job);
        if (next === root.lastKey)
            return;
        root.lastKey = next;
        root.dismissed = false;
        if (!root.job)
            root.cardOpen = false;
        else
            root.arrived();
    }

    // CUPS's own label of the reason (CupsService, already translated), without its severity. "stopped"
    // (IslandPrint.errorOf, a stop without a reason) is a printer state, not a reason: its state label.
    readonly property string reasonText: {
        const reason = String(root.job?.error || "stopped").replace(/-(error|warning|report)$/, "");
        return reason === "stopped" ? CupsService.getPrinterStateTranslation(reason) : CupsService.getPrinterStateReasonTranslation(reason);
    }
    readonly property string pageText: root.job?.pages ? I18n.tr("Page %1/%2", "island print bubble: page printing of the job's pages").arg(root.job.page).arg(root.job.pages) : ""
    readonly property string title: root.error ? I18n.tr("Printer problem", "island print bubble title") : I18n.tr("Printing", "island print bubble title")
    // The island face's value: the page, else the error or the printer.
    readonly property string summary: root.error ? root.reasonText : root.pageText || (root.job?.printer ?? "")
    readonly property string iconName: root.error ? "print_error" : "print"

    readonly property var face: ({
            // A new id when it turns to an error, so the wing springs to its warning shape.
            "id": root.error ? "print-error" : "print",
            "source": "print",
            "kind": root.error ? "error" : "printing",
            "seq": 0,
            "icon": root.iconName,
            "progress": root.error ? -1 : Print.progress(root.job),
            "text": root.error ? "" : Print.pageText(root.job),
            "title": root.title,
            "detail": root.error ? root.reasonText : root.pageText || (root.job?.name ?? ""),
            "accent": root.error ? "warning" : "primary",
            "page": root.job?.page ?? 0,
            "open": root.cardOpen,
            "printSource": root
        })

    // The card's actions, on CUPS.
    function cancel() {
        const j = root.job;
        if (!j)
            return;
        CupsService.cancelJob(j.printer, j.jobId);
    }

    function resume() {
        const j = root.job;
        if (!j)
            return;
        CupsService.resumePrinter(j.printer);
    }
}
