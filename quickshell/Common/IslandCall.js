.pragma library

// Call bubble (island, apps side, source "call"): which app is in a call, read from its PipeWire streams. No call API
// on the desktop, so a call is an app that records the microphone and either plays sound back (a two way stream:
// browsers' WebRTC, Discord, Signal...) or tags its stream with a phone role.
// A4: this bubble's pure logic, tested by vm (tests/island-call.test.mjs).

// rows: one per PipeWire stream node {id, input (bool), app, binary, icon, pid, role, muted}. Returns one call per app,
// in the order the apps started recording: {key, app, binary, icon, pid, inputs / outputs: [stream ids], muted (every
// input muted), deafened (every output muted)}. app is the stream's application name unless it names a voice engine.
function calls(rows) {
    const groups = [];
    for (const row of rows || [])
        groupRow(groups, row);
    return groups.filter(g => g.inputs.length > 0 && (g.outputs.length > 0 || g.phone)).map(callOf);
}

// One stream row into its app's group (made on its first row); a row with no app key is left out.
function groupRow(groups, row) {
    if (!row || typeof row !== "object")
        return;
    const key = appKey(row);
    if (!key)
        return;
    let group = groups.find(g => g.key === key);
    if (!group) {
        group = {
            "key": key,
            "app": "",
            "binary": "",
            "icon": "",
            "pid": String(row.pid || ""),
            "inputs": [],
            "mutedInputs": 0,
            "outputs": [],
            "mutedOutputs": 0,
            "phone": false
        };
        groups.push(group);
    }
    group.app = group.app || String(row.app || "").trim();
    group.binary = group.binary || String(row.binary || "").trim();
    group.icon = group.icon || String(row.icon || "").trim();
    if (/^(communication|phone)$/i.test(String(row.role || "")))
        group.phone = true;
    if (row.input) {
        group.inputs.push(row.id);
        if (row.muted)
            group.mutedInputs++;
    } else {
        group.outputs.push(row.id);
        if (row.muted)
            group.mutedOutputs++;
    }
}

// An app's group as a call: its name (the binary when the stream only names the engine), its streams, mute and deafen.
function callOf(g) {
    return {
        "key": g.key,
        "app": engineName(g.app) ? g.binary || g.app : g.app || g.binary,
        "binary": g.binary,
        "icon": g.icon || g.binary.toLowerCase(),
        "pid": g.pid,
        "inputs": g.inputs,
        "outputs": g.outputs,
        "muted": g.mutedInputs === g.inputs.length,
        "deafened": g.outputs.length > 0 && g.mutedOutputs === g.outputs.length
    };
}

// Chromium's WebRTC (Discord, Electron apps) names its streams after the engine, not the app.
function engineName(name) {
    return /webrtc|voice ?engine/i.test(String(name || ""));
}

// Names to look up the app's desktop entry with, best first: the binary (unless it is a runtime that hosts the app,
// like electron), then the stream's app name.
function entryNames(call) {
    if (!call)
        return [];
    const names = [];
    const binary = String(call.binary || "").trim();
    if (binary && !/^(electron\d*|node|python\d*(\.\d+)?|java|bwrap)$/i.test(binary))
        names.push(binary);
    const app = String(call.app || "").trim();
    if (app && !engineName(app) && app !== binary)
        names.push(app);
    return names;
}

// Streams of one process belong together; without a pid, the binary or the app name.
function appKey(row) {
    if (row.pid)
        return "pid:" + row.pid;
    const name = String(row.binary || row.app || "").trim().toLowerCase();
    return name ? "app:" + name : "";
}

// The pill holds at most 6 characters: m:ss under an hour (up to 59:59), then 1h02.
function duration(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    const h = Math.floor(s / 3600);
    const m = Math.floor(s % 3600 / 60);
    const pad = n => (n < 10 ? "0" : "") + n;
    if (h > 0)
        return h + "h" + pad(m);
    return m + ":" + pad(s % 60);
}

// A notification action that ends the call (an incoming or ongoing call notification's "Hang up" / "Decline"),
// by its identifier or label; -1 if none. actions: [{identifier, text}].
function hangUpAction(actions) {
    const words = /hang.?up|end.?call|decline|reject|raccroch|terminer|refuser/i;
    const list = actions || [];
    for (let i = 0; i < list.length; i++) {
        const a = list[i];
        if (a && words.test(String(a.identifier || "") + " " + String(a.text || "")))
            return i;
    }
    return -1;
}

// Whether a name (a window's app id, a notification's app name) is this call's app: same app, binary or icon name,
// ignoring case and a reverse-domain prefix (org.signal.Signal ~ signal).
function sameApp(call, name) {
    const tail = v => String(v || "").trim().toLowerCase().split(".").pop();
    const n = tail(name);
    if (!call || !n)
        return false;
    return [call.app, call.binary, call.icon].some(v => tail(v) === n);
}
