# Trash bubble with Undo

Status: working prototype

![The trash bubble: file name and an Undo button](../media/faces-b-trash-undo/trash.png)

*The trash bubble: file name and an Undo button*

In one sentence: When a file goes to the trash, from DMS, a file manager or a terminal, the island shows its name with an Undo button while a ring drains.

## What it does

- When a file goes to the home trash, the island shows its name, with an Undo button. If several files go at once, the text shows the first name and how many more.
- A ring (or the liquid on the card) drains during the Undo time. Hovering pauses the time. Undo puts the files back.
- It does not matter who trashed the file: DMS, a file manager, or `gio trash`.
- Deletions made by the disk card are not announced twice; the disk card shows its own Undo.
- Restoring or emptying the trash does not raise the bubble.
- On the card, a page falls into the trash icon.

## Try it

- Check out `island-prototype`, use a bar in the Island layout, and run `gio trash some-file.txt`, or delete a file in a file manager.
- Press Undo before the ring empties: the file goes back. Hovering pauses the time.

## Why

- The bubble offers Undo for one Undo window, whoever trashed the file (comment in `IslandTrashSource.qml`).
- The source watches the trash folder through the file system, so it needs no polling.

## How it is built

- Logic: [`Common/IslandTrash.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandTrash.js). A name not seen before in `Trash/info` is a new deletion. The first listing only seeds.
- Source: [`Modules/DIsland/IslandTrashSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandTrashSource.qml) watches `$XDG_DATA_HOME/Trash/info` (default `~/.local/share/Trash/info`) and counts `DiskCleanupService.quietTrash` per screen to skip the disk card's own deletions.
- Card: [`Cards/BubbleCardTrash.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardTrash.qml).
- Tests (pure logic): [`tests/island-trash.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-trash.test.mjs).

## Known limits

- On the test bench, a fake `.trashinfo` file made the island show the trash icon, the name and Undo, and the clock came back after the Undo time. A real Undo of a real file was not tried.
- A review found that the source exists once per screen but reads a global counter (`quietTrash`), so with two screens an Undo could be shown twice. It was not checked in the final code.
- The QML files have no automated test.

## Images

The trash bubble: file name and an Undo button.

![The trash bubble: file name and an Undo button](../media/faces-b-trash-undo/trash.png)
