import QtQuick
import QtQuick.Shapes
import qs.Common
import "../../Common/IslandKit.js" as Kit
import "../../Common/IslandLiquidSplit.js" as Split

// Pivot: the bubble turns a quarter round its icon as it lands (the icon stays upright), then the liquid falls to the bottom
// on a slow spring and sloshes. Only a level tile pivots (its icon tops it, as it ends the pill); the others keep the plain morph.
// While it pivots the wing is laid out as the upright tile, turned back flat at the start: same outline as the pill, and the
// validated tile at the end, where it hands back to the stock layout and gauge.
TileTransition {
    id: pivot

    // Extra inputs, bound by the wing.
    property bool open: false
    property int side: -1
    property real level: 0
    // The wing's gauge tones.
    property color trackColor
    property color liquidColor
    property real trackGap: 3
    property real radius: 0
    property real content: 1
    property bool reduced: false
    property bool farEdge: false

    // Springs from the web mockup (stiffness, damping ratio; delays in ms on opening / closing): turn 300/0.55 (30 / 60),
    // size 340/0.55 (40 / 40), fall 150/0.4 (220 / 0). The flight itself stays on the wing's tile spring.
    property real rotX: 0
    property real rotV: 0
    property real sizeX: 0
    property real sizeV: 0
    property real fallX: 0
    property real fallV: 0
    property real slosh: 0
    property real phase: 0
    property real clock: 0
    property var pending: []
    property bool moving: false

    readonly property bool pivoting: pivot.active && pivot.carded && pivot.gauged && (pivot.moving || pivot.slosh > 0.05 || (pivot.open ? pivot.tileShape < 1 : pivot.tile >= 0.01))
    readonly property real pillLong: pivot.restLength
    readonly property real side0: pivot.side < 0 ? -1 : 1
    // Upright frame: width is the pill's thickness growing to the tile's side, height its length growing to the tile's height.
    readonly property real frameW: Math.max(0, pivot.mix(pivot.pillThick, pivot.tileSide, pivot.sizeX))
    readonly property real frameH: Math.max(0, pivot.mix(pivot.pillLong, pivot.tileThick, pivot.sizeX))
    // The wing's box keeps its inner edge; this brings the icon from the pill's outer end to the tile's top as it flies.
    readonly property real flatShift: pivot.pivoting ? (pivot.pillLong - pivot.pillThick) * (1 - Math.max(0, Math.min(1, pivot.tile))) : 0
    readonly property real shiftX: pivot.side0 * pivot.flatShift
    // On a bar at the far edge the box keeps its bottom, so the icon is brought down to the pill's middle too.
    readonly property real shiftY: pivot.farEdge ? pivot.flatShift : 0

    length: pivot.pivoting ? pivot.frameW : pivot.mix(pivot.restLength, pivot.tileSide, pivot.tileShape)
    thick: pivot.pivoting ? pivot.frameH : pivot.mix(pivot.pillThick, pivot.tileThick, pivot.tileShape)
    iconY: pivot.pivoting ? pivot.frameW / 2 : pivot.mix(pivot.pillIconY, pivot.tileIconY, pivot.tileOf)
    // Left wing: the upright frame turned back a quarter counterclockwise lies flat with its icon at the outer (left) end.
    turn: pivot.pivoting ? pivot.side0 * 90 * (1 - pivot.rotX) : 0
    gaugeShown: !pivot.pivoting
    z: 0.5

    function targets() {
        const t = pivot.open ? 1 : 0;
        return [{
                "key": "rot",
                "t": t,
                "at": pivot.clock + (pivot.open ? 0.03 : 0.06)
            }, {
                "key": "size",
                "t": t,
                "at": pivot.clock + 0.04
            }, {
                "key": "fall",
                "t": t,
                "at": pivot.clock + (pivot.open ? 0.22 : 0)
            }];
    }
    property real rotT: 0
    property real sizeT: 0
    property real fallT: 0
    function snap() {
        const t = pivot.open ? 1 : 0;
        pivot.pending = [];
        pivot.rotT = pivot.sizeT = pivot.fallT = t;
        pivot.rotX = pivot.sizeX = pivot.fallX = t;
        pivot.rotV = pivot.sizeV = pivot.fallV = 0;
        pivot.slosh = 0;
        pivot.moving = false;
    }
    onOpenChanged: {
        if (!pivot.active || pivot.reduced || !pivot.gauged) {
            pivot.snap();
            return;
        }
        pivot.pending = pivot.targets();
        pivot.moving = true;
    }
    onActiveChanged: pivot.snap()
    onReducedChanged: pivot.snap()
    Component.onCompleted: pivot.snap()

    // [stiffness, damping ratio] of the turn, the size and the fall, mass 1, as the mockup's Spring class (TileJelly's).
    readonly property var springs: ({
            "rot": [300, 0.55],
            "size": [340, 0.55],
            "fall": [150, 0.4]
        })

    FrameAnimation {
        id: frames

        running: pivot.active && pivot.gauged && (pivot.moving || pivot.slosh > 0.05)
        onTriggered: {
            const real = Math.min(0.05, frames.frameTime * pivot.pace);
            let left = real;
            let rx = pivot.rotX, rv = pivot.rotV, sx = pivot.sizeX, sv = pivot.sizeV, fx = pivot.fallX, fv = pivot.fallV;
            let rt = pivot.rotT, st = pivot.sizeT, ft = pivot.fallT;
            let pend = pivot.pending;
            let clock = pivot.clock;
            const step = Split.springStep, sr = pivot.springs.rot, ss = pivot.springs.size, sf = pivot.springs.fall;
            while (left > 0) {
                const d = Math.min(Split.subStep, left);
                clock += d;
                pend = pend.filter(p => {
                    if (p.at > clock)
                        return true;
                    if (p.key === "rot")
                        rt = p.t;
                    else if (p.key === "size")
                        st = p.t;
                    else
                        ft = p.t;
                    return false;
                });
                [rx, rv] = step(rx, rv, rt, sr, d);
                [sx, sv] = step(sx, sv, st, ss, d);
                [fx, fv] = step(fx, fv, ft, sf, d);
                left -= d;
            }
            // Slosh: kicked by the fall and the turn, it rings down; the wave's phase runs on.
            const speed = Math.abs(fv) * 1.4 + Math.abs(rv) * 0.3;
            pivot.slosh = Split.slosh(pivot.slosh, real, speed * Split.sloshGain);
            pivot.phase += real * Split.sloshWave;
            const still = (x, v, t) => Math.abs(x - t) < 0.001 && Math.abs(v) < 0.01;
            const settled = pend.length === 0 && still(rx, rv, rt) && still(sx, sv, st) && still(fx, fv, ft);
            pivot.clock = clock;
            pivot.pending = pend;
            pivot.rotT = rt;
            pivot.sizeT = st;
            pivot.fallT = ft;
            pivot.rotX = settled ? rt : rx;
            pivot.rotV = settled ? 0 : rv;
            pivot.sizeX = settled ? st : sx;
            pivot.sizeV = settled ? 0 : sv;
            pivot.fallX = settled ? ft : fx;
            pivot.fallV = settled ? 0 : fv;
            pivot.moving = !settled;
        }
    }

    // The liquid in the upright frame: its long axis runs down from the icon. Flat on the pill it lies against the icon's end;
    // once upright it falls to the bottom, where it is the stock gauge.
    Item {
        id: well

        readonly property real inset: Theme.spacingXS
        readonly property real gx: well.inset
        readonly property real gy: pivot.frameW + pivot.trackGap
        readonly property real gw: Math.max(0, pivot.width - 2 * well.inset)
        readonly property real gh: Math.max(0, pivot.height - well.gy - well.inset)
        readonly property real fall: Math.max(-0.1, Math.min(1.1, pivot.fallX))
        readonly property real len: well.gh * Math.max(0, Math.min(1, pivot.level))
        readonly property real start: well.gy + (well.gh - well.len) * Math.max(0, Math.min(1, well.fall))
        readonly property var outline: {
            if (!pivot.pivoting)
                return [];
            const pts = [];
            const n = 14;
            const top = well.gy, bottom = well.gy + well.gh;
            // A1: the kit's wave along the well (i / n, 0 to 1), the well being `fronts` kit fronts wide: half a radian a point.
            const fronts = n / (2 * Math.PI);
            const clampY = y => Math.max(top, Math.min(bottom, y));
            for (let i = 0; i <= n; i++) {
                const k = Math.sin(Math.PI * i / n);
                // The leading end waves while it falls, and lies flat on the floor once it is there.
                pts.push(Qt.point(well.gx + well.gw * i / n, clampY(well.start + well.len + Kit.wave(fronts * i / n, pivot.slosh, pivot.phase) * k * Math.max(0, 1 - well.fall))));
            }
            for (let i = n; i >= 0; i--) {
                const k = Math.sin(Math.PI * i / n);
                pts.push(Qt.point(well.gx + well.gw * i / n, clampY(well.start - Kit.wave(fronts * i / n, pivot.slosh, pivot.phase + 1) * k * well.fall)));
            }
            return pts;
        }

        anchors.fill: parent
        visible: pivot.pivoting
        opacity: pivot.content

        Rectangle {
            x: well.gx
            y: well.gy
            width: well.gw
            height: well.gh
            radius: Math.max(0, pivot.radius - well.inset)
            color: pivot.trackColor
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: pivot.liquidColor
                strokeColor: "transparent"
                strokeWidth: 0

                PathPolyline {
                    path: well.outline
                }
            }
        }
    }
}
