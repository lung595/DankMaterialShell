.pragma library

// What a script (over IPC) or a plugin hands the island, checked and shaped before it shows: the limits and ids that keep
// a source from flooding the island or passing for another, the permanent bubbles' table, and the shell-drawn faces
// (ready face, bubble face, a plugin face's sizes) read from its data. IslandActivities.js holds the island's own rules.

// A bubble reads the same fields as the ready face, plus a very short text ("62 %", "4:59").
function bubbleFace(data) {
    const face = readyFace(data);
    const short = faceText(data && typeof data === "object" ? data.shortText : "");
    return {
        "icon": face.icon,
        "progress": face.progress,
        "text": short.length > 6 ? short.slice(0, 6) : short,
        "accent": face.accent
    };
}

const accents = ["primary", "secondary", "tertiary", "error", "warning", "info", "success"];
const maxActions = 3;
const maxTextLines = 3;
const maxImageUrl = 2048;

function faceText(value) {
    if (typeof value === "string")
        return value;
    return typeof value === "number" && isFinite(value) ? String(value) : "";
}

// The shell-drawn face, for scripts and for plugins that leave compactContent unset.
function readyFace(data) {
    const d = data && typeof data === "object" ? data : {};
    const progress = Number(d.progress);
    const hasProgress = d.progress !== undefined && d.progress !== null && d.progress !== "" && isFinite(progress);
    const actions = (Array.isArray(d.actions) ? d.actions : []).filter(a => a && typeof a === "object" && faceText(a.id) && faceText(a.label)).slice(0, maxActions).map(a => ({
                "id": faceText(a.id),
                "label": faceText(a.label)
            }));
    const text = faceText(d.text).replace(/\r/g, "").split("\n").slice(0, maxTextLines).join("\n");
    // The sheet shows every line; the folded face and the bubble's card row only the first.
    const lines = text === "" ? [] : text.split("\n");
    return {
        "icon": faceText(d.icon),
        "title": faceText(d.title),
        "text": text,
        "progress": hasProgress ? Math.max(0, Math.min(1, progress)) : -1,
        "actions": actions,
        "accent": accents.indexOf(d.accent) === -1 ? "primary" : d.accent,
        "image": imageUrl(d.image),
        "detail": lines[0] ?? "",
        "lines": lines
    };
}

// Enter on a focused sheet runs the first action.
function primaryAction(face) {
    return face && face.actions && face.actions.length > 0 ? face.actions[0].id : "";
}

// IPC limits, so a script cannot flood the island nor pass for another source.
const maxIpcData = 16384;
const maxScripts = 8;
const maxScriptName = 64;
const maxNotifyApp = 128;

// IPC hands strings; anything but a JSON object refuses the call instead of showing an empty face.
function parseIpcData(json) {
    if (json === undefined || json === null || String(json).trim() === "")
        return {};
    if (String(json).length > maxIpcData)
        return null;
    try {
        const value = JSON.parse(json);
        return value && typeof value === "object" && !Array.isArray(value) ? value : null;
    } catch (e) {
        return null;
    }
}

// What `dms ipc call island activity...` prints besides a token: ISLAND_ACTIVITY_BAD_DATA (data that is not a JSON object
// of at most maxIpcData characters, or an update with nothing in it), ISLAND_ACTIVITY_NO_CONTENT (neither a title, an
// icon nor an image: the ready face would be empty), scriptData's ISLAND_ACTIVITY_BAD_ACCENT and ISLAND_ACTIVITY_BAD_IMAGE,
// ISLAND_ACTIVITY_REFUSED (a bad or extra script name, a too long notifyApp), ISLAND_ACTIVITY_UNKNOWN (no live activity
// of a script under that token), ISLAND_ACTIVITY_UPDATED, ISLAND_ACTIVITY_ENDED.
// A new activity's refusal for its parsed data, or "" when it can show.
function ipcRefusal(parsed) {
    if (!parsed)
        return "ISLAND_ACTIVITY_BAD_DATA";
    const face = readyFace(parsed);
    return face.title === "" && face.icon === "" && face.image === "" ? "ISLAND_ACTIVITY_NO_CONTENT" : "";
}

// A script's image: an icon of the theme (hasIcon, Quickshell.hasThemeIcon on the host) or the absolute path of a local
// picture. Never a URL nor an image provider, so a script cannot make the shell fetch anything nor read a device.
// The URL the face loads, "" for none, null when refused.
const maxIconName = 128;
const pictureTypes = /\.(png|jpe?g|svg|webp|gif|bmp)$/i;
function scriptImage(value, hasIcon) {
    if (value === undefined || value === null || value === "")
        return "";
    if (typeof value !== "string" || value.length > maxImageUrl || /[\u0000-\u001f\u007f]/.test(value))
        return null;
    if (value.startsWith("/"))
        return pictureTypes.test(value) ? "file://" + value.split("/").map(encodeURIComponent).join("/") : null;
    return value.length <= maxIconName && /^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(value) && hasIcon?.(value) === true ? "image://icon/" + value : null;
}

// A script's parsed data, checked: the IPC answer refusing it, or the data with its image as the URL the face loads.
// An accent is one of the theme's roles, never a raw colour.
function scriptData(parsed, hasIcon) {
    if (parsed.accent !== undefined && accents.indexOf(parsed.accent) === -1)
        return "ISLAND_ACTIVITY_BAD_ACCENT";
    const image = scriptImage(parsed.image, hasIcon);
    if (image === null)
        return "ISLAND_ACTIVITY_BAD_IMAGE";
    if (image !== "")
        parsed.image = image;
    return parsed;
}

// Only a script's own activity ("script:<name>:<n>") answers over IPC, never a plugin's or the shell's.
function ipcOwns(token) {
    return typeof token === "string" && /^script:[^:]+:\d+$/.test(token);
}

// A token is "<source>:<n>": a plugin id with a colon could pass for a script's or the shell's.
function pluginIdAllowed(id) {
    return typeof id === "string" && id !== "" && id.indexOf(":") === -1;
}

// Permanent bubbles (IslandActivityService.permanent): one entry per owner, { pluginId: { side, image, label, dropText,
// bubbleContent, receiving, seq } }. Keep awake ("dms:keepawake") is the shell's own and draws its own bubble.
function permanentAllowed(id, loaded, allowed) {
    return id === "dms:keepawake" || (pluginIdAllowed(id) && loaded === true && allowed === true);
}

// Qt 6 gives a url value (Qt.resolvedUrl) as an object: its text is the URL. One too long to be a URL is dropped, never cut.
function imageUrl(value) {
    const text = value && typeof value === "object" ? String(value) : value;
    return typeof text === "string" && text.length <= maxImageUrl ? text : "";
}

// A face a plugin draws itself: a QML Component, or null to keep the shell's.
function ownContent(value) {
    return value && typeof value === "object" && typeof value.createObject === "function" ? value : null;
}

// A new table with id's entry set (options) or gone (null); an owner setting its entry again keeps its place in line.
function withPermanent(table, id, options, seq) {
    const previous = (table || {})[id];
    if (!options && !previous)
        return table;
    const next = Object.assign({}, table);
    if (options)
        next[id] = Object.assign({}, options, {
            "pluginId": id,
            "side": options.side === "left" ? "left" : "right",
            "receiving": options.receiving === true,
            "bubbleContent": ownContent(options.bubbleContent),
            "seq": previous ? previous.seq : seq
        });
    else
        delete next[id];
    return next;
}

// The plugin bubble a side shows: the newest owner there.
function permanentOn(table, side) {
    let shown = null;
    for (const entry of Object.values(table || {})) {
        if (entry.side === side && pluginIdAllowed(entry.pluginId) && (!shown || entry.seq > shown.seq))
            shown = entry;
    }
    return shown;
}

// liveNames: the scripts with an activity now; asking again under one of them replaces it.
function scriptAllowed(name, liveNames, notifyApp) {
    if (!name || name.length > maxScriptName || name.indexOf(":") !== -1)
        return false;
    if (typeof notifyApp === "string" && notifyApp.trim().length > maxNotifyApp)
        return false;
    return liveNames.indexOf(name) !== -1 || liveNames.length < maxScripts;
}

function clampSize(value, min, max, fallback) {
    const n = Number(value);
    if (value === undefined || value === null || !isFinite(n))
        return fallback;
    return Math.max(min, Math.min(max, Math.ceil(n)));
}

// [min, max, default] for each size a plugin face may ask for.
const faceBounds = {
    "compactLength": [120, 360, 240],
    "expandedWidth": [280, 736, 460],
    "expandedHeight": [120, 480, 200],
    // A plugin's own bubble (along the bar) and its card row; the host keeps them at least as big as its own.
    "bubbleLength": [0, 240, 0],
    "cardHeight": [0, 240, 0]
};

function faceSize(face, key) {
    const b = faceBounds[key];
    return clampSize(face ? face[key] : undefined, b[0], b[1], b[2]);
}

// 0 keeps the shell's size for a face that does not ask for one (a plugin's bubble or card row).
function ownFaceSize(face, key) {
    return face && face[key] > 0 ? faceSize(face, key) : 0;
}
