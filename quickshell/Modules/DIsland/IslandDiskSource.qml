pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/DiskUsage.js" as DiskUsage

// The disk almost full bubble (machine side B2, kind "disk", its row in B8): raised once each time a mount drops under
// DiskSpaceService's threshold; its face fields, read by the island's "disk" face and IslandBarHost's bubbleList.
QtObject {
    id: root

    required property IslandController controller
    property bool enabled: true

    readonly property string folder: DiskSpaceService.lowFolder
    readonly property int freePercent: Math.round(DiskSpaceService.lowFree * 100)
    readonly property real used: Math.max(0, Math.min(1, 1 - DiskSpaceService.lowFree))
    readonly property var face: ({
            "icon": "hard_drive",
            "progress": -1,
            // Standing beside the launcher: the used share as the volume's liquid, its tone turning to the alert as it fills.
            "standLevel": root.used,
            "standText": I18n.tr("%1%", "island disk bubble: used space percent under the upright pill").arg(Math.round(root.used * 100)),
            "alertShare": DiskUsage.alertShare(DiskSpaceService.lowFree, DiskSpaceService.lowThreshold),
            "text": I18n.tr("%1%", "island disk bubble: free space percent in the pill").arg(root.freePercent),
            "title": I18n.tr("Disk almost full", "island disk bubble title"),
            "detail": I18n.tr("%1 free · %2%", "island disk bubble detail: free size, free percent").arg(DiskUsage.fmt(DiskSpaceService.lowAvail)).arg(root.freePercent),
            "accent": "error"
        })

    // The island's own "disk" face first, else the machine bubble (IslandBarHost.playMachine).
    signal arrived
    onFolderChanged: {
        if (root.folder && root.enabled && root.controller.bubblesEnabled)
            root.arrived();
        else if (!root.folder && root.controller.machineBubbleKind === "disk")
            root.controller.hideMachineBubble();
    }
}
