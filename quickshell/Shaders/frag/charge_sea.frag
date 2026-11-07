#version 450

// The charge face's sea (his mockup B "Expressive" of 29/10, maquettes-charge-2910.html): an organic surface of three
// incommensurate swells with a slow slosh and a breath on its height, a paler back wave a little higher, the front
// shaded from the level's colour to its deep; bubbles that rise and burst into rings at the surface; over it the bolt's
// Material cookie, its nine lobes dug by the power, turning. Every shape is a pure function of the uniforms the sea's
// clock sets (phase, breath, rise, turn): a frame only sets numbers, nothing is allocated. Lengths follow the mockup's
// 84 px high sea. Cut to the well's inner rounded rectangle, soft by a pixel. K15: GLSL 120 safe (no constant arrays,
// no integer %, no integer min/max/clamp/abs).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 sizePx;
    float radius;
    float line;
    float amp;
    float phase;
    float breath;
    float rise;
    float bubbles;
    float markR;
    float markDepth;
    float markTurn;
    vec4 liqColor;
    vec4 deepColor;
    vec4 bubColor;
    vec4 markColor;
} ubuf;

const float TAU = 6.2831853;
const float MOCK_H = 84.0;
const float LOBES = 9.0;
// The shader's own bound of bubbles: IslandCharge.bubbles never asks more.
const int BUBBLE_MAX = 20;

vec4 acc = vec4(0.0);

// Source-over, as the canvas paints: the colour's own alpha times the coverage a.
void over(vec4 c, float a) {
    a = clamp(a * c.a, 0.0, 1.0);
    acc = vec4(c.rgb, 1.0) * a + acc * (1.0 - a);
}

float rnd(float i, float k) {
    return fract(sin(i * 12.9898 + k * 78.233) * 43758.5453);
}

// The mockup's surf(): the surface's height at u (0 left wall, 1 right) for layer 0 (front) or 1 (back).
float surf(float u, float layer) {
    float t = ubuf.phase + layer * 1.7;
    float a = ubuf.amp * (0.78 + 0.22 * sin(ubuf.breath + layer * 0.9));
    return a * (0.52 * sin(u * TAU * 0.9 + t) + 0.30 * sin(u * TAU * 2.1 - t * 1.63 + 1.3 + layer)
            + 0.18 * sin(u * TAU * 3.7 + t * 2.71 + 0.4))
        + ubuf.amp * 0.5 * sin(ubuf.phase * 0.31 + layer * 0.6) * (u - 0.5);
}

void main() {
    vec2 s = ubuf.sizePx;
    vec2 p = qt_TexCoord0 * s;
    float px = s.y / MOCK_H;
    float u = p.x / max(1.0, s.x);
    float depth = s.y - ubuf.line;

    if (depth > 0.2 * px) {
        // The back wave, paler and a little higher.
        float yb = ubuf.line - 2.4 * px + 0.85 * surf(u, 1.0);
        over(ubuf.liqColor, 0.28 * clamp(p.y - yb + 0.5, 0.0, 1.0));
        // The front, from the level's colour at its crest to the deep at the floor.
        float yf = ubuf.line + surf(u, 0.0);
        float front = clamp(p.y - yf + 0.5, 0.0, 1.0);
        float top = ubuf.line - 4.0 * px;
        over(mix(ubuf.liqColor, ubuf.deepColor, clamp((p.y - top) / max(1.0, s.y - top), 0.0, 1.0)), front);
        // The bubbles: each its lane, size and pace; it rises from under the floor to the surface (seen inside the
        // front only), then bursts there into a ring that widens and fades.
        float pop = 0.3 * s.y;
        float cycle = depth + pop;
        for (int i = 0; i < BUBBLE_MAX; i++) {
            float fi = float(i);
            if (fi >= ubuf.bubbles)
                break;
            float h1 = rnd(fi, 1.0);
            float r = (0.8 + 2.0 * h1 * h1) * px;
            float v = (0.7 + 0.6 * rnd(fi, 2.0)) * (0.6 + 0.3 * r / px);
            float bx = s.x * (0.075 + 0.85 * rnd(fi, 3.0));
            float c = mod(ubuf.rise * v + rnd(fi, 4.0) * cycle, cycle);
            if (c < depth) {
                vec2 b = vec2(bx + 1.2 * px * sin(ubuf.breath + fi), s.y + r - c);
                over(ubuf.bubColor, front * clamp(r - length(p - b) + 0.5, 0.0, 1.0));
            } else if (depth > 3.0 * px) {
                float k = (c - depth) / pop;
                vec2 b = vec2(bx, ubuf.line + surf(bx / max(1.0, s.x), 0.0));
                float ring = (1.0 + 5.0 * k) * px;
                over(ubuf.bubColor, (1.0 - k) * 0.8 * clamp(1.0 - abs(length(p - b) - ring), 0.0, 1.0));
            }
        }
    }

    // The bolt's mark: a cookie r = r0 (1 + k cos(n (a - turn))), its outer radius markR.
    vec2 d = p - s * 0.5;
    float k = ubuf.markDepth;
    float r0 = ubuf.markR / (1.0 + k);
    float edge = r0 * (1.0 + k * cos(LOBES * (atan(d.y, d.x) - ubuf.markTurn)));
    over(ubuf.markColor, clamp(edge - length(d) + 0.5, 0.0, 1.0));

    float cr = min(ubuf.radius, min(s.x, s.y) * 0.5);
    vec2 q = abs(d) - s * 0.5 + cr;
    float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - cr;
    fragColor = acc * clamp(0.5 - sd, 0.0, 1.0) * ubuf.qt_Opacity;
}
