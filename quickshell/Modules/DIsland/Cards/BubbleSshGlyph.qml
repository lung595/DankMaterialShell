import QtQuick
import qs.Common

// Incoming SSH bubble's pill (source "ssh"): the status dot, red, on the terminal's corner while a session is open.
BubbleStatusDot {
    source: "ssh"
    dotColor: Theme.error
    label: I18n.tr("SSH session open", "island ssh bubble: red dot")
}
