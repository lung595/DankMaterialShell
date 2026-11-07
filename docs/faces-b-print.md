# Printing bubble

Status: working prototype

## What it does

- While a CUPS job is printing, a bubble with a printer icon appears. The card, titled "Printing", shows the document name, the printer, and a Cancel button.
- When a printer stops, or its state reason ends in `-error`, and a job is waiting, the bubble turns orange. The card, "Printer problem", shows the reason (for example "Media Jam") with Resume and Cancel.
- A printer paused on purpose is not an error. An error wins over a job that prints on another printer.
- A new job or a new error plays on the free island first, then stays as a bubble.
- The cross on the bubble hides that job in that state. A new job or a new reason shows it again.
- The printer glyph slides a sheet out of the tray on each new page, once, and rests. With reduced motion there is no sheet.

## Why

- DMS already knows the printers (`CupsService`), so the island can show a stuck job without a new service.
- The bubble reads CUPS events pushed by the DMS server (D-Bus), with no polling.

## How it is built

- Logic: [`Common/IslandPrint.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandPrint.js). `current(printers)` picks the job printing now, or a printer in error with jobs waiting.
- Source: [`Modules/DIsland/IslandPrintSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandPrintSource.qml) reads `CupsService.printers` and subscribes to the service while it is shown. A job leaves only after it stayed gone for a moment, because CUPS rebuilds its printers with no jobs and then fetches them. Reasons use the labels `CupsService` already translates.
- Card and glyph: [`Cards/BubbleCardPrint.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardPrint.qml), [`Cards/BubblePrintGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubblePrintGlyph.qml).
- Echo type: [`Common/IslandEcho.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandEcho.js).
- Tests (pure logic): [`tests/island-print.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-print.test.mjs).

## Known limits

- DMS's CUPS jobs carry no page counts, so the "3/12" counter and the page progress are not shown today. The code supports them if a job has `pages` and `pagesDone`; the upgrade is to add `job-impressions` to the core's Job (a `shortcut:` comment).
- It was tried only on the test bench with a fake IPP server on 127.0.0.1, with two scenes (a job printing, a jam). Live transitions through CUPS D-Bus events and a "stopped" printer with no reason were not played.
- On the bench, the log showed one TypeError per scene from `Kit/IslandButtonRow.qml` while the card changed its number of buttons. The card still displayed correctly. The cause was not found.
- No real printer was used.

## Images

No screenshot yet.

