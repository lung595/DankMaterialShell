# Shelf: cloud folders and drop zones

Status: working prototype

## What it does

- The shelf card has three drop zones: Convert, Share and Cloud. They stay hidden until you drag a file, then they rise.
- Drop a file on **Cloud** and the zone offers the synced folders you chose. Let go on one of them and the file is copied there. The shelf says "Copied to the cloud folder", the zone button flashes, and the zone closes like the other zones.
- If no cloud folder is set yet, the zone shows "Choose a folder...". The folder you pick is added to your list, then the file is copied into it.
- A "cloud folder" is a normal local folder that your own sync app keeps in step with the cloud. DMS only copies files into it. It has no account and no network access of its own.
- In the settings, a card "Shelf" lets you turn each zone on or off and change their order, and add, rename, change the icon of, or remove cloud folders. Removing a cloud folder only forgets it, the folder stays on the disk. This settings card is in Bar settings, Dot settings and the options of the island widget.
- The shelf card shows a note "Zones set in the settings" under the zones. It is a link to those settings.

## Why

- A file can go to the cloud with one drop, and DMS does not need to know any cloud service.
- A synced folder keeps the privacy choice with the user: the sync app decides what leaves the computer.
- The zones are a setting so each user can keep only the ones they use.

## How it is built

- The two settings are `islandShelfZones` (order and on/off of `convert`, `share`, `cloud`; an empty list means all three) and `islandShelfClouds` (a list of `{name, icon, path}`). They are declared in [`SettingsSpec.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/settings/SettingsSpec.js) and [`SettingsData.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/SettingsData.qml).
- `clouds()` in [`IslandShelf.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandShelf.js) keeps only absolute paths, counts `/a/` and `/a` as one folder (the first wins), and gives a default name and the `cloud` icon. It has tests in [`island-shelf.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-shelf.test.mjs).
- The zone logic (`zoneAct`, the folder picker, the copy and the message) is in [`IslandShelfSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandShelfSource.qml). The copy is the `copy` verb of [`island-shelf.sh`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/scripts/island-shelf.sh), which picks a free name and never overwrites.
- Zone names are in [`IslandShelfZones.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandShelfZones.qml). The settings card is [`IslandShelfCard.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/Settings/Widgets/IslandShelfCard.qml).

## Known limits

- The folder picker and the drag-to-reorder of zones in the settings were not captured on the test bench. The empty-Cloud state was not captured.
- If you turn every zone off, nothing tells you why the zones are gone.
- The mock-up settings page has more cloud options (keys `islandShelfCloudSpring`, `islandShelfCloudMode`, `islandShelfCloudAfter`). They have no behavior yet, see the settings mock-up page.

## Images

No screenshot yet.

