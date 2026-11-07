.pragma library

// Never the same info twice: an app's notification that only says what a bubble says (a copy, a finished download, a
// file in the trash, a stick, a print job, the network, the VPN, the battery) is told apart by its app and its words.
// [kind, the apps that say it (null = any), its words (read with the app's name)]; the first that matches wins, so the
// narrow ones come first (a VPN is a connection too, a download's name may hold "copy").
const kinds = [
    ["vpn", /network|nm-applet|vpn|wireguard|tailscale|mullvad|proton/i, /\bvpn\b|wireguard|tailscale/i],
    // A network app's own words about the network (a password asked, the networks around) are no connection.
    ["wifi", /network|nm-applet|r[ée]seau|iwd|connman|wi-?fi/i, /connect|connexion/i],
    ["download", /firefox|chrom|brave|zen|librewolf|vivaldi|epiphany|\bweb\b|floorp|waterfox|opera|edge/i, /download|t[ée]l[ée]charg/i],
    ["trash", /files|fichiers|nautilus|dolphin|thunar|nemo|caja|pcmanfm/i, /trash|corbeille|deleted|supprim/i],
    ["usb", /udisk|disks|disques|nautilus|files|fichiers|dolphin|thunar|nemo/i, /\busb\b|mount|mont[ée]|eject|[ée]ject|drive|cl[ée]\b|removable|amovible/i],
    ["print", /\bprint|cups|imprim/i, /print|impr(im|ession)|\bjob\b/i],
    ["battery", /^dms$|upower|power|batter/i, /batter/i],
    ["copy", null, /\b(cop(y|ied)|clipboard)\b|copi[ée]|presse-papiers/i]
];

// The kind of info a notification only repeats, "" when it says something of its own. A kind bound to its apps reads
// the summary and the body; one said by any app (a copy) reads the summary only, so a message about copying is not one.
function kind(app, summary, body) {
    const a = String(app ?? "");
    const head = a + " " + String(summary ?? "");
    const words = head + " " + String(body ?? "");
    const hit = kinds.find(k => k[1] ? k[1].test(a) && k[2].test(words) : k[2].test(head));
    return hit ? hit[0] : "";
}

// What each bubble (or island activity, by its id as a machine kind) says.
const said = {
    "copy": "copy",
    "download": "download",
    "trash": "trash",
    "usb": "usb",
    "print": "print",
    "vpn": "vpn",
    "network": "wifi",
    "openwifi": "wifi",
    "battery": "battery",
    "charging": "battery",
    "charged": "battery",
    "unplugged": "battery",
    "batterycritical": "battery"
};

// Whether an app's notification of this echo kind may take the island: never while the island or a bubble already says
// it (held: those kinds, e.g. a trash with its Undo), nor when brief info lives in bubbles. Alerts always may.
function adoptable(kind, critical, briefBubbles, held) {
    if (critical || !kind)
        return true;
    return !briefBubbles && (held ?? []).indexOf(kind) === -1;
}

function bubbleKind(face) {
    if (!face)
        return "";
    return said[face.source === "system" ? face.kind : face.source] ?? "";
}
