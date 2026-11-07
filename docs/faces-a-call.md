# Island call bubble

Status: working prototype

## What it does
- Shows a bubble on the apps side of the island while an app is in a call: the app's icon, how long the call lasts, and a badge when the microphone or the headset is muted.
- The call is found from PipeWire: an app that records the microphone and plays sound, or whose stream has the phone-call role. Discord is recognised by its stream name "WEBRTC VoiceEngine" and its binary.
- Click the bubble to open the card: app name, "Call in progress" or "Call · microphone off", and buttons Mute, Deafen and Go to call. A Hang up button shows only when the app offers a "Hang up" action in its notification.
- Mute and Deafen touch only the app's own PipeWire streams, never the system microphone or output. Deafen also cuts the app's microphone. Unmuting while deafened removes the deafen.
- The bubble leaves when the streams end. The cross on the bubble hides it until the next call.
- The call stays visible when Do Not Disturb is on.

## Why
- The author wanted to see and control a voice call (for example in Discord) without going back to the app window.
- Mute must act on the app only: the app's own mute button does not know about it, and the system microphone must stay untouched (decision recorded in the notes).
- The notes record that a call or a critical notification from an app that already has an activity is always shown, and the app's activity then becomes a bubble.
- The "stop screen sharing" button was removed from the call card on purpose (decision of 25 October).

## How it is built
- [`quickshell/Common/IslandCall.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCall.js): plain JavaScript logic that groups streams by app and separates inputs from outputs.
- [`quickshell/Modules/DIsland/IslandCallSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandCallSource.qml): the source (apps side, `call`). It reacts to PipeWire's node list only; the duration ticks once a second, only while a call is on. API for the card: `toggleMute()`, `toggleDeafen()`, `deafen()`, `undeafen()`, `hangUp()`, `goTo()`. The icon comes from the desktop entry found by the app's binary.
- [`quickshell/Modules/DIsland/Cards/BubbleCardCall.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardCall.qml) and [`quickshell/Modules/DIsland/Cards/BubbleCallGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCallGlyph.qml): the card and the badge glyph.
- [`quickshell/Modules/DIsland/IslandBarHost.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBarHost.qml) and [`quickshell/Modules/DIsland/IslandBubbles.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBubbles.qml): the source is created in the host and the card is registered in the bubbles.
- Tests: [`quickshell/tests/island-call.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-call.test.mjs) covers the JavaScript logic.

## Known limits
- No desktop API ends a call, and Discord's local RPC needs an approved client for voice control. So for Discord the card offers "Go to call" and not "Hang up".
- Only the pure JavaScript is unit tested. The source, the card and the host wiring are not.
- It was checked on a test bench with a private PipeWire and a simulated call (mute and deafen read back with `pw-dump`), not with a real call.
- No animation measurement was made.

## Images
No screenshot yet.

