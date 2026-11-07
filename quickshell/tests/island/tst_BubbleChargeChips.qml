import QtQuick
import QtTest
import "../../Modules/DIsland/Cards"

// The charge face's chips (Cards/BubbleChargeChips.qml): time left, full at, then the session's gain, each on its own
// slice of the island's growth; with no time to show (0 W) neither time chip is there.
TestCase {
    name: "BubbleChargeChips"
    when: windowShown
    width: 600
    height: 100

    Component {
        id: chipsOf

        BubbleChargeChips {
            charge: ({ "leftText": "1 h 05", "fullAtText": "full at 14:44", "gainText": "+3% in 4 min" })
            grow: 0
            still: false
            from: 1
            pieces: 4
            chipHeight: 24
            chipPad: 12
            textWidth: 160
        }
    }

    function chips(flow) {
        return flow.children.filter(c => c.label !== undefined);
    }

    function test_orderAndStaggeredArrival() {
        const flow = createTemporaryObject(chipsOf, this);
        const [left, full, gain] = chips(flow);
        compare(left.label, "1 h 05");
        compare(full.label, "full at 14:44");
        compare(gain.label, "+3% in 4 min");
        verify(left.x < full.x && full.x < gain.x, "time left, full at, then the gain");
        // pieces 1 to 3 of 4: the growth's second half split in four slices, [5/8, 3/4], [3/4, 7/8], [7/8, 1].
        flow.grow = 0.6;
        compare(left.opacity, 0);
        flow.grow = 0.6875;
        verify(left.opacity > 0.4 && left.opacity < 0.6, "the first chip half in: " + left.opacity);
        compare(full.opacity, 0, "the second waits for the first");
        flow.grow = 0.8;
        compare(left.opacity, 1);
        verify(full.opacity > 0 && full.opacity < 1, "the second on its way: " + full.opacity);
        compare(gain.opacity, 0, "the third waits for the second");
        flow.grow = 0.95;
        compare(full.opacity, 1);
        verify(gain.opacity > 0 && gain.opacity < 1, "the third on its way: " + gain.opacity);
        flow.grow = 1;
        compare(gain.opacity, 1);
        flow.grow = 0;
        flow.still = true;
        for (const chip of chips(flow))
            compare(chip.opacity, 1, "held still: " + chip.modelData.key + " shown");
    }

    function test_noTimeChipsAtZeroWatts() {
        const flow = createTemporaryObject(chipsOf, this, { "grow": 1, "charge": { "leftText": "", "fullAtText": "", "gainText": "+0% in 2 min" } });
        const [left, full, gain] = chips(flow);
        verify(!left.visible, "no time left");
        verify(!full.visible, "no full at");
        // The Flow lays out only the chips shown: the gain alone, first in the row.
        compare(gain.x, 0);
        compare(flow.implicitWidth, gain.width);
    }
}
