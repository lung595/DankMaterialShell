import QtQuick
import qs.Common

// Camera bubble's open card (source "camera", card rules C: the header names the apps filming), and go to the first
// one's window when it has one. Read live from the bubble's source (IslandCameraSource).
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var camera: card.bubble?.camera ?? null

    BubbleActions {
        visible: card.camera?.canGoTo ?? false

        BubbleAction {
            role: "primary"
            iconName: "open_in_new"
            text: I18n.tr("Go to app", "island camera bubble: bring the filming app's window forward")
            activeFocusOnTab: true
            Accessible.name: text
            onClicked: card.camera?.goTo()
        }
    }
}
