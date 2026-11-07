import QtQuick
import QtTest
import "../../Modules/DIsland/Kit"

// A decor's clock (Kit/IslandClock.qml): 60 ticks a second at most on any screen, each carrying whole screen periods.
TestCase {
    name: "IslandClock"

    Component {
        id: clockOf

        IslandClock {}
    }

    SignalSpy {
        id: ticks

        signalName: "tick"
    }

    function test_sixtyTicksASecondAtMost_data() {
        return [
            { tag: "60 Hz", refresh: 60, every: 1 },
            { tag: "240 Hz", refresh: 240, every: 4 },
        ];
    }

    function test_sixtyTicksASecondAtMost(data) {
        const clock = createTemporaryObject(clockOf, this, { "refresh": data.refresh });
        compare(clock.every, data.every);
        ticks.clear();
        ticks.target = clock;
        clock.running = true;
        wait(500);
        clock.running = false;
        // shortcut: a loaded test machine may tick late; the bound that matters is the top (no more than 60 a second).
        verify(ticks.count >= 10 && ticks.count <= 31, ticks.count + " ticks in 0.5 s");
        const dt = ticks.signalArguments[0][0];
        verify(dt >= data.every / data.refresh - 1e-9, "dt " + dt + " is whole periods");
        verify(Math.abs(dt * data.refresh - Math.round(dt * data.refresh)) < 1e-6, "dt " + dt + " is whole periods");
    }

    function test_dueCountsTheDecorsImages() {
        const clock = createTemporaryObject(clockOf, this);
        clock._ticks = 2;
        verify(clock.due(2, 1));
        compare(clock._frames, 2);
        compare(clock._held, 0);
        compare(clock._ticks, 0);
    }
}
