pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "../../../Common/DiskUsage.js" as DiskUsage
import "../../../Common/DiskChart.js" as DiskChart

// The disk card's chart (BubbleCardDisk): the shown folder as a treemap or as rings, cells gliding to their new place
// (exponential approach; reduced motion puts them in place at once), the pointer's hover and clicks. Layouts, hit tests,
// colors, text fitting and easing are DiskChart.js (tested by vm); this file only paints them.
Canvas {
    id: chart

    required property BubbleCardDisk card

    readonly property real cellRadius: Theme.cornerRadiusXS
    readonly property real frameRadius: Theme.cornerRadiusS
    readonly property string fontFamily: Theme.fontFamily
    // shortcut: dark ink on the always light branch fills, no theme token fits both themes; check in light mode.
    readonly property string ink: "rgba(20,18,24,0.92)"
    // Shown places, eased toward the layout's, by node id.
    property var shown: ({})
    property real last: 0
    property bool moving: false
    // The last layout drawn, for the pointer and the arrows; the rings' geometry with it.
    property var items: []
    property var ring: ({})

    anchors.fill: parent
    anchors.margins: Theme.spacingXS
    visible: card.svc.mode !== "list"
    Accessible.role: Accessible.Graphic
    Accessible.name: card.svc.mode === "sun" ? I18n.tr("Disk space rings", "island disk card: chart") : I18n.tr("Disk space treemap", "island disk card: chart")

    function rgba(c, a) {
        return `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},${a})`;
    }
    // Vivid branch colors, turned from the theme's primary hue (DiskChart.branchHsl); the grouped crumbs in the outline.
    function branch(i, depth, light) {
        const c = DiskChart.branchHsl(i, depth, light, Theme.primary.hslHue);
        return c ? Qt.hsla(c.h, c.s, c.l, 1) : Theme.outline;
    }
    function fit(ctx, s, max) {
        return DiskChart.fitText(t => ctx.measureText(t).width, s, max);
    }
    function ease(d, key, target, props, k, grow) {
        const e = DiskChart.easeTo(chart.shown, key, target, props, k, d, grow);
        if (e.moved)
            chart.moving = true;
        return e.shown;
    }

    function drawTree(ctx, k) {
        const items = DiskChart.layoutTree(card.folder, 0, 0, width, height, 0, 0, []);
        chart.items = items;
        let mark = null;
        for (const it of items) {
            const d = chart.ease(0.25, it.node.id, it, ["x", "y", "w", "h"], k, t => ({
                        "x": t.x + t.w / 2,
                        "y": t.y + t.h / 2,
                        "w": 0,
                        "h": 0
                    }));
            if (d.w < 1 || d.h < 1)
                continue;
            if (it.node === card.chosenNode)
                mark = d;
            ctx.beginPath();
            if (it.dir)
                chart.drawFolder(ctx, it, d, chart.branch(it.col, 0, 0.72));
            else
                chart.drawFile(ctx, it, d, chart.branch(it.col, 0, 0.72));
        }
        // The chosen cell, ringed in the theme's primary over everything.
        if (mark) {
            ctx.beginPath();
            ctx.roundedRect(mark.x + 1, mark.y + 1, mark.w - 2, mark.h - 2, chart.cellRadius, chart.cellRadius);
            ctx.strokeStyle = chart.rgba(Theme.primary, 1);
            ctx.lineWidth = 2;
            ctx.stroke();
        }
    }
    // A folder: a tinted frame, its name and size along its top when they fit.
    function drawFolder(ctx, it, d, c) {
        const n = it.node;
        const r = Math.min(chart.frameRadius, d.w / 2, d.h / 2);
        ctx.roundedRect(d.x, d.y, d.w, d.h, r, r);
        ctx.fillStyle = chart.rgba(c, (n === card.hovered ? 0.3 : 0.14) + Math.min(it.depth, 3) * 0.03);
        ctx.fill();
        ctx.strokeStyle = chart.rgba(c, 0.55);
        ctx.lineWidth = 1;
        ctx.stroke();
        if (!it.hd || d.h <= 18)
            return;
        ctx.font = `600 11px "${chart.fontFamily}"`;
        ctx.textBaseline = "middle";
        const sz = DiskUsage.fmt(n.size);
        const szw = d.w > 110 ? ctx.measureText(sz).width + 8 : 0;
        ctx.fillStyle = chart.rgba(c, 1);
        ctx.fillText(chart.fit(ctx, n.name, d.w - 14 - szw), d.x + 6, d.y + 9);
        if (!szw)
            return;
        ctx.font = `500 10px "${chart.fontFamily}"`;
        ctx.fillStyle = chart.rgba(Theme.surfaceVariantText, 1);
        ctx.textAlign = "right";
        ctx.fillText(sz, d.x + d.w - 6, d.y + 9);
        ctx.textAlign = "left";
    }
    // A file: a filled cell, its name then its size inside when they fit.
    function drawFile(ctx, it, d, c) {
        const n = it.node;
        const r = Math.min(chart.cellRadius, d.w / 2, d.h / 2);
        ctx.roundedRect(d.x, d.y, d.w, d.h, r, r);
        ctx.fillStyle = chart.rgba(c, (n.other ? 0.45 : Math.max(0.55, 0.94 - it.depth * 0.08)) * (n === card.hovered ? 0.8 : 1));
        ctx.fill();
        if (d.w <= 40 || d.h <= 20)
            return;
        ctx.textBaseline = "middle";
        ctx.fillStyle = n.other ? chart.rgba(Theme.surfaceText, 1) : chart.ink;
        ctx.font = `600 10.5px "${chart.fontFamily}"`;
        ctx.fillText(chart.fit(ctx, n.name, d.w - 10), d.x + 5, d.y + 10);
        if (d.h <= 34)
            return;
        ctx.font = `500 10px "${chart.fontFamily}"`;
        ctx.globalAlpha = 0.75;
        ctx.fillText(chart.fit(ctx, DiskUsage.fmt(n.size), d.w - 10), d.x + 5, d.y + 23);
        ctx.globalAlpha = 1;
    }

    function drawSun(ctx, k) {
        const maxD = 4;
        const R = Math.min(width, height) / 2 - 4;
        const r0 = R * 0.32;
        const g = {
            "cx": width / 2,
            "cy": height / 2,
            "r0": r0,
            "rw": (R - r0) / maxD
        };
        const tree = card.folder;
        const items = tree.size > 0 ? DiskChart.layoutSun(tree, 0, Math.PI * 2, 1, maxD, 0, []) : [];
        chart.items = items;
        chart.ring = g;
        for (const it of items) {
            // An arc opens from its start angle, the rings' own growth.
            const d = chart.ease(0.002, "s:" + it.node.id, it, ["a0", "a1"], k, t => ({
                        "a0": t.a0,
                        "a1": t.a0
                    }));
            if (d.a1 - d.a0 >= 0.0015)
                chart.drawArc(ctx, it, d, g);
        }
        chart.drawHub(ctx, g, tree);
    }
    // One arc of the rings (g: their center and radii), its name along it on the first ring when it fits.
    function drawArc(ctx, it, d, g) {
        const ri = g.r0 + (it.depth - 1) * g.rw + 1;
        const ro = g.r0 + it.depth * g.rw - 1;
        const q = -Math.PI / 2;
        ctx.beginPath();
        ctx.arc(g.cx, g.cy, ro, d.a0 + q, d.a1 + q, false);
        ctx.arc(g.cx, g.cy, ri, d.a1 + q, d.a0 + q, true);
        ctx.closePath();
        ctx.fillStyle = chart.rgba(chart.branch(it.col, it.depth - 1, 0.74), (it.node.other ? 0.6 : 1) * (it.node === card.hovered ? 0.8 : 1));
        ctx.fill();
        const chosen = it.node === card.chosenNode;
        ctx.strokeStyle = chart.rgba(chosen ? Theme.primary : Theme.surface, 1);
        ctx.lineWidth = chosen ? 2.5 : 1.5;
        ctx.stroke();
        const rm = ri + g.rw / 2;
        if (it.depth !== 1 || (d.a1 - d.a0) * rm <= 60)
            return;
        const am = (d.a0 + d.a1) / 2 + q;
        ctx.save();
        ctx.translate(g.cx + Math.cos(am) * rm, g.cy + Math.sin(am) * rm);
        ctx.rotate(am + Math.PI / 2 + (Math.sin(am) > 0 ? Math.PI : 0));
        ctx.font = `600 10.5px "${chart.fontFamily}"`;
        ctx.fillStyle = chart.ink;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(chart.fit(ctx, it.node.name, (d.a1 - d.a0) * rm - 10), 0, 0);
        ctx.restore();
    }
    // The rings' hub: the folder's size, then its name or the scan's state.
    function drawHub(ctx, g, tree) {
        ctx.beginPath();
        ctx.arc(g.cx, g.cy, g.r0 - 4, 0, Math.PI * 2, false);
        ctx.fillStyle = chart.rgba(Theme.surfaceContainerHigh, 1);
        ctx.fill();
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillStyle = chart.rgba(Theme.surfaceText, 1);
        ctx.font = `700 ${Math.round(Math.max(14, Math.min(22, g.r0 * 0.3)))}px "${chart.fontFamily}"`;
        ctx.fillText(DiskUsage.fmt(tree.size), g.cx, g.cy - 4);
        ctx.font = `500 10.5px "${chart.fontFamily}"`;
        ctx.fillStyle = chart.rgba(Theme.surfaceVariantText, 1);
        ctx.fillText(card.svc.scanning ? I18n.tr("Scanning...", "island disk card: rings center") : tree.parent ? chart.fit(ctx, tree.name, 2 * g.r0 - 16) : I18n.tr("scanned", "island disk card: rings center"), g.cx, g.cy + 14);
        ctx.textAlign = "left";
    }

    function itemAt(x, y) {
        if (card.svc.mode === "sun")
            return DiskChart.hitRing(chart.items, chart.ring.cx, chart.ring.cy, chart.ring.r0, chart.ring.rw, x, y);
        return DiskChart.hit(chart.items, x, y);
    }

    onPaint: {
        const now = Date.now();
        const dt = Math.min(0.05, chart.last ? (now - chart.last) / 1000 : 0.016);
        chart.last = now;
        // Same pace as the rest of DMS: a slower animation setting slows the glide too.
        const k = card.reduce ? 1 : 1 - Math.exp(-dt * 11 * SettingsData.specDefault("animationDuration") / Math.max(1, SettingsData.animationDuration));
        const ctx = getContext("2d");
        ctx.reset();
        chart.moving = false;
        if (width > 0 && height > 0)
            chart.mode === "sun" ? chart.drawSun(ctx, k) : chart.drawTree(ctx, k);
    }

    // Redraws only while the scan feeds the tree or a cell is still on its way.
    FrameAnimation {
        running: card.visible && (card.svc.scanning || chart.moving)
        onTriggered: chart.requestPaint()
    }
    readonly property int revision: card.svc.revision
    readonly property string mode: card.svc.mode
    onRevisionChanged: chart.requestPaint()
    onModeChanged: {
        chart.last = 0;
        chart.requestPaint();
    }
    Component.onCompleted: requestPaint()

    // Over the frame's margin too: a click there must not reach the bubble behind (it would move into the island).
    MouseArea {
        anchors.fill: parent
        anchors.margins: -Theme.spacingXS
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: card.hovered?.children && !card.hovered.other ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: mouse => {
            const it = chart.itemAt(mouse.x - Theme.spacingXS, mouse.y - Theme.spacingXS);
            const n = it ? it.node : null;
            if (n === card.hovered)
                return;
            card.hovered = n;
            chart.requestPaint();
        }
        onExited: {
            card.hovered = null;
            chart.requestPaint();
        }
        onClicked: mouse => {
            card.takeKeys();
            const x = mouse.x - Theme.spacingXS;
            const y = mouse.y - Theme.spacingXS;
            const it = chart.itemAt(x, y);
            if (!it) {
                // The rings' hub: one folder up.
                if (card.svc.mode === "sun" && Math.hypot(x - chart.ring.cx, y - chart.ring.cy) < chart.ring.r0)
                    card.up();
                return;
            }
            if (mouse.button === Qt.RightButton || !card.enter(it.node))
                card.pick(it.node.other ? it.node.parent : it.node);
        }
    }
}
