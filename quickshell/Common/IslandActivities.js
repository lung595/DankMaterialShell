.pragma library

const kinds = ["alert", "live", "glance"];
// Lifetimes by arrival tier (IslandArrival.js: brief, normal, important), the one place for them: in the island the info
// is big (its swell, its card), then compact; a bubble lives the total. A lasting state is big as long as a notification,
// then stays as long as it lasts.
const bigMsByTier = [400, 1400, 2000];
const compactMsByTier = [1600, 3600, 3600];

function tierIndex(tier) {
    return Math.max(0, Math.min(2, tier ?? 1));
}
function bigMs(tier) {
    return bigMsByTier[tierIndex(tier)];
}
function compactMs(tier) {
    return compactMsByTier[tierIndex(tier)];
}
function lifetimeMs(tier) {
    return bigMs(tier) + compactMs(tier);
}

// Shared by every bubble and island face: a brief info, one with an Undo (its countdown too), a notification or glance,
// an important one (a call, a code).
const briefTimeoutMs = bigMsByTier[0] + compactMsByTier[0];
// An Undo is big as long as a notification but shorter compact (4 s in all), so it gets its own compact time.
const undoCompactMs = 2600;
const undoTimeoutMs = bigMsByTier[1] + undoCompactMs;
const glanceTimeoutMs = bigMsByTier[1] + compactMsByTier[1];
const importantTimeoutMs = bigMsByTier[2] + compactMsByTier[2];
// A copied secret (password, 2FA code) leaves the clipboard and its history this long after the copy.
var secretWipeMs = 30000;
// The charge's power history: one point per sample while it charges only, whole span kept within the bound.
var chargeSampleMs = 30000;
var chargeHistoryMax = 240;

// One occupant per island; a newcomer needs a strictly higher rank, so equal ranks keep the oldest.
// A notification steps in front of a live activity, which comes back once it is gone.
const ranks = {
    "home": 0,
    "glance": 1,
    "live": 2,
    "notification": 3,
    "system": 4,
    "sheet": 5,
    "alert": 6,
    "critical": 7
};

function kindRank(kind) {
    return ranks[kinds.indexOf(kind) === -1 ? "live" : kind];
}

function occupantRank(occupant) {
    if (!occupant)
        return ranks.home;
    if (occupant.activity === "plugin")
        return kindRank(occupant.kind);
    if (occupant.activity === "notification")
        return occupant.critical ? ranks.critical : ranks.notification;
    if (occupant.system)
        return ranks.system;
    return occupant.expanded ? ranks.sheet : ranks.home;
}

function preempts(kind, occupant) {
    return kindRank(kind) > occupantRank(occupant);
}

// Do not disturb holds everything but alerts; the per-plugin switch keeps a plugin from abusing them.
function nextRequest(requests, island, quiet) {
    let best = null;
    for (const request of requests || []) {
        // A one-time code gets through do not disturb, which a screen share turns on.
        if ((request.hosts || []).indexOf(island) === -1 || (quiet && request.kind !== "alert" && request.pluginId !== "dms:code2fa"))
            continue;
        if (!best || kindRank(request.kind) > kindRank(best.kind) || (kindRank(request.kind) === kindRank(best.kind) && request.seq < best.seq))
            best = request;
    }
    return best;
}

// What happens to the activity an island holds: gone from the service, on screen, or pushed aside.
function heldOutcome(alive, active, locked) {
    if (!alive)
        return "end";
    return active && !locked ? "shown" : "interrupted";
}

// Whether the next request takes the island from its occupant now.
function takesIsland(next, occupant, held, active) {
    if (!next || (next.token === held && active))
        return false;
    if (!preempts(next.kind, occupant))
        return false;
    // An activity pushed aside by the user's own sheet, or by what they brought in from a bubble, waits for it to close.
    if (occupant.held)
        return next.state === "waiting";
    return next.state === "waiting" || !occupant.expanded || active;
}

// Bubbles: what loses the island waits beside it, the machine on the leading side, apps on the trailing one.
const levelKinds = ["volume", "brightness", "mic"];

function bubbleSide(bubble) {
    return bubble && (bubble.source === "system" || bubble.side === "machine") ? "machine" : "apps";
}

function bubbleRank(bubble) {
    switch (bubble.source) {
    case "plugin":
        return kindRank(bubble.kind);
    case "notification":
        return bubble.critical ? ranks.critical : ranks.notification;
    }
    return ranks.home;
}

// The leading side keeps the newest machine change, the rest waiting behind it; the trailing side shows the most important app, then the newest.
function bubbleSides(bubbles, quiet) {
    const machine = (bubbles || []).filter(b => bubbleSide(b) === "machine").sort((a, b) => b.seq - a.seq);
    // Do not disturb keeps app bubbles to what the island itself would show, the call the user is in, and a one-time code.
    const apps = (bubbles || []).filter(b => bubbleSide(b) === "apps" && !(quiet && !(b.source === "plugin" && b.kind === "alert") && b.source !== "call" && b.source !== "code2fa")).sort((a, b) => bubbleRank(b) - bubbleRank(a) || b.seq - a.seq);
    return {
        "machine": machine.length > 0 ? machine[0] : null,
        "machines": machine,
        "apps": apps
    };
}

// "Always in a bubble" sends level changes beside an idle island instead of into it.
function levelInBubble(kind, always) {
    return always === true && levelKinds.indexOf(kind) !== -1;
}

// Brief info (and an Undo) lives in the island unless the user wants it in a bubble; lasting states and alerts stay.
// Battery: fully charged, unplugged and low are brief; plugging in is normal, critical important.
const briefKinds = ["capslock", "powerprofile", "idleinhibitor", "charged", "unplugged", "battery", "network", "dnd", "output", "reopen", "copy", "trash", "display", "periph"];
function briefInBubble(kind, always) {
    return always === true && briefKinds.indexOf(kind) !== -1;
}

// How long an island face stays: an Undo's lifetime when it offers one.
const undoKinds = ["output", "powerprofile", "trash", "display"];
// Machine faces that are notifications (5 s, frozen on hover); plugging in opens the charge face as long.
const glanceKinds = ["weatheralert", "charging"];
// Machine faces that are important (a critical battery).
const importantKinds = ["batterycritical"];

function faceTimeoutMs(kind) {
    if (importantKinds.indexOf(kind) !== -1)
        return importantTimeoutMs;
    if (glanceKinds.indexOf(kind) !== -1)
        return glanceTimeoutMs;
    return undoKinds.indexOf(kind) !== -1 ? undoTimeoutMs : briefTimeoutMs;
}

// How a face arrives in the island: brief (a brief info, a level), normal (an Undo, a lasting state) or important.
function faceTier(kind) {
    if (importantKinds.indexOf(kind) !== -1)
        return 2;
    if (undoKinds.indexOf(kind) !== -1)
        return 1;
    return briefKinds.indexOf(kind) !== -1 || levelKinds.indexOf(kind) !== -1 ? 0 : 1;
}

// Island faces whose info has a bubble: hovered or clicked, the island grows into that bubble's own card, in place.
const faceCardKinds = ["copy", "trash", "disk", "display", "periph", "progress", "frozen", "weatheralert", "charging"];
function hasFaceCard(kind) {
    return faceCardKinds.indexOf(kind) !== -1;
}

// The face a launcher, an alert or another face pushed out takes the island back once it is idle, if its info lives on.
function faceToReturn(displaced, activity, expanded, alive) {
    return displaced && alive && !expanded && (activity === "home" || activity === "media") ? displaced : "";
}

// The signal a request emits on reaching the screen, if any.
function showSignal(state) {
    return state === "waiting" ? "shown" : state === "interrupted" ? "resumed" : "";
}

// An activity on every screen stays shown while any island shows it, and is interrupted once the last one lets go.
function shownChange(entry, island, showing) {
    const shownOn = (entry.shownOn || []).filter(host => host !== island);
    if (showing) {
        shownOn.push(island);
        return {
            "shownOn": shownOn,
            "state": "shown",
            "signal": showSignal(entry.state)
        };
    }
    const pushedAside = shownOn.length === 0 && entry.state === "shown";
    return {
        "shownOn": shownOn,
        "state": pushedAside ? "interrupted" : entry.state,
        "signal": pushedAside ? "interrupted" : ""
    };
}

// The entry the island draws: the live one, or the one that just ended while its faces still fade out with the island
// (the service forgets it at once).
function shownEntry(live, last, shown) {
    return live ?? (shown ? last : null);
}

// The timeout a request may ask for (ms): longer ones are clamped, a request never outlives ten minutes.
const minTimeoutMs = 1000;
const maxTimeoutMs = 600000;

function normalizeOptions(options) {
    const o = options && typeof options === "object" ? options : {};
    const kind = kinds.indexOf(o.kind) === -1 ? "live" : o.kind;
    const timeout = o.timeoutMs;
    const glance = kind === "glance";
    return {
        "kind": kind,
        "expanded": typeof o.expanded === "boolean" ? o.expanded : kind === "alert",
        "timeoutMs": typeof timeout === "number" && isFinite(timeout) && timeout > 0 ? Math.max(minTimeoutMs, Math.min(maxTimeoutMs, Math.round(timeout))) : (glance ? glanceTimeoutMs : 0),
        "screen": typeof o.screen === "string" ? o.screen : "",
        "showInFullscreen": o.showInFullscreen === true,
        "notifyApp": typeof o.notifyApp === "string" ? o.notifyApp.trim() : "",
        "data": o.data && typeof o.data === "object" ? o.data : {}
    };
}

// Whether a notification from appName belongs to one of these activities, which the island already shows. A request
// matches the app its plugin declared (notifyApp) and only that; without one, its id or its name (nameOf(pluginId)).
function holdsApp(requests, appName, nameOf) {
    const app = String(appName ?? "").trim().toLowerCase();
    if (!app)
        return false;
    return (requests || []).some(r => {
        const declared = String(r.notifyApp ?? "").trim().toLowerCase();
        if (declared)
            return declared === app;
        const id = String(r.pluginId ?? "");
        return id.replace(/^script:/, "").toLowerCase() === app || String((nameOf && nameOf(id)) ?? "").toLowerCase() === app;
    });
}

// held: holdsApp for the notification's app. A call or a critical one still shows, the app's activity waiting in its
// bubble meanwhile; the rest stays in the list only.
function notificationShows(held, critical) {
    return critical === true || !held;
}

// Each bubble wing rests at its own widest face, kept when the last item leaves so it melts back from its own width.
function wingRest(rest, need) {
    return need > 0 ? need : rest;
}

// How far a wing reaches out of the island for input: its gap, then its card while hovered open, else its rest.
function wingReach(has, hoverOpen, cardWant, rest, gap) {
    if (!has)
        return 0;
    return gap + (hoverOpen ? Math.max(cardWant, rest) : rest);
}
