.pragma library

// The island's low peripheral bubble (mouse, keyboard, gamepad, headset): which UPower reading raises it.
// A discharging device raises "low" once under 15 % and once more under 5 %; climbing back to 20 % rearms both (no
// repeat on a 15/16 % jitter). Starting to charge raises "charging" and rearms. A device's first reading only seeds its
// state, so one already charging when the shell starts stays quiet; one already low still warns.

// UPower's startup list has arrived by then: a peripheral appearing later is a plug (IslandPeriphSource, B12).
var settleMs = 5000;

const icons = {
    "mouse": "mouse",
    "keyboard": "keyboard",
    "gamepad": "sports_esports",
    "headset": "headset_mic",
    "headphones": "headphones"
};
const steps = [5, 15];
const rearm = 20;

function icon(type) {
    return icons[type] ?? "";
}

// UPower calls a device that shows a mouse and a keyboard interface (a Logitech mouse on its cable) a keyboard: the
// type the same model reported another time (by its receiver: mouse only) wins over that guess. Any other type is
// trusted as reported. Keyed by model name, Quickshell gives no serial (B12). Only an own entry of `types` holding a known
// non-keyboard type counts: session.json is user data, a model named "constructor" must not read an inherited value.
const recallable = ["mouse", "gamepad", "headset", "headphones"];
function kind(reported, types, model) {
    const remembered = reported === "keyboard" ? recalled(types, model) : "";
    return recallable.includes(remembered) ? remembered : reported;
}

// B12: the same mouse is "Acme Glide X 2" by its receiver and "Glide X 2" on its cable, so a name that is the other with
// one leading (vendor) word matches it. shortcut: two models that differ only by that word share a type; key by serial
// if Quickshell ever exposes it.
function recalled(types, model) {
    if (!types || typeof types !== "object" || Array.isArray(types) || !model)
        return "";
    const tail = name => name.slice(name.indexOf(" ") + 1);
    const name = Object.keys(types).find(m => m === model || tail(m) === model || tail(model) === m);
    return name === undefined ? "" : types[name];
}

// The remembered types (SessionData.islandPeriphTypes) once `model` reported `type`, or null when nothing changes.
// The last rememberMax models written are kept, the oldest leave. A name longer than nameMax, a key of every object
// ("__proto__", "constructor") or a name in digits (an object lists those first, out of write order) is never written;
// nor is a type kind() would not recall (UPower's keyboard guess, the very one it corrects).
const rememberMax = 16;
const nameMax = 128;
function remember(types, model, type) {
    // session.json is user data: a null, a string or a list there starts over from an empty map, as kind() reads nothing from it.
    const own = types && typeof types === "object" && !Array.isArray(types) ? types : {};
    const unsafe = !model || model.length > nameMax || model in Object.prototype || /^\d+$/.test(model);
    if (!recallable.includes(type) || unsafe || own[model] === type)
        return null;
    const next = Object.assign({}, own);
    delete next[model];
    next[model] = type;
    const models = Object.keys(next);
    models.slice(0, Math.max(0, models.length - rememberMax)).forEach(m => delete next[m]);
    return next;
}

// The state a device gets before its first reading. At startup none: the reading only seeds (one already charging
// stays quiet). Once the shell has settled, a device that appears is a plug (a Logitech on its cable re-enumerates as
// a new UPower device, already charging): it reads as if seen discharging, so "charging" is raised at once (B12).
function first(settled) {
    return settled ? { "mark": 100, "charging": false, "step": 0 } : null;
}

// prev: the last result for this device, or null; percent: 0..100 (0 = UPower's "unset"); charging: bool.
// Returns { mark (lowest step already raised, 100 = none), charging, alert: "" | "low" | "charging", step }.
function step(prev, percent, charging) {
    if (charging)
        return {
            "mark": 100,
            "charging": true,
            "alert": prev && !prev.charging ? "charging" : "",
            "step": 0
        };
    if (!(percent > 0))
        return Object.assign({}, prev ?? { "mark": 100 }, { "charging": false, "alert": "", "step": 0 });
    const mark = !prev || percent >= rearm ? 100 : prev.mark;
    const hit = steps.find(s => percent <= s && mark > s);
    return {
        "mark": hit ?? mark,
        "charging": false,
        "alert": hit ? "low" : "",
        "step": hit ?? 0
    };
}
