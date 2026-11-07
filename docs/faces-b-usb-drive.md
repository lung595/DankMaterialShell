# USB drive bubble

Status: working prototype

## What it does

- When a removable drive (USB stick, plugged disk) appears, the island plays its arrival first, then keeps a bubble with a USB icon.
- The bubble shows the drive's label (else its model, else its device) and "N GB free", or the size if the drive is not mounted.
- The card has two buttons. Open mounts the drive if needed and opens it in the file manager. Eject unmounts every mounted file system of the drive, then powers the drive off.
- After Eject, the card says "You can unplug it" for a moment, then the bubble goes away.
- If the drive is pulled out without ejecting, the bubble disappears. A failed action shows an error toast.

## Why

- Eject powers the drive off, then the card says "You can unplug it".
- Eject unmounts all file systems of the disk because a key can hold several (comment in the source).

## How it is built

- Drive list: [`Common/IslandUsb.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandUsb.js) reads `lsblk -J` and keeps file systems on hotplug, removable or USB disks. Containers that `udisksctl` cannot mount (swap, LUKS, LVM, RAID members) are left out.
- Source: [`Modules/DIsland/IslandUsbSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandUsbSource.qml). It reacts to UDisks2 signals through DMS's D-Bus bridge, else `udisksctl monitor`, and re-reads `lsblk`. No polling. It uses `udisksctl mount`, `unmount` and `power-off`.
- Card: [`Cards/BubbleCardUsb.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardUsb.qml).
- Notification echo: [`Common/IslandEcho.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandEcho.js) recognises a notification from a disk or file manager about a drive as the same event.
- Tests (pure logic): [`tests/island-usb.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-usb.test.mjs).

## Known limits

- It was never tried with a real USB drive or real UDisks2. On the test bench, a fake `lsblk` and a fake `udisksctl` simulated a drive called "BANC" with 12.4 GB free.
- Open, Eject and "You can unplug it" were not exercised. The D-Bus signal path was not tested (the bench used `udisksctl monitor`).
- A review note says a new arrival can reset the busy state during an action, and that the D-Bus block is copied from the SSH source.

## Images

No screenshot yet.

