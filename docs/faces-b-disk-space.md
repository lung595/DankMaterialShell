# Low disk space bubble and disk explorer

Status: working prototype

## What it does

- When a disk has less than 10 % free space, a "Disk almost full" bubble appears. It shows the free share and the free size. A liquid level shows the used share and turns to the alert tone as the disk fills.
- The bubble opens a card that scans the folder and shows it as a treemap (default), as rings, or as a list of the largest files.
- The card has a breadcrumb to go back up, the scan time and file count, the size and share of the current folder, and keyboard keys: arrows to move, Enter to open, Backspace to go up, Del to trash.
- A "Free up space" row lists what each cleanup suggestion would free. Actions: Trash (with Undo), Open, and Shelf (send a file to the island shelf).
- Trashing never deletes: files go to the trash and can be restored. Emptying the trash and the tools' own prune are separate actions; cleaning is done by holding a button.

## Why

- The bubble is raised once each time a mount drops under the threshold, and the card is the place to see where the space went (comments in `IslandDiskSource.qml`). The charts are ported from the web disk mock-up (comment in `DiskChart.js`).
- Only `/` and the home folder are scanned, so no user path is typed or shown (comment in the card).

## How it is built

- Watch: [`Services/DiskSpaceService.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/DiskSpaceService.qml) runs `df` at start, when the mount list changes (`DgopService`), and at most every 30 minutes. Under `lowThreshold` (0.1) it sets `lowFolder`. A disk stays "low" until its free share reaches 1.2 times the threshold, so it does not flap.
- Bubble: [`Modules/DIsland/IslandDiskSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandDiskSource.qml) raises the bubble each time a mount drops under the threshold. The island's own "disk" face is used first, then the machine bubble.
- Scan: [`Services/DiskUsageService.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/DiskUsageService.qml) gets the used space from statfs at once, then runs four `du -0abx` readers for the tree. Pure logic: [`Common/DiskUsage.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/DiskUsage.js).
- Charts: [`Common/DiskChart.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/DiskChart.js) lays out the treemap and the rings and finds what the pointer or arrow keys point at.
- Cleanup: [`Services/DiskCleanupService.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Services/DiskCleanupService.qml) and [`Common/DiskCleanup.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/DiskCleanup.js) measure what each suggestion frees, move to the trash with Undo, empty the trash, and call the tools' prune. Nothing goes to the network.
- Card: [`Cards/BubbleCardDisk.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardDisk.qml), with parts such as `DiskChartView`, `DiskCrumbs`, `DiskLargestList`, `DiskCleanupPanel`, `DiskCardKeys` in the same folder.
- Tests (pure logic): [`tests/island-disk.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-disk.test.mjs), [`tests/island-disk-explore.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-disk-explore.test.mjs).

## Known limits

- It was never tried on a disk that is really almost full. On the test bench a fake `df` and a temporary copy with a changed threshold were used. The card was captured only once opened; the Rings and Largest views, keyboard use, trash and Undo, Shelf, and the Canvas drag were not captured.
- The card has a Canvas that repaints while dragging. Its smoothness was not measured.
- A review note says the size and the number of lines of the first version were above the project's guideline.
- Real `du` scans and real cleanups on real folders were not tried.

## Images

No screenshot yet.

