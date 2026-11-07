pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandWeather.js" as IslandWeather

// The weather alert (machine side, kind "weatheralert"): the next ticked event (Settings > Weather > Island alerts), told 15 min
// before it starts or now, read from WeatherService's 15 min forecast only. It never adds a reference: no request of its
// own, nothing while no weather widget keeps the service fetching. One timer, armed for
// the next due time only; nothing runs between forecasts.
// B9: coded step by step (source, card); B2: machine side.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    // The island's "weatheralert" face first, else the machine bubble (IslandBarHost.playMachine).
    signal arrived

    readonly property var weather: SettingsData.weatherEnabled ? WeatherService.weather : null
    readonly property var quarters: IslandWeather.quarters(root.weather)
    readonly property var gaps: IslandWeather.missing(root.weather)
    readonly property var ticked: (SettingsData.islandWeatherAlerts ?? []).filter(e => root.gaps.indexOf(e) < 0)
    property real nowMs: Date.now()
    // The last episode told ({ event, end }), so it is told once.
    property var seen: null
    readonly property var next: root.enabled ? IslandWeather.alert(root.quarters, root.nowMs, root.ticked, root.seen) : null
    // The alert on show, as it was told.
    property var shown: null
    // A due time is never armed sooner than this: a forecast a moment late still lands once.
    readonly property int minDueMs: 1000
    // While an alert is on show, the clock moves at its next step: each minute of its "in 15 min" (rounded, as shown),
    // its start (it turns to now), then its end (the episode is over and leaves the show). Nothing runs in between.
    readonly property real shownStepT: !root.shown ? -1 : root.nowMs < root.shown.startT ? root.minuteStep(root.shown.startT) : root.shown.endT
    function minuteStep(startT) {
        return Math.min(startT, startT - (Math.round((startT - root.nowMs) / 60000) - 0.5) * 60000);
    }
    onShownStepTChanged: {
        shownStep.stop();
        if (root.shownStepT < 0)
            return;
        shownStep.interval = Math.max(root.minDueMs, root.shownStepT - Date.now());
        shownStep.start();
    }

    onQuartersChanged: {
        root.nowMs = Date.now();
        // Over, or gone from the forecast (weather off, a failed reload): nothing is on show any more.
        if (!IslandWeather.relocate(root.quarters, root.shown, root.nowMs))
            root.shown = null;
    }
    onNextChanged: {
        due.stop();
        if (!root.next)
            return;
        if (!root.next.ready) {
            due.interval = Math.max(root.minDueMs, root.next.due - root.nowMs);
            due.start();
            return;
        }
        // The island's face, else the bubble when bubbles are on: IslandBarHost.playMachine decides.
        root.shown = IslandWeather.pinned(root.quarters, root.next);
        root.seen = IslandWeather.seenOf(root.quarters, root.next);
        root.arrived();
    }

    property Timer due: Timer {
        repeat: false
        onTriggered: root.nowMs = Date.now()
    }

    property Timer shownStep: Timer {
        repeat: false
        onTriggered: {
            root.nowMs = Date.now();
            if (!IslandWeather.relocate(root.quarters, root.shown, root.nowMs))
                root.shown = null;
        }
    }

    function icon(a) {
        switch (a.event) {
        case "hail":
            return "weather_hail";
        case "storm":
            return "thunderstorm";
        case "snow":
            return a.ice ? "ac_unit" : "weather_snowy";
        case "fog":
            return "foggy";
        case "heat":
            return "sunny";
        }
        return "rainy";
    }

    function name(a, unit) {
        switch (a.event) {
        case "hail":
            return [
                I18n.tr("Hail risk", "island weather alert"),
                I18n.tr("Hail", "island weather alert"),
                I18n.tr("Hail", "island weather alert"),
                I18n.tr("Heavy hail", "island weather alert")
            ][a.level];
        case "storm":
            return [
                I18n.tr("Storm", "island weather alert"),
                I18n.tr("Storm or strong wind", "island weather alert"),
                I18n.tr("Gale", "island weather alert"),
                I18n.tr("Violent storm", "island weather alert")
            ][a.level];
        case "snow":
            return a.ice ? I18n.tr("Freezing rain", "island weather alert") : [
                I18n.tr("A few flakes", "island weather alert"),
                I18n.tr("Light Snow", "island weather alert"),
                I18n.tr("Moderate snow", "island weather alert"),
                I18n.tr("Heavy Snow", "island weather alert")
            ][a.level];
        case "fog":
            return [
                I18n.tr("Fog", "island weather alert"),
                I18n.tr("Dense fog", "island weather alert"),
                I18n.tr("Very dense fog", "island weather alert"),
                I18n.tr("Thick fog", "island weather alert")
            ][a.level];
        case "heat":
            if (unit === "uv")
                return a.level >= 3 ? I18n.tr("Extreme UV", "island weather alert") : I18n.tr("Very high UV", "island weather alert");
            return [
                I18n.tr("Heat", "island weather alert"),
                I18n.tr("Strong heat", "island weather alert"),
                I18n.tr("Very strong heat", "island weather alert"),
                I18n.tr("Heatwave", "island weather alert")
            ][a.level];
        }
        return [
            I18n.tr("A few drops", "island weather alert"),
            I18n.tr("Light Rain", "island weather alert"),
            I18n.tr("Heavy Rain", "island weather alert"),
            I18n.tr("Very heavy rain", "island weather alert")
        ][a.level];
    }

    function valueText(m) {
        switch (m.unit) {
        case "kmh":
            return WeatherService.formatSpeed(Math.round(m.value));
        case "m":
            return WeatherService.formatVisibility(Math.round(m.value));
        case "c":
            return WeatherService.formatTemp(Math.round(m.value));
        case "uv":
            return I18n.tr("UV %1", "island weather alert: UV index").arg(Math.round(m.value));
        case "cmh":
            return I18n.tr("%1 cm/h", "island weather alert: snow rate").arg(Math.round(m.value * 10) / 10);
        }
        return I18n.tr("%1 mm/h", "island weather alert: rain rate").arg(Math.round(m.value * 10) / 10);
    }

    readonly property var face: {
        const a = IslandWeather.relocate(root.quarters, root.shown, root.nowMs);
        if (!a)
            return null;
        const qs = root.quarters;
        const peak = qs[a.peak] ?? null;
        const m = peak ? IslandWeather.measure(a.event, peak) : {
            "value": 0,
            "unit": ""
        };
        const what = root.name(a, m.unit);
        const live = root.nowMs >= qs[a.start]?.t;
        const minutes = live ? 0 : Math.max(0, Math.round((qs[a.start].t - root.nowMs) / 60000));
        const until = live
            ? I18n.tr("%1 until %2", "island weather alert: event, end hour").arg(what).arg(a.endAt)
            : I18n.tr("%1 in %2 min, until %3", "island weather alert: event, minutes, end hour").arg(what).arg(minutes).arg(a.endAt);
        const peakText = m.unit === "m"
            ? I18n.tr("visibility down to %1 around %2", "island weather alert: lowest visibility, hour")
            : I18n.tr("max %1 around %2", "island weather alert: peak value, hour");
        const top = peak ? peakText.arg(root.valueText(m)).arg(peak.at) : "";
        const chart = IslandWeather.bars(qs, a, root.nowMs);
        return {
            "icon": root.icon(a),
            "progress": -1,
            // The flat pill shows it too (valued): how long before it starts, or now.
            "valued": true,
            "text": live ? I18n.tr("now", "island weather alert: the event is on") : I18n.tr("In %1 min", "island weather alert: minutes before the event").arg(minutes),
            // Under the upright pill's icon, as narrow as it is: the minutes left, or now.
            "standText": live ? I18n.tr("now", "island weather alert: the event is on") : I18n.tr("%1′", "island weather alert, upright pill: minutes before the event").arg(minutes),
            "title": until,
            "short": what,
            "detail": top,
            "accent": ["hail", "storm", "heat"].indexOf(a.event) >= 0 ? "warning" : "primary",
            // Hovered, the bubble grows the island rather than a card beside it.
            "island": true,
            "weather": {
                "event": a.event,
                "level": a.level,
                "bars": chart.bars,
                "now": chart.now,
                "end": chart.end,
                "from": chart.from,
                "endAt": a.endAt,
                "label": I18n.tr("By 15 min from %1: %2", "island weather alert chart, for screen readers: first hour, peak").arg(chart.from).arg(top)
            }
        };
    }
}
