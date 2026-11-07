.pragma library

// Eye break (EyeBreakService): the settings' bounds, the countdown text and where a break shows.

const intervalBounds = [5, 120, 20]; // minutes between breaks: min, max, default
const durationBounds = [10, 120, 20]; // seconds of a break

function clamp(value, bounds) {
    const n = Number(value);
    if (value === null || value === undefined || !isFinite(n))
        return bounds[2];
    return Math.max(bounds[0], Math.min(bounds[1], Math.round(n)));
}

function intervalMs(minutes) {
    return clamp(minutes, intervalBounds) * 60000;
}

function durationSec(seconds) {
    return clamp(seconds, durationBounds);
}

// A break never lands over a fullscreen window, or while the mic, the camera or a screen share is in use (a call).
function deferred(fullscreen, mic, camera, sharing) {
    return !!(fullscreen || mic || camera || sharing);
}

// An island at rest takes the break whole; one busy with anything else leaves it to its machine bubble.
function islandFree(island) {
    return !!island && !island.expanded && (!island.pluginActive || resting(island.pluginToken)) && !island.notificationActive && !island.systemActivityActive;
}

// The shelf only sits in an island nothing else wants: it steps aside for any newcomer (IslandShelfSource).
function resting(token) {
    return String(token ?? "").startsWith("dms:shelf:");
}

function route(islands) {
    return (islands || []).some(islandFree) ? "island" : "bubble";
}
