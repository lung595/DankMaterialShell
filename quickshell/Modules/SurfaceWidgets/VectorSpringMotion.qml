pragma ComponentBehavior: Bound

import QtQuick
import "../../Common/FrameCadence.js" as FrameCadence

QtObject {
    id: root

    property bool enabled: true
    property bool running: false
    property bool reducedMotion: false

    property real stiffness: 560
    property real damping: 37
    property real mass: 1
    property real positionEpsilon: 0.035
    property real velocityEpsilon: 0.035
    property real maximumFrameTime: 1 / 30
    property real integrationStep: 1 / 240
    property int maximumSubsteps: 256
    readonly property real timeConstantMs: reducedMotion ? 0 : 2000 * mass / Math.max(1, damping)

    property real currentWidth: 176
    property real currentHeight: 42
    property real currentOffsetAlong: 0
    property real currentOffsetCross: 8
    property real currentTopLeftRadius: 21
    property real currentTopRightRadius: 21
    property real currentBottomLeftRadius: 21
    property real currentBottomRightRadius: 21

    property real targetWidth: currentWidth
    property real targetHeight: currentHeight
    property real targetOffsetAlong: currentOffsetAlong
    property real targetOffsetCross: currentOffsetCross
    property real targetTopLeftRadius: currentTopLeftRadius
    property real targetTopRightRadius: currentTopRightRadius
    property real targetBottomLeftRadius: currentBottomLeftRadius
    property real targetBottomRightRadius: currentBottomRightRadius

    property real velocityWidth: 0
    property real velocityHeight: 0
    property real velocityOffsetAlong: 0
    property real velocityOffsetCross: 0
    property real velocityTopLeftRadius: 0
    property real velocityTopRightRadius: 0
    property real velocityBottomLeftRadius: 0
    property real velocityBottomRightRadius: 0
    // Cadence rule K7: seconds of frames above 120 a second, folded into the next step (FrameCadence.fold).
    property real _foldedTime: 0
    // The eight axes as their [target, current, velocity] property names, and one frame's integrated [current, velocity]
    // per axis: both made once, so advance() allocates nothing per frame.
    readonly property var _axes: ["Width", "Height", "OffsetAlong", "OffsetCross", "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius"].map(n => ["target" + n, "current" + n, "velocity" + n])
    readonly property var _frame: new Float64Array(16)

    // One per integration step, so consumers copy the body once instead of binding to eight currents.
    signal stepped()

    function matchesTarget(target) {
        return targetWidth === target.width && targetHeight === target.height && targetOffsetAlong === target.offsetAlong && targetOffsetCross === target.offsetCross && targetTopLeftRadius === target.topLeftRadius && targetTopRightRadius === target.topRightRadius && targetBottomLeftRadius === target.bottomLeftRadius && targetBottomRightRadius === target.bottomRightRadius;
    }

    function setTarget(target, seedVelocity) {
        if (matchesTarget(target) && !seedVelocity)
            return;
        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetAlong = target.offsetAlong;
        targetOffsetCross = target.offsetCross;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        if (seedVelocity) {
            velocityOffsetAlong = seedVelocity.offsetAlong ?? velocityOffsetAlong;
            velocityOffsetCross = seedVelocity.offsetCross ?? velocityOffsetCross;
        }

        if (reducedMotion) {
            settle();
            return;
        }

        if (!isSettled())
            running = true;
    }

    function snapTo(target) {
        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetAlong = target.offsetAlong;
        targetOffsetCross = target.offsetCross;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        currentWidth = target.width;
        currentHeight = target.height;
        currentOffsetAlong = target.offsetAlong;
        currentOffsetCross = target.offsetCross;
        currentTopLeftRadius = target.topLeftRadius;
        currentTopRightRadius = target.topRightRadius;
        currentBottomLeftRadius = target.bottomLeftRadius;
        currentBottomRightRadius = target.bottomRightRadius;

        velocityWidth = 0;
        velocityHeight = 0;
        velocityOffsetAlong = 0;
        velocityOffsetCross = 0;
        velocityTopLeftRadius = 0;
        velocityTopRightRadius = 0;
        velocityBottomLeftRadius = 0;
        velocityBottomRightRadius = 0;
        running = false;
        stepped();
    }

    function isSettled() {
        const positionSettled = Math.abs(targetWidth - currentWidth) <= positionEpsilon && Math.abs(targetHeight - currentHeight) <= positionEpsilon && Math.abs(targetOffsetAlong - currentOffsetAlong) <= positionEpsilon && Math.abs(targetOffsetCross - currentOffsetCross) <= positionEpsilon && Math.abs(targetTopLeftRadius - currentTopLeftRadius) <= positionEpsilon && Math.abs(targetTopRightRadius - currentTopRightRadius) <= positionEpsilon && Math.abs(targetBottomLeftRadius - currentBottomLeftRadius) <= positionEpsilon && Math.abs(targetBottomRightRadius - currentBottomRightRadius) <= positionEpsilon;
        const velocitySettled = Math.abs(velocityWidth) <= velocityEpsilon && Math.abs(velocityHeight) <= velocityEpsilon && Math.abs(velocityOffsetAlong) <= velocityEpsilon && Math.abs(velocityOffsetCross) <= velocityEpsilon && Math.abs(velocityTopLeftRadius) <= velocityEpsilon && Math.abs(velocityTopRightRadius) <= velocityEpsilon && Math.abs(velocityBottomLeftRadius) <= velocityEpsilon && Math.abs(velocityBottomRightRadius) <= velocityEpsilon;
        return positionSettled && velocitySettled;
    }

    function settle() {
        currentWidth = targetWidth;
        currentHeight = targetHeight;
        currentOffsetAlong = targetOffsetAlong;
        currentOffsetCross = targetOffsetCross;
        currentTopLeftRadius = targetTopLeftRadius;
        currentTopRightRadius = targetTopRightRadius;
        currentBottomLeftRadius = targetBottomLeftRadius;
        currentBottomRightRadius = targetBottomRightRadius;

        velocityWidth = 0;
        velocityHeight = 0;
        velocityOffsetAlong = 0;
        velocityOffsetCross = 0;
        velocityTopLeftRadius = 0;
        velocityTopRightRadius = 0;
        velocityBottomLeftRadius = 0;
        velocityBottomRightRadius = 0;
        running = false;
        stepped();
    }

    function advance(rawFrameTime) {
        if (!enabled || !running || reducedMotion)
            return;

        const frameTime = Math.min(Math.max(rawFrameTime, 0), maximumFrameTime);
        if (frameTime <= 0)
            return;

        const inverseMass = 1 / Math.max(0.001, mass);
        // Short animation speeds scale stiffness by 1/f², so shrink the step until explicit Euler stays stable.
        const stableStep = 1 / Math.max(1, damping * inverseMass, Math.sqrt(stiffness * inverseMass));
        const steps = Math.min(maximumSubsteps, Math.max(1, Math.ceil(frameTime / Math.min(integrationStep, stableStep))));
        const step = frameTime / steps;
        const k = stiffness;
        const c = damping;
        const f = root._frame;

        // The axes are independent: each is integrated in plain locals, then all are written once per frame (no array
        // per frame), since every property write re-runs its bindings.
        for (let j = 0; j < root._axes.length; j++) {
            const axis = root._axes[j];
            const target = root[axis[0]];
            let x = root[axis[1]], v = root[axis[2]];
            for (let i = 0; i < steps; i++) {
                v += (k * (target - x) - c * v) * inverseMass * step;
                x += v * step;
            }
            // A sum is finite only when both terms are (NaN and infinities carry through).
            if (!Number.isFinite(x + v)) {
                settle();
                return;
            }
            f[2 * j] = x;
            f[2 * j + 1] = v;
        }
        for (let j = 0; j < root._axes.length; j++) {
            root[root._axes[j][2]] = f[2 * j + 1];
            root[root._axes[j][1]] = f[2 * j];
        }

        if (isSettled())
            settle();
        else
            stepped();
    }

    onEnabledChanged: {
        if (!enabled) settle();
    }

    onReducedMotionChanged: {
        if (reducedMotion)
            settle();
    }

    property FrameAnimation frameAnimation: FrameAnimation {
        running: root.enabled && root.running && !root.reducedMotion
        onRunningChanged: root._foldedTime = 0
        onTriggered: {
            const time = FrameCadence.fold(root._foldedTime, frameTime);
            root._foldedTime = Math.max(0, -time);
            if (time > 0)
                root.advance(time);
        }
    }
}
