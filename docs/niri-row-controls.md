# niri settings page: shared rows and the "Keep this change?" banner

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- Every setting is a row with an icon, a title, a tip on hover and, in Expert mode, its KDL key.
- A changed setting shows a "Modified" dot and a "Reset to default" button, placed just before the control.
- Some rows show a battery cost icon (high, some or light) with a tip. The list covers blur, shadows, animations and Alt-Tab previews.
- A "New" pill marks options that arrived with the running niri version, until the user has seen them. Settings that depend on a parent (for example ring width under the focus ring switch) fold under it.
- For settings that can cut off the keyboard or the screen, a "Keep this change?" banner floats at the top. It counts down 15 seconds and then reverts, unless the user presses Keep.
- Slider, choice (segmented), color swatches, tile and card components share the same look.

## Why

- The author asked for rows that are quiet and tidy: an icon plate, no lines between rows, a soft plate on hover.
- Choice groups use the normal DMS button group; this was his decision on 1/11.
- A wrong layout or mod key must never lock the user out, so risky changes come back by themselves.
- The "Try" button was removed on 1/11, so rows no longer have it.

## How it is built

- Components in [Components/](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Components/NiriRow.qml): `NiriRow`, `NiriRowActions`, `NiriSlider`, `NiriSeg`, `NiriSwatches` (DMS theme colors plus a picker), `NiriTile` and `NiriCard`.
- Rows read and write through [NiriPageService.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Services/NiriPageService.qml) with a `settingKey`, or through the DMS setting named in the section module.
- The battery cost list is fixed inside `NiriRow.qml`; a section never sets one.
- [NiriKeep.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Components/NiriKeep.qml) is the banner and [keep.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/keep.js) holds its rules (15 seconds, the value before the first unkept change).
- [news.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/news.js) lists which keys came with niri 25.11 and 26.04.

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- A style, the KDL drawer and an undo never start the Keep countdown. Only the section's own edits do.
- The cost icons exist for four settings only.

## Images

No screenshot yet.

