.pragma library

// What a script (over IPC) or a plugin hands the island, checked and shaped; its own rules are in IslandActivities.js.

// A bubble reads the same fields as the ready face, plus a very short text ("62 %", "4:59"), cut at maxShortText.
const maxShortText = 6;
function bubbleFace(data) {
    const face = readyFace(data);
    const short = faceText(data && typeof data === "object" ? data.shortText : "");
    return {
        "icon": face.icon,
        "progress": face.progress,
        "text": short.slice(0, maxShortText),
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

// The shell-drawn face (scripts, plugins without compactContent). words: the host's translated names of the state
// accents, as a light theme folds several onto the surface's text tone.
function readyFace(data, words) {
    const d = data && typeof data === "object" ? data : {};
    const progress = Number(d.progress);
    const hasProgress = d.progress !== undefined && d.progress !== null && d.progress !== "" && isFinite(progress);
    const actions = (Array.isArray(d.actions) ? d.actions : []).filter(a => a && typeof a === "object" && faceText(a.id) && faceText(a.label)).slice(0, maxActions).map(a => ({
                "id": faceText(a.id),
                "label": faceText(a.label)
            }));
    const accent = accents.indexOf(d.accent) === -1 ? "primary" : d.accent;
    const state = words?.[accent] ?? "";
    const title = faceText(d.title);
    const text = faceText(d.text).replace(/\r/g, "").split("\n").slice(0, maxTextLines).join("\n");
    const detail = [state, text].filter(part => part !== "").join(" · ");
    // The sheet shows every line; the folded face and the bubble's card row only the first.
    const lines = detail === "" ? [] : detail.split("\n");
    return {
        "icon": faceText(d.icon),
        "title": title,
        "text": text,
        "progress": hasProgress ? Math.max(0, Math.min(1, progress)) : -1,
        "actions": actions,
        "accent": accent,
        "image": imageUrl(d.image),
        "detail": lines[0] ?? "",
        "lines": lines,
        "name": [state, title, text].filter(part => part !== "").join(", ")
    };
}

// Enter on a focused sheet runs the first action.
function primaryAction(face) {
    return face?.actions?.[0]?.id ?? "";
}

// IPC limits, so a script cannot flood the island nor pass for another source.
const maxIpcData = 16384;
const maxScripts = 8;
const maxScriptName = 64;
const maxNotifyApp = 128;
// A script's source and tokens start with it (requestScript, ipcOwns); var, as the service reads it.
var scriptPrefix = "script:";

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

// `dms ipc call island activity*` answers, besides a token: ISLAND_ACTIVITY_BAD_DATA (not a JSON object within
// maxIpcData), _NO_CONTENT (no title, icon nor image, first call or update), scriptData's _BAD_ACCENT and _BAD_IMAGE,
// scriptRefusal's _BAD_NAME, _BAD_NOTIFY_APP and _TOO_MANY, _NO_ISLAND (none on that screen), _UNKNOWN (no script
// activity under that token), _UPDATED, _ENDED.
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

// A script's data, checked: the IPC answer refusing it, or the object with its image as the URL the face loads.
// An accent is one of the theme's roles, never a raw colour.
function scriptData(json, hasIcon) {
    const parsed = parseIpcData(json);
    const refused = ipcRefusal(parsed);
    if (refused)
        return refused;
    if (parsed.accent !== undefined && accents.indexOf(parsed.accent) === -1)
        return "ISLAND_ACTIVITY_BAD_ACCENT";
    const image = scriptImage(parsed.image, hasIcon);
    if (image === null)
        return "ISLAND_ACTIVITY_BAD_IMAGE";
    if (image !== "")
        parsed.image = image;
    return parsed;
}

// The bare token, so a script keeps it: tok=$(dms ipc call island activity ...).
function ipcActivity(service, id, kind, screen, data, hasIcon) {
    const parsed = scriptData(data, hasIcon);
    if (typeof parsed === "string")
        return parsed;
    return service.requestScript(id, {
        "kind": kind,
        "screen": screen,
        "expanded": parsed.expanded,
        "timeoutMs": parsed.timeoutMs,
        "notifyApp": parsed.notifyApp,
        "data": parsed
    });
}

function ipcActivityUpdate(service, token, data, hasIcon) {
    if (!ipcOwns(token))
        return "ISLAND_ACTIVITY_UNKNOWN";
    const parsed = scriptData(data, hasIcon);
    if (typeof parsed === "string")
        return parsed;
    return service.update(token, parsed) ? "ISLAND_ACTIVITY_UPDATED" : "ISLAND_ACTIVITY_UNKNOWN";
}

function ipcActivityEnd(service, token) {
    return ipcOwns(token) && service.release(token) ? "ISLAND_ACTIVITY_ENDED" : "ISLAND_ACTIVITY_UNKNOWN";
}

function ipcActivityStatus(service, token) {
    const entry = ipcOwns(token) ? service.entry(token) : null;
    return entry ? JSON.stringify({
        "state": entry.state,
        "action": entry.lastAction
    }) : "ISLAND_ACTIVITY_UNKNOWN";
}

function ipcOpenActivity(host, tag) {
    // A face that cannot open (title, icon or progress only) or suspended input: nothing opens, so say so.
    if (!host.islandController.pluginActive || !host.islandController.requestExpand(true))
        return `${tag}_ACTIVITY_UNAVAILABLE: activity`;
    return `${tag}_OPEN: activity\t${host.screen?.name ?? ""}`;
}

// Only a script's activity ("script:<name>:<n>") answers over IPC, never a plugin's or the shell's. Any local caller of
// dms ipc may address any script's token (island status lists them): scripts run as the same user, no boundary between.
function ipcOwns(token) {
    return typeof token === "string" && token.startsWith(scriptPrefix) && /^[^:]+:\d+$/.test(token.slice(scriptPrefix.length));
}

// A token is "<source>:<n>": a plugin id with a colon could pass for a script's or the shell's.
function pluginIdAllowed(id) {
    return typeof id === "string" && id !== "" && id.indexOf(":") === -1;
}

// Permanent bubbles (IslandActivityService.permanent): one entry per owner, { pluginId: { side, image, label,
// bubbleContent, receiving, seq } }. Keep awake ("dms:keepawake") is the shell's own and draws its own bubble.
function permanentAllowed(id, loaded, allowed) {
    return id === "dms:keepawake" || (pluginIdAllowed(id) && loaded === true && allowed === true);
}

// A permanent bubble's own fields come from a plugin: typed and bounded as a face's are (B10). The bubble's width follows
// its label; an image URL too long to be one (maxImageUrl) is dropped, never cut.
const maxPermanentLabel = 24;

// Qt 6 gives a url value (Qt.resolvedUrl) as an object: its text is the URL.
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
            "label": faceText(options.label).slice(0, maxPermanentLabel),
            "image": imageUrl(options.image),
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

// The IPC answer refusing a script's activity, or "". liveNames: scripts showing one now; asking again replaces it.
function scriptRefusal(name, liveNames, notifyApp) {
    if (!name || name.length > maxScriptName || name.indexOf(":") !== -1 || /[\u0000-\u001f\u007f]/.test(name))
        return "ISLAND_ACTIVITY_BAD_NAME";
    if (typeof notifyApp === "string" && notifyApp.trim().length > maxNotifyApp)
        return "ISLAND_ACTIVITY_BAD_NOTIFY_APP";
    return liveNames.indexOf(name) !== -1 || liveNames.length < maxScripts ? "" : "ISLAND_ACTIVITY_TOO_MANY";
}

function clampSize(value, min, max, fallback) {
    const n = Number(value);
    if (value === undefined || value === null || !isFinite(n))
        return fallback;
    return Math.max(min, Math.min(max, Math.ceil(n)));
}

// [min, max, default, ready-face min] per size a plugin face may ask for; that min fits three whole labels at 125 % text.
const faceBounds = {
    "compactLength": [120, 360, 240, 240],
    "expandedWidth": [280, 736, 460, 400],
    "expandedHeight": [120, 480, 200, 200],
    // A plugin's own bubble (along the bar) and its card row; the host keeps them at least as big as its own.
    "bubbleLength": [0, 240, 0, 0],
    "cardHeight": [0, 240, 0, 0]
};

function faceSize(face, key, ready) {
    const b = faceBounds[key];
    return clampSize(face ? face[key] : undefined, b[ready ? 3 : 0], b[1], b[2]);
}

// 0 keeps the shell's size for a face that does not ask for one (a system face, a plugin's bubble or card).
function ownFaceSize(face, key) {
    return face && face[key] > 0 ? faceSize(face, key) : 0;
}
