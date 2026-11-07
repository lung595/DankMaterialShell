.pragma library

.import "IslandActivities.js" as Activities

// The per-bubble table of the island settings: one row per bubble the island can show, and the sparse
// islandBubbleTable setting that only keeps what differs from a row's default.
// Exports stay var and function: tests/qml-script.mjs only sees those.

var families = ["system", "apps", "alerts"];
var scaleKeys = {
    system: "islandTimeScaleMachine",
    apps: "islandTimeScaleApps",
    alerts: "islandTimeScaleAlerts"
};
// Lifetime by importance (brief, normal, important) for a bubble moved off its own importance.
var tierLifeMs = [2000, 5000, 5600];
// The Notifications > Timeouts choices.
var lifeChoicesS = [1, 3, 5, 8, 10, 15, 30, 60, 120];

// life in ms: 0 while active, -1 set by the plugin. side: "machine" (left) or "apps" (right). tier: 0 brief, 1 normal, 2 important.
var rows = [
    { id: "volume", family: "system", icon: "volume_up", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["sound", "audio"] },
    { id: "mic", family: "system", icon: "mic", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["microphone", "input"] },
    { id: "micmute", family: "system", icon: "mic_off", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["mute"] },
    { id: "brightness", family: "system", icon: "brightness_medium", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["screen", "backlight"] },
    { id: "output", family: "system", icon: "speaker", side: "machine", life: 4000, tier: 1, dnd: true, tags: ["speaker", "headphones"] },
    { id: "powerprofile", family: "system", icon: "bolt", side: "machine", life: 4000, tier: 1, dnd: true, tags: ["power", "performance"] },
    { id: "keepawake", family: "system", icon: "coffee", side: "machine", life: 0, tier: 1, dnd: true, tags: ["idle inhibitor", "caffeine"] },
    { id: "network", family: "system", icon: "wifi", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["network", "wifi"] },
    { id: "openwifi", family: "system", icon: "wifi_find", side: "machine", life: 0, tier: 1, dnd: true, tags: ["portal", "hotspot"] },
    { id: "dnd", family: "system", icon: "do_not_disturb_on", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["dnd", "quiet"] },
    { id: "capslock", family: "system", icon: "keyboard_capslock", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["keyboard"] },
    { id: "charging", family: "system", icon: "battery_charging_full", side: "machine", life: 5000, tier: 1, dnd: true, tags: ["power", "plug"], showKey: "islandChargingPulse" },
    { id: "battery", family: "system", icon: "battery_full", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["battery", "low"] },
    { id: "periph", family: "system", icon: "devices", side: "machine", life: 2000, tier: 0, dnd: true, tags: ["bluetooth", "mouse", "keyboard", "headset", "gamepad"] },
    { id: "display", family: "system", icon: "desktop_windows", side: "machine", life: 4000, tier: 1, dnd: true, tags: ["monitor", "screen"] },
    { id: "disk", family: "system", icon: "hard_drive", side: "machine", life: 0, tier: 1, dnd: true, tags: ["storage", "space"] },
    { id: "eyes", family: "system", icon: "visibility", side: "machine", life: 0, tier: 1, dnd: true, tags: ["eyes", "rest"], showKey: "islandEyeBreak", showShared: true, lockLife: true },
    { id: "shelf", family: "system", icon: "stacks", side: "machine", life: 0, tier: 1, dnd: true, tags: ["files", "drop"] },
    { id: "notification", family: "apps", icon: "notifications", side: "apps", life: 5000, tier: 1, dnd: false, tags: ["message"] },
    { id: "progress", family: "apps", icon: "progress_activity", side: "apps", life: 0, tier: 1, dnd: false, tags: ["progress"] },
    { id: "transfer", family: "apps", icon: "download", side: "apps", life: 0, tier: 1, dnd: false, tags: ["download", "copy", "extract", "torrent"] },
    { id: "copy", family: "apps", icon: "check", side: "apps", life: 2000, tier: 0, dnd: false, tags: ["clipboard", "copy"] },
    { id: "password", family: "apps", icon: "key", side: "apps", life: 30000, tier: 1, dnd: false, tags: ["password", "secret"], secret: true },
    { id: "trash", family: "apps", icon: "delete", side: "apps", life: 4000, tier: 1, dnd: false, tags: ["trash", "undo"] },
    { id: "reopen", family: "apps", icon: "restart_alt", side: "apps", life: 2000, tier: 0, dnd: false, tags: ["reopen", "window"] },
    { id: "frozen", family: "apps", icon: "error", side: "apps", life: 0, tier: 1, dnd: false, tags: ["crash", "frozen"] },
    { id: "media", family: "apps", icon: "music_note", side: "apps", life: 0, tier: 1, dnd: false, tags: ["music", "player"] },
    { id: "call", family: "apps", icon: "call", side: "apps", life: 0, tier: 1, dnd: true, tags: ["call", "voice"] },
    { id: "camera", family: "apps", icon: "videocam", side: "apps", life: 0, tier: 1, dnd: false, tags: ["webcam", "privacy"] },
    { id: "vpn", family: "apps", icon: "vpn_key", side: "apps", life: 0, tier: 1, dnd: false, tags: ["vpn", "tunnel"] },
    { id: "ssh", family: "apps", icon: "terminal", side: "apps", life: 0, tier: 1, dnd: false, tags: ["ssh", "remote"] },
    { id: "usb", family: "apps", icon: "usb", side: "apps", life: 0, tier: 1, dnd: false, tags: ["usb", "drive"] },
    { id: "print", family: "apps", icon: "print", side: "apps", life: 0, tier: 1, dnd: false, tags: ["printer"] },
    { id: "plugin", family: "apps", icon: "extension", side: "apps", life: 5000, tier: 1, dnd: false, tags: ["plugin", "glance", "live"] },
    { id: "callincoming", family: "alerts", icon: "ring_volume", side: "apps", life: 0, tier: 2, dnd: true, tags: ["ring", "phone"] },
    { id: "code2fa", family: "alerts", icon: "password", side: "apps", life: 5600, tier: 2, dnd: true, tags: ["2fa", "otp", "code"], secret: true },
    // Show, Do Not Disturb and lifetime are forced: the bubble must stay to answer the request.
    { id: "auth", family: "alerts", icon: "lock", side: "apps", life: 0, tier: 2, dnd: true, tags: ["polkit", "password prompt"], locked: true },
    { id: "urgent", family: "alerts", icon: "notifications_active", side: "apps", life: 5600, tier: 2, dnd: false, tags: ["urgent", "attention"] },
    { id: "batterycritical", family: "alerts", icon: "battery_alert", side: "machine", life: 5600, tier: 2, dnd: true, tags: ["battery", "critical"] },
    { id: "weatheralert", family: "alerts", icon: "thunderstorm", side: "machine", life: 5000, tier: 1, dnd: true, tags: ["weather", "storm", "rain"] },
    { id: "pluginalert", family: "alerts", icon: "extension", side: "apps", life: -1, tier: 2, dnd: true, tags: ["plugin", "alert"] }
];

function row(id) {
    return rows.find(r => r.id === id) ?? null;
}

function rowsOf(family) {
    return rows.filter(r => r.family === family);
}

function defaults(r) {
    return {
        enabled: true,
        side: r.side,
        tier: r.tier,
        lifeMs: 0,
        sound: "none",
        dnd: r.dnd
    };
}

// The lifetime "Default" stands for: the row's own one at its own importance, else the importance's one, times the family scale.
function defaultLifeMs(r, tier, scale) {
    if (r.life <= 0)
        return r.life;
    const base = tier === r.tier ? r.life : tierLifeMs[tier];
    const ms = Math.round(base * (scale || 1));
    return r.secret ? Math.min(ms, Activities.secretWipeMs) : ms;
}

// A secret is wiped after secretWipeMs, so its bubble never outlives it.
function lifeChoicesMs(r) {
    return lifeChoicesS.map(s => s * 1000).filter(ms => !r.secret || ms <= Activities.secretWipeMs);
}

function effective(table, id, scale) {
    const r = row(id);
    if (!r)
        return null;
    const state = Object.assign(defaults(r), (table || {})[id]);
    if (r.locked) {
        state.enabled = true;
        state.dnd = true;
        state.lifeMs = 0;
    }
    state.defaultLifeMs = defaultLifeMs(r, state.tier, scale);
    return state;
}

// A new table with one field set; picking the default value removes the field, and an empty entry goes away.
function withField(table, id, field, value) {
    const next = Object.assign({}, table);
    const r = row(id);
    if (!r)
        return next;
    const entry = Object.assign({}, next[id]);
    if (value === defaults(r)[field])
        delete entry[field];
    else
        entry[field] = value;
    if (Object.keys(entry).length > 0)
        next[id] = entry;
    else
        delete next[id];
    return next;
}

function without(table, id) {
    const next = Object.assign({}, table);
    delete next[id];
    return next;
}

function changed(table, id, field) {
    const entry = (table || {})[id];
    return !!entry && field in entry;
}

function countDnd(table) {
    return rows.filter(r => effective(table, r.id, 1).dnd).length;
}
