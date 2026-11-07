import QtQuick
import QtTest
import "../../Modules/DIsland/Kit"

// The charge face's count (Kit/IslandOdometer.qml): the wheels and the width are decided on the final value before the
// count starts, so the "%" after it never moves while the value climbs.
TestCase {
    name: "IslandOdometer"
    when: windowShown
    width: 200
    height: 100

    Component {
        id: counted

        Row {
            property alias odo: odo
            property alias percent: percent

            IslandOdometer {
                id: odo

                font.pixelSize: 32
            }
            Text {
                id: percent

                text: "%"
                font.pixelSize: 32
            }
        }
    }

    function wheelsOf(odo) {
        return odo.children[odo.children.length - 1].children.filter(c => c.place !== undefined).length;
    }

    function test_widthAndWheelsHeldFromTheStart_data() {
        return [
            { tag: "to 99.6", to: 99.6, wheels: 3 },
            { tag: "to 9.6", to: 9.6, wheels: 2 },
        ];
    }

    function test_widthAndWheelsHeldFromTheStart(data) {
        const row = createTemporaryObject(counted, this);
        row.odo.to = data.to;
        row.odo.value = 0;
        compare(row.odo.count, data.wheels);
        tryCompare(row.odo, "implicitWidth", row.odo.implicitWidth);
        const width = row.odo.implicitWidth;
        const percentX = row.percent.x;
        verify(width > 0);
        compare(wheelsOf(row.odo), data.wheels);
        for (const v of [0.5, 9.4, data.to * 0.5, data.to - 0.1, data.to]) {
            row.odo.value = v;
            compare(row.odo.count, data.wheels, "count at " + v);
            compare(row.odo.implicitWidth, width, "width at " + v);
            compare(row.percent.x, percentX, "the % at " + v);
        }
    }
}
