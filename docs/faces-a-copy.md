# Island copy bubble

Status: working prototype

![A copy shows a Copied bubble; hovering it opens the card with the first line](../media/faces-a-copy/copy-bubble-and-card.gif)

*A copy shows a Copied bubble; hovering it opens the card with the first line*

In one sentence: Each copy shows a short "Copied!" bubble with the type of what was copied, and its card shows the first line or the file name, with secrets masked.

## What it does

- Each copy into the DMS clipboard (text, link, image, file) shows a short "Copied!" bubble on the apps side of the island, in front of the other bubbles, with a check mark on a shape.
- The bubble shows the type of the copy as an icon (text, link, image, file, secret). A copied image shows its own round thumbnail.
- Hover the bubble or the island to see a card: the title "Copied!", and under it the first line of the copy (40 characters at most) or the file name. A text that looks like a secret is masked.
- A new copy while the bubble shows restarts its time and moves its shape on.
- A copy made by the island itself (for example the Copy button of a 2FA code) does not play the bubble. A short quiet window of about 1.5 seconds covers the clipboard update that comes back.
- With the setting "Always show brief info in a bubble", the copy goes only to the bubble, beside the island.

## Try it

- Check out `island-prototype`, use a bar in the Island layout, and copy some text, a link, an image or a file.
- The bubble shows on the apps side. Hover it, or the island, to see the card with the first line.
- Turn on "Always show brief info in a bubble" (settings card "Bubbles") to keep the copy beside the island only.

## Why

- A copy is a short confirmation, so it should pass in front of the other bubbles (the author's table of bubbles, 24 October).
- The preview must not leak a secret, so only a one-line peek is kept and a secret is masked.
- A copy that the island made itself already says "Copied" on its own button, so a second bubble would be noise.

## How it is built

- [`quickshell/Common/IslandCopy.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCopy.js): plain JavaScript logic. A new copy is a clipboard entry whose id is above the last one seen (the first state only seeds). It also finds the kind from the entry's metadata only (never its data), the one-line peek, the secret test, and the own-copy window.
- [`quickshell/Modules/DIsland/IslandCopySource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandCopySource.qml): the source (apps side, `copy`). It follows the DMS clipboard state as it is pushed, with no polling. Only an image's data is read, never a text, over DMS's local socket, and it is dropped when the bubble goes.
- [`quickshell/Modules/DIsland/Cards/BubbleCardCopy.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardCopy.qml) and [`quickshell/Modules/DIsland/Cards/BubbleCopyType.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCopyType.qml): the card and the type icon or thumbnail.
- [`quickshell/Modules/DIsland/IslandBarHost.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBarHost.qml) and [`quickshell/Modules/DIsland/IslandBubbles.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBubbles.qml): the wiring. The setting is `islandBriefBubbles`.
- Tests: [`quickshell/tests/island-copy.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-copy.test.mjs) covers the JavaScript logic.

## Known limits

- The secret test is a guess from the text shape (one word without space, such as a one-time code, a long hex or base64 run, or 8 or more characters mixing three kinds). It can be wrong both ways.
- On the test bench, the copy was never recorded by the DMS clipboard history, so the bubble was not seen playing there. The behavior is known from the code and the unit tests.
- Only the pure JavaScript is unit tested.
- No animation measurement was made.

## Images

A copy shows a Copied bubble; hovering it opens the card with the first line.

![A copy shows a Copied bubble; hovering it opens the card with the first line](../media/faces-a-copy/copy-bubble-and-card.gif)

The copy card: Copied and a one-line preview.

![The copy card: Copied and a one-line preview](../media/faces-a-copy/copy-card.png)
