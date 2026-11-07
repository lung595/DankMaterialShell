.pragma library

// The disk explorer's two charts, laid out from DiskUsage.js's tree: the nested treemap (squarified, van Wijk) and the
// rings (radial partition), small items grouped; and what the pointer and the arrow keys find on them. Ported from the
// web disk mockup. A4: pure logic, tested by vm (tests/island-disk.test.mjs).

// Layout items come parents first, so the last one under the point is the deepest.
function hit(items, x, y) {
    let found = null;
    for (const it of items)
        if (x >= it.x && x < it.x + it.w && y >= it.y && y < it.y + it.h)
            found = it;
    return found;
}

// The rings as drawn (hub radius r0, rings rw wide, angle 0 up and clockwise): the arc under the point, null on the hub.
function hitRing(items, cx, cy, r0, rw, x, y) {
    const r = Math.hypot(x - cx, y - cy);
    if (r < r0)
        return null;
    const depth = Math.floor((r - r0) / rw) + 1;
    let a = Math.atan2(x - cx, cy - y);
    if (a < 0)
        a += 2 * Math.PI;
    return items.find(it => it.depth === depth && a >= it.a0 && a < it.a1) || null;
}

// Arrow keys over the shown folder's own cells (depth 0): the nearest one that way, drift across it costing double.
function step(items, from, dx, dy) {
    const top = items.filter(it => it.depth === 0);
    if (!top.length)
        return null;
    let at = top.find(it => it.node === from);
    if (!at) {
        const inner = items.find(it => it.node === from);
        at = inner ? top.find(it => inner.x >= it.x && inner.x < it.x + it.w && inner.y >= it.y && inner.y < it.y + it.h) : null;
        return (at || top[0]).node;
    }
    const cx = at.x + at.w / 2;
    const cy = at.y + at.h / 2;
    let best = at;
    let score = Infinity;
    for (const it of top) {
        const ax = it.x + it.w / 2 - cx;
        const ay = it.y + it.h / 2 - cy;
        const along = dx ? ax * dx : ay * dy;
        if (it === at || along <= 1)
            continue;
        const s = along + 2 * Math.abs(dx ? ay : ax);
        if (s < score) {
            score = s;
            best = it;
        }
    }
    return best.node;
}

// Biggest first; crumbs under minFrac (or past cap) are grouped into one "N others" node, never a group of one.
function kids(n, minFrac, cap) {
    const ks = (n.children || []).filter(c => c.size > 0).sort((a, b) => b.size - a.size);
    const out = [];
    const small = [];
    for (const c of ks)
        (out.length && (c.size < n.size * minFrac || out.length >= (cap || 40)) ? small : out).push(c);
    if (small.length === 1)
        out.push(small[0]);
    else if (small.length)
        out.push({
            "id": n.id + "/…",
            "name": "+" + small.length,
            "size": small.reduce((s, c) => s + c.size, 0),
            "other": true,
            "parent": n
        });
    return out;
}

function worst(row, rs, short, scale) {
    let mx = 0;
    let mn = Infinity;
    for (const it of row) {
        const a = it.size * scale;
        mx = Math.max(mx, a);
        mn = Math.min(mn, a);
    }
    const s2 = short * short;
    const r2 = rs * rs;
    return Math.max(s2 * mx / r2, r2 / (s2 * mn));
}

// Rows of near-square cells along the short side; out gets [item, x, y, w, h].
function squarify(list, x, y, w, h, out) {
    let total = list.reduce((s, c) => s + c.size, 0);
    let i = 0;
    while (i < list.length && w > 0.5 && h > 0.5 && total > 0) {
        const short = Math.min(w, h);
        const scale = w * h / total;
        let row = [list[i]];
        let rs = list[i].size * scale;
        let wr = worst(row, rs, short, scale);
        let j = i + 1;
        for (; j < list.length; j++) {
            const a = list[j].size * scale;
            const nr = row.concat(list[j]);
            const nw = worst(nr, rs + a, short, scale);
            if (nw > wr)
                break;
            row = nr;
            rs += a;
            wr = nw;
        }
        const th = rs / short;
        let off = 0;
        for (const it of row) {
            const len = it.size * scale / th;
            out.push(w >= h ? [it, x, y + off, th, len] : [it, x + off, y, len, th]);
            off += len;
        }
        if (w >= h) {
            x += th;
            w -= th;
        } else {
            y += th;
            h -= th;
        }
        total -= rs / scale;
        i = j;
    }
}

// Nested treemap: a dir big enough frames its children under a title band (hd); color = index of the top-level branch.
function layoutTree(n, x, y, w, h, depth, color, out) {
    const cells = [];
    squarify(kids(n, 0.012), x, y, w, h, cells);
    cells.forEach((cell, idx) => {
        const c = cell[0];
        const cw = cell[3];
        const ch = cell[4];
        const col = c.other ? -1 : depth === 0 ? idx : color;
        const dir = !!c.children && !c.other;
        const hd = dir && ch > 40 && cw > 48 ? 18 : 0;
        out.push({
            "node": c,
            "x": cell[1],
            "y": cell[2],
            "w": cw,
            "h": ch,
            "depth": depth,
            "col": col,
            "dir": dir,
            "hd": hd
        });
        if (dir && cw > 26 && ch > 26 && depth < 7)
            layoutTree(c, cell[1] + 3, cell[2] + (hd || 3), cw - 6, ch - (hd || 3) - 3, depth + 1, col, out);
    });
    return out;
}

// Rings: one per level, angle follows size; col = index of the top-level branch.
function layoutSun(n, a0, a1, depth, maxDepth, color, out) {
    const span = a1 - a0;
    let a = a0;
    kids(n, Math.min(0.6, 0.03 / Math.max(span, 1e-6))).forEach((c, idx) => {
        const s = n.size > 0 ? span * c.size / n.size : 0;
        const col = c.other ? -1 : depth === 1 ? idx : color;
        out.push({
            "node": c,
            "a0": a,
            "a1": a + s,
            "depth": depth,
            "col": col
        });
        if (c.children && !c.other && depth < maxDepth && s > 0.01)
            layoutSun(c, a, a + s, depth + 1, maxDepth, col, out);
        a += s;
    });
    return out;
}

// The arrows on the rings: the first ring's item next to from by d (-1 / 1), grouped crumbs left out; its first item when
// from is not on it, null when it is empty.
function ringStep(items, from, d) {
    const ring = items.filter(it => it.depth === 1 && !it.node.other);
    const at = ring.findIndex(it => it.node === from);
    const next = ring[at < 0 ? 0 : Math.max(0, Math.min(ring.length - 1, at + d))];
    return next ? next.node : null;
}

// The arrows on the list: index moved by d and kept on the list (0 on an empty one, where no item is).
function listStep(count, index, d) {
    return Math.max(0, Math.min(count - 1, index + d));
}

// A branch's color as hue, saturation and lightness (0..1): each top branch turned 0.13 from the base hue (the theme's
// primary, 0.72 when it has none), greyer and darker one level down; null for the grouped crumbs (i < 0).
function branchHsl(i, depth, light, baseHue) {
    if (i < 0)
        return null;
    return {
        "h": ((baseHue >= 0 ? baseHue : 0.72) + i * 0.13) % 1,
        "s": Math.max(0.45, 0.78 - depth * 0.06),
        "l": light - depth * 0.05
    };
}

// s cut with an ellipsis to fit max pixels, as width(text) measures them: "" under 12 px or when not one letter fits.
function fitText(width, s, max) {
    if (max < 12)
        return "";
    if (width(s) <= max)
        return s;
    let lo = 0;
    let hi = s.length;
    while (lo < hi) {
        const m = (lo + hi + 1) >> 1;
        if (width(s.slice(0, m) + "…") <= max)
            lo = m;
        else
            hi = m - 1;
    }
    return lo ? s.slice(0, lo) + "…" : "";
}

// shown[key] (born from grow(target) the first time) moved toward target by k (0..1) on each of props; moved while one of
// them was still more than d away. Returns {shown, moved}.
function easeTo(shown, key, target, props, k, d, grow) {
    let s = shown[key];
    if (!s) {
        s = grow(target);
        shown[key] = s;
    }
    let moved = false;
    for (const p of props) {
        const dv = target[p] - s[p];
        s[p] += dv * k;
        if (Math.abs(dv) > d)
            moved = true;
    }
    return {
        "shown": s,
        "moved": moved
    };
}
