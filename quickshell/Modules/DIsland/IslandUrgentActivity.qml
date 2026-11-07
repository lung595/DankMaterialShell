pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DIsland.Kit

// A window calling for attention as the island's own face, while the island is free: the app's icon and the
// window's title for 5 s; a click goes to the window. IslandUrgentSource hands it to the bubble when the island is busy.
// Compact and symmetric: the kit's app icon on the left, the title, centered with the same margin on both sides.
IslandActivityComponent {
    id: root

    compactLength: 300

    compactContent: Item {
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            IslandAppIcon {
                id: appIcon

                anchors.verticalCenter: parent.verticalCenter
                size: Theme.iconSize + Theme.spacingS
                source: root.activityData.image ?? ""
                iconName: "notifications_active"
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.compactLength - appIcon.width - Theme.spacingS - Theme.spacingM * 2)
                text: root.activityData.title ?? ""
                elide: Text.ElideRight
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("Go to %1", "island urgent window: focus the window that calls").arg(root.activityData.title ?? "")
            onClicked: {
                appIcon.poke();
                const id = root.activityData.windowId ?? -1;
                if (id >= 0)
                    NiriService.focusWindow(id);
                IslandActivityService.remove(root.token, "dismissed");
            }
        }
    }
}
