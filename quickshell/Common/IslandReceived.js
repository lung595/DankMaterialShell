.pragma library

// The island's "received" bubble: is this notification a file that another device sent (LocalSend, Warpinator...)?
// Reads only what the sending app put in its notification: the file, the device, a progress while it is big and still
// coming. KDE Connect and Abyss are left to their own plugins. Returns null when it is not a received file.

const senders = /localsend|warpinator|packet|quick ?share|nearby|bluetooth|blueman|obex|sharik|sendanywhere|snapdrop|pairdrop/i;
const plugins = /kde ?connect|kdeconnect|abyss/i;
// A known sender also notifies other things (a device paired, a request): only its transfer notifications count.
const transfer = /\b(received|receiving|incoming|transfer|saved|downloaded|download)\b|re[çc]u|r[ée]ception|enregistr|t[ée]l[ée]charg/i;
// Any other app counts only with an explicit "file received".
const explicit = /\bfiles?\b[^.]{0,30}\breceived\b|\breceived\b[^.]{0,30}\bfiles?\b|fichiers?\b[^.]{0,30}\bre[çc]us?\b/i;
const pathRe = /(?:file:\/\/)?(\/(?:[^\s"'<>\/]+\/)*[^\s"'<>\/]+\.[A-Za-z0-9]{1,8})(?=[\s"'<>,;)]|$)/;
const nameRe = /["«“']([^"»”'\n]{1,120}\.[A-Za-z0-9]{1,8})["»”']|(?:^|\s)([^\s"'<>\/]{1,120}\.[A-Za-z0-9]{1,8})(?=[\s,;:)]|$)/;
// "from X" first; the French "de X" only when X is not the file itself ("Réception de photo.jpg").
const deviceRes = [/(?:^|[\s"(«“])(?:from|depuis|by|par)\s+(?:l['’]appareil\s+|device\s+)?["«“]?([^"»”.,:;\n]{1,40}?)["»”]?\s*(?:[,:;\n]|\.(?![A-Za-z0-9])|$)/i,
    /(?:^|[\s"(«“])de\s+(?:l['’]appareil\s+)?["«“]?([^"»”.,:;\n]{1,40}?)["»”]?\s*(?:[,:;\n]|\.(?![A-Za-z0-9])|$)/i];

function deviceOf(text) {
    for (const re of deviceRes) {
        const m = text.match(re);
        if (m)
            return m[1].trim();
    }
    return "";
}

function plain(s) {
    return String(s ?? "").replace(/<[^>]*>/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"");
}

const kinds = [
    [/^(png|jpe?g|gif|webp|bmp|svg|avif|heic|tiff?)$/, "image"],
    [/^(mp4|mkv|webm|mov|avi|m4v)$/, "movie"],
    [/^(mp3|flac|ogg|opus|wav|m4a|aac)$/, "audio_file"],
    [/^(zip|tar|gz|xz|zst|7z|rar|bz2)$/, "folder_zip"],
    [/^(pdf|txt|md|odt|docx?|rtf|epub)$/, "description"]
];

// The Material icon for a file name.
function iconFor(name) {
    const ext = (String(name ?? "").match(/\.([A-Za-z0-9]+)$/)?.[1] ?? "").toLowerCase();
    for (const [re, icon] of kinds)
        if (re.test(ext))
            return icon;
    return "draft";
}

// 0..1 while the file is coming (the freedesktop "value" hint, or a "42 %" in the text), -1 once there or unknown.
function progressOf(text, hints) {
    const hinted = Number(hints?.value);
    const pct = Number.isFinite(hinted) && hints?.value !== undefined && hints?.value !== null && hints?.value !== "" ? hinted : Number(text.match(/(\d{1,3})\s?%/)?.[1]);
    return Number.isFinite(pct) && pct >= 0 && pct < 100 ? pct / 100 : -1;
}

function parse(app, summary, body, hints, desktopEntry) {
    const who = String(app ?? "") + " " + String(desktopEntry ?? "");
    if (plugins.test(who))
        return null;
    const text = plain(summary) + "\n" + plain(body);
    if (!(senders.test(who) ? transfer.test(text) : explicit.test(text)))
        return null;
    const path = text.match(pathRe)?.[1] ?? "";
    const named = path ? "" : text.match(nameRe);
    const file = path ? path.slice(path.lastIndexOf("/") + 1) : named ? (named[1] ?? named[2]) : "";
    const device = deviceOf(text);
    return {
        "file": file,
        "path": path,
        "folder": path ? path.slice(0, path.lastIndexOf("/")) || "/" : "",
        "device": device,
        "progress": progressOf(text, hints),
        "icon": iconFor(file),
        "isImage": iconFor(file) === "image" && path !== ""
    };
}
