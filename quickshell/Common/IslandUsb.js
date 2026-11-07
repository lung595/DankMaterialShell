.pragma library

// USB stick / plugged disk bubble (island, source "usb"): the removable filesystems, read from
// `lsblk -J -l -b -o PATH,PKNAME,TYPE,FSTYPE,LABEL,MODEL,FSAVAIL,SIZE,MOUNTPOINT,HOTPLUG,RM,TRAN`, re-run on UDisks2 signals.
// A4: the drive list and its arrivals are pure logic, tested by island-usb.test.mjs.

// One entry per filesystem on a hotplug, removable or USB disk: dev (/dev/sdb1), disk (/dev/sdb, for power-off),
// name (label, else the disk's model, else the device), free (bytes, -1 while not mounted), size, mount ("" if none).
// Containers, not filesystems: udisksctl cannot mount them.
const unmountable = ["swap", "crypto_LUKS", "LVM2_member", "linux_raid_member"];

function drives(json) {
    let rows;
    try {
        rows = (typeof json === "string" ? JSON.parse(json) : json)?.blockdevices;
    } catch (e) {
        return [];
    }
    if (!Array.isArray(rows))
        return [];
    const byName = {};
    for (const row of rows)
        if (row && row.path)
            byName[row.path.replace(/^\/dev\//, "")] = row;
    const rootOf = row => {
        let r = row;
        for (let i = 0; i < 8 && r && r.pkname && byName[r.pkname]; i++)
            r = byName[r.pkname];
        return r;
    };
    const out = [];
    for (const row of rows) {
        if (!row || !row.path || !row.fstype || unmountable.indexOf(row.fstype) !== -1 || (row.type !== "part" && row.type !== "disk"))
            continue;
        const disk = rootOf(row);
        if (!disk || !(disk.hotplug === true || disk.rm === true || disk.tran === "usb"))
            continue;
        const mount = typeof row.mountpoint === "string" && row.mountpoint.startsWith("/") ? row.mountpoint : "";
        const label = String(row.label || "").trim();
        const model = String(disk.model || "").trim();
        out.push({
            "dev": row.path,
            "disk": disk.path,
            "name": label || model || row.path.replace(/^\/dev\//, ""),
            "free": mount && row.fsavail !== null && row.fsavail !== undefined ? Number(row.fsavail) : -1,
            "size": Number(row.size) || 0,
            "mount": mount
        });
    }
    return out;
}

// The first drive in `now` that `before` (the previous drives) did not have, or null.
function arrived(before, now) {
    const seen = (before || []).map(d => d.dev);
    return (now || []).find(d => seen.indexOf(d.dev) === -1) ?? null;
}

// Decimal units, like file managers show a stick's size: "12.4 GB".
function size(bytes) {
    const n = Number(bytes);
    if (!isFinite(n) || n < 0)
        return "";
    const units = ["B", "kB", "MB", "GB", "TB"];
    let v = n;
    let i = 0;
    while (v >= 1000 && i < units.length - 1) {
        v /= 1000;
        i++;
    }
    return (i === 0 || v >= 100 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
}

// `udisksctl mount` prints "Mounted /dev/sdb1 at /run/media/me/STICK" (older: a trailing dot): the path, or "".
function mountedAt(output) {
    const m = String(output || "").match(/ at (\/.*?)\.?\s*$/m);
    return m ? m[1] : "";
}
