# Low battery of mice, keyboards and other devices

Status: working prototype

## What it does

- When the battery of a wireless mouse, keyboard, gamepad or headset (seen by UPower) goes under 15 %, a bubble appears. It appears again under 5 %.
- When the device starts charging, a "charging" bubble appears.
- The level gauge of the bubble blinks a few times when it appears or when its level moves. With reduced motion it stays lit.
- When the level climbs back to 20 %, both warnings are armed again.

## Why

- The thresholds and the 20 % re-arm are written in the code so a reading that jitters around 15/16 % does not warn again and again (comment in `IslandPeriph.js`).
- A device already charging when the shell starts stays quiet; a device already low still warns.

## How it is built

- Logic: [`Common/IslandPeriph.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandPeriph.js) decides what each UPower reading raises. A device's first reading only seeds its state. It also keeps the device type: UPower can call a mouse on a cable a "keyboard", so the type the same model reported through its receiver wins.
- Source: [`Modules/DIsland/IslandPeriphSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandPeriphSource.qml), machine side, kind `periph`. It follows each device's own change signals, with no polling. A device that appears after UPower's startup list is a plug.
- Blinking gauge: [`Modules/DIsland/IslandGaugeBlink.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandGaugeBlink.qml).
- Tests (pure logic): [`tests/island-periph.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-periph.test.mjs).

## Known limits

- It was never tried with a real device. The bubble, the card and the blinking were not captured, because UPower devices cannot be faked on the test bench. No screenshot exists.
- The blinking was not measured for cost.
- The QML files have no automated test.

## Images

No screenshot yet.

