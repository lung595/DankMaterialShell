import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const C = loadScript(new URL("../Common/AppCrash.js", import.meta.url));

const entry = (fields) => JSON.stringify(Object.assign({
    "COREDUMP_PID": "4821",
    "COREDUMP_COMM": "gnome-text-edit",
    "COREDUMP_EXE": "/usr/bin/gnome-text-editor",
    "COREDUMP_SIGNAL_NAME": "SIGSEGV",
    "MESSAGE": "Process 4821 (gnome-text-edit) of user 1000 dumped core.\n\nModule libgtk-4.so.1 from rpm gtk4\nStack trace of thread 4821:\n#0  0x7f g_type_check_instance (libgobject-2.0.so.0 + 0x3a)\n#1  0x7f gtk_widget_snapshot (libgtk-4.so.1 + 0x1b)\n\nStack trace of thread 4822:\n#0  0x7f poll (libc.so.6 + 0x9)"
}, fields));

test("a coredump entry gives the pid, signal, desktop candidates and the crashing thread's stack", () => {
    const c = C.parse(entry({ "COREDUMP_USER_UNIT": "app-niri-org.gnome.TextEditor-31337.scope" }));
    assert.equal(c.pid, 4821);
    assert.equal(c.signal, "SIGSEGV");
    assert.deepEqual(Array.from(c.names), ["niri-org.gnome.TextEditor", "org.gnome.TextEditor", "gnome-text-editor", "gnome-text-edit"]);
    const log = c.log.split("\n");
    assert.equal(log[0], "Process 4821 (gnome-text-edit) of user 1000 dumped core.");
    assert.equal(log[1], "Stack trace of thread 4821:");
    assert.ok(!c.log.includes("poll"), "stops at the next thread");
});

test("unit names: service with @, plain scope, foreign units", () => {
    assert.deepEqual(Array.from(C.unitIds("app-org.gnome.Nautilus@a1b2.service")), ["org.gnome.Nautilus"]);
    assert.deepEqual(Array.from(C.unitIds("app-firefox-12ab.scope")), ["firefox"]);
    assert.deepEqual(Array.from(C.unitIds("session-2.scope")), []);
    assert.deepEqual(Array.from(C.unitIds("")), []);
});

test("byte arrays decode, bad or foreign lines give null", () => {
    assert.equal(C.parse(entry({ "COREDUMP_COMM": [110, 111, 116, 101, 115] })).comm, "notes");
    assert.equal(C.parse("not json"), null);
    assert.equal(C.parse(JSON.stringify({ "MESSAGE": "hello" })), null);
    assert.equal(C.parse("null"), null);
});
