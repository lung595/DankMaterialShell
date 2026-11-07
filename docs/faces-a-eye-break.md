# Island eye break

Status: working prototype

## What it does
- Every so often, it asks you to rest your eyes (the 20-20-20 idea: look far away for a few seconds). It is off by default.
- If the island is free, the island takes the break: an eye, the text "Look far away" and a countdown (for example 0:19). A click skips the break.
- If the island is busy, or becomes busy during the break, the break goes to a bubble on the left (kind `eyes`). The card has a "Skip" button and the text "Look at something far away until the end". The bubble is shown again at each second tick.
- The break never starts over a fullscreen window, nor while the microphone, the camera or a screen share is in use (a call). It then waits one more interval.
- It stops while the session is locked.
- In the island settings (Bubbles card): a switch "Eye breaks", a slider "Break every" (5 to 120 minutes, default 20) and a slider for the break length (10 to 120 seconds, default 20).

## Why
- The author wanted a gentle reminder to rest the eyes that follows the island's rules: the free island takes the event, a busy island gives it to a bubble.
- It must not disturb a call or a fullscreen window.
- It is off by default (the table of bubbles says "off by default").
- The face has no button, because it is not urgent. The Skip button lives on the bubble.

## How it is built
- [`quickshell/Services/EyeBreakService.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/EyeBreakService.qml): the service. One timer, stopped while off or locked. It waits the interval, then ticks each second through the break. It uses the privacy service to watch the streams, only while someone holds a reference.
- [`quickshell/Common/IslandEyes.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandEyes.js): plain JavaScript. The setting bounds, the rules for deferring (`deferred`) and for choosing where the break shows (`route`: island or bubble). An island is free when it is not expanded, shows no active notification or system activity, and shows no plugin except the resting shelf.
- [`quickshell/Modules/DIsland/IslandEyesActivity.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandEyesActivity.qml): the island face (activity `dms:eyes`).
- [`quickshell/Modules/DIsland/Cards/BubbleCardEyes.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardEyes.qml) and [`quickshell/Modules/DIsland/Cards/EyeBreakGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/EyeBreakGlyph.qml): the card and the animated eye (a frame animation drawn in the glyph itself).
- Settings `islandEyeBreak`, `islandEyeBreakInterval` and `islandEyeBreakDuration` in [`quickshell/Common/settings/SettingsSpec.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/settings/SettingsSpec.js); the controls are in [`quickshell/Modules/Settings/Widgets/IslandBubblesCard.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/Settings/Widgets/IslandBubblesCard.qml).
- Tests: [`quickshell/tests/island-eyes.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-eyes.test.mjs) covers the JavaScript logic, including the shelf rule.

## Known limits
- There is no command to start a break, so on a test bench it was only seen by waiting for a real one (interval 5 minutes, length 20 seconds). The island face was captured in that way. The bubble (island busy), the card, the settings and the deferral during a call or fullscreen were not captured.
- Only the pure JavaScript is unit tested. The service, the timer, the island face, the card and the glyph are not.
- The eye glyph uses its own frame animation, outside the island kit. A reviewer counted this as a debt. Its cost was not measured.

## Images
No screenshot yet.

