import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import "../Activities"

// Password copied (source "password"): the password manager's icon, or a padlock, in a ring that empties over the 30 s
// before the clipboard is cleared. Never the copied text.
// B8: its pill, as the bubbles' table says.
Item {
    id: root

    property var bubble: null
    property color accent: Theme.primary
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    readonly property string app: root.bubble?.password?.app ?? ""

    visible: root.bubble?.source === "password"
    implicitWidth: ring.implicitWidth
    implicitHeight: ring.implicitHeight

    ReadyActivityRing {
        id: ring

        anchors.fill: parent
        accent: root.accent
        iconName: root.app === "" ? "lock" : ""
        // Reduced motion: a full ring that simply goes with the bubble.
        progress: root.visible ? (root.still ? 1 : root.bubble.password?.remaining ?? 1) : -1
    }

    CcAppIcon {
        anchors.centerIn: parent
        visible: root.app !== ""
        iconSize: Theme.iconSizeSmall
        appId: root.visible ? root.app : ""
    }

    Accessible.role: Accessible.Graphic
    Accessible.name: I18n.tr("Password copied", "island password bubble title")
}
