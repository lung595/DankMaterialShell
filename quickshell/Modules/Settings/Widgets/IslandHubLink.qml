import QtQuick
import qs.Common

// Sends a host page (bar, widget, dot) to the Island hub with this host's island selected.
SettingsCard {
    id: root

    property var parentModal: null
    property string barId: ""
    readonly property var hub: SettingsTabs.page("island")

    iconName: "blur_on"
    title: root.hub?.text ?? ""

    SettingsNavRow {
        iconName: "blur_on"
        title: root.title
        hint: root.hub?.hint ?? ""
        onClicked: keyboard => {
            SettingsUiState.selectIsland(root.barId);
            root.parentModal?.navigateTo("island", keyboard);
        }
    }
}
