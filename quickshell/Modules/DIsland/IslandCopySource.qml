pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandCopy.js" as Copy
import "../../Common/IslandArrival.js" as Arrival

// The "copied" bubble (apps side, source "copy"): each copy (text, image, file) in DMS's clipboard. A brief info like any
// other: it is one of the apps side's items, so the wing enters, replaces, stands beside the launcher
// and leaves with it exactly as with every bubble. Its hover card peeks at the copy, a secret masked; a password manager's
// copy is not even stored by DMS. A copy while it shows restarts its lifetime and moves its shape on.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    property bool shown: false
    // One more per copy: a copy while it shows moves the wing's shape on (IslandBubbles eventKey).
    property int pulse: 0
    // What the hover card shows of the copy: one line, a secret masked (IslandCopy.peek); an image shows its icon instead.
    property string peek: ""
    // How much of a copied text or file name the peek keeps: one line of the hover card.
    readonly property int peekLength: 40
    readonly property string copiedTitle: I18n.tr("Copied!", "island copied bubble: title shown after a copy to the clipboard")
    // text, link, image, file or secret (IslandCopy.kind): its icon stands under the check, and heads the card.
    property string kind: "text"
    readonly property bool image: root.kind === "image"
    // A copied image's own picture, as a data URL, asked of DMS's clipboard only for an image and dropped when the bubble goes.
    property string thumb: ""
    property real thumbId: -1
    readonly property var face: ({
            "pulse": root.pulse,
            "id": "copy",
            "source": "copy",
            "kind": "copy",
            // Ahead of every other app bubble: it is what the user just did.
            "seq": 3e6,
            "icon": "check",
            "progress": -1,
            "text": root.copiedTitle,
            "valued": true,
            "title": root.copiedTitle,
            "detail": root.peek,
            "peekImage": root.image,
            "typeIcon": Copy.kindIcon(root.kind),
            // Its card is headed by the copy's kind (BubbleCardCopy), the pill keeps the check.
            "cardIcon": Copy.kindIcon(root.kind),
            "thumb": root.thumb,
            "accent": "primary"
        })

    // The real source: DMS's clipboard state, pushed on every change (no polling).
    property int lastId: -1
    readonly property Connections clipboard: Connections {
        target: DMSService
        enabled: root.enabled

        function onClipboardStateUpdate(data) {
            const s = Copy.step(data?.history, root.lastId);
            root.lastId = s.last;
            // A copy the island made itself: the button that made it says so with its check, no bubble.
            if (!s.copied || Copy.ownCopy())
                return;
            root.show(Copy.newest(data?.history));
        }
    }

    function show(entry) {
        root.kind = Copy.kind(entry);
        const files = root.kind === "file" ? Copy.files(entry?.preview, root.peekLength) : null;
        root.peek = root.image ? "" : files ? files.name || I18n.tr("%1 files", "island copied bubble: several files copied").arg(files.count) : Copy.peek(entry?.preview, root.peekLength);
        root.thumb = "";
        root.thumbId = -1;
        root.play();
        // Only an image's data is ever read (never a text, so never a secret), over DMS's local socket.
        if (!root.shown || !root.image || typeof entry?.id !== "number" || !Copy.thumbOk(entry))
            return;
        const id = entry.id;
        root.thumbId = id;
        DMSService.sendRequest("clipboard.getEntry", {
            "id": id
        }, response => {
            // Late: the bubble went or another copy came meanwhile.
            if (root.thumbId !== id || response?.error || !Copy.thumbOk(entry, response?.result?.data))
                return;
            root.thumb = ClipboardService.imageDataUrl(response?.result?.data, response?.result?.mimeType || entry.mimeType);
        });
    }

    // The island's own "copy" face first (IslandBarHost asks for it); a bubble only when the island cannot or will not.
    signal arrived
    readonly property bool onIsland: root.controller.activeActivity === "copy"
    // Hovering the island's face holds it, as hovering the bubble does.
    readonly property bool islandHeld: root.onIsland && root.controller.timeoutSuspended
    onIslandHeldChanged: root.hold(root.islandHeld)
    // Its island face was put back after an alert, but the copy's time ran out meanwhile. Leaving the island for its
    // bubble, the copy lives its whole time again (M20).
    onOnIslandChanged: {
        if (Arrival.bubbleClockRestarts(root.onIsland, root.shown))
            root.life.restart();
        Qt.callLater(root.leave);
    }
    readonly property Connections ending: Connections {
        target: root.controller

        function onSystemActivityEnding(activityId) {
            if (activityId === "copy")
                root.hide();
        }
    }

    readonly property Timer life: Timer {
        interval: root.controller.transientTimeout
        onTriggered: root.close()
    }

    function play() {
        if (!root.enabled || !root.controller.bubblesEnabled)
            return;
        root.pulse++;
        root.shown = true;
        root.life.restart();
        root.arrived();
    }
    function hide() {
        root.life.stop();
        root.shown = false;
        root.peek = "";
        root.kind = "text";
        root.thumb = "";
        root.thumbId = -1;
    }
    function close() {
        root.hide();
        root.leave();
    }
    function leave() {
        if (root.onIsland && !root.shown)
            root.controller.finishTransient();
    }
    // Hovering the bubble holds it, as every brief info.
    function hold(inside) {
        if (!root.shown)
            return;
        if (inside)
            root.life.stop();
        else
            root.life.restart();
    }
}
