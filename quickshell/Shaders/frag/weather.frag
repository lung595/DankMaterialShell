#version 450

// The weather alert's sky, after the validated mockup's two canvas painters: rich = 0 is its draw() (the bubble's shape,
// the island while the alert arrives: density scales the counts by area), rich = 1 its drawRich() (the island grown into
// the alert's card, quieter and more detailed). Every particle is a pure function of the time, so a frame only sets
// uniforms. kind: 0 rain, 1 hail, 2 storm, 3 snow, 4 fog, 5 heat; level 0..3 its force; env how strongly it shows.
// To read alive rather than mechanical: each particle has its own speed, size and phase, and a new place each time it
// falls again; a few seconds' gusts sway the wind and make the density breathe; depth (far = slower, thinner, fainter);
// drops leave a streak along their fall (motion blur, so a low frame rate still reads), splash where they land.
// IslandKit.weatherSpeed bounds the fastest particle of each kind: keep it in step with the speeds here.
// Masked to a rounded rectangle, one radius per corner (top-left, top-right, bottom-right, bottom-left: a notch's top
// corners are square), a disc when they are half the size, soft by a pixel.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float kind;
    float level;
    float env;
    float density;
    float rich;
    vec4 radii;
    vec2 sizePx;
    vec4 fxColor;
    vec4 fx2Color;
    vec4 warnColor;
} ubuf;

// Per-level tables as vec4, read through at(): the GLSL 120 variant (NVIDIA's GL) refuses constant arrays.
const vec4 RAIN_N = vec4(4.0, 9.0, 16.0, 26.0);
const vec4 RAIN_SP = vec4(0.3, 0.75, 1.4, 1.9);
const vec4 RAIN_LEN = vec4(3.0, 4.0, 7.0, 9.0);
const vec4 RAIN_LEAN = vec4(0.1, 0.2, 0.3, 0.7);
const vec4 RAIN_A = vec4(0.8, 0.6, 0.8, 0.85);
const vec4 RAIN_RN = vec4(4.0, 8.0, 18.0, 30.0);
const vec4 FS = vec4(0.5, 0.8, 1.2, 1.7);
const vec4 SS = vec4(0.6, 0.85, 1.1, 1.4);

float at(vec4 v, int i) {
    return i <= 0 ? v.x : i == 1 ? v.y : i == 2 ? v.z : v.w;
}

vec4 acc = vec4(0.0);

// Source-over, as the canvas paints.
void over(vec4 c, float a) {
    a = clamp(a, 0.0, 1.0);
    acc = vec4(c.rgb, 1.0) * a + acc * (1.0 - a);
}

float rnd(float i, float k) {
    return fract(sin(i * 12.9898 + k * 78.233) * 43758.5453);
}

// Smooth 1D value noise, 0..1; its slope stays under 1.5 per unit.
float vnoise(float x) {
    float i = floor(x), f = fract(x);
    return mix(rnd(i, 31.0), rnd(i + 1.0, 31.0), f * f * (3.0 - 2.0 * f));
}

// The wind's gusts, 0..1, over several seconds (its slope under 1.5 * (0.65 * 0.23 + 0.35 * 0.61) per second).
float gust(float t) {
    return 0.65 * vnoise(t * 0.23) + 0.35 * vnoise(t * 0.61 + 17.0);
}

float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

// The distance to a segment and where along it (0 at a, 1 at b).
vec2 segAlong(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Coverage of a stroke or a dot of this half width at distance d.
float ink(float d, float halfWidth) {
    return clamp(halfWidth + 0.5 - d, 0.0, 1.0);
}

// A hailstone's height over its phase: it falls to the ground (h below its start) by 0.5, then bounces twice, each
// bounce `e` of the last one's speed (e <= 0.34 keeps both within the phase); its fastest is as it lands, 4 h a phase.
float hailY(float ph, float h, float e) {
    float g = 8.0 * h;
    if (ph < 0.5)
        return 0.5 * g * ph * ph;
    float q = ph - 0.5, v = 4.0 * h * e;
    if (q < e)
        return h - v * q + 0.5 * g * q * q;
    q -= e;
    v *= e;
    if (q < e * e)
        return h - v * q + 0.5 * g * q * q;
    return h;
}

// Rain: each drop falls at its own speed along the gusting wind, a streak fading to its tail, in one of the depths,
// shown or not as the shower breathes; heavy rain splashes where its near drops land, over a mist on the ground.
void drops(vec2 p, vec2 s, float t, float env, int l, float n, bool rich, bool splashes) {
    float lean0 = at(RAIN_LEAN, l);
    float lean = lean0 * (0.5 + gust(t));
    float breath = 0.45 + 0.55 * gust(t * 0.7 + 40.0);
    float lw = l >= 2 ? 0.6 : 0.5;
    // Blown out at the left, a drop comes back in at the right, both out of sight (the margin holds its longest streak);
    // more drops for the wider span, and for those out of sight below or faint far off, so the sky keeps its weight.
    float margin = lean0 * 1.5 * at(RAIN_LEN, l) * 1.4 + 2.0, span = s.x + 2.0 * margin;
    float count = min(80.0, ceil(n * 1.35 * span / s.x));
    for (int k = 0; k < 80; k++) {
        float i = float(k);
        if (i >= count)
            break;
        float z = rnd(i, 11.0);
        float len = at(RAIN_LEN, l) * mix(0.55, 1.0, z) * (rich ? 0.8 + rnd(i, 6.0) * 0.6 : 1.0);
        float v = at(RAIN_SP, l) * (0.85 + rnd(i, 1.0) * 0.35) * mix(0.6, 1.0, z) * (s.y + 14.0);
        // Its fall runs past the bottom, so the splash has time.
        float range = s.y + 6.0 + len;
        float u = t * v / range + rnd(i, 2.0);
        float fall = floor(u), pos = fract(u) * range;
        // A new place each fall, within its own slice.
        float x0 = (i + rnd(i + fall * 7.31, 3.0)) / count * span;
        vec2 head = vec2(mod(x0 - lean * pos, span) - margin, pos - 2.0);
        float dx = p.x - head.x;
        if (dx < -9.0 || dx > len * lean + 9.0)
            continue;
        float shown = clamp((breath - rnd(i, 12.0) * 0.8) * 5.0, 0.0, 1.0);
        float a = env * shown * mix(0.65, 1.0, z) * (rich ? at(RAIN_A, l) * (0.4 + rnd(i, 7.0) * 0.6) : at(RAIN_A, l));
        vec2 da = segAlong(p, head + vec2(lean, -1.0) * len, head);
        over(ubuf.fxColor, a * mix(0.55, 1.0, da.y) * ink(da.x, lw * mix(0.75, 1.0, z)));
        float hit = s.y + 0.5;
        if (splashes && z > 0.5 && pos > hit) {
            // A flat ring and two droplets thrown up.
            float ph = (pos - hit) / (range - hit);
            float x = mod(x0 - lean * hit, span) - margin, r = 1.0 + ph * 3.5;
            float sa = a * (1.0 - ph) * 0.7;
            vec2 c = vec2(x, s.y - 2.0);
            vec2 q = (p - c) / vec2(r * 1.8, r * 0.55);
            over(ubuf.fxColor, sa * ink(abs(length(q) - 1.0) * r * 0.55, 0.4));
            float dy = s.y - 2.0 - ph * (1.0 - ph) * 10.0;
            over(ubuf.fxColor, sa * ink(length(p - vec2(x - r, dy)), 0.8));
            over(ubuf.fxColor, sa * ink(length(p - vec2(x + r * 0.8, dy - 1.0)), 0.7));
        }
    }
    if (splashes) {
        float mist = smoothstep(s.y - 7.0, s.y, p.y) * (0.55 + 0.45 * vnoise(p.x * 0.08 + t * 0.6));
        over(ubuf.fxColor, env * (l >= 3 ? 0.16 : 0.1) * breath * mist);
    }
}

void lightning(vec2 p, vec2 s, float x0, float nn, int steps, float swing, float key, float a, float halfWidth) {
    float d = 1e3;
    vec2 from = vec2(x0, 0.0);
    for (int k = 1; k <= 5; k++) {
        if (k > steps)
            break;
        float i = float(k);
        vec2 to = vec2(x0 + (mod(i, 2.0) == 1.0 ? -swing : swing) * (0.5 + rnd(nn, i + key)), s.y * i / float(steps));
        d = min(d, seg(p, from, to));
        from = to;
    }
    over(ubuf.warnColor, a * ink(d, halfWidth));
}

// The storm's flash in this `cell` seconds: at a moment of its own, now and then none, a flicker after it; 0 when dark.
float flash(float t, float cell, out float nn) {
    nn = floor(t / cell);
    if (rnd(nn, 9.0) > 0.8)
        return 0.0;
    float q = mod(t, cell) - 0.2 - rnd(nn, 10.0) * (cell - 1.0);
    float again = 0.2 + rnd(nn, 11.0) * 0.12;
    if (q > 0.0 && q < 0.12)
        return 1.0 - q * 3.0;
    if (q > again && q < again + 0.1 + rnd(nn, 12.0) * 0.06)
        return 0.7;
    return 0.0;
}

// Hail: stones of their own size and speed falling in, streaked as they speed up, bouncing twice to rest and fading.
void hail(vec2 p, vec2 s, float t, float env, int lv, float n, bool rich) {
    for (int k = 0; k < 48; k++) {
        float i = float(k);
        if (i >= n)
            break;
        float z = rnd(i, 11.0);
        float rate = (rich ? 0.7 : 0.9) * mix(0.8, 1.0, z) + rnd(i, 1.0) * 0.4;
        rate *= at(SS, lv);
        float u = t * rate + rnd(i, 2.0);
        float fall = floor(u), ph = fract(u);
        float key = i + fall * 5.17;
        float x = rnd(key, 3.0) * s.x + (ph > 0.5 ? (ph - 0.5) * 14.0 * (rnd(key, 4.0) - 0.5) : 0.0);
        if (abs(p.x - x) > 6.0)
            continue;
        vec2 c = vec2(x, hailY(ph, s.y, 0.22 + rnd(i, 13.0) * 0.12) - 3.0);
        float r = (rich ? 1.4 + rnd(i, 5.0) * 1.8 : 1.7) * mix(0.75, 1.0, z);
        float blur = ph < 0.5 ? min(8.0 * s.y * ph * rate * 0.025, 2.0 * r) : 0.0;
        float a = env * (rich ? 0.6 : 0.9) * mix(0.65, 1.0, z) * (1.0 - smoothstep(0.88, 1.0, ph));
        over(ubuf.fx2Color, a * ink(seg(p, c - vec2(0.0, blur), c), r));
        if (rich && ph > 0.5 && ph < 0.57) {
            vec2 g = vec2(x, s.y - 2.0);
            float ring = abs(length(p - g) - (2.0 + (ph - 0.5) * 60.0));
            over(ubuf.fx2Color, env * 0.5 * (1.0 - (ph - 0.5) / 0.07) * ink(ring, 0.4) * step(p.y, g.y));
        }
    }
}

// Snow: flakes in depth, each drifting on its own two eddies and the gusts; the rich sky turns some into crystals.
void snow(vec2 p, vec2 s, float t, float env, int lv, float n, bool rich) {
    float wind = 8.0 * (gust(t + 70.0) - 0.5);
    for (int k = 0; k < 64; k++) {
        float i = float(k);
        if (i >= n)
            break;
        float z = rnd(i, 11.0);
        float rate = ((rich ? 0.1 : 0.18) + rnd(i, 1.0) * 0.12) * at(SS, lv) * mix(0.6, 1.0, z);
        float u = t * rate + rnd(i, 2.0);
        float fall = floor(u);
        float y = fract(u) * (s.y + 10.0) - 5.0;
        float sway = (2.5 + 3.5 * rnd(i, 6.0)) * mix(0.6, 1.0, z) * sin(t * (0.7 + 0.6 * rnd(i, 4.0)) + rnd(i, 8.0) * 6.28)
            + 1.5 * sin(t * (1.9 + 0.8 * rnd(i, 14.0)) + y * 0.12 + i);
        vec2 c = vec2(rnd(i + fall * 3.7, 3.0) * s.x + sway + wind * mix(0.5, 1.0, z), y);
        float depth = mix(0.7, 1.0, z);
        if (rich) {
            float r = (0.9 + rnd(i, 5.0) * 3.0) * depth;
            float a = env * (0.4 + rnd(i, 7.0) * 0.35) * mix(0.5, 1.0, z);
            if (rnd(i, 8.0) > 0.62) {
                // A six-branched crystal.
                float d = 1e3;
                for (int b = 0; b < 3; b++) {
                    float ang = t * 0.4 + i + float(b) * 1.0472;
                    vec2 dir = vec2(cos(ang), sin(ang)) * r * 1.4;
                    d = min(d, seg(p, c - dir, c + dir));
                }
                over(ubuf.fx2Color, a * ink(d, 0.4));
            } else {
                over(ubuf.fx2Color, a * ink(length(p - c), r * 0.6));
            }
        } else {
            over(ubuf.fx2Color, env * 0.9 * mix(0.6, 1.0, z) * ink(length(p - c), (1.0 + rnd(i, 5.0) * 1.1) * depth));
        }
    }
}

// A fog band at height y, `th` thick, whose edges undulate and swell as it drifts: 0..1 at p.
float bank(vec2 p, float t, float y, float th, float i) {
    float yc = y + (vnoise(p.x * 0.04 + t * 0.25 + i * 7.0) - 0.5) * th * 0.9;
    float spread = th * (0.35 + 0.25 * vnoise(p.x * 0.03 - t * 0.18 + i * 3.0));
    return 1.0 - smoothstep(spread * 0.3, spread, abs(p.y - yc));
}

// Heat: a ripple line in the air at height y, drifting up and down, swelling, breaking where the air is calm.
void ripple(vec2 p, vec2 s, float t, float tt, float i, float a) {
    float amp = (2.0 + i * 0.4) * (0.7 + 0.6 * vnoise(t * 0.4 + i * 5.0));
    float arg = p.x * 0.05 + tt * (1.1 + i * 0.17) + i * 1.7;
    float y = s.y * (0.12 + i * 0.19) + 3.0 * (vnoise(t * 0.3 + i * 9.0) - 0.5) + sin(arg) * amp;
    float slope = cos(arg) * 0.05 * amp;
    float broken = smoothstep(0.25, 0.6, vnoise(p.x * 0.04 - tt * 0.2 + i * 3.0));
    over(ubuf.warnColor, a * broken * ink(abs(p.y - y) / sqrt(1.0 + slope * slope), 0.5));
}

void heat(vec2 p, vec2 s, float t, float env, int lv, float n, bool rich) {
    float tt = t * at(SS, lv);
    float glow = 0.1 + 0.05 * (2.0 * gust(t * 0.8 + 60.0) - 1.0) + (rich ? 0.02 : 0.04) + (rich ? 0.04 : 0.03) * float(lv);
    over(ubuf.warnColor, env * glow * clamp(1.0 - length(p - vec2(s.x * 0.5, s.y)) / max(s.x, s.y), 0.0, 1.0));
    if (rich) {
        for (int k = 0; k < 5; k++)
            ripple(p, s, t, tt, float(k), env * 0.28);
    } else {
        ripple(p, s, t, tt, 1.0, env * 0.16);
        ripple(p, s, t, tt, 3.0, env * 0.16);
    }
    for (int k = 0; k < 48; k++) {
        float i = float(k);
        if (i >= n)
            break;
        float u = t * (0.2 + rnd(i, 1.0) * 0.15) * at(SS, lv) + rnd(i, 2.0);
        float ph = fract(u);
        vec2 c = vec2(rnd(i + floor(u) * 4.3, 3.0) * s.x + sin(t * (1.5 + 1.5 * rnd(i, 4.0)) + i * 2.1) * 2.0, s.y - ph * s.y);
        over(ubuf.warnColor, env * (1.0 - ph) * (rich ? 0.6 : 0.9) * ink(length(p - c), 1.2 * (0.8 + 0.4 * rnd(i, 5.0))));
    }
}

void paintDraw(vec2 p, vec2 s, float t, float env, int kind, int lv, float m) {
    if (kind == 0 || kind == 2) {
        int l = kind == 2 ? (lv < 1 ? 1 : lv) : lv;
        drops(p, s, t, env * (kind == 2 ? 0.75 : 1.0), l, l == 0 ? 4.0 : floor(at(RAIN_N, l) * m + 0.5), false, l >= 2);
    }
    if (kind == 2) {
        float nn;
        float f = flash(t, 2.4, nn);
        if (f > 0.0) {
            over(ubuf.warnColor, env * f * 0.22);
            lightning(p, s, s.x * (0.2 + rnd(nn, 4.0) * 0.6), nn, 4, 4.0, 0.0, env * f, 0.75);
        }
    }
    if (kind == 1)
        hail(p, s, t, env, lv, floor(9.0 * m * at(FS, lv) + 0.5), false);
    if (kind == 3)
        snow(p, s, t, env, lv, floor(12.0 * m * at(FS, lv) + 0.5), false);
    if (kind == 4) {
        float tt = t * at(SS, lv);
        for (int k = 0; k < 3; k++) {
            float i = float(k);
            float x = (fract(tt * 0.045 * (1.0 + i * 0.35) + rnd(i, 1.0)) * 1.8 - 0.5) * s.x;
            float across = 1.0 - smoothstep(0.0, s.x * 0.55, abs(p.x - x));
            float breath = 0.8 + 0.4 * gust(t * 0.5 + i * 13.0);
            over(ubuf.fx2Color, env * (0.16 + 0.06 * float(lv)) * breath * across * bank(p, tt, s.y * (0.2 + i * 0.3), s.y * 0.5, i));
        }
    }
    if (kind == 5)
        heat(p, s, t, env, lv, floor(8.0 * m * at(FS, lv) + 0.5), false);
}

void paintRich(vec2 p, vec2 s, float t, float env, int kind, int lv) {
    if (kind == 0 || kind == 2) {
        int l = kind == 2 ? (lv < 1 ? 1 : lv) : lv;
        drops(p, s, t, env * (kind == 2 ? 0.8 : 1.0), l, at(RAIN_RN, l), true, l >= 2);
    }
    if (kind == 2) {
        float nn;
        float f = flash(t, 3.2, nn);
        if (f > 0.0) {
            over(ubuf.warnColor, env * f * 0.16);
            // The bolt stays in the margins, clear of the text.
            float x = rnd(nn, 4.0) < 0.5 ? 5.0 + rnd(nn, 5.0) * 8.0 : s.x - 13.0 + rnd(nn, 5.0) * 8.0;
            lightning(p, s, x, nn, 5, 5.0, 6.0, env * f * 0.9, 0.8);
        }
    }
    if (kind == 1)
        hail(p, s, t, env, lv, min(24.0, floor(12.0 * at(FS, lv) + 0.5)), true);
    if (kind == 3)
        snow(p, s, t, env, lv, min(32.0, floor(18.0 * at(FS, lv) + 0.5)), true);
    if (kind == 4) {
        // Banks in depth: the far ones large, slow and pale.
        float tt = t * at(SS, lv);
        for (int k = 0; k < 6; k++) {
            float i = float(k), d = i / 5.0;
            float len = s.x * (1.2 - 0.5 * d);
            float x = (fract(tt * (0.012 + 0.04 * d) + rnd(i, 1.0)) * 1.8 - 0.4) * s.x;
            float across = 1.0 - smoothstep(0.0, len * 0.55, abs(p.x - x));
            float th = s.y * (0.34 - 0.12 * d);
            float breath = 0.8 + 0.4 * gust(t * 0.5 + i * 13.0);
            over(ubuf.fx2Color, env * (0.1 + 0.14 * d) * (0.45 + 0.2 * float(lv)) * breath * across * bank(p, tt, s.y * (0.1 + 0.16 * i) + th * 0.5, th, i));
        }
    }
    if (kind == 5)
        heat(p, s, t, env, lv, min(17.0, floor(10.0 * at(FS, lv) + 0.5)), true);
}

void main() {
    vec2 s = ubuf.sizePx;
    vec2 p = qt_TexCoord0 * s;
    int lv = int(clamp(ubuf.level, 0.0, 3.0));
    int kind = int(ubuf.kind + 0.5);
    if (ubuf.rich > 0.5)
        paintRich(p, s, ubuf.time, ubuf.env, kind, lv);
    else
        paintDraw(p, s, ubuf.time, ubuf.env, kind, lv, clamp(ubuf.density, 1.0, 3.0));

    vec2 d = p - s * 0.5;
    float corner = d.x < 0.0 ? (d.y < 0.0 ? ubuf.radii.x : ubuf.radii.w) : (d.y < 0.0 ? ubuf.radii.y : ubuf.radii.z);
    float r = min(corner, min(s.x, s.y) * 0.5);
    vec2 q = abs(d) - s * 0.5 + r;
    float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    fragColor = acc * clamp(0.5 - sd, 0.0, 1.0) * ubuf.qt_Opacity;
}
