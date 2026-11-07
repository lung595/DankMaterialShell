# Password manager copies: wipe and island bubble

Status: working prototype

## What it does
- When a password manager copies a secret (it sets the `x-kde-passwordManagerHint` hint), the island shows a "password copied" bubble. It shows the manager's icon (a padlock if unknown) inside a ring that empties over 30 seconds. It never shows the copied text.
- After 30 seconds the clipboard is emptied, but only if it still holds that same copy. The entry in the clipboard history is removed at the deadline, unless it is pinned.
- A click on the bubble clears the clipboard now.
- If the user copies something else from another application, the wipe is cancelled. A second marked copy pushes the deadline.
- The deadline survives a restart of the shell.
- The bubble is hidden while the screen is shared. If the free island can take it, it plays there first.

## Why
- A password must not stay in the clipboard or in the history (rule written on 24 October: a code or a password must not linger).
- What the user copies on their own is never wiped; only secrets from a password manager, or secrets the island itself helped to copy.
- The wipe timer lives in the Go core so it survives a restart of the shell.

## How it is built
- [`core/internal/server/clipboard/secret.go`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/clipboard/secret.go): the wipe. It keeps only a SHA-256 fingerprint and the deadline in the database, so a restart still wipes the history. `secretWipeAfter` is 30 seconds. `CopySecret` copies a text and arms the wipe.
- [`core/internal/server/clipboard/manager.go`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/clipboard/manager.go) and [`core/internal/server/clipboard/handlers.go`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/clipboard/handlers.go): the hint is detected and counted, and a new request `clipboard.clearSecret` empties the clipboard now if it still holds a password manager copy. New fields are added to the clipboard state.
- [`core/internal/server/clipboard/secret_test.go`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/clipboard/secret_test.go): Go tests (the secret is counted; wipe only if it is still there; history; pinned entry; restart; the user's own copy; cancel).
- [`quickshell/Modules/DIsland/IslandPasswordSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandPasswordSource.qml): the source (apps side, `password`). It reacts to the DMS clipboard state only; the countdown runs only while a copy is held and only while the bubble shows. The 30 seconds come from `secretWipeMs` in [`quickshell/Common/IslandActivities.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandActivities.js).
- [`quickshell/Common/IslandPassword.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandPassword.js) and [`quickshell/Modules/DIsland/Cards/BubblePasswordGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubblePasswordGlyph.qml): the logic and the ring glyph.
- Tests: [`quickshell/tests/island-password.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-password.test.mjs).

## Known limits
- On the test bench, a real marked copy reached the clipboard but no bubble appeared in two tries, and the cause was not found. So the bubble was not seen working end to end, and there is no capture.
- The Go tests passed in the project's test gate with Go 1.27.1. Running `go test` directly with the local Go (1.26.10) was refused, because `go.mod` asks for 1.27.3 or newer.
- Only the pure JavaScript and the Go package are tested. The QML source and the glyph are not.
- This feature changes the Go core as well as the shell, so it is the one face in this group that needs a change in `core/`.

## Images
No screenshot yet.

