import QtQuick
import qs.Common
import qs.DCommon.Widgets

// USB stick bubble's open card (source "usb"): Open and Eject under the header (name, free space); once ejected the
// header says "You can unplug it" and the buttons go. Read live from the bubble's source (IslandUsbSource).
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var usb: card.bubble?.usb ?? null

    BubbleActions {
        visible: !(card.usb?.ejected ?? true)

        BubbleAction {
            iconName: "folder_open"
            text: I18n.tr("Open", "island usb bubble: open the stick in the file manager")
            enabled: !(card.usb?.busy ?? true)
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Open %1", "island usb bubble: open button").arg(card.bubble?.title ?? "")
            onClicked: card.usb?.open()
        }

        BubbleAction {
            iconName: "eject"
            text: I18n.tr("Eject", "island USB card: action")
            busy: card.usb?.busy ?? false
            enabled: !(card.usb?.busy ?? true)
            activeFocusOnTab: true
            Accessible.name: I18n.tr("Eject %1", "island usb bubble: eject button").arg(card.bubble?.title ?? "")
            onClicked: card.usb?.eject()
        }
    }
}
