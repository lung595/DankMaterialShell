# Shelf: send, move, act on and remove files

Status: working prototype

## What it does

- Drag a tile out of the shelf into any app: that file goes there. Drag the shelf title or the file count and all the chosen files go. A long press on a tile also starts the drag.
- Ctrl+C copies the chosen files to the DMS clipboard, so you can paste them in a file manager. A single image is copied as an image.
- The card has drop zones (Convert, Share, Cloud) that stay hidden until you drag a file, then they rise. **Convert** changes a file's format (for example image formats, video to GIF, PDF pages, merging PDFs, zip and extract). **Share** sends the file to a device (see below). **Cloud** copies it into a synced folder (see the cloud page). Share lists the devices paired with KDE Connect. LocalSend is offered when it is installed. If no phone is connected, the shelf says "No phone connected".
- A file dropped on a folder in the explorer tree, or on a folder tile, is moved there (hold Ctrl to copy). Its name stays free: a taken name becomes "notes (2).md". The shelf links follow the file.
- Under the details sheet of the explorer, the two or three main actions of the selection are shown, with "Open" first. The rest is in "More" and in the right-click menu (also the Menu key and Shift+F10). Rename (F2) keeps the file in its folder and never takes the name of another file. Other actions for the type of file are in the menu; they create new files next to the source, under a free name, and never overwrite.
- Remove with the x on a tile, or Delete: this only forgets the link, the file stays on the disk. Shift+Delete moves the files to the trash. "Clear all" must be held for about two seconds, and says "Hold 2 s to clear all" when you only click. Every move, remove or clear says "Ctrl Z undoes it" and shows an Undo button with a countdown. Ctrl+Z puts files back, even from the trash. Ctrl+Y does it again.

## Why

- The owner asked for the fewest clicks possible: a drag out is 1 gesture, a drag into a folder is 1 gesture, and an action on a selection is 2.
- Every destructive step can be undone, so nothing in the shelf asks "are you sure".

## How it is built

- The actions are the verbs of [`island-shelf.sh`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/scripts/island-shelf.sh) (`move`, `copy`, `unmove`, `trash`, `untrash`, `rename`, `convert`, `zip`, `phone`...). It checks that every argument is an absolute path, refuses a folder moved into itself (code 6) or into a read-only folder (code 7), and never overwrites. The script uses local tools only.
- The list of buttons per file type is `plan` and `asidePlan` in [`IslandShelf.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandShelf.js); moving uses `movable`, `moves` and `relink`. Tests: [`island-shelf-depot.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-shelf-depot.test.mjs) and [`island-shelf-actions.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-shelf-actions.test.mjs).
- The zones, the devices (`kdeconnect-cli`), the history for Ctrl+Z, and the drag out (`takingOut`, `droppedOut`) are in [`IslandShelfSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandShelfSource.qml). The card is [`BubbleCardShelf.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardShelf.qml).
- The hold button and the undo button come from the island kit: [`IslandHoldButton.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Kit/IslandHoldButton.qml) and [`IslandUndoButton.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Kit/IslandUndoButton.qml).
- Copying files to the clipboard is a Go call, `clipboard.copyFiles`, in [`manager.go`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/core/internal/server/clipboard/manager.go).

## Known limits

- Sending to a phone was never played on the test bench (it needs a network device).
- A drag started on the press that finds a deleted file is lost.
- Ctrl while dropping is not seen when the card has no keyboard. The copy was proven by the script, not by a real drag.
- Ctrl+C of one image offers only `image/png`.
- If a move of several files is partly undone, the first file comes back and the shelf list does not.
- Undo of the trash was not tried with a real trash that had other files.
- Buttons on tiles are smaller than 44 px.
- Early versions crashed the shell when you dragged from the explorer. That was fixed and checked on the bench. A drag from the tree and the explorer still has its own drag proxy, so a launcher opened during it could still crash.

## Images

No screenshot yet.

