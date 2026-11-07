.pragma library

// The island's weather alert, read from WeatherService's 15 min forecast only (Open-Meteo minutely_15, in the same request
// DMS already makes). An event is told 15 min before its first quarter, or "now" when it is already there; one episode
// (the quarters in a row where it lasts) is told once. Levels 0..3 say its force; -1 = not there.
// A4: this bubble's pure logic, tested by vm (tests/island-weather.test.mjs).

// Worst first: a quarter with several events is told as the worst ticked one.
var EVENTS = ["hail", "storm", "snow", "rain", "fog", "heat"];
var QUARTER_MS = 900000;
var LEAD_MS = QUARTER_MS;
var BARS = 8;

// Rain in mm/h: a few drops, light from 0.5, heavy from 2.5, very heavy from 7.6 (AMS rates).
var RAIN = [0.5, 2.5, 7.6];
// Snow in cm/h; strong wind gusts in km/h (from 62, gale); visibility in m (fog under 1 km); feels-like in °C; UV index.
var SNOW = [0.5, 1.5, 3];
var GUST = [62, 75, 89];
var FOG = [1000, 500, 200, 100];
var HEAT = [30, 34, 37, 40];
var UV = [8, 9, 10, 11];

function num(v) {
    return typeof v === "number" && isFinite(v) ? v : null;
}

// Index of the last step a value reaches, -1 under the first.
function stepOf(v, steps) {
    var n = -1;
    for (var i = 0; i < steps.length; i++)
        if (v !== null && v >= steps[i])
            n = i;
    return n;
}

function rainLevel(mmh) {
    return mmh > 0 ? 1 + stepOf(mmh, RAIN) : -1;
}

function freezing(code) {
    return code === 56 || code === 57 || code === 66 || code === 67;
}

function levelOf(event, q) {
    var code = q.code;
    switch (event) {
    case "hail":
        return code === 99 ? 3 : code === 96 ? 1 : -1;
    case "storm":
        return Math.max(code >= 95 ? 1 : -1, stepOf(num(q.gust), GUST) < 0 ? -1 : 1 + stepOf(num(q.gust), GUST));
    case "snow":
        return Math.max(freezing(code) ? (code === 57 || code === 67 ? 2 : 1) : -1, q.snow > 0 ? 1 + stepOf(q.snow, SNOW) : -1);
    case "rain":
        return rainLevel(q.rain);
    case "fog":
        var v = num(q.visibility), n = -1;
        for (var i = 0; i < FOG.length; i++)
            if (v !== null && v < FOG[i])
                n = i;
        return Math.max(code === 45 || code === 48 ? 0 : -1, n);
    case "heat":
        return Math.max(stepOf(num(q.feels), HEAT), stepOf(num(q.uv), UV));
    }
    return -1;
}

// The measure a bar and the card's line show, and its bar height (0..1).
function measure(event, q) {
    switch (event) {
    case "storm":
        return { "value": q.gust ?? 0, "unit": "kmh", "frac": (q.gust ?? 0) / 100 };
    case "snow":
        return { "value": q.snow ?? 0, "unit": "cmh", "frac": (q.snow ?? 0) / 4 };
    case "fog":
        var v = q.visibility ?? 3000;
        return { "value": v, "unit": "m", "frac": (3000 - Math.min(v, 3000)) / 3000 };
    case "heat":
        return stepOf(num(q.uv), UV) > stepOf(num(q.feels), HEAT) ? { "value": q.uv, "unit": "uv", "frac": q.uv / 12 } : { "value": q.feels ?? 0, "unit": "c", "frac": ((q.feels ?? 20) - 20) / 25 };
    }
    // Rain and hail: the rain rate.
    return { "value": q.rain ?? 0, "unit": "mmh", "frac": (q.rain ?? 0) / 10 };
}

// The worst ticked event of a quarter, or null.
function eventOf(q, ticked) {
    for (var i = 0; i < EVENTS.length; i++) {
        var e = EVENTS[i];
        if (ticked.indexOf(e) >= 0) {
            var l = levelOf(e, q);
            if (l >= 0)
                return { "event": e, "level": l };
        }
    }
    return null;
}

// Open-Meteo's minutely_15 (one array per field) as WeatherService keeps it: one row a quarter for the next six hours,
// null where the model says nothing.
function rows15(m15) {
    var src = m15 || {};
    var times = src.time || [];
    var at = function (key, i) {
        return num(src[key] ? src[key][i] : null);
    };
    var out = [];
    for (var i = 0; i < times.length; i++)
        out.push({
            "rawTime": times[i],
            "rain": at("rain", i),
            "snowfall": at("snowfall", i),
            "weatherCode": at("weather_code", i),
            "visibility": at("visibility", i),
            "gust": at("wind_gusts_10m", i),
            "feelsLike": at("apparent_temperature", i)
        });
    return out;
}

// WeatherService's quarters, rates per hour, with the UV of their hour (Open-Meteo gives it hourly only). Their times are
// the place's local time, with no offset: read through the place's UTC offset when there is one, as the machine's
// local time otherwise.
function quarters(weather) {
    var list = weather && weather.minutely15 || [];
    var offset = weather && typeof weather.utcOffsetSeconds === "number" ? weather.utcOffsetSeconds : null;
    var uv = {};
    var hours = weather && weather.hourlyForecast || [];
    for (var h = 0; h < hours.length; h++)
        uv[String(hours[h].rawTime).slice(0, 13)] = num(hours[h].uv);
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var m = list[i];
        var rain = num(m.rain), snow = num(m.snowfall);
        out.push({
            "t": offset === null ? new Date(m.rawTime).getTime() : Date.parse(m.rawTime + "Z") - offset * 1000,
            "at": String(m.rawTime).slice(11, 16),
            "rain": rain === null ? null : rain * 4,
            "snow": snow === null ? null : snow * 4,
            "code": num(m.weatherCode),
            "visibility": num(m.visibility),
            "gust": num(m.gust),
            "feels": num(m.feelsLike),
            "uv": uv[String(m.rawTime).slice(0, 13)] ?? null
        });
    }
    return out;
}

function current(qs, nowMs) {
    var c = 0;
    for (var i = 0; i < qs.length; i++)
        if (qs[i].t <= nowMs)
            c = i;
    return c;
}

function addQuarter(at) {
    var m = (Number(at.slice(0, 2)) * 60 + Number(at.slice(3, 5)) + 15) % 1440;
    return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
}

// The next episode of a ticked event from now, skipping the one already told (seen: { event, end }), or null.
// ready: its time to be told has come (15 min before, or now); due: when it will be.
function alert(qs, nowMs, ticked, seen) {
    if (!qs || qs.length === 0)
        return null;
    var c = current(qs, nowMs), skipping = false;
    for (var i = c; i < qs.length; i++) {
        var ev = eventOf(qs[i], ticked);
        if (seen && ev && ev.event === seen.event && (qs[i].t < seen.end || skipping)) {
            skipping = true;
            continue;
        }
        skipping = false;
        if (!ev)
            continue;
        var end = i, peak = i, best = -1;
        while (end < qs.length && levelOf(ev.event, qs[end]) >= 0) {
            var f = measure(ev.event, qs[end]).frac;
            if (f > best) {
                best = f;
                peak = end;
            }
            end++;
        }
        var due = qs[i].t - LEAD_MS;
        return {
            "event": ev.event,
            "start": i,
            "end": end,
            "peak": peak,
            "level": levelOf(ev.event, qs[peak]),
            "ice": ev.event === "snow" && freezing(qs[peak].code),
            "due": due,
            "ready": nowMs >= due,
            "now": qs[i].t <= nowMs,
            "inMin": Math.max(0, Math.round((qs[i].t - nowMs) / 60000)),
            "endAt": end < qs.length ? qs[end].at : addQuarter(qs[qs.length - 1].at),
            "endT": end < qs.length ? qs[end].t : qs[qs.length - 1].t + QUARTER_MS
        };
    }
    return null;
}

// The episode as told, pinned by time: a reload of the forecast starts it again from the current quarter, so its
// indices would point at other quarters.
function pinned(qs, a) {
    return a ? Object.assign({}, a, { "startT": qs[a.start].t, "peakT": qs[a.peak].t }) : null;
}

// A pinned episode with its indices found again in the current forecast: started already, it starts at the first
// quarter; a peak gone by is -1. null once it is over or when there is no forecast (weather off, a failed reload).
function relocate(qs, a, nowMs) {
    if (!a || !qs || qs.length === 0 || nowMs >= a.endT)
        return null;
    var at = function (t) {
        for (var i = 0; i < qs.length; i++)
            if (qs[i].t >= t)
                return i;
        return qs.length;
    };
    var peak = at(a.peakT);
    return Object.assign({}, a, {
        "start": Math.min(at(a.startT), qs.length - 1),
        "peak": peak < qs.length && qs[peak].t === a.peakT ? peak : -1,
        "end": at(a.endT)
    });
}

// What to remember of a told episode.
function seenOf(qs, a) {
    return a ? { "event": a.event, "end": a.endT } : null;
}

// The card's chart: BARS quarters from the current one, the alert's event at each (level, height), the now and end marks as
// fractions of the width (end -1 when past the chart).
function bars(qs, a, nowMs) {
    var c = current(qs, nowMs), out = [];
    for (var i = 0; i < BARS; i++) {
        var q = qs[c + i];
        var l = q && a ? levelOf(a.event, q) : -1;
        out.push({ "level": l, "frac": l < 0 ? 0 : Math.max(0.08, Math.min(1, measure(a.event, q).frac)) });
    }
    var e = a ? a.end - c : BARS + 1;
    return {
        "bars": out,
        "now": qs.length ? Math.max(0, Math.min(1, (nowMs - qs[c].t) / QUARTER_MS)) / BARS : 0,
        "end": e <= BARS ? e / BARS : -1,
        "from": qs.length ? qs[c].at : ""
    };
}

// Events the forecast cannot tell: all without a 15 min forecast, else those whose data never comes.
function missing(weather) {
    var qs = weather && weather.available ? quarters(weather) : [];
    if (qs.length === 0)
        return EVENTS.slice();
    function none(keys) {
        return qs.every(q => keys.every(k => q[k] === null));
    }
    var need = {
        "hail": ["code"],
        "storm": ["code", "gust"],
        "snow": ["code", "snow"],
        "rain": ["rain"],
        "fog": ["code", "visibility"],
        "heat": ["feels", "uv"]
    };
    return EVENTS.filter(e => none(need[e]));
}
