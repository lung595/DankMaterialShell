# DankIsland: everything I built for DMS

DankIsland is the island widget of DankMaterialShell (DMS). These pages describe each feature I added to it, in open pull requests or in prototypes, and the niri settings page, with links to the code.
Each page says what the feature does, why, how it is built, its known limits and, when there is one, a screenshot.

## Foundation (closed PRs)

| Feature | Status | Page | Code |
|---|---|---|---|
| Island kit: motion rules and widgets | in [PR #4180](https://github.com/duxlabs-dev/dux-shell/pull/4180) (closed) | [socle-kit-widgets](docs/socle-kit-widgets.md) | [IslandKit.js](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Common/IslandKit.js) |
| Spring frame cadence (120 steps a second) | in [PR #4180](https://github.com/duxlabs-dev/dux-shell/pull/4180) (closed) | [socle-spring-frame-cadence](docs/socle-spring-frame-cadence.md) | [FrameCadence.js](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Common/FrameCadence.js) |
| Readable warning colour in light mode | in [PR #4180](https://github.com/duxlabs-dev/dux-shell/pull/4180) (closed) | [socle-light-warning-tone](docs/socle-light-warning-tone.md) | [Theme.qml](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Common/Theme.qml) |
| Island activities API for plugins | in [PR #4181](https://github.com/duxlabs-dev/dux-shell/pull/4181) (closed) | [socle-activities-api](docs/socle-activities-api.md) | [IslandActivities.js](https://github.com/lung595/DankMaterialShell/blob/island/2-api/quickshell/Common/IslandActivities.js) |
| Scripts on the island over IPC | in [PR #4181](https://github.com/duxlabs-dev/dux-shell/pull/4181) (closed) | [socle-activities-ipc](docs/socle-activities-ipc.md) | [DIsland.qml](https://github.com/lung595/DankMaterialShell/blob/island/2-api/quickshell/Modules/DIsland/DIsland.qml) |
| Loading indicator with your own shapes (dux-qml-common) | in [PR #42](https://github.com/duxlabs-dev/dux-qml-common/pull/42) of dux-qml-common (closed) | [socle-loading-indicator](docs/socle-loading-indicator.md) | [DLoadingIndicator.qml](https://github.com/lung595/dux-qml-common/blob/island/common/DCommon/Widgets/DLoadingIndicator.qml) |

## Bubbles

| Feature | Status | Page | Code |
|---|---|---|---|
| Arrival of infos | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-arrival](docs/bulles-arrival.md) | [IslandArrivalState.qml](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Modules/DIsland/IslandArrivalState.qml) |
| Wings and displaced bubbles | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-wings](docs/bulles-wings.md) | [IslandBarHost.qml](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Modules/DIsland/IslandBarHost.qml) |
| Bubble card | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-card](docs/bulles-card.md) | [IslandBubbles.qml](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Modules/DIsland/IslandBubbles.qml) |
| Tiles beside the launcher | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-tiles](docs/bulles-tiles.md) | [IslandBubbles.qml](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Modules/DIsland/IslandBubbles.qml) |
| Notifications as island activities | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-notifications](docs/bulles-notifications.md) | [IslandNotificationSource.qml](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Modules/DIsland/IslandNotificationSource.qml) |
| Plugin activities and system faces | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-plugins](docs/bulles-plugins.md) | [IslandActivityComponent.qml](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Modules/Plugins/IslandActivityComponent.qml) |
| Bubble and arrival settings | in [PR #4182](https://github.com/duxlabs-dev/dux-shell/pull/4182) (closed) | [bulles-settings](docs/bulles-settings.md) | [SettingsSpec.js](https://github.com/lung595/DankMaterialShell/blob/island/3-bubbles/quickshell/Common/settings/SettingsSpec.js) |

## Island faces

| Feature | Status | Page | Code |
|---|---|---|---|
| Island weather alert | working prototype | [faces-a-weather-alert](docs/faces-a-weather-alert.md) | [IslandWeather.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandWeather.js) |
| Island call bubble | working prototype | [faces-a-call](docs/faces-a-call.md) | [IslandCall.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCall.js) |
| Island camera bubble | working prototype | [faces-a-camera](docs/faces-a-camera.md) | [IslandCamera.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCamera.js) |
| Island copy bubble | working prototype | [faces-a-copy](docs/faces-a-copy.md) | [IslandCopy.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCopy.js) |
| Password manager copies: wipe and island bubble | working prototype | [faces-a-password-copy](docs/faces-a-password-copy.md) | [secret.go](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/clipboard/secret.go) |
| Island network bubbles: VPN dropped, incoming SSH, open Wi-Fi | working prototype | [faces-a-network](docs/faces-a-network.md) | [IslandVpn.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandVpn.js) |
| Island system faces and level bubbles | working prototype | [faces-a-system-faces](docs/faces-a-system-faces.md) | [IslandSystemSource.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandSystemSource.qml) |
| Island charge bubble and card | working prototype | [faces-a-charge-bubble](docs/faces-a-charge-bubble.md) | [IslandCharge.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCharge.js) |
| Island charge face (sea and odometer) | working prototype | [faces-a-charge-face](docs/faces-a-charge-face.md) | [BubbleChargeFace.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleChargeFace.qml) |
| Island keep awake bubble | working prototype | [faces-a-keep-awake](docs/faces-a-keep-awake.md) | [IslandKeepAwake.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandKeepAwake.js) |
| Island eye break | working prototype | [faces-a-eye-break](docs/faces-a-eye-break.md) | [EyeBreakService.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/EyeBreakService.qml) |
| One-time code (2FA) | working prototype | [faces-b-code-2fa](docs/faces-b-code-2fa.md) | [IslandCode2fa.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCode2fa.js) |
| Authentication requests (polkit) in the island | working prototype | [faces-b-polkit-auth](docs/faces-b-polkit-auth.md) | [IslandAuthSource.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandAuthSource.qml) |
| Island over fullscreen windows | working prototype | [faces-b-overlay-layer](docs/faces-b-overlay-layer.md) | [IslandLayer.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandLayer.js) |
| Downloads, received files and progress | working prototype | [faces-b-downloads](docs/faces-b-downloads.md) | [DownloadService.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/DownloadService.qml) |
| Transfers (copies, archives, torrents, downloads) | working prototype | [faces-b-transfers](docs/faces-b-transfers.md) | [handlers.go](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/transfers/handlers.go) |
| Low disk space bubble and disk explorer | working prototype | [faces-b-disk-space](docs/faces-b-disk-space.md) | [DiskSpaceService.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/DiskSpaceService.qml) |
| USB drive bubble | working prototype | [faces-b-usb-drive](docs/faces-b-usb-drive.md) | [IslandUsb.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandUsb.js) |
| Printing bubble | working prototype | [faces-b-print](docs/faces-b-print.md) | [IslandPrint.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandPrint.js) |
| New screen plugged in | working prototype | [faces-b-screen-layout](docs/faces-b-screen-layout.md) | [IslandScreen.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandScreen.js) |
| Low battery of mice, keyboards and other devices | working prototype | [faces-b-peripheral-battery](docs/faces-b-peripheral-battery.md) | [IslandPeriph.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandPeriph.js) |
| Trash bubble with Undo | working prototype | [faces-b-trash-undo](docs/faces-b-trash-undo.md) | [IslandTrash.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandTrash.js) |
| App events: crash, reopen and urgent window | working prototype | [faces-b-app-events](docs/faces-b-app-events.md) | [AppCrashService.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/AppCrashService.qml) |

## Shelf and settings

| Feature | Status | Page | Code |
|---|---|---|---|
| Shelf: drop files and keep them | working prototype | [etagere-drop-and-keep](docs/etagere-drop-and-keep.md) | [IslandShelfDrop.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandShelfDrop.qml) |
| Shelf: find a file | working prototype | [etagere-find](docs/etagere-find.md) | [IslandShelf.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandShelf.js) |
| Shelf: open and preview a file | working prototype | [etagere-open-preview](docs/etagere-open-preview.md) | [IslandShelfSource.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandShelfSource.qml) |
| Shelf: send, move, act on and remove files | working prototype | [etagere-send-remove](docs/etagere-send-remove.md) | [island-shelf.sh](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/scripts/island-shelf.sh) |
| Shelf: cloud folders and drop zones | working prototype | [etagere-cloud](docs/etagere-cloud.md) | [SettingsSpec.js](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/settings/SettingsSpec.js) |
| Shelf: shortcut, keyboard and launcher | working prototype | [etagere-keyboard](docs/etagere-keyboard.md) | [DIsland.qml](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/DIsland.qml) |
| Island settings page (mock-up) | mock-up | [etagere-settings-mockup](docs/etagere-settings-mockup.md) | [SettingsTabs.qml](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Common/SettingsTabs.qml) |

## niri settings page

The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.

| Feature | Status | Page | Code |
|---|---|---|---|
| niri settings page: shell and layout | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-page-shell](docs/niri-page-shell.md) | [NiriTab.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/NiriTab.qml) |
| niri settings page: safe config writing | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-safe-config-writing](docs/niri-safe-config-writing.md) | [store.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/store.go) |
| niri settings page: KDL drawer | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-kdl-drawer](docs/niri-kdl-drawer.md) | [NiriKdlDrawer.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Drawer/NiriKdlDrawer.qml) |
| niri settings page: health popover and config doctor | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-health-doctor](docs/niri-health-doctor.md) | [doctor.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/doctor.go) |
| niri settings page: Styles (presets and profiles) | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-styles](docs/niri-styles.md) | [NiriStylesPopup.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Shell/NiriStylesPopup.qml) |
| niri settings page: shared rows and the "Keep this change?" banner | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-row-controls](docs/niri-row-controls.md) | [NiriRow.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Components/NiriRow.qml) |
| niri settings page: search by words or by keys | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-search](docs/niri-search.md) | [search.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/search.js) |
| niri settings page: window look (gaps, ring, border, corners, shadow, blur) | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-windows-look](docs/niri-windows-look.md) | [LookCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Windows/LookCard.qml) |
| niri settings page: columns, overview and Alt-Tab | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-windows-columns](docs/niri-windows-columns.md) | [ColumnsCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Windows/ColumnsCard.qml) |
| niri settings page: Super+R fills the remaining space | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-super-r-cycle](docs/niri-super-r-cycle.md) | [NiriColumnCycle.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Services/NiriColumnCycle.qml) |
| niri settings page: window rules | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-window-rules](docs/niri-window-rules.md) | [RulesCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Windows/RulesCard.qml) |
| niri settings page: animations | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-animations](docs/niri-animations.md) | [AnimationsSection.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/AnimationsSection.qml) |
| niri settings page: workspaces board, names and bulk actions | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-workspaces-board](docs/niri-workspaces-board.md) | [BoardCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Workspaces/BoardCard.qml) |
| niri settings page: close a whole workspace | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-close-workspace](docs/niri-close-workspace.md) | [NiriWorkspaceActions.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Services/NiriWorkspaceActions.qml) |
| niri settings page: session and startup environment | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-session-startup](docs/niri-session-startup.md) | [SessionCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Workspaces/SessionCard.qml) |
| niri settings page: drawn keyboard for shortcuts | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-keybinds-keyboard](docs/niri-keybinds-keyboard.md) | [KeyboardCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/KeyboardCard.qml) |
| niri settings page: shortcut list, guided add, packs and export | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-keybinds-list](docs/niri-keybinds-list.md) | [BindsPane.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Keybinds/BindsPane.qml) |
| niri settings page: add the missing default binds | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-default-binds](docs/niri-default-binds.md) | [niri_defaults.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/keybinds/providers/niri_defaults.go) |
| niri settings page: input (keyboard, touchpad, mouse, cursor) | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-input](docs/niri-input.md) | [InputKeyboardCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Input/InputKeyboardCard.qml) |
| niri settings page: gestures | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-gestures](docs/niri-gestures.md) | [GesturesSection.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/GesturesSection.qml) |
| niri settings page: hot corners | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-hot-corners](docs/niri-hot-corners.md) | [CornersCard.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/Gestures/CornersCard.qml) |
| niri settings page: Advanced section | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-advanced](docs/niri-advanced.md) | [AdvancedSection.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Sections/AdvancedSection.qml) |
| niri settings page: logo on the Super key | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-super-key-logo](docs/niri-super-key-logo.md) | [SuperKeyLogo.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Niri/Keys/SuperKeyLogo.qml) |
| niri settings page: one place for each setting, and ways to reach the page | in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063) | [niri-settings-links](docs/niri-settings-links.md) | [SettingsNiriLink.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Modules/Settings/Widgets/SettingsNiriLink.qml) |

## Reference branches

- [island/1-kit](https://github.com/lung595/DankMaterialShell/tree/island/1-kit): The code of PR #4180, with the island kit (motion rules, spring frame cadence, widgets) and the readable warning colour in light mode.
- [island/2-api](https://github.com/lung595/DankMaterialShell/tree/island/2-api): The code of PR #4181, with the island activities API for plugins and the IPC calls for scripts.
- [island/3-bubbles](https://github.com/lung595/DankMaterialShell/tree/island/3-bubbles): The code of PR #4182, with the arrival of infos, wings and bubbles, the bubble card, tiles, notifications, plugin activities and their settings.
- [island-prototype](https://github.com/lung595/DankMaterialShell/tree/island-prototype): The whole island as a working prototype, not in a PR, with every island face and the shelf.
- [island-settings-mockup](https://github.com/lung595/DankMaterialShell/tree/island-settings-mockup): The island settings page mock-up, not in a PR.
- [page-niri-pr](https://github.com/lung595/DankMaterialShell/tree/page-niri-pr): The code of PR #4063, with the niri settings page.
- [dux-qml-common island/common](https://github.com/lung595/dux-qml-common/tree/island/common): The code of PR #42 of dux-qml-common, with the loading indicator that takes the caller's own shapes.

