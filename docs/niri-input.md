# niri settings page: input (keyboard, touchpad, mouse, cursor)

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- A Keyboard card: layouts (comma separated, for example `us,fr`), the shortcut that switches layout (Alt + Shift, Ctrl + Shift, Caps lock, Super + Space or custom), repeat delay and rate, Num Lock at startup, remember layout (globally or per window), and XKB options, variant, model and a keymap file.
- A new layout goes back after a countdown unless the user keeps it, so a wrong layout cannot lock the keyboard.
- A "Touchpad and mouse" card: tap to click, natural scrolling, focus follows mouse, pointer jumps to focus, pointer speed, acceleration profile (Flat or Adaptive), scroll speed, tap and drag, drag lock, disable while typing, disable with external mouse, click method (button areas or clickfinger), scroll method and middle click emulation.
- Mouse rows: natural scrolling, speed, acceleration, scroll speed, left-handed, scroll method and middle click emulation.
- A Cursor card: theme (with a preview image of the real cursor shapes), size, hide while typing and hide when idle.
- Several options are picture tiles instead of plain switches.

## Why

- The author decided that under niri there are no duplicate settings: Keyboard, Mouse and touchpad, and the cursor card live only on the niri page. The old tabs are hidden and leave a link.
- In his words (18/10 evening), the Input section of DMS should disappear under niri and be merged into the niri page.

## How it is built

- Cards: [InputKeyboardCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputKeyboardCard.qml), [InputTouchpadCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputTouchpadCard.qml), [InputMouseRows.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputMouseRows.qml), [InputCursorCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputCursorCard.qml), [InputCursorArt.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputCursorArt.qml), [InputTileArt.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputTileArt.qml) and [InputSliderControl.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputSliderControl.qml). The section is [InputSection.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/InputSection.qml).
- [input.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/sections/input.js): all options except "pointer jumps to focus" (`input.warp`) reuse existing DMS settings (`SettingsData`) that reach `dms/input.kdl` or `dms/cursor.kdl`. The page adds no second writer.
- The cursor preview reads the XCursor files of the theme, picks the best size, and builds a PNG in JavaScript (the code says QML cannot read local files with XMLHttpRequest, so one probe prints a file as base64).
- Risky keyboard changes use the "Keep this change?" banner (15 s).

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- The cursor preview code is long (a hand-made PNG encoder) and the notes list `input.js` at 324 lines, over the author's own 300 line rule.
- The page reads little-endian XCursor files only; the code says big-endian writers exist but none is installed on the test machine.

## Images

No screenshot yet.

