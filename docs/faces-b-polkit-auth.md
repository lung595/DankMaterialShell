# Authentication requests (polkit) in the island

Status: working prototype

## What it does

- A polkit request ("this app wants administrator rights") appears on the island instead of in a separate dialog.
- The island shows what the request waits for: a masked password field, a fingerprint scan, or a face scan.
- It has Authenticate and Cancel buttons, and Escape cancels.
- A failed attempt turns the face red and shakes it. A success shows a check for a moment, then the island lets go.
- The island is lifted over fullscreen windows while the request is shown (see the overlay layer page).
- If the island is off, locked, or not on the focused screen, the usual DMS dialog is used instead.

## Why

- The owner decided that polkit requests are lifted over fullscreen windows, so they can be answered at once (see the overlay layer page).
- The old dialog is kept as the fallback, so a request is still shown when the island is not available.
- The response goes straight to the polkit flow and is never stored or logged (comment in the source).

## How it is built

- Source: [`Modules/DIsland/IslandAuthSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandAuthSource.qml) claims the request before the dialog (`claim`, `begin`, `submit`, `cancel`, `finish`) and follows the flow signals (success, failure, cancel, response required, supplementary message). It has the states ask, busy, failed and success.
- Hook: [`Services/PolkitService.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/PolkitService.qml) has an `islandClaim` function. `DMSShell.qml` does not show the dialog when `PolkitService.islandClaim()` is true.
- Mode logic: [`Common/IslandAuth.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandAuth.js). `mode(responseRequired, supplementary)` gives password, fingerprint, face or wait. A response is asked for by the password prompt alone, because `pam_fprintd` and `howdy` only send info lines while they wait.
- Face: [`Modules/DIsland/IslandAuthActivity.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandAuthActivity.qml), activity id `dms:auth`.
- Tests (pure logic only): [`tests/island-auth.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-auth.test.mjs).

## Known limits

- It was never tried with a real polkit request (password, fingerprint or face). A request cannot be triggered on the test bench without touching the real session. No screenshot exists.
- The QML files, the hook and the host wiring have no automated test.
- The project's own review script flagged some files as longer than the 300-line guideline (`IslandBarHost.qml`, `DIsland.qml`, `DMSShell.qml`), a "failed" phase that stays after a biometric failure, and typing before the fingerprint reader answers. It was not checked whether the final code fixes them.

## Images

No screenshot yet.

