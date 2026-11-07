.pragma library

// One `journalctl -o json` line of a systemd-coredump entry -> {pid, comm, signal, names, log} or null.
// names: desktop entry candidates, best first (the app id systemd put in the unit, then the process names).
// A4: pure logic, tested by island-crash.test.mjs.
function parse(line) {
    let e;
    try {
        e = JSON.parse(line);
    } catch (err) {
        return null;
    }
    if (!e || typeof e !== "object" || !e.COREDUMP_PID)
        return null;
    const comm = text(e.COREDUMP_COMM);
    const exe = text(e.COREDUMP_EXE);
    const names = [];
    const push = n => {
        if (n && names.indexOf(n) < 0)
            names.push(n);
    };
    unitIds(text(e.COREDUMP_USER_UNIT)).forEach(push);
    push(exe.slice(exe.lastIndexOf("/") + 1));
    push(comm);
    return {
        "pid": Number(text(e.COREDUMP_PID)),
        "comm": comm,
        "signal": text(e.COREDUMP_SIGNAL_NAME) || text(e.COREDUMP_SIGNAL),
        "names": names,
        "log": tail(text(e.MESSAGE))
    };
}

// The journal gives a byte array instead of a string when the value is not valid UTF-8.
function text(v) {
    if (typeof v === "string")
        return v;
    if (Array.isArray(v))
        return String.fromCharCode.apply(null, v.filter(b => b >= 32 || b === 10));
    return v === undefined || v === null ? "" : String(v);
}

// app[-<launcher>]-<id>[@<random>].service or app[-<launcher>]-<id>-<random>.scope (systemd desktop app naming).
function unitIds(unit) {
    const m = /^app-(.+?)(?:@[^.]*)?\.(service|scope)$/.exec(unit);
    if (!m)
        return [];
    let rest = m[1];
    if (m[2] === "scope")
        rest = rest.replace(/-[0-9a-f]+$/i, "");
    const parts = rest.split("-");
    return parts.length > 1 ? [rest, parts.slice(1).join("-")] : [rest];
}

// The summary line, then the start of the crashing thread's stack (systemd prints it first), at most 8 lines.
function tail(message) {
    const lines = message.split("\n").map(l => l.trim()).filter(l => l.length > 0);
    if (!lines.length)
        return "";
    const stack = lines.findIndex(l => l.startsWith("Stack trace of thread"));
    const next = lines.findIndex((l, i) => i > stack && l.startsWith("Stack trace of thread"));
    const frames = stack < 0 ? lines.slice(-7) : lines.slice(stack, Math.min(stack + 7, next < 0 ? lines.length : next));
    return [lines[0]].concat(frames.filter(l => l !== lines[0])).join("\n");
}
