# niri settings page: shortcut list, guided add, packs and export

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- A side pane lists the shortcuts of the key or category picked on the drawn keyboard. Each row has Test, Edit and Delete.
- A row shows the keys and a tag for the origin (DMS file or `config.kdl`), "N do the same" when several keys run one action, and "Overridden by config" when a later file replaces it.
- "New shortcut" is a guided add without KDL. Step 1: open an app, a niri action, a DMS action or another action. Step 2: press the keys. A free key shows "Free"; a taken key shows who uses it. Saving over a DMS bind asks to replace it. A key from `config.kdl` cannot be replaced there, so the page asks for another key.
- Test runs the action once. A "More" menu offers: Packs, Export, Remove duplicates, Add default shortcuts, Cheatsheet, a "Show" filter (All, DMS, niri config), and "Unused" (greyed out, it needs usage information that niri does not give).
- Packs are ready-made sets: Vim HJKL, Arrows, GNOME-like and Hyprland-like. The keyboard previews a pack before it is applied, and the pack lists keys that change and keys kept in `config.kdl`.
- Remove duplicates removes the DMS copy of a key bound twice, with an Undo. Export saves an image of the shortcuts, one sheet by category. A first-time banner offers Setup: create the DMS binds file and add the include to the compositor config, and warns when config binds after the include may override DMS binds.

## Why

- The author wanted the old Keybinds tab features in a clearer form, with the shortcut list only shown on demand, and the list opened by search.
- He wanted a guided add that needs no KDL, with live conflict display.
- The buttons were cut to one visible "New"; the other tools moved to a menu (mock-up v4).

## How it is built

- [BindsPane.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsPane.qml), [BindsHead.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsHead.qml), [BindsRow.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsRow.qml), [BindsTag.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsTag.qml), [BindsEmpty.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsEmpty.qml), [BindsMenu.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsMenu.qml), [BindsAdd.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsAdd.qml), [BindsAddPick.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsAddPick.qml), [BindsPacks.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsPacks.qml), [BindsExport.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsExport.qml) and [BindsInclude.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsInclude.qml).
- [binds.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/binds.js) splits action text like KDL does, finds the program a spawn bind runs, and builds the `niri msg` arguments for Test.
- It uses the existing `KeybindsService` (the `dms keybinds` command line); there is no new writer. Saves and removals run one process at a time.

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- "Unused" is greyed out: the notes say niri does not report shortcut use.
- `dms keybinds set` cannot change a key that comes from `config.kdl`.
- The notes list "one search entry per action" and the "N do the same" tag as small follow-ups, and the cap of 40 in the guided add as something to report upstream only.
- `BindsPane.qml` is 351 lines (the notes say 318 after a later change), over the author's own 300 line rule.

## Images

No screenshot yet.

