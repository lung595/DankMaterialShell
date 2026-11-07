import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandWeather.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);

const T0 = new Date("2026-10-25T09:00").getTime();
const MIN = 60000;
function iso(i) {
    const d = new Date(T0 + i * 15 * MIN);
    const p = n => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}
// A forecast as WeatherService gives it: one entry per quarter from 9:00, rain in mm per 15 min.
function weather(rain, extra) {
    return {
        "available": true,
        "minutely15": rain.map((r, i) => Object.assign({
                "rawTime": iso(i),
                "rain": r,
                "snowfall": 0,
                "weatherCode": r > 0 ? 61 : 1,
                "visibility": 20000,
                "gust": 10,
                "feelsLike": 15
            }, extra ? extra(i) : {})),
        "hourlyForecast": []
    };
}
const at = (h, m) => new Date(`2026-10-25T${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`).getTime();
const plain = x => JSON.parse(JSON.stringify(x));

test("rain has four levels from mm/h: a few drops, light, heavy, very heavy", () => {
    const q = mmh => ({ "rain": mmh, "snow": 0, "code": 61 });
    assert.equal(C.levelOf("rain", q(0)), -1);
    assert.equal(C.levelOf("rain", q(0.2)), 0);
    assert.equal(C.levelOf("rain", q(0.5)), 1);
    assert.equal(C.levelOf("rain", q(2.4)), 1);
    assert.equal(C.levelOf("rain", q(2.5)), 2);
    assert.equal(C.levelOf("rain", q(7.6)), 3);
    assert.equal(C.rainLevel(0.4), 0);
    assert.equal(C.rainLevel(12), 3);
});

test("the other events: hail by code, storm by code or gusts, ice, fog by visibility, heat by feels-like or UV", () => {
    assert.equal(C.levelOf("hail", { "code": 96 }), 1);
    assert.equal(C.levelOf("hail", { "code": 99 }), 3);
    assert.equal(C.levelOf("hail", { "code": 95 }), -1);
    assert.equal(C.levelOf("storm", { "code": 95, "gust": 20 }), 1);
    assert.equal(C.levelOf("storm", { "code": 3, "gust": 80 }), 2);
    assert.equal(C.levelOf("storm", { "code": 3, "gust": 40 }), -1);
    assert.equal(C.levelOf("snow", { "code": 3, "snow": 0.5 }), 1);
    assert.equal(C.levelOf("snow", { "code": 67, "snow": 0 }), 2);
    assert.equal(C.levelOf("fog", { "code": 3, "visibility": 400 }), 1);
    assert.equal(C.levelOf("fog", { "code": 45, "visibility": null }), 0);
    assert.equal(C.levelOf("fog", { "code": 3, "visibility": 5000 }), -1);
    assert.equal(C.levelOf("heat", { "feels": 35, "uv": 2 }), 1);
    assert.equal(C.levelOf("heat", { "feels": 20, "uv": 10 }), 2);
    assert.equal(C.levelOf("heat", { "feels": 20, "uv": 3 }), -1);
});

test("quarters read the forecast in mm/h and take the hour's UV", () => {
    const w = weather([0, 1.5]);
    w.hourlyForecast = [{ "rawTime": "2026-10-25T09:00", "uv": 7 }];
    const qs = C.quarters(w);
    assert.equal(qs.length, 2);
    assert.equal(qs[1].rain, 6);
    assert.equal(qs[1].at, "09:15");
    assert.equal(qs[1].uv, 7);
    assert.equal(qs[1].t, at(9, 15));
    assert.deepEqual(plain(C.quarters(null)), []);
});

test("quarters read their times in the place's own time zone when it has one", () => {
    const w = weather([0, 0]);
    w.minutely15[1].rawTime = "2026-10-25T09:15";
    w.utcOffsetSeconds = -4 * 3600;
    assert.equal(C.quarters(w)[1].t, Date.parse("2026-10-25T13:15Z"));
});

test("an event is told 15 min before it starts, not earlier", () => {
    const qs = C.quarters(weather([0, 0, 0, 0, 0.6, 0.8, 0.2, 0]));
    const early = C.alert(qs, at(9, 44), ["rain"], null);
    assert.equal(early.ready, false);
    assert.equal(early.due, at(9, 45));
    const due = C.alert(qs, at(9, 45), ["rain"], null);
    assert.equal(due.ready, true);
    assert.equal(due.now, false);
    assert.equal(due.inMin, 15);
    assert.equal(qs[due.start].at, "10:00");
});

test("an event already there is told now, with its end and its peak", () => {
    const qs = C.quarters(weather([0.1, 0.6, 1.5, 0.4, 0, 0]));
    const a = C.alert(qs, at(9, 5), ["rain"], null);
    assert.equal(a.ready, true);
    assert.equal(a.now, true);
    assert.equal(a.start, 0);
    assert.equal(a.end, 4);
    assert.equal(qs[a.peak].at, "09:30");
    assert.equal(a.level, 2);
    assert.equal(a.endAt, "10:00");
});

test("a told episode keeps its quarters by time when the forecast reloads, and goes once over or without forecast", () => {
    const qs = C.quarters(weather([0.1, 0.6, 1.5, 0.4, 0, 0]));
    const told = C.pinned(qs, C.alert(qs, at(9, 5), ["rain"], null));
    // A reload a quarter later starts from 9:15.
    const later = qs.slice(1);
    const a = C.relocate(later, told, at(9, 20));
    assert.equal(later[a.peak].at, "09:30");
    assert.equal(a.start, 0);
    assert.equal(a.end, 3);
    assert.equal(C.relocate(later, told, at(10, 0)), null);
    assert.equal(C.relocate([], told, at(9, 20)), null);
});

test("only ticked events are told; the worst event of a quarter wins", () => {
    const qs = C.quarters(weather([0, 1, 1], i => i === 2 ? { "weatherCode": 99 } : {}));
    assert.equal(C.alert(qs, at(9, 0), ["snow"], null), null);
    assert.equal(C.alert(qs, at(9, 0), ["rain"], null).event, "rain");
    assert.equal(C.alert(qs, at(9, 0), ["rain", "hail"], null).event, "rain");
    assert.equal(C.alert(qs, at(9, 0), ["hail"], null).event, "hail");
    assert.equal(C.eventOf(qs[2], ["rain", "hail"]).event, "hail");
});

test("an episode told once is not told again while it goes on, the next one is", () => {
    const qs = C.quarters(weather([0.5, 0.5, 0.5, 0, 0, 0.5, 0.5, 0]));
    const first = C.alert(qs, at(9, 0), ["rain"], null);
    const seen = C.seenOf(qs, first);
    assert.equal(seen.end, at(9, 45));
    const later = C.alert(qs, at(9, 20), ["rain"], seen);
    assert.equal(qs[later.start].at, "10:15");
    assert.equal(later.ready, false);
    // A new forecast stretching the same episode further keeps it told.
    const longer = C.quarters(weather([0.5, 0.5, 0.5, 0.5, 0.5, 0, 0, 0]));
    assert.equal(C.alert(longer, at(9, 20), ["rain"], seen), null);
});

test("bars: eight quarters of 15 min from now, tinted by level, with now and end marks", () => {
    const qs = C.quarters(weather([0, 0.1, 0.5, 2, 1, 0, 0, 0, 0, 0]));
    const a = C.alert(qs, at(9, 5), ["rain"], null);
    const b = C.bars(qs, a, at(9, 5));
    assert.equal(b.bars.length, 8);
    assert.deepEqual(plain(b.bars.map(x => x.level)), [-1, 0, 1, 3, 2, -1, -1, -1]);
    assert.ok(b.bars[3].frac > b.bars[2].frac && b.bars[3].frac <= 1);
    assert.ok(Math.abs(b.now - 5 / 15 / 8) < 1e-9);
    assert.equal(b.end, 5 / 8);
    assert.equal(b.from, "09:00");
    // An end past the two hours has no mark.
    assert.equal(C.bars(C.quarters(weather(new Array(12).fill(1))), C.alert(C.quarters(weather(new Array(12).fill(1))), at(9, 0), ["rain"], null), at(9, 0)).end, -1);
});

test("missing: every event without a forecast, an event whose data never comes, none otherwise", () => {
    assert.deepEqual(plain(C.missing(null)), plain(C.EVENTS));
    assert.deepEqual(plain(C.missing({ "available": true, "minutely15": [] })), plain(C.EVENTS));
    assert.deepEqual(plain(C.missing(weather([0, 1]))), []);
    assert.deepEqual(plain(C.missing(weather([0, 1], () => ({ "visibility": null })))), []);
    assert.deepEqual(plain(C.missing(weather([0, 1], () => ({ "visibility": null, "weatherCode": null })))), ["hail", "fog"]);
    assert.deepEqual(plain(C.missing(weather([0, 1], () => ({ "rain": null })))), ["rain"]);
});

test("rows15: Open-Meteo's quarter arrays become one row a quarter, null where a value is missing", () => {
    const rows = C.rows15({ "time": ["2026-10-25T09:00", "2026-10-25T09:15"], "rain": [0.5, null], "wind_gusts_10m": [40] });
    assert.equal(rows.length, 2);
    assert.deepEqual(plain(rows[0]), { "rawTime": "2026-10-25T09:00", "rain": 0.5, "snowfall": null, "weatherCode": null, "visibility": null, "gust": 40, "feelsLike": null });
    assert.equal(rows[1].rain, null);
    assert.equal(rows[1].gust, null);
    assert.deepEqual(plain(C.rows15(undefined)), []);
});
