# One-time code (2FA)

Status: working prototype

![A one-time code arrives: shown hidden on the island, then the digits appear when the pointer rests on it](../media/faces-b-code-2fa/code-arrives.gif)

*A one-time code arrives: shown hidden on the island, then the digits appear when the pointer rests on it*

In one sentence: A one-time code from a notification shows in the island with its digits hidden until you hover it, and Copy puts it in the clipboard for 30 seconds only.

## What it does

- When a notification arrives with a one-time code (for example an SMS relayed by a phone app, a mail or an authenticator), the island shows it as a bubble. The sending app's icon is shown with it.
- The digits are hidden (`••• •••`) until the pointer hovers the bubble. A Copy button copies the code.
- When the island is free, the code is shown on the island itself first. When the island is busy, the bubble keeps it and the island takes it back once it is free.
- The code leaves the clipboard 30 seconds after Copy, and it does not enter the clipboard history.
- While the screen is being shared, the digits stay hidden, even on hover.
- Only a notification that arrived in the last 10 seconds is used.

## Try it

- Check out `island-prototype`, use a bar in the Island layout, and send a notification with a code: `notify-send "Bank" "Your code is 482913"`.
- Hover the island or the bubble to see the digits, then press Copy.

## Why

- Codes are secrets: the notes say the code is kept in memory only, never logged, and wiped from the clipboard.
- Without the DMS server, the owner decided to copy for a single paste only (`wl-copy --paste-once`), so the code does not stay in the clipboard.
- Hiding the digits while sharing the screen avoids showing a code to an audience.

## How it is built

- Finding the code: [`Common/IslandCode2fa.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCode2fa.js) reads a 4 to 8 digit code (or 3+3 / 4+4 split by a space or a dash) next to a keyword such as "code", "OTP" or "verification". It ignores dates, times and amounts. It also builds the copy command (`copyPlan`).
- Source: [`Modules/DIsland/IslandCode2faSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandCode2faSource.qml) listens to new notifications from `NotificationService` and to `PrivacyService.screensharingActive`. Its timers run only while a code is present.
- Island face: [`IslandCode2faActivity.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandCode2faActivity.qml), activity id `dms:code2fa`.
- Bubble card: [`Cards/BubbleCardCode2fa.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardCode2fa.qml). Its liquid drains during the 30 seconds before the clipboard is cleared.
- Digits: [`Kit/IslandCodeDigits.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Kit/IslandCodeDigits.qml).
- Wiring: [`IslandBarHost.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBarHost.qml) and [`IslandBubbles.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBubbles.qml).
- Tests (pure logic only): [`tests/island-code2fa.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-code2fa.test.mjs).

## Known limits

- Only English and French keywords are recognised (a `shortcut:` comment in the code says so).
- Hover, Copy, the real wipe after 30 seconds, and the screen-sharing mask were not tried on a real session. The QML files have no automated test.
- Without the DMS server, the fallback clears the clipboard after one paste, not after 30 seconds.
- A review by the project's own relecteur script noted that false positives and wrong codes were possible when another number comes first. It was not re-checked on the final code.

## Images

A one-time code arrives: shown hidden on the island, then the digits appear when the pointer rests on it.

![A one-time code arrives: shown hidden on the island, then the digits appear when the pointer rests on it](../media/faces-b-code-2fa/code-arrives.gif)

The code face with its digits shown and the Copy button.

![The code face with its digits shown and the Copy button](../media/faces-b-code-2fa/code-card.png)
