pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.DIsland.Kit

// Transfers bubble's open card (source "transfer"): one section per category, as DMS's launcher sections (icon and title
// in the primary tone, the section's total "2 of 3 · 4 min", Pause all and Cancel all), the moving one on top, its rows
// below (BubbleTransferRow). Hovered or focused, a row offers Pause or Resume (only when its app lets it), Cancel (held
// 2 s), Open folder and, once finished, Open. Keyed models keep each row's delegate (and a cancel being held) while the
// order changes. The list scrolls past a few rows.
// C29: built on BubbleCardBase.
BubbleCardBase {
    id: card

    readonly property var transfer: card.bubble?.transfer ?? null
    readonly property var sections: card.transfer?.sections ?? []
    readonly property real lineGap: Theme.spacingXS
    // The wave progress's height (its playhead).
    readonly property real barHeight: Theme.spacingL
    // The name line and the section header hold the kit's buttons.
    readonly property real nameHeight: Math.max(nameProbe.implicitHeight, Theme.buttonHeightS)
    readonly property real detailHeight: detailProbe.implicitHeight
    readonly property real rowHeight: card.nameHeight + card.lineGap + card.barHeight + card.lineGap + card.detailHeight
    // Two sections of three rows in view at most; more scroll.
    readonly property real maxListHeight: 2 * Theme.buttonHeightS + 3 * card.rowHeight + 4 * Theme.spacingS

    function icon(category) {
        return ({
                "download": "download",
                "torrent": "swap_vert",
                "copy": "file_copy",
                "archive": "folder_zip",
                "send": "devices",
                "disk": "usb"
            })[category] ?? "file_copy";
    }

    // The rows' own text, measured as drawn (font metrics alone come out short and cut the last row).
    StyledText {
        id: nameProbe

        visible: false
        text: "Ag"
        font.pixelSize: NotificationMetrics.bodySize
        font.weight: Theme.fontWeightMedium
    }
    StyledText {
        id: detailProbe

        visible: false
        text: "Ag"
        font.pixelSize: Theme.fontSizeSmall
    }

    DFlickable {
        id: flick

        width: parent?.width ?? 0
        height: Math.min(sectionColumn.implicitHeight, card.maxListHeight)
        contentHeight: sectionColumn.implicitHeight
        fadeLength: Theme.spacingS
        clip: true
        interactive: contentHeight > height
        showScrollBar: contentHeight > height
        Accessible.role: Accessible.List
        Accessible.name: I18n.tr("Transfers", "island transfers bubble: the list of transfers")

        Column {
            id: sectionColumn

            width: flick.width
            spacing: Theme.spacingS

            Repeater {
                model: ScriptModel {
                    values: card.sections
                    objectProp: "category"
                }

                delegate: Column {
                    id: section

                    required property var modelData
                    readonly property var rows: section.modelData.rows

                    width: sectionColumn.width
                    spacing: Theme.spacingXS

                    // The section's header: icon, title and total; Pause all and Cancel all when some row allows them.
                    Item {
                        width: parent.width
                        height: Theme.buttonHeightS

                        Row {
                            anchors.left: parent.left
                            anchors.right: sectionActions.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DIcon {
                                id: sectionIcon

                                anchors.verticalCenter: parent.verticalCenter
                                name: card.icon(section.modelData.category)
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                            }
                            StyledText {
                                id: sectionTitle

                                anchors.verticalCenter: parent.verticalCenter
                                text: card.transfer?.texts.sectionTitle(section.modelData.category) ?? ""
                                wrapMode: Text.NoWrap
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightMedium
                                color: Theme.primary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - sectionIcon.width - sectionTitle.width - 2 * parent.spacing)
                                text: card.transfer?.texts.sectionTotal(section.modelData) ?? ""
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                font.pixelSize: Theme.fontSizeSmall
                                font.features: {
                                    "tnum": 1
                                }
                                color: Theme.surfaceVariantText
                            }
                        }
                        Row {
                            id: sectionActions

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            IslandButton {
                                visible: section.modelData.canPause
                                iconName: section.modelData.paused ? "play_arrow" : "pause"
                                text: ""
                                activeFocusOnTab: true
                                Accessible.name: section.modelData.paused ? I18n.tr("Resume all", "island transfers card: resume every paused transfer of a section") : I18n.tr("Pause all", "island transfers card: pause every transfer of a section that allows it")
                                onClicked: card.transfer?.actions.setPaused(!section.modelData.paused, section.rows)
                            }
                            IslandHoldButton {
                                visible: section.modelData.canCancel
                                iconName: "close"
                                text: ""
                                activeFocusOnTab: true
                                Accessible.name: I18n.tr("Cancel all", "island transfers bubble: stop every transfer")
                                onConfirmed: card.transfer?.actions.cancel(section.rows)
                            }
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: section.rows
                            objectProp: "id"
                        }

                        delegate: BubbleTransferRow {
                            owner: card
                            width: section.width
                        }
                    }
                }
            }
        }
    }
}
