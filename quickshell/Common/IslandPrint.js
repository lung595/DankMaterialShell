.pragma library

// The island's printing bubble: out of CupsService.printers ({name: {state, stateReason, jobs: [{id, name, state}]}}),
// the job printing now, or a printer in error with jobs waiting. An error wins over a job printing elsewhere.
// A4: pure logic, tested by vm.
// shortcut: DMS's cups jobs carry no page counts (and its events fire on state changes only), so "page 3/12" shows
// only for a job that has pages/pagesDone (the mockup's); upgrade by adding job-impressions(-completed) to core's Job.

// A stopped printer that says nothing of its own (a printer paused on purpose is never an error, see errorOf).
const calmReasons = ["", "none"];

function errorOf(printer, job) {
    const reason = String(printer?.stateReason ?? "");
    if (reason === "paused")
        return "";
    // A stopped printer with jobs waiting is stuck whatever it says; else CUPS reasons say how bad they are by suffix.
    if (job?.state === "processing-stopped" || printer?.state === "stopped")
        return calmReasons.indexOf(reason) === -1 ? reason : "stopped";
    return /-error$/.test(reason) ? reason : "";
}

function count(v) {
    const n = Math.floor(Number(v));
    return isFinite(n) && n > 0 ? n : 0;
}

// null, or {printer, jobId, name, page, pages, error} (error = CUPS reason, "" while it prints).
function current(printers) {
    let best = null;
    for (const name of Object.keys(printers || {})) {
        const printer = printers[name];
        for (const job of printer?.jobs || []) {
            const error = errorOf(printer, job);
            if (!error && job?.state !== "processing")
                continue;
            if (best && (best.error || !error))
                continue;
            const pages = count(job.pages);
            best = {
                "printer": name,
                "jobId": Number(job.id) || 0,
                "name": String(job.name ?? ""),
                "page": pages ? Math.min(Math.max(count(job.pagesDone), 1), pages) : 0,
                "pages": pages,
                "error": error
            };
        }
    }
    return best;
}

// The pill's short value ("3/12", at most 6 characters), "" without a count.
function pageText(s) {
    if (!s?.pages)
        return "";
    const text = s.page + "/" + s.pages;
    return text.length <= 6 ? text : String(s.page);
}

function progress(s) {
    return s?.pages ? s.page / s.pages : -1;
}

// What a dismissal hides: this job in this state; a new job or a new reason shows again.
function key(s) {
    return s ? s.printer + "|" + s.jobId + "|" + s.error : "";
}
