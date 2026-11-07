# Low battery of mice, keyboards and other devices

Status: working prototype

![A wireless mouse goes under 15 %, then starts charging](../media/faces-b-peripheral-battery/battery-low.gif)

*A wireless mouse goes under 15 %, then starts charging*

In one sentence: When a wireless mouse, keyboard, gamepad or headset goes under 15 %, and again under 5 %, a bubble shows the device and its level, and another one when it starts charging.

## What it does

- When the battery of a wireless mouse, keyboard, gamepad or headset (seen by UPower) goes under 15 %, a bubble appears. It appears again under 5 %.
- When the device starts charging, a "charging" bubble appears.
- The level gauge of the bubble blinks a few times when it appears or when its level moves. With reduced motion it stays lit.
- When the level climbs back to 20 %, both warnings are armed again.

## Try it

- Check out `island-prototype`, use a bar in the Island layout, and use a wireless device that UPower sees. The bubble comes when its battery goes under 15 %.
- Plug the device in to charge: a "charging" bubble shows.

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

A wireless mouse goes under 15 %, then starts charging.

![A wireless mouse goes under 15 %, then starts charging](../media/faces-b-peripheral-battery/battery-low.gif)

The low battery bubble of a mouse: device type and percent with the level gauge.

![The low battery bubble of a mouse: device type and percent with the level gauge](../media/faces-b-peripheral-battery/battery-low.png)
