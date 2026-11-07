# Island charge face (sea and odometer)

Status: working prototype

## What it does
- When you plug in the laptop and the island is free, it opens into a charge face. On the left is a bordered well with a "sea" of the battery level: three swells, bubbles that burst at the surface, and a bolt on a Material "cookie" shape that breathes and turns with the power. The more watts, the more bubbles, the faster the waves.
- At the plug, one ripple in the color of the level leaves the bolt. It plays once. If the face is not shown at the plug, the ring is dropped so a later hover or command does not replay it.
- On the right, the level is a large number on digit wheels that roll to the value, then the power chip (watts and a word such as "slow", "normal", "fast" or "ultra"), a wavy progress bar, and three chips: time left, full at, and the energy gained in the session (once the session is a minute old).
- Each piece appears in turn while the island grows. The sea stays quiet once the island folds.
- A click turns the face into the charge card (see [the charge bubble page](faces-a-charge-bubble.md)).
- With reduced motion, the face shows its final state and nothing runs. The sea is flat and has no bubbles.

## Why
- The author said the first face was "not designed enough, no movement, not enough useful info" (27 October), and after a second test "still not modern enough" (28 October).
- He liked the "current" idea (waves and bubbles that follow the power) but wanted a border around the sea. He then chose the Material 3 Expressive style, "validated as is", from three mock-ups (Apple, Flux, Google). The notes keep a rule from this: a liquid in the island lives in a bordered well and never touches the island edge.
- The info he asked for: power with a word, a power curve, and the gain of the session.

## How it is built
- [`quickshell/Modules/DIsland/Cards/BubbleChargeFace.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleChargeFace.qml): the face (kind `chargeface`). It follows the island's growth, so the content follows the island.
- [`quickshell/Modules/DIsland/Cards/BubbleChargeChips.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Cards/BubbleChargeChips.qml): the three chips (they wrap if the row is too narrow).
- [`quickshell/Modules/DIsland/Kit/IslandChargeSea.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Kit/IslandChargeSea.qml) and [`quickshell/Shaders/frag/charge_sea.frag`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Shaders/frag/charge_sea.frag): the sea in one shader drawn from numbers, with one clock pushed at the kit's cadence. The clock runs for a short time after the face shows and is zero at rest.
- [`quickshell/Modules/DIsland/Kit/IslandOdometer.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/Kit/IslandOdometer.qml): digit wheels; a wheel rolls to its next digit as the value passes it, and the width never jumps.
- [`quickshell/Common/IslandCharge.js`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Common/IslandCharge.js) and [`quickshell/Modules/DIsland/IslandChargeSource.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/Modules/DIsland/IslandChargeSource.qml): the numbers (power share, wave pace, breath, when each piece appears) and the data (shared with the charge bubble).
- Tests: [`island-charge-sea-shader.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island-charge-sea-shader.test.mjs), [`tst_BubbleChargeChips.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island/tst_BubbleChargeChips.qml) and [`tst_IslandOdometer.qml`](https://github.com/lung595/DankMaterialShell/blob/island-prototype/quickshell/tests/island/tst_IslandOdometer.qml).

## Known limits
- Never seen on a test bench: no battery and no charge simulation there. There is no capture of the face.
- The cost of the animation (sea shader, wheels, ring) in CPU and GPU was never measured.
- The sea and the wheels are only tested lightly: the shader has a test file, the chips and the odometer have QML tests, and the face itself has none. One test run reported 4 passed for the two QML test files together, and it was not checked that this covers both.
- A note of 28 October mentions a "binding loop" on `faceBigness` with reduced motion. It already existed on the base, was not caused by this work, and was not rechecked on the final code.

## Images
No screenshot yet.

