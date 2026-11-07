# niri settings page: Styles (presets and profiles)

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- A "Styles" button in the header opens a popover.
- It offers four presets: Compact, niri default, Comfortable and Focus.
- The user can save the current look as a named profile, apply it later, or delete it.
- A style can be exported to a file and imported from a file. An imported style is shown before it is applied.
- A style only sets a few look keys: gaps, focus ring on and width, border on and width, corner radius, shadow, how the focused column is centered, and the animation slowdown.

## Why

- The author wanted presets and saved profiles in one click, and import and export.
- A style never carries custom KDL or other settings, so a shared file cannot run anything.

## How it is built

- [NiriStylesPopup.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Shell/NiriStylesPopup.qml) is the popover. [NiriStylesThumb.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Shell/NiriStylesThumb.qml) draws a style as three columns. [NiriStylesTransfer.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Shell/NiriStylesTransfer.qml) does import and export.
- [presets.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/presets.js) lists the presets and the allowed keys, and has `snapshot`, `parseStyle` and `exportStyle`. A name is at most 40 characters and an imported file at most 65536 bytes.
- Profiles are stored in the page state under the key `styles.profiles`.

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- The popover says "Hover to preview", and a hovered style sets `SettingsUiState.niriPreviewState`. A search of the branch found no drawn desktop that reads that value, so the hover preview is not visible today.
- Profiles that react to plugged screens or battery were postponed outside this page (notes, 18/10).

## Images

No screenshot yet.

