# niri settings page: one place for each setting, and ways to reach the page

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- Under niri, the old Settings tabs whose settings now live on the niri page are hidden: Keybinds, Keyboard, Mouse and touchpad, and Window rules.
- Where niri-only settings used to be, a row "Set in niri" opens the niri page on the right section. Such rows exist in Compositor layout, Displays (niri output settings), Keybinds, Keyboard, Mouse and touchpad, Wallpaper and colors (cursor), and Window rules.
- The IPC call `settings openWith niri` opens the niri page. `SettingsUiState.niriSection` picks the section.
- Right click on a workspace in the bar opens a small menu under niri. The menu keeps the old action and adds a way to open the niri page on its Workspaces section. Other compositors keep the direct action.
- Hyprland and Mango are not changed.

## Why

- The author decided on 18/10 that there are no duplicate settings: under niri, a setting that touches niri lives only on the niri page, and the old place has a link.
- Per-screen settings (columns, gaps, hot corners per output) stay in Displays. This was decided on 18/10 in the evening.
- The right click menu was validated as it is (Overview and Niri settings).

## How it is built

- [SettingsNiriLink.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Widgets/SettingsNiriLink.qml) is the link row. It is used in [CompositorLayoutTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/CompositorLayoutTab.qml), [NiriOutputSettings.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/DisplayConfig/NiriOutputSettings.qml), [KeybindsTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/KeybindsTab.qml), [KeyboardTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/KeyboardTab.qml), [MouseTouchpadTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/MouseTouchpadTab.qml), [WallpaperColorsTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/WallpaperColorsTab.qml) and [WindowRulesTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/WindowRulesTab.qml).
- [SettingsTabs.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/SettingsTabs.qml) has the flags `niriOnly` (the niri tab) and `hiddenOnNiri`, and `niriSection` for the target section. Search entries of hidden tabs lead to the niri page.
- [DMSShellIPC.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/DMSShellIPC.qml) has `openWith` for the niri section.
- [WorkspaceSwitcher.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/DBar/Widgets/WorkspaceSwitcher.qml) has the context menu (`openContextMenu`, `openNiriWorkspaces`).

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- The notes (1/11) say upstream maintainers asked why the page does not just fill the gaps of the existing pages. This is the main design question of the pull request, and the author offered two options: a smaller tab with the existing cards put back, or no tab at all.
- The page and the old tabs share the same DMS settings, so the link rows only move where the user changes them.

## Images

No screenshot yet.

