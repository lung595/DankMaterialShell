pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandCharge.js" as Charge
import "../../Common/IslandActivities.js" as Activities
import "../../Common/IslandArrival.js" as Arrival
import "../../Common/IslandKit.js" as Kit

// The laptop battery (machine side, his choices of 27/10): plugging in opens the island's charge face (kind "charging",
// a normal info), then the lasting "charge" bubble stays while it charges (under any passing machine bubble, seq -1);
// fully charged, unplugged and low are brief infos, critical an important one (kinds "charged", "unplugged", "battery",
// "batterycritical"). Reads BatteryService only; the power is sampled while it charges only, kept in memory, bounded.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    readonly property bool available: BatteryService.batteryAvailable
    readonly property real level: BatteryService.batteryLevel / 100
    readonly property bool plugged: BatteryService.isPluggedIn
    readonly property bool charging: BatteryService.isCharging
    readonly property real watts: Math.abs(BatteryService.changeRate)
    readonly property real seconds: root.charging ? BatteryService.estimatedSeconds() : 0
    // The pack's capacity left against its design (UPower), "" when unknown.
    readonly property string health: BatteryService.batteryHealth === "N/A" ? "" : BatteryService.batteryHealth
    readonly property bool low: BatteryService.isLowBattery && !root.charging
    readonly property bool critical: BatteryService.isCriticalBattery && !root.charging

    // A step of the battery: "plugged", "unplugged", "full", "low", "critical" (IslandBarHost plays its face).
    signal stepped(string step)

    readonly property var reading: ({
            "plugged": root.plugged,
            "charging": root.charging,
            "level": root.level
        })
    // The first reading only seeds: a shell started on its charger stays quiet.
    property var lastReading: null
    Component.onCompleted: {
        root.lastReading = root.available ? root.reading : null;
        // A shell started on its charger counts the session from now, without the plug's ring.
        if (root.available && root.charging) {
            root.startLevel = root.level;
            root.startedAt = Date.now();
        }
    }
    onReadingChanged: {
        if (!root.available)
            return;
        const step = Charge.step(root.lastReading, root.reading);
        root.lastReading = root.reading;
        if (step === "plugged") {
            root.history = [];
            root.dismissed = false;
            root.startLevel = root.level;
            root.startedAt = Date.now();
            root.now = root.startedAt;
            root.ringPending = true;
            root.recent = true;
            root.life.restart();
        }
        if (step && root.enabled)
            root.stepped(step);
    }
    onLowChanged: {
        if (root.low && root.enabled)
            root.stepped("low");
    }
    onCriticalChanged: {
        if (root.critical && root.enabled)
            root.stepped("critical");
    }

    // [time ms, watts] while it charges; nothing samples on battery or once full (D3).
    property var history: []
    readonly property Timer sampler: Timer {
        interval: Activities.chargeSampleMs
        repeat: true
        triggeredOnStart: true
        running: root.enabled && root.available && root.charging
        onTriggered: root.history = Charge.record(root.history, Date.now(), root.watts, Activities.chargeHistoryMax)
    }
    readonly property var stats: Charge.summary(root.history)

    // The island shows the charge (its face, or the card a click on it opens).
    readonly property bool shown: root.controller.activeActivity === "charging"
    // Leaving it, the clicked card is forgotten and the bubble's life starts again (M20); while shown, that life waits.
    onShownChanged: {
        if (root.shown)
            root.life.stop();
        else
            root.detail = false;
        if (Arrival.bubbleClockRestarts(root.shown, root.recent))
            root.life.restart();
    }
    // Once the pointer leaves the island, the card a click opened is forgotten: the next hover shows the face, the card
    // takes a new click (his choice of 28/10).
    readonly property bool pointed: root.controller.pointerInside
    onPointedChanged: {
        if (!root.pointed)
            root.detail = false;
    }

    // The clock times move once a minute while something shows them, read again the moment it shows.
    property real now: Date.now()
    readonly property Timer minute: Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Charge.clockLive(root.shown, root.lasting, root.cardOpen)
        onTriggered: root.now = Date.now()
    }

    function timeText(seconds) {
        const t = Charge.left(seconds);
        if (!t)
            return "";
        if (t.h === 0)
            return I18n.tr("%1 min", "island charge: time left in minutes").arg(t.m);
        return I18n.tr("%1 h %2", "island charge: time left in hours and minutes").arg(t.h).arg(String(t.m).padStart(2, "0"));
    }
    readonly property bool clock24: SettingsData.use24HourClock !== false
    readonly property string leftText: root.timeText(root.seconds)
    readonly property string fullAt: Charge.left(root.seconds) ? Charge.clock(root.now + root.seconds * 1000, root.clock24) : ""
    function clockText(ms) {
        return Charge.clock(ms, root.clock24);
    }
    readonly property string percent: Charge.percent(root.level) + "%"

    // The open island's face (BubbleChargeFace): the session's start (what the plug gave since), the ring it owes the
    // face once at the plug, the power as text and word (USB PD tiers, IslandCharge.speed), and how far the island has
    // grown into the face (DIslandSurface.faceBigness): the face counts its level and reveals its chips on it.
    property real startLevel: 0
    property real startedAt: 0
    property bool ringPending: false
    // The plug's ring, taken once by the face that plays it.
    function takeRing() {
        const owed = root.ringPending;
        root.ringPending = false;
        return owed;
    }
    property real grow: 1
    readonly property string wattsText: root.watts > 0 ? I18n.tr("%1 W", "island charge face: power in watts").arg(Number(root.watts).toLocaleString(Qt.locale(), "f", 1)) : ""
    readonly property string speedText: {
        switch (Charge.speed(root.watts)) {
        case "slow":
            return I18n.tr("slow", "island charge face: charging power word, under 10 W");
        case "normal":
            return I18n.tr("Normal").toLocaleLowerCase();
        case "fast":
            return I18n.tr("fast", "island charge face: charging power word, 30 to 65 W");
        case "ultra":
            return I18n.tr("ultra fast", "island charge face: charging power word, 65 W and above");
        }
        return "";
    }
    readonly property var gain: Charge.gain(root.startLevel, root.level, root.startedAt, root.now)
    readonly property string gainPct: Charge.gainPct(root.gain)
    readonly property string gainText: root.gainPct ? I18n.tr("%1% in %2 min", "island charge face: what the session gave, signed percent and minutes").arg(root.gainPct).arg(root.gain.min) : ""
    readonly property string fullAtText: root.fullAt !== "" ? I18n.tr("full at %1", "island charge face: clock time the battery is full").arg(root.fullAt) : ""
    // The level's ramp on the island's surface (the upright pill's track, the open island's glow).
    function hueAt(level) {
        const c = Kit.batteryHue(level, {
            "error": Theme.error,
            "warning": Theme.warning,
            "success": Theme.success,
            "surface": Theme.hostSurface,
            "ink": Theme.surfaceText
        });
        return Qt.rgba(c.r, c.g, c.b, 1);
    }
    readonly property color hue: root.hueAt(root.level)

    // Right click hides the lasting bubble until the next plug; a click on it opens its card.
    property bool dismissed: false
    property bool cardOpen: false
    // A click on the open island face turns it into the card (the chart), until the face goes.
    property bool detail: false
    // Charging and not hidden: the island's face opens on hover while this holds.
    readonly property bool live: root.enabled && root.available && root.charging && !root.dismissed
    // The bubble lives one notification (glanceTimeoutMs, mouvement.md §3; his choice of 28/10: no lasting bubble) once
    // the island has released the face (or at once, when the island was busy); a 100 % (or the charge limit the firmware
    // stops at) brings the "Charged" brief back.
    property bool recent: false
    readonly property Timer life: Timer {
        interval: Activities.faceTimeoutMs("charging")
        onTriggered: root.recent = false
    }
    readonly property bool lasting: root.live && root.recent
    onLastingChanged: {
        if (!root.lasting)
            root.cardOpen = false;
    }

    function titleOf(kind) {
        switch (kind) {
        case "charged":
            return I18n.tr("Charged", "island charge: the battery is full");
        case "unplugged":
            return I18n.tr("Unplugged", "island charge: the charger was removed");
        case "battery":
            return I18n.tr("Low Battery");
        case "batterycritical":
            return I18n.tr("Critical Battery");
        }
        return I18n.tr("Plugged in", "island system face: power connected title");
    }
    // A face or bubble of the battery, by kind (IslandBarHost: islandFaces, machineEntry, faceBubble).
    function faceOf(kind) {
        // "Charged" shows the level read: a firmware charge limit stops the charge at 80 %, not at 100 %.
        const level = root.level;
        return {
            "id": kind === "charging" ? "charge" : "system",
            "source": "system",
            "kind": kind,
            // Under any passing machine bubble: it comes back once that one leaves.
            "seq": kind === "charging" ? -1 : 0,
            "icon": "",
            "cardIcon": "",
            "progress": -1,
            "text": root.percent,
            // The level stays beside the battery on the flat pill ("64%").
            "valued": true,
            "value": root.percent,
            "standLevel": level,
            "standText": root.percent,
            "hue": root.hueAt(level),
            "title": root.titleOf(kind),
            "detail": kind === "charging" ? I18n.tr("Charging · %1", "island charge card subtitle: battery level").arg(root.percent) : root.percent,
            // The shape follows the ramp's bounds (mouvement.md §6): warning to 15 %, the alert's to 5 %; only the critical
            // info is an alert that rings.
            "accent": kind === "batterycritical" ? "error" : Kit.batteryShape(level) !== "" ? "warning" : "primary",
            "shapeFamily": kind !== "batterycritical" && Kit.batteryShape(level) === "alert" ? "alert" : "",
            "open": kind === "charging" && root.cardOpen,
            "battery": {
                "level": level,
                "bolt": kind === "charging",
                "badge": "",
                // The pill's liquid waves with the power while it charges (IslandLiquid.wave).
                "wave": kind === "charging" ? {
                    "amp": Charge.waveAmp(root.watts, Theme.spacingXXS),
                    "rate": Charge.waveRate(root.watts)
                } : null
            },
            "charge": root
        };
    }
    readonly property var face: root.faceOf("charging")
}
