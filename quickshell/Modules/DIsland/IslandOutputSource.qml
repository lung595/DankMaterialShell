import QtQuick
import qs.Services

// The default audio output changed: remembers the one before it so the island can switch back (Undo).
// Reacts to AudioService.sink only; no timer, no polling.
QtObject {
    id: root

    signal switched

    readonly property string sinkName: AudioService.sink?.name ?? ""
    property string lastName: ""
    property string lastLabel: ""
    property string previousName: ""
    property string previousLabel: ""
    // The switch back requested by undo(): it lands as a sink change that must not open the island again.
    property string undoTarget: ""

    readonly property string name: AudioService.displayName(AudioService.sink)
    readonly property string icon: AudioService.sinkIcon(AudioService.sink)
    readonly property string previous: previousLabel
    readonly property bool canUndo: previousName !== "" && AudioService.getAvailableSinks().some(node => node.name === previousName)

    onSinkNameChanged: {
        // A sink that briefly drops (unplugged, restarting) keeps the last one as "before".
        if (!sinkName)
            return;
        const back = sinkName === undoTarget;
        if (!back && lastName && lastName !== sinkName) {
            previousName = lastName;
            previousLabel = lastLabel;
            switched();
        }
        if (back) {
            undoTarget = "";
            previousName = "";
        }
        lastName = sinkName;
        lastLabel = AudioService.displayName(AudioService.sink);
    }

    function undo() {
        if (!canUndo)
            return;
        undoTarget = previousName;
        if (!AudioService.setDefaultSinkByName(previousName))
            undoTarget = "";
    }
}
