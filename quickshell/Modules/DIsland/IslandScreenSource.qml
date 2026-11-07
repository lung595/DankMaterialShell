pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandScreen.js" as IslandScreen

// The screen plugged bubble (machine side, kind "display"): a niri output appears, the card asks extend / duplicate /
// only this one and extends by itself after a while; a choice made for that monitor is kept and applied the next time,
// with an Undo's lifetime to take it back. Reacts to NiriService.outputs only (OutputsChanged event); its timer runs only while it asks.
QtObject {
    id: root

    required property IslandController controller
    required property string screenName
    property bool enabled: true

    // "" (nothing shown), "ask" (the choice is open) or "applied" (a kept choice, undo open).
    property string phase: ""
    property string choice: "extend"
    property string output: ""
    property string label: ""
    property string key: ""
    // The outputs as niri set them on plug, for undo.
    property var before: ({})
    // A kept "only": the other outputs to turn off once its Undo is over (reset), not at once: off, the screen with the
    // focus would take away the bar that carries this bubble, and its Undo with it.
    property var pendingOff: []
    property var _names: null

    // Asking waits longer than an Undo: a choice to read and make, not one to take back.
    readonly property int waitMs: phase === "ask" ? root.controller.undoTimeout * 3 : root.controller.undoTimeout
    readonly property var face: ({
            "icon": "desktop_windows",
            "progress": -1,
            "text": "",
            "title": root.phase === "applied" ? I18n.tr("Screen layout applied", "island screen bubble title, a kept choice was applied") : I18n.tr("Screen connected", "island screen bubble title"),
            "detail": root.label,
            "open": true,
            "screenSource": root
        })

    // The island's own "display" face first (its value Choose or Undo), else the machine bubble (IslandBarHost.playMachine).
    signal arrived
    readonly property bool onIsland: controller.activeActivity === "display"
    // Hovering the island's face holds the wait, as hovering the bubble does.
    readonly property bool islandHeld: onIsland && controller.timeoutSuspended
    onIslandHeldChanged: hold(islandHeld)
    // The face keeps the wait's clock too: the island's transient timer must not drop it mid-choice.
    readonly property Connections islandTimerWatch: Connections {
        target: root.controller.transientTimer

        function onRunningChanged() {
            if (root.controller.transientTimer.running && root.onIsland && root.phase)
                root.controller.transientTimer.stop();
        }
    }

    // A face that leaves early (its Choose, Escape, another face) hands the choice or the Undo to the machine bubble's card.
    readonly property Connections ending: Connections {
        target: root.controller

        function onSystemActivityEnding(activityId) {
            if (activityId !== "display" || !root.phase)
                return;
            root.controller.showMachineBubble("display");
            root.controller.machineBubbleTimer.stop();
        }
    }

    readonly property Timer decide: Timer {
        interval: root.waitMs
        onTriggered: root.phase === "ask" ? root.choose("extend", false) : root.finish()
    }

    readonly property Connections outputsWatch: Connections {
        target: NiriService

        function onOutputsChanged() {
            root.outputsChanged();
        }
    }

    // The bubble keeps its own clock: the wing's transient timer must not drop it mid-choice.
    readonly property Connections bubbleWatch: Connections {
        target: root.controller

        function onMachineBubbleKindChanged() {
            // Its face back in the island hides the bubble; the question goes on there.
            if (root.controller.machineBubbleKind !== "display" && !root.onIsland)
                root.reset();
        }
    }
    readonly property Connections bubbleTimerWatch: Connections {
        target: root.controller.machineBubbleTimer

        function onRunningChanged() {
            if (root.controller.machineBubbleTimer.running && root.controller.machineBubbleKind === "display")
                root.controller.machineBubbleTimer.stop();
        }
    }

    Component.onCompleted: {
        if (Object.keys(NiriService.outputs).length)
            _names = Object.keys(NiriService.outputs);
    }

    function outputsChanged() {
        const outputs = NiriService.outputs;
        const fresh = IslandScreen.added(_names, outputs);
        _names = Object.keys(outputs);
        // Unplugged while asked or before its Undo ran out: nothing left to choose, and the other screens stay on.
        if (phase && !outputs[output]) {
            pendingOff = [];
            finish();
        }
        if (!fresh.length || !enabled || !CompositorService.isNiri || CompositorService.getFocusedScreen()?.name !== screenName)
            return;
        plugged(fresh[0], outputs);
    }

    function plugged(name, outputs) {
        if (!controller.bubblesEnabled)
            return;
        output = name;
        label = IslandScreen.label(outputs[name], name);
        key = IslandScreen.key(outputs[name], name);
        before = JSON.parse(JSON.stringify(outputs));
        const kept = SessionData.islandScreenChoices[key];
        if (IslandScreen.CHOICES.indexOf(kept) >= 0) {
            choice = kept;
            const steps = IslandScreen.actions(kept, name, outputs);
            send(steps.filter(s => s.action !== "Off"));
            pendingOff = steps.filter(s => s.action === "Off");
            phase = "applied";
        } else {
            choice = "extend";
            phase = "ask";
        }
        arrived();
        if (!onIsland && controller.machineBubbleKind !== "display")
            return reset();
        if (onIsland)
            controller.transientTimer.stop();
        else
            controller.machineBubbleTimer.stop();
        decide.restart();
    }

    // explicit: the person picked it, so it is kept for this monitor.
    function choose(next, explicit) {
        if (phase !== "ask")
            return;
        choice = next;
        if (explicit)
            SessionData.setIslandScreenChoice(key, next);
        send(IslandScreen.actions(next, output, before));
        finish();
    }

    function undo() {
        if (phase !== "applied")
            return;
        pendingOff = [];
        send(IslandScreen.restore(before));
        finish();
    }

    function finish() {
        reset();
        if (controller.machineBubbleKind === "display")
            controller.hideMachineBubble();
        if (onIsland)
            controller.finishTransient();
    }

    function reset() {
        decide.stop();
        const off = phase === "applied" ? pendingOff : [];
        pendingOff = [];
        phase = "";
        send(off);
    }

    // Hovering the bubble holds its wait.
    function hold(inside) {
        if (!phase)
            return;
        if (inside)
            decide.stop();
        else
            decide.restart();
    }

    // One step at a time through `niri msg output` (IslandScreen.command), so niri's answer is read: a refusal (its exit
    // code) stops the steps left and shows. The request socket (NiriService.send) sends on without reading the answer.
    function send(list, from) {
        const i = from ?? 0;
        if (i >= list.length)
            return;
        const command = IslandScreen.command(list[i]);
        if (!command)
            return send(list, i + 1);
        Proc.runCommand("island-screen-output", command, (output, exitCode) => {
            if (exitCode === 0)
                send(list, i + 1);
            else
                ToastService.showError(I18n.tr("Could not change the screen layout", "island screen bubble: niri did not take the request"));
        });
    }
}
