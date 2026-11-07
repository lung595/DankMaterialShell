# Island camera bubble

Status: working prototype

## What it does
- Shows a bubble on the apps side of the island while an app uses the camera: the app's logo on the flat pill and a green dot while it films. If the logo is missing, a camera icon is used.
- Screen sharing is not counted as a camera.
- Click the bubble to open a card with the app name (or the names, separated by commas, if several apps film) and the detail "Camera". The card has a "Go to app" button when the app has a window.
- Right click hides the bubble until an app starts filming again.
- When the camera stops, the bubble goes and the card closes. An app that loses its stream for less than 3 seconds (a renegotiation) does not play the arrival again and does not lift a hidden state.
- The bubble is not shown when the island already shows the camera activity.

## Why
- The author wanted a visible sign that the camera is on, in the same place and style as the other app bubbles.
- The notes ask for the app's logo on the flat pill with a green dot, and no count on the pill (the "+N" was removed on 24 October); the card names every app that films.
- The bubble ranks ahead of the other app bubbles, after a call, because the camera is on the user.

## How it is built
- [`quickshell/Common/IslandCamera.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCamera.js): plain JavaScript logic. It finds the apps that film (an input video stream linked to a `Video/Source`, without the Screen role), makes a key per app, and handles the 3-second grace delay.
- [`quickshell/Modules/DIsland/IslandCameraSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandCameraSource.qml): the source (apps side, `camera`). It reads PipeWire nodes and links only, with no polling, like the microphone privacy indicator. It binds the video streams so their app properties arrive.
- [`quickshell/Modules/DIsland/Cards/BubbleCardCamera.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardCamera.qml) and [`quickshell/Modules/DIsland/Cards/BubbleCameraGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCameraGlyph.qml): the card and the logo with the green dot.
- [`quickshell/Modules/DIsland/IslandBarHost.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBarHost.qml) and [`quickshell/Modules/DIsland/IslandBubbles.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBubbles.qml): the wiring (bubble list, click, right click, card).
- Tests: [`quickshell/tests/island-camera.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-camera.test.mjs) covers the JavaScript logic.

## Known limits
- Only simulated on a test bench (a private PipeWire with a fake video source and a fake app), not with real camera hardware or a real video call.
- The arrival logic in QML has no test; only the JavaScript logic does.
- A first review of the first branch scored it 58 out of 100 and asked for corrections (the "+N" count, duplicated code with the call source, magic numbers such as the rank 1.9e6). Some were fixed. The fixes were not reviewed a second time.
- The "Go to app" button disappears when the app has no window, without any explanation.
- No animation measurement was made.

## Images
No screenshot yet.

