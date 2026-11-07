# Island settings page (mock-up)

Status: mock-up

## What it does

- A new entry "Island" in the settings sidebar, just after Bar widgets. It opens a hub like the Dock hub, with eleven pages: General, Home, Behavior, Bubbles, Each bubble (a sub-page), Notifications, Shelf, Appearance, Motion, Plugins and Advanced.
- The hub adapts to where the island lives: a bar in Island layout (8 pages plus Plugins and Advanced), an Island widget in a normal bar (7 pages plus Plugins), or the floating Dot (6 pages plus Plugins).
- The island cards that used to sit in Bar > General, Bar > Appearance, Bar widgets > Island and Bar > Dot are sorted by theme into these pages. 93 existing settings were moved, none were lost, and all still use their old keys.
- "Each bubble" is a table of 41 bubbles (18 system, 16 apps, 7 alerts). A chip filter picks System, Apps, Alerts or "Allowed in Do Not Disturb". An editor sets side, lifetime, importance, sound and Do Not Disturb for each bubble.
- New rows (13 new keys): a shape under the logo, a time scale for each bubble family, an app filter and a privacy option for notifications, and quiet hours that can follow Do Not Disturb.
- The Shelf page has 11 cards and 70 settings: Look, Arrivals, Keeping, Inputs, Drop zones, Cloud folders, Share (KDE Connect, LocalSend, default device), Shortcuts, Privacy, Accessibility and Screens. Each row reads and writes its own `islandShelf*` key.

## Why

- Five island cards were pasted into four different settings pages. The mock-up puts them in one place, sorted by theme.
- The owner asked for a shelf settings page that lists everything an end user could change, so he can decide what is worth building.
- The page uses only DMS settings components, so it looks like the rest of DMS.

## How it is built

- The sidebar entry is in [`SettingsTabs.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Common/SettingsTabs.qml). The hub is [`IslandHubHeader.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/IslandHubHeader.qml), with a small link card [`IslandHubLink.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/Widgets/IslandHubLink.qml) on the host pages.
- Each page is one `Island<Name>Tab.qml` in `quickshell/Modules/Settings/`, for example [`IslandShelfTab.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/IslandShelfTab.qml), [`IslandBubbleTableTab.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/IslandBubbleTableTab.qml) and [`IslandMotionTab.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/IslandMotionTab.qml). The shelf cards are `IslandShelf*Card.qml` in `Widgets/`, for example [`IslandShelfLookCard.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/Widgets/IslandShelfLookCard.qml) and [`IslandShelfCloudCard.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/Widgets/IslandShelfCloudCard.qml).
- Island settings are read and written by [`IslandSettingsStore.qml`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Modules/Settings/Widgets/IslandSettingsStore.qml). The new keys and their defaults are at the end of `ISLAND_DEFAULTS` in [`BarWidgetDefaults.js`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Common/settings/BarWidgetDefaults.js). The 58 new shelf keys are in [`SettingsSpec.js`](https://github.com/lung595/DankMaterialShell/blob/island-settings-mockup/quickshell/Common/settings/SettingsSpec.js).
- The settings search index (`settings_search_index.json`) was regenerated for the new rows.
- Every new file is under 300 lines.

## Known limits

- It is a mock-up. The 13 island keys and the 58 shelf keys are saved but nothing reads them yet. Only the shelf zones, the cloud folders and the shelf grouping already work (see the cloud and find pages).
- It was checked on a bench without a screen, in a window of 1280 x 800. Keyboard use and screen readers were not tried. The style with square corners was not looked at.
- The style check at the last full round gave 91 out of 100. Two wording fixes were left: a wrong hint on the widget host row ("Show in bar, placement, background") and two English phrases ("goes from one info to the next", "As the theme").
- The translation catalog (`en.json`, `template.json`) was not updated. The new strings enter it with the next full extraction.
- The search can point at a row that is hidden for the chosen host, for example "bluetooth" finds a hidden Status row in the Island layout.
- The link to "Each bubble" is at the bottom of the Bubbles page, below the fold when Eye breaks is on. The Do Not Disturb checkbox column has no header.
- The branch was cut from an older base and still has to be rebased.

## Images

No screenshot yet.

