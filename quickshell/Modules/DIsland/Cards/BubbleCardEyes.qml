import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Notifications

// Eye break bubble's open card (kind "eyes"): the live eye in the header's icon box (one eye, no glyph beside it), the
// countdown under the title, what to do in the title's column, then Skip in the bottom row.
BubbleCardBase {
    id: card

    iconComponent: Component {
        EyeBreakGlyph {
            size: Theme.iconSize
            color: Theme[card.bubble?.accent ?? "primary"] ?? Theme.primary
        }
    }

    StyledText {
        x: NotificationMetrics.appIconSize + NotificationMetrics.iconSpacing
        width: parent.width - x
        text: I18n.tr("Look at something far away until the end", "island eye break: what to do during the break")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    actions: [
        BubbleAction {
            iconName: "skip_next"
            text: I18n.tr("Skip", "island eye break: end the break now")
            activeFocusOnTab: true
            onClicked: EyeBreakService.skip()
        }
    ]
}
