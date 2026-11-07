# Island charge bubble and card

Status: working prototype

## What it does
- Plugging in the laptop opens the charge face of the island (see [the charge face page](faces-a-charge-face.md)). When the island is busy, or once the face closes, a "charge" bubble shows on the left side, under any passing machine bubble, for about 5 seconds (the time of a notification; it waits while the face or the card is shown).
- Right click hides the charge until the next plug.
- Click or hover opens the card: the battery in the header ("Plugged in", "Charging · 64%"), a thin chart "Charging power over time" since the plug (with the average power and the energy received), three figures (left, full at, health), and the power profile buttons. If setting a profile fails, it says "Failed to set power profile".
- Charge steps also give short infos: fully charged, unplugged, and low battery are brief; a critical battery is an important one.
- The power is sampled only while it charges, kept in memory and bounded (when the history gets too long, neighbour points merge two by two).
- A shell started on its charger stays quiet (the first reading only seeds).

## Why
- The author's rule for all bubbles: the free island plays the plug first, then the bubble. On 28 October he asked that the charge bubble disappear ("I thought about 4.5 s"). The notes picked 5 seconds, the length of a notification, as the closest rule in his norms.
- Leaving the island forgets the clicked card, and changing the power profile does not close it.
- Words for the power speed use USB Power Delivery levels, because no standard names them: slow under 10 W, normal under 30 W, fast under 65 W, ultra above.

## How it is built
- IPC, without a pointer: `island charge open|card|hide` opens the face, turns it into the card, or hides the charge. `island card open|close|toggle` does the same for the card of the machine bubble.
- [`quickshell/Common/IslandCharge.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCharge.js): plain JavaScript. `step` says plugged, unplugged or full from two readings; `record` and `summary` handle the power history; `left`, `clock` and `speed` give the texts. The same file holds the numbers used by the face's animation.
- [`quickshell/Modules/DIsland/IslandChargeSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandChargeSource.qml): the source. It reads `BatteryService` only. It gives the pack health (capacity against design, from UPower), the states `plugged`, `unplugged`, `full`, `low` and `critical`, and `takeRing()` for the face.
- [`quickshell/Modules/DIsland/Cards/BubbleCardCharge.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleCardCharge.qml) (the card, whose chart repaints only when a point comes in) and [`quickshell/Modules/DIsland/Cards/BubbleChargeGlyph.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleChargeGlyph.qml) (the battery glyph in the bubble).
- [`quickshell/Common/IslandMachineCard.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandMachineCard.js) and [`quickshell/Modules/DIsland/DIsland.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/DIsland.qml): the `island charge` and `island card` commands. Answers include `ISLAND_UNAVAILABLE`, `ISLAND_CHARGE_UNKNOWN_ACTION` and `ISLAND_CHARGE_UNAVAILABLE` (not charging, or island busy). Without a pointer the card is pinned.
- [`quickshell/Modules/DIsland/IslandBarHost.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandBarHost.qml) creates the source and opens the face at the plug.
- Tests: [`island-charge.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-charge.test.mjs) and [`island-machine-card.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-machine-card.test.mjs).

## Known limits
- Never seen on a test bench: the bench has no battery and no way to simulate a charge. No capture exists.
- Only the pure JavaScript is unit tested. The source, the card, the host and the commands are not.
- The speed words are a convention chosen for this work, not a standard.

## Images
No screenshot yet.

