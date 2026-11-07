# niri settings page: session and startup environment

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- A "Session" card (in Workspaces) can reopen programs at login, each on its own workspace and screen.
- The user adds a program, picks its workspace and screen, or removes it. "Save open windows" fills the list from what is open now. "Clear" empties it.
- The card shows how many programs are in the session. It tells that a change counts at the next login.
- The Startup section (Expert mode only) has an Environment list: variables in the form NAME=value. Programs see a change after the next login.
- The apps that start at login are still managed in Applications, Autostart. The page shows a link to it.

## Why

- The author wanted programs per workspace and screen restored at start, and an environment list.
- Autostart apps stay in the existing Applications tab, so the page keeps only the placement and the environment.

## How it is built

- [SessionCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Workspaces/SessionCard.qml) and [SessionOutput.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Workspaces/SessionOutput.qml). The Startup section is [StartupSection.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/StartupSection.qml).
- [session.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/sections/session.js) keeps `session.on` and `session.apps` (`appId`, `command`, `workspace`, `output`) and writes a `spawn-at-startup` line plus a `window-rule` (match by app ID, `at-startup=true`) with `open-on-workspace` or `open-on-output`. [startup.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/sections/startup.js) keeps `startup.env`.
- The doctor warns when a program starts twice, from Autostart and from this page ([autostart.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/autostart.go)).

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- niri matches startup rules by app ID only, so one app can have one place.
- The variable name is written bare into KDL, so the page only accepts letters, digits and `_` in it.

## Images

No screenshot yet.

