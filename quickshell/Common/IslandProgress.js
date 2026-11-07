.pragma library

// Progress bubble (island, apps side): notifications carrying the freedesktop "value" hint (0..100), updated in place by
// the app through replaces-id. Jobs are { id, ratio, body, ... }; the state keeps when each job was first seen.

// The "value" hint as 0..1, or -1 when the notification has none.
function ratio(hints) {
    const v = hints ? hints.value : undefined;
    if (typeof v !== "number" || !isFinite(v))
        return -1;
    return Math.max(0, Math.min(1, v / 100));
}

// "3 of 12", "3/12", "3 sur 12" in the body: files done and total, or null.
function files(text) {
    const m = /(\d+)\s*(?:\/|of|sur|de|von)\s*(\d+)/i.exec(String(text || ""));
    if (!m)
        return null;
    const done = Number(m[1]), total = Number(m[2]);
    return total > 0 && done <= total ? { "done": done, "total": total } : null;
}

// A transfer rate the app wrote in the body ("4.2 MB/s", "850 Kio/s"), or "".
function speed(text) {
    const m = /(\d+(?:[.,]\d+)?\s*[kKMGT]?i?[Bo]\/s)/.exec(String(text || ""));
    return m ? m[1] : "";
}

// Seconds left at the pace since the job was first seen, or -1 while it cannot be told.
function remaining(start, r, now) {
    if (!start || r >= 1 || r <= start.ratio || now <= start.t)
        return -1;
    const rate = (r - start.ratio) / (now - start.t);
    return Math.max(1, Math.round((1 - r) / rate / 1000));
}

// Seconds left as the card says them: {s} under a minute (else s = -1), then whole minutes rounded once, so it never
// reads "60 min" nor "1 h 60 min".
function clock(seconds) {
    if (seconds < 60)
        return { "s": seconds, "h": 0, "m": 0 };
    const minutes = Math.round(seconds / 60);
    return { "s": -1, "h": Math.floor(minutes / 60), "m": minutes % 60 };
}

// Next state from the live jobs (oldest first). A job first seen already finished is an old one: never shown.
// A job that vanishes near its end (the app closed it on completion) stays as finished, for its check.
// startTimer: the shown job just finished, so its check stays for a while, then hide() lets it go.
function step(prev, jobs, now) {
    const p = prev || {};
    const starts = {}, gone = {};
    for (const j of jobs || []) {
        const known = p.starts && p.starts[j.id];
        starts[j.id] = known || { "t": now, "ratio": j.ratio };
        if ((p.gone && p.gone[j.id]) || (!known && j.ratio >= 1))
            gone[j.id] = true;
    }
    const live = (jobs || []).filter(j => !gone[j.id]);
    let current = live.length ? live[live.length - 1] : null;
    const was = p.current || null;
    if (!current && was && !starts[was.id] && was.ratio >= 0.99)
        current = Object.assign({}, was, { "ratio": 1 });
    if (current && was && !starts[current.id] && was.id === current.id)
        starts[current.id] = (p.starts && p.starts[current.id]) || { "t": now, "ratio": 1 };
    const finished = !!current && current.ratio >= 1;
    const wasFinished = !!was && !!current && was.id === current.id && was.ratio >= 1;
    return { "starts": starts, "gone": gone, "current": current, "startTimer": finished && !wasFinished };
}

// The shown job leaves (its check is over, or the user dismissed it); the next live one, if any, takes its place.
function hide(state, jobs, now) {
    const s = state || {};
    const gone = Object.assign({}, s.gone);
    if (s.current)
        gone[s.current.id] = true;
    return step({ "starts": s.starts, "gone": gone, "current": null }, jobs, now);
}
