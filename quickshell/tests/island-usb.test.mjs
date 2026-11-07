import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const ctx = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandUsb.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), ctx);
const U = ctx;

const lsblk = {
    "blockdevices": [
        { "path": "/dev/nvme0n1", "pkname": null, "type": "disk", "fstype": null, "hotplug": false, "rm": false, "tran": "nvme" },
        { "path": "/dev/nvme0n1p2", "pkname": "nvme0n1", "type": "part", "fstype": "btrfs", "mountpoint": "/", "fsavail": 5, "size": 9 },
        { "path": "/dev/zram0", "pkname": null, "type": "disk", "fstype": "swap", "mountpoint": "[SWAP]", "hotplug": false },
        { "path": "/dev/sdb", "pkname": null, "type": "disk", "fstype": null, "model": "Cruzer Blade", "hotplug": true, "rm": true, "tran": "usb", "size": 16000000000 },
        { "path": "/dev/sdb1", "pkname": "sdb", "type": "part", "fstype": "vfat", "label": "STICK", "mountpoint": "/run/media/u/STICK", "fsavail": 12400000000, "size": 15990000000 },
        { "path": "/dev/sdb2", "pkname": "sdb", "type": "part", "fstype": "ext4", "label": null, "mountpoint": null, "fsavail": null, "size": 4000000 },
        { "path": "/dev/sdb3", "pkname": "sdb", "type": "part", "fstype": "crypto_LUKS", "label": null, "mountpoint": null, "fsavail": null, "size": 4000000 }
    ]
};

test("only filesystems of removable disks, named by label then model, free only when mounted", () => {
    const d = U.drives(JSON.stringify(lsblk));
    assert.equal(d.length, 2);
    assert.equal(d[0].dev, "/dev/sdb1");
    assert.equal(d[0].disk, "/dev/sdb");
    assert.equal(d[0].name, "STICK");
    assert.equal(d[0].free, 12400000000);
    assert.equal(d[0].mount, "/run/media/u/STICK");
    assert.equal(d[1].name, "Cruzer Blade");
    assert.equal(d[1].free, -1);
    assert.equal(d[1].mount, "");
});

test("bad lsblk output gives no drives", () => {
    assert.equal(U.drives("not json").length, 0);
    assert.equal(U.drives("{}").length, 0);
    assert.equal(U.drives(null).length, 0);
});

test("a new device is an arrival, the same list again or a removal is not", () => {
    const d = U.drives(lsblk);
    assert.equal(U.arrived([], d).dev, "/dev/sdb1");
    assert.equal(U.arrived(d, d), null);
    assert.equal(U.arrived(d, d.slice(1)), null);
    assert.equal(U.arrived(d.slice(1), d).dev, "/dev/sdb1");
});

test("sizes in decimal units and the mount path from udisksctl", () => {
    assert.equal(U.size(12400000000), "12.4 GB");
    assert.equal(U.size(512), "512 B");
    assert.equal(U.size(250000000000), "250 GB");
    assert.equal(U.size(-1), "");
    assert.equal(U.mountedAt("Mounted /dev/sdb1 at /run/media/u/MY STICK\n"), "/run/media/u/MY STICK");
    assert.equal(U.mountedAt("Mounted /dev/sdb1 at /media/STICK."), "/media/STICK");
    assert.equal(U.mountedAt("Error mounting"), "");
});
