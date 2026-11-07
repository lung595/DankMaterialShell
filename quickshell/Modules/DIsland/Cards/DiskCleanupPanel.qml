pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskUsage.js" as DiskUsage
import "../../../Common/DiskCleanup.js" as Cleanup

// The disk card's cleanup (BubbleCardDisk, DiskCleanupService): what each suggestion would free, folded under its
// total, each row with its own button (hold to confirm).
Rectangle {
    id: panel

    required property BubbleCardDisk card
    readonly property var rows: Cleanup.rows(card.clean.facts)

    width: parent.width
    height: cleanupColumn.implicitHeight
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    Column {
        id: cleanupColumn

        width: parent.width

        Item {
            width: parent.width
            height: Theme.buttonHeightS

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: cleanupMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"
            }
            DIcon {
                id: cleanupIcon

                x: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: "cleaning_services"
                size: Theme.iconSizeSmall
                color: Theme.primary
            }
            StyledText {
                anchors.left: cleanupIcon.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: cleanupTotal.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Free up space", "island disk card: cleanup suggestions")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                elide: Text.ElideRight
            }
            StyledText {
                id: cleanupTotal

                anchors.right: cleanupChevron.left
                anchors.rightMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                text: card.clean.factsPending > 0 ? I18n.tr("Measuring…", "island disk card: cleanup sizes being read") : DiskUsage.fmt(Cleanup.total(card.cleanup))
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.primary
            }
            DIcon {
                id: cleanupChevron

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: card.cleanupOpen ? "expand_less" : "expand_more"
                size: Theme.iconSizeSmall
                color: Theme.surfaceVariantText
            }
            MouseArea {
                id: cleanupMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: I18n.tr("Free up space", "island disk card: cleanup suggestions")
                onClicked: card.cleanupOpen = !card.cleanupOpen
            }
        }

        Repeater {
            model: card.cleanupOpen ? panel.rows : []

            Item {
                id: row

                required property var modelData
                readonly property bool empty: row.modelData.size <= 0
                readonly property var titles: ({
                        "trash": I18n.tr("Trash", "island disk card: cleanup row"),
                        "old": I18n.tr("Old downloads", "island disk card: cleanup row"),
                        "caches": I18n.tr("Safe caches", "island disk card: cleanup row"),
                        "packages": I18n.tr("Unused packages and images", "island disk card: cleanup row")
                    })
                readonly property string sub: {
                    const f = card.clean.facts;
                    switch (row.modelData.id) {
                    case "trash":
                        return I18n.tr("Hold to empty for good", "island disk card: trash row");
                    case "old":
                        return I18n.tr("%1 items not opened in 6 months", "island disk card: old downloads row").arg(row.modelData.count);
                    case "caches":
                        return I18n.tr("Rebuilt by their apps · to the trash", "island disk card: caches row");
                    }
                    const parts = [];
                    if (f.flatpak?.refs?.length)
                        parts.push(I18n.tr("%1 Flatpak runtimes", "island disk card: unused flatpak runtimes").arg(f.flatpak.refs.length));
                    if (f.images?.count)
                        parts.push(I18n.tr("%1 dangling images", "island disk card: podman or docker dangling images").arg(f.images.count));
                    return parts.join(" · ");
                }

                width: parent.width
                height: rowText.implicitHeight + Theme.spacingS * 2

                Rectangle {
                    width: parent.width - Theme.spacingS * 2
                    x: Theme.spacingS
                    height: 1
                    color: Theme.outlineMedium
                }
                Column {
                    id: rowText

                    x: Theme.spacingS
                    y: Theme.spacingS
                    width: parent.width - x - rowButton.width - Theme.spacingS * 2

                    StyledText {
                        width: parent.width
                        text: row.titles[row.modelData.id] + " · " + DiskUsage.fmt(row.modelData.size)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }
                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: row.empty ? I18n.tr("Nothing to free", "island disk card: cleanup row already clean") : row.sub
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
                Loader {
                    id: rowButton

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    active: !row.empty
                    width: item ? Math.min(item.implicitWidth, row.width * 0.4) : 0
                    sourceComponent: row.modelData.id === "old" ? reviewButton : row.modelData.id === "caches" ? clearButton : row.modelData.id === "trash" ? emptyButton : pruneButton
                }
            }
        }
    }

    Component {
        id: reviewButton

        BubbleAction {
            focusPolicy: Qt.TabFocus
            text: I18n.tr("Review", "island disk card: list the old downloads")
            onClicked: {
                card.oldOnly = true;
                card.cleanupOpen = false;
                card.sel = null;
                card.svc.mode = "list";
            }
        }
    }
    Component {
        id: clearButton

        IslandHoldButton {
            focusPolicy: Qt.TabFocus
            text: I18n.tr("Clear", "island disk card: safe caches to the trash, held 2 s")
            Accessible.name: I18n.tr("Clear caches, hold 2 seconds", "island disk card: screen reader name of the held Clear")
            onConfirmed: card.act.trash((card.clean.facts.caches || []).map(c => ({
                        "path": c.path,
                        "node": DiskUsage.find(card.svc.tree, card.svc.path, c.path)
                    })), I18n.tr("Caches", "island disk card: what Undo restores after Clear"))
        }
    }
    Component {
        id: emptyButton

        IslandHoldButton {
            focusPolicy: Qt.TabFocus
            text: I18n.tr("Empty", "island disk card: empty the trash, held 2 s")
            Accessible.name: I18n.tr("Empty trash, hold 2 seconds", "island disk card: screen reader name of the held Empty")
            onConfirmed: card.clean.emptyTrash()
        }
    }
    Component {
        id: pruneButton

        IslandHoldButton {
            focusPolicy: Qt.TabFocus
            text: I18n.tr("Remove", "island disk card: flatpak uninstall --unused and image prune, held 2 s")
            Accessible.name: I18n.tr("Remove unused packages and images, hold 2 seconds", "island disk card: screen reader name of the held Remove")
            onConfirmed: card.clean.prune()
        }
    }
}
