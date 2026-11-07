import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandReceived.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);

test("a sender's finished transfer gives the file, its folder and the device", () => {
    const r = C.parse("LocalSend", "File received", "Saved /data/u/Downloads/photo.jpg from Pixel 8", {}, "org.localsend.localsend_app");
    assert.equal(r.file, "photo.jpg");
    assert.equal(r.path, "/data/u/Downloads/photo.jpg");
    assert.equal(r.folder, "/data/u/Downloads");
    assert.equal(r.device, "Pixel 8");
    assert.equal(r.progress, -1);
    assert.equal(r.icon, "image");
    assert.equal(r.isImage, true);
});

test("a big file still coming has a progress, from the hint or the text", () => {
    assert.equal(C.parse("Warpinator", "Receiving report.pdf", "from laptop", { "value": 42 }).progress, 0.42);
    assert.equal(C.parse("Warpinator", "Receiving", "\"film.mkv\" 7 % from laptop", {}).progress, 0.07);
    const r = C.parse("Warpinator", "Receiving", "\"film.mkv\" 7 % from laptop", {});
    assert.equal(r.file, "film.mkv");
    assert.equal(r.icon, "movie");
    assert.equal(r.isImage, false);
    assert.equal(C.parse("Warpinator", "Transfer done", "film.mkv 100 %", {}).progress, -1);
});

test("French texts: the file is not taken for the device", () => {
    const r = C.parse("Bluetooth", "Réception de photo.png", "", {});
    assert.equal(r.file, "photo.png");
    assert.equal(r.device, "");
    assert.equal(C.parse("LocalSend", "Fichier reçu", "notes.txt de Téléphone", {}).device, "Téléphone");
});

test("other notifications of a sender, and other apps, are not received files", () => {
    assert.equal(C.parse("LocalSend", "Device connected", "Pixel 8 is online", {}), null);
    assert.equal(C.parse("Firefox", "Download complete", "a.zip", {}), null);
    assert.equal(C.parse("Some app", "1 file received", "a.zip from desk", {}).file, "a.zip");
});

test("KDE Connect and Abyss are left to their plugins", () => {
    assert.equal(C.parse("KDE Connect", "File received", "a.jpg from phone", {}), null);
    assert.equal(C.parse("x", "File received", "a.jpg", {}, "org.kde.kdeconnect.app"), null);
    assert.equal(C.parse("Abyss", "File received", "a.jpg", {}), null);
});
