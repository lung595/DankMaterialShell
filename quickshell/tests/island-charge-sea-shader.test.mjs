import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

// The charge face's sea (Kit/IslandChargeSea.qml) loads Shaders/qsb/charge_sea.frag.qsb: it must be there, and built from
// the charge_sea.frag beside it (recompiled with Qt's qsb when one is installed, its dump compared).
const frag = fileURLToPath(new URL("../Shaders/frag/charge_sea.frag", import.meta.url));
const built = fileURLToPath(new URL("../Shaders/qsb/charge_sea.frag.qsb", import.meta.url));
const qsb = [process.env.QSB, "/usr/lib64/qt6/bin/qsb", "/usr/lib/qt6/bin/qsb"].find(p => p && existsSync(p));

test("the charge sea's compiled shader is in the tree", () => {
    assert.ok(existsSync(built) && statSync(built).size > 0);
});

test("the charge sea's compiled shader matches its source", { skip: !qsb && "no qsb (set QSB to Qt's qsb)" }, () => {
    const dir = mkdtempSync(join(tmpdir(), "charge-sea-"));
    try {
        const fresh = join(dir, "charge_sea.frag.qsb");
        execFileSync(qsb, ["--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", fresh, frag]);
        const dump = path => execFileSync(qsb, ["-d", path], { encoding: "utf8" });
        assert.equal(dump(built), dump(fresh));
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
