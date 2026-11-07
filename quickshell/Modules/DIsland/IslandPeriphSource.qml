pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import "../../Common/IslandPeriph.js" as Periph
import "../../Common/IslandKit.js" as Kit

// The low peripheral bubble (machine side, kind "periph"): a mouse, keyboard, gamepad or headset seen by UPower crossing
// 15 % then 5 %, or starting to charge. Driven by each device's own change signals, nothing polls. Its face fields are
// read by IslandBarHost's bubbleList; no island activity.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    // The island's own "periph" face first, else the machine bubble (IslandBarHost.playMachine).
    signal arrived
    // The reading on show: { type, percent, charging, seconds, device }.
    property var shown: null
    // Per device (native path): the last Periph.step() result. Plain map, nothing binds to it.
    property var marks: ({})
    // True once UPower's startup list has had time to arrive: a device appearing later is a plug (Periph.first).
    // shortcut: a fixed delay (Periph.settleMs), a device UPower lists later than that at boot would raise a
    // bubble; make it UPower's own "ready" of the whole list if that ever shows.
    property bool settled: false
    readonly property Timer settle: Timer {
        interval: Periph.settleMs // B12
        running: true
        onTriggered: root.settled = true
    }

    readonly property real seconds: root.shown ? (root.shown.device?.timeToFull ?? root.shown.seconds) : 0
    readonly property string timeLeft: root.seconds > 0 ? BatteryService.formatDuration(root.seconds) : ""
    readonly property var face: {
        const s = root.shown;
        if (!s)
            return null;
        const name = root.typeName(s.type);
        const percent = I18n.tr("%1 %", "island peripheral bubble: battery percent").arg(Math.round(s.percent));
        const level = Math.max(0, Math.min(1, s.percent / 100));
        const shape = Kit.batteryShape(level);
        return {
            "icon": Periph.icon(s.type),
            // The A1 battery says the level: no track beside it, the level as its value; the time to full is in the card.
            "progress": -1,
            "text": percent,
            "valued": true,
            "standLevel": level,
            "standText": percent,
            "title": s.charging ? I18n.tr("%1 charging", "island peripheral bubble title: device type").arg(name) : I18n.tr("%1 low", "island peripheral bubble title: device type").arg(name),
            "detail": s.charging && root.timeLeft ? I18n.tr("%1 · %2 until full", "island peripheral bubble detail: percent, time left").arg(percent).arg(root.timeLeft) : percent,
            // The shape follows the battery's bounds (mouvement.md §6): warning to 15 %, the alert's to 5 %, no ring.
            "accent": shape !== "" ? "warning" : "primary",
            "shapeFamily": shape === "alert" ? "alert" : "",
            "blink": !s.charging,
            // The A1 battery with the device's icon as a badge on its corner (bubbles.md, 27/10).
            "battery": {
                "level": s.percent / 100,
                "bolt": s.charging,
                "badge": Periph.icon(s.type)
            }
        };
    }

    function typeName(type) {
        switch (type) {
        case "mouse":
            return I18n.tr("Mouse", "island peripheral bubble: device type");
        case "keyboard":
            return I18n.tr("Keyboard", "island peripheral bubble: device type");
        case "gamepad":
            return I18n.tr("Controller", "island peripheral bubble: device type");
        }
        return I18n.tr("Headset", "island peripheral bubble: device type");
    }

    function typeOf(device) {
        switch (device.type) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.GamingInput:
            return "gamepad";
        case UPowerDeviceType.Headset:
            return "headset";
        case UPowerDeviceType.Headphones:
            return "headphones";
        }
        return "";
    }

    // One reading of one device; raises the bubble when Periph.step() says so. Returns the alert ("" = none).
    function read(key, type, percent, charging, seconds, device) {
        const next = Periph.step(root.marks[key] ?? Periph.first(root.settled), percent, charging);
        root.marks[key] = next;
        if (!next.alert || !root.enabled || !root.controller.bubblesEnabled)
            return "";
        root.shown = {
            "type": type,
            "percent": percent,
            "charging": charging,
            "seconds": seconds,
            "device": device
        };
        root.arrived();
        return next.alert;
    }

    // A model's type, remembered for the next time UPower guesses keyboard for it (B12).
    function keep(model, type) {
        const kept = Periph.remember(SessionData.islandPeriphTypes, model, type);
        if (kept)
            SessionData.set("islandPeriphTypes", kept);
    }

    property Instantiator devices: Instantiator {
        model: UPower.devices

        delegate: QtObject {
            id: watch

            required property UPowerDevice modelData
            // B12: what UPower says, remembered on its own change: `type` reads the remembered map, so writing the map from
            // type's own change was a binding loop.
            readonly property string reported: watch.modelData.ready ? root.typeOf(watch.modelData) : ""
            readonly property string type: watch.reported ? Periph.kind(watch.reported, SessionData.islandPeriphTypes, watch.modelData.model) : ""
            readonly property real percent: Math.round(watch.modelData.percentage * 100)
            readonly property bool charging: watch.modelData.state === UPowerDeviceState.Charging
            // The path its mark is kept under, still known once UPower has dropped the device.
            property string key

            function check() {
                if (!watch.type)
                    return;
                watch.key = watch.modelData.nativePath;
                root.read(watch.key, watch.type, watch.percent, watch.charging, watch.modelData.timeToFull, watch.modelData);
            }

            Component.onCompleted: {
                root.keep(watch.modelData.model, watch.reported);
                watch.check();
            }
            onReportedChanged: root.keep(watch.modelData.model, watch.reported)
            onTypeChanged: watch.check()
            onPercentChanged: watch.check()
            onChargingChanged: watch.check()
        }
        // A dropped device loses its mark: back on the same path, it comes in as a plug again (Periph.first, B12).
        onObjectRemoved: (index, object) => delete root.marks[object.key]
    }
}
