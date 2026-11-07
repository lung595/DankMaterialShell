.pragma library

// Incoming SSH bubble (island, source "ssh"): logind's remote sessions opened by sshd, read from
// `loginctl list-sessions -j` (the ids) then `LC_ALL=C loginctl show-session <ids> -p Id -p Name -p Remote -p RemoteHost
// -p Service -p Timestamp`, re-run on login1's SessionNew / SessionRemoved signals.
// A4: this bubble's pure logic, tested by vm (tests/island-ssh.test.mjs).

// The session ids of `loginctl list-sessions -j`, or [] when it does not parse.
function ids(json) {
    let rows;
    try {
        rows = typeof json === "string" ? JSON.parse(json) : json;
    } catch (e) {
        return [];
    }
    if (!Array.isArray(rows))
        return [];
    return rows.map(r => String(r?.session ?? "")).filter(id => /^[A-Za-z0-9_.-]+$/.test(id));
}

// shortcut: the time zone's abbreviation is ignored (the session's time is read as local), fine for a local machine.
function stamp(text) {
    const m = String(text || "").match(/(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/);
    return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() : 0;
}

// One entry per remote sshd session in show-session's blocks (blank-line separated Key=Value lines), oldest first:
// id, user, host (RemoteHost, "" if unknown), since (ms since the epoch, 0 if unknown).
function sessions(text) {
    const out = [];
    for (const block of String(text || "").split(/\n\s*\n/)) {
        const p = {};
        for (const line of block.split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                p[line.slice(0, i).trim()] = line.slice(i + 1).trim();
        }
        if (!p.Id || p.Remote !== "yes" || !/ssh/i.test(p.Service || ""))
            continue;
        out.push({
            "id": p.Id,
            "user": p.Name || "",
            "host": p.RemoteHost || "",
            "since": stamp(p.Timestamp)
        });
    }
    return out.sort((a, b) => a.since - b.since);
}

// The first session in `now` that `before` did not have, or null.
function arrived(before, now) {
    const seen = (before || []).map(s => s.id);
    return (now || []).find(s => seen.indexOf(s.id) === -1) ?? null;
}
