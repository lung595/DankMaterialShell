import QtQuick
import qs.Common

// Camera bubble's pill (source "camera", B8): the status dot, green, on the filming app icon's corner as long as it films.
BubbleStatusDot {
    source: "camera"
    dotColor: Theme.success
    label: I18n.tr("Camera on", "island camera bubble: the green dot")
}
