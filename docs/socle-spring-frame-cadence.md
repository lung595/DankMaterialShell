# Spring frame cadence (120 steps a second)

Status: in [PR #4180](https://github.com/duxlabs-dev/dux-shell/pull/4180) (closed)

## What it does

- The springs of the bar, the dock and the island take at most 120 steps a second. On master they step on every screen frame, so 240 steps a second on a 240 Hz screen.
- Up to 120 Hz, every frame steps. From 144 to 240 Hz, every second frame steps.
- The time of a skipped frame is added to the next step, so the motion looks the same.
- The alert rings of the kit run on their own clock, `IslandDecorClock`, which is a Timer and not an animation driver. It runs only while the rings play and its window is visible.
- The rings draw at a rate that divides the panel rate, between 24 and 120 images a second. An image is drawn only if something moved by at least half a pixel.
- The screen refresh comes from `NiriService.outputs`. Until it is known, the code assumes 60 Hz.

## Why

- The author decided that no island animation should go above 120 images a second on any screen. Above that, the CPU and GPU work is wasted.
- The cap is set in one place for each family of animation, not in the callers.
- A cheap idle matters: nothing should run when nothing moves.

## How it is built

- [`FrameCadence.js`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Common/FrameCadence.js) has `fold()`. A frame shorter than 1/126 s is folded into the next one. The 5 % slack stops an off-vsync tick at 126 Hz from counting as a faster screen.
- [`VectorSpringMotion.qml`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Modules/SurfaceWidgets/VectorSpringMotion.qml) calls `fold()` on each `FrameAnimation` frame. BarSurface, DockBody and DIslandSurface use it. It also integrates into one `Float64Array` made once, where master makes three new arrays on every frame.
- [`IslandKit.js`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Common/IslandKit.js) has the helpers `framesBetween()`, `cadenceDue()` and `screenRefresh()`. [`IslandClock.js`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Common/IslandClock.js) works out the tick interval, and [`IslandDecorClock.qml`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/Modules/DIsland/Kit/IslandDecorClock.qml) is the Timer.
- The decor clock ticks every round(refresh / 60) screen refreshes. That gives 45 to 77 ticks a second on screens at 60, 75, 90, 120, 144, 165 and 240 Hz.
- The liquid has no clock. Its front moves only while its spring moves.
- Tests: [`spring-cadence.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/tests/spring-cadence.test.mjs) plays 480 frames at 60, 120, 144, 165, 240 and 480 Hz and checks that no time is lost. [`island-kit-cadence.test.mjs`](https://github.com/lung595/DankMaterialShell/blob/island/1-kit/quickshell/tests/island-kit-cadence.test.mjs) covers the clock and the decors.
- There are no settings.

## Known limits

- Proven on a simulated clock only. The author did not test a real 144, 165 or 240 Hz screen.
- At 144 Hz the springs now step 72 times a second, and 82.5 at 165 Hz. This is wanted and tested, but it shows in the diff of `VectorSpringMotion.qml`.
- On the bench, the idle CPU did not change (0.20 % of one core on both sides, below the noise). The spring steps a second on a simulated 240 Hz clock went from 250 to 125.
- Frame time at 240 Hz was not measured. The bench renders in software at about 54 frames a second.
- Qt animations (fades, `Behavior`, `NumberAnimation`) are not capped by this change.
- A comment and a test name say the decor clock ticks 60 times a second on any screen. This is wrong: it ticks a whole number of refreshes apart.

## Images

No screenshot yet.

