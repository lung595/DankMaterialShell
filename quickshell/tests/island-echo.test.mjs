import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const E = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandEcho.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), E);

test("a notification about a copy is told apart, from any app", () => {
    assert.equal(E.kind("Quick Capture", "Screenshot Copied"), "copy");
    assert.equal(E.kind("", "Copied to clipboard"), "copy");
    assert.equal(E.kind("Flameshot", "Image copiée dans le presse-papiers"), "copy");
    assert.equal(E.kind("Signal", "New message from Alex"), "");
    assert.equal(E.kind("Signal", "Copyright notice"), "");
    // A copy is read in the summary only: a message whose body talks of copying stays a message.
    assert.equal(E.kind("Signal", "Alice", "Can you copy the file?"), "");
    assert.equal(E.kind("Quick Capture", "Screenshot Copied", "Saved to Pictures"), "copy");
    assert.equal(E.kind(undefined, undefined), "");
});

test("a browser's finished download, not a chat about one", () => {
    assert.equal(E.kind("Firefox", "Download completed report-copy.pdf"), "download");
    assert.equal(E.kind("Chromium", "Téléchargement terminé photo.jpg"), "download");
    assert.equal(E.kind("Signal", "Did the download finish?"), "");
});

test("a file manager's trash, not a mail about one", () => {
    assert.equal(E.kind("Files", "Report.pdf moved to the trash"), "trash");
    assert.equal(E.kind("dolphin", "Fichier mis à la corbeille"), "trash");
    assert.equal(E.kind("Thunderbird", "Empty the trash bin today"), "");
});

test("a mounted stick from a disk tool", () => {
    assert.equal(E.kind("udiskie", "Device mounted /dev/sdb1"), "usb");
    assert.equal(E.kind("Disks", "Clé USB éjectée, vous pouvez la retirer"), "usb");
    assert.equal(E.kind("Discord", "USB headset giveaway"), "");
});

test("a print job from the print system", () => {
    assert.equal(E.kind("system-config-printer", "Printing document Report.pdf"), "print");
    assert.equal(E.kind("Printers", "Impression terminée"), "print");
    assert.equal(E.kind("Signal", "Can you print it?"), "");
    // The fingerprint daemon is no print system.
    assert.equal(E.kind("fprintd", "Fingerprint print job enrolled"), "");
});

test("a Wi-Fi connection from the network manager", () => {
    assert.equal(E.kind("NetworkManager", "Connection established Home Wi-Fi"), "wifi");
    assert.equal(E.kind("nm-applet", "Déconnecté du réseau"), "wifi");
    assert.equal(E.kind("Signal", "Wi-Fi password is on the fridge"), "");
    assert.equal(E.kind("nm-applet", "Network password required for Home Wi-Fi"), "");
    assert.equal(E.kind("NetworkManager", "Wi-Fi networks available"), "");
});

test("a VPN, ahead of the plain connection it also is", () => {
    assert.equal(E.kind("NetworkManager", "VPN connection established"), "vpn");
    assert.equal(E.kind("Mullvad VPN", "Connected to se-got-wg-001"), "vpn");
    assert.equal(E.kind("Signal", "Use a VPN for that"), "");
});

test("DMS's low battery warning", () => {
    assert.equal(E.kind("DMS", "Low Battery Battery is at 15% - Consider charging soon"), "battery");
    assert.equal(E.kind("Steam", "Controller battery low"), "");
});

test("each bubble says one kind of info", () => {
    assert.equal(E.bubbleKind({ "source": "copy" }), "copy");
    assert.equal(E.bubbleKind({ "source": "download" }), "download");
    assert.equal(E.bubbleKind({ "source": "trash" }), "trash");
    assert.equal(E.bubbleKind({ "source": "usb" }), "usb");
    assert.equal(E.bubbleKind({ "source": "print" }), "print");
    assert.equal(E.bubbleKind({ "source": "vpn" }), "vpn");
    assert.equal(E.bubbleKind({ "source": "system", "kind": "network" }), "wifi");
    assert.equal(E.bubbleKind({ "source": "system", "kind": "battery" }), "battery");
    for (const kind of ["charging", "charged", "unplugged", "batterycritical"])
        assert.equal(E.bubbleKind({ "source": "system", "kind": kind }), "battery", kind);
    assert.equal(E.bubbleKind({ "source": "system", "kind": "volume" }), "");
    assert.equal(E.bubbleKind({ "source": "notification" }), "");
    assert.equal(E.bubbleKind(null), "");
});

test("an echo never takes the island from the info it repeats, nor from an Undo", () => {
    assert.equal(E.adoptable("", false, true, ["trash"]), true);
    assert.equal(E.adoptable("trash", true, true, ["trash"]), true);
    assert.equal(E.adoptable("trash", false, false, []), true);
    assert.equal(E.adoptable("trash", false, true, []), false);
    assert.equal(E.adoptable("trash", false, false, ["trash"]), false);
    assert.equal(E.adoptable("copy", false, false, ["trash"]), true);
    assert.equal(E.adoptable("copy", false, false, null), true);
});
