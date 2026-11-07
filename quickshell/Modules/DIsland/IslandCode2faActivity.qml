pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DIsland.Cards
import qs.Modules.DIsland.Kit
import "../../Common/IslandCode2fa.js" as Code
import "../../Common/IslandKit.js" as Kit

// A one-time code as the island's own face, while the island is free: the sending app's icon, the code hidden (••• •••)
// until hovered, and Copy (the clipboard lets it go 30 s later). IslandCode2faSource hands it to the bubble when busy.
// Compact and symmetric: icon on the left, the code, the kit's copy button on the right.
IslandActivityComponent {
    id: root

    readonly property var source: root.activityData.code2fa ?? null
    // Kept as the island folds: the source empties its code the moment the island lets it go.
    property string code: ""
    Binding on code {
        value: root.source?.entry?.code ?? ""
        when: (root.source?.entry?.code ?? "") !== ""
        restoreMode: Binding.RestoreNone
    }
    property bool copied: false
    Binding on copied {
        value: root.source?.copied ?? false
        when: !!root.source?.entry
        restoreMode: Binding.RestoreNone
    }

    readonly property string copiedLabel: I18n.tr("Copied · cleared in 30 s", "island 2FA code bubble: the code is on the clipboard, wiped 30 s later")

    // Wide enough for the longest label (the Copy button's feedback) once copied: icon, code and button between the margins.
    // The masked code and its icon; once copied, room for the check and "Copied" too.
    readonly property real restLength: 260
    compactLength: root.copied ? Math.max(root.restLength, Theme.spacingM * 2 + Theme.iconSize + Theme.spacingS * 2 + codeMetrics.advanceWidth + Theme.spacingS + labelMetrics.advanceWidth + Theme.iconSizeMedium + Theme.spacingS * 3) : root.restLength

    TextMetrics {
        id: codeMetrics

        text: Code.grouped(root.code)
        font.family: Theme.monoFontFamily
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
    }

    TextMetrics {
        id: labelMetrics

        text: root.copiedLabel
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    compactContent: Item {
        HoverHandler {
            id: hover
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            IslandAppIcon {
                id: appIcon

                // An important info: the filled alert shape, and one ring out of it as it shows.
                readonly property var roles: Kit.alertRoles("critical", true, Theme.isLightMode)

                anchors.verticalCenter: parent.verticalCenter
                size: Theme.iconSize + Theme.spacingS
                source: root.activityData.image ?? ""
                iconName: "password"
                shapeColor: Theme[appIcon.roles[0]]
                iconColor: Theme[appIcon.roles[1]]

                IslandAlertWave {
                    anchors.centerIn: parent
                    z: -1
                    base: appIcon.size
                    reach: 1 + Theme.spacingS / appIcon.size
                    rings: 2
                    Component.onCompleted: play()
                }
            }

            IslandCodeDigits {
                id: digits

                anchors.verticalCenter: parent.verticalCenter
                readonly property bool sharing: root.source?.sharing ?? false

                text: Code.shown(root.code, hover.hovered, sharing)
                pixelSize: Theme.fontSizeMedium
                Accessible.role: Accessible.StaticText
                Accessible.name: sharing ? I18n.tr("Hidden code, the screen is shared", "island 2FA code bubble: the code stays masked during a screen share") : hover.hovered ? Code.grouped(root.code) : I18n.tr("Hidden code, hover to show it", "island 2FA code bubble: the masked code")
            }

            BubbleAction {
                id: copyButton

                anchors.verticalCenter: parent.verticalCenter
                // 20 % flatter than an icon box (his choice of 25/10), kept even so it centres on the face.
                buttonHeight: Math.round((Theme.iconSize + Theme.spacingS) * 0.8 / 2) * 2
                iconName: root.copied ? "check" : "content_copy"
                feedbackText: root.copiedLabel
                keepFeedback: root.copied
                Accessible.name: root.copied ? I18n.tr("Copied, cleared in 30 seconds", "island 2FA code bubble: screen reader") : I18n.tr("Copy", "island 2FA code bubble: copy the code")
                onClicked: {
                    root.source?.copy();
                    copyButton.flash(true);
                    appIcon.poke();
                    digits.hop();
                }
            }
        }
    }
}
