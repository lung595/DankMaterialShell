# New screen plugged in

Status: working prototype

## What it does

- When a new monitor is plugged in (niri), a "display" bubble offers three layouts: Extend, Duplicate, Only this one.
- If nobody chooses, Extend is applied by itself after three times the Undo delay. A countdown shows this.
- Once a layout is applied, the face shows it with an Undo button until the Undo delay ends. Undo restores the outputs as they were before.
- The choice can be kept for that monitor ("Kept for this screen"). The next time the same monitor is plugged, the kept choice is applied, with Undo available.
- Only the focused screen's island answers.

## Why

- The choice is offered on the island right when the monitor appears, and a choice made for a monitor is remembered (comments in the source).
- Undo and the delayed "turn off the others" exist because turning off the focused screen would remove the bar that carries the bubble and its Undo (comment in the source).

## How it is built

- Logic: [`Common/IslandScreen.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandScreen.js) finds which output just appeared (the first fill is the boot, not a plug), builds a key for the monitor (make, model and serial, else the port name), and builds the niri `Output` actions (On, Off, Position) to apply or undo a choice.
- Source: [`Modules/DIsland/IslandScreenSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandScreenSource.qml), machine side, kind `display`. It reacts to `NiriService.outputs` only. With "only this one", the `Off` actions wait in `pendingOff` until the Undo delay is over.
- Card: [`Cards/BubbleCardScreen.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardScreen.qml): three chips, an Extend button with a draining liquid.
- Kept choices: the `islandScreenChoices` setting (`SessionData.qml`, `Common/settings/SessionSpec.js`).
- Tests (pure logic): [`tests/island-screen.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-screen.test.mjs).

## Known limits

- niri has no output mirroring, so "Duplicate" moves the new output to the position of the reference output (a `shortcut:` comment in `IslandScreen.js`). It is not a true mirror.
- It was never tried with a real monitor, and nothing was captured, because a new output comes from real niri and cannot be reproduced on the test bench.
- A review found that with a kept "only" choice, turning off the focused screen removed the Undo. The code now delays the `Off` actions, but this was read and not replayed.
- Whether the internal screen comes back if niri does not turn it on again was not checked.

## Images

No screenshot yet.

