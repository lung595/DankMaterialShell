pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Notifications
import qs.Modules.Plugins
import qs.Modules.DIsland.Cards
import qs.Modules.DIsland.Kit
import "../../Common/IslandKit.js" as Kit

// The shelf in the island (IslandShelfSource): its card, the same as in its bubble, while a file is dragged over the
// island (its drop zones lit) or opened by its shortcut. Compact (on its way in, or folded by a popout), a small pile of the newest
// files, the wing's shape size, and "N files".
// B7: the shelf's face in the island, flat in it.
IslandActivityComponent {
    id: root

    readonly property var source: root.activityData.shelf ?? null
    readonly property var items: root.source?.items ?? []
    readonly property real shape: root.source?.shapeSize ?? Theme.iconSize * 2
    readonly property real glyph: root.source?.iconSize ?? Theme.iconSize
    // The pile: up to three cards, each one step aside from the one behind it.
    readonly property int pile: Math.min(3, root.items.length)
    readonly property real step: Theme.spacingXS
    readonly property real pileWidth: root.shape + Math.max(0, root.pile - 1) * root.step
    // Under a drag the files are not known before the drop: no "0 files" then.
    readonly property string label: (root.source?.over ?? false) ? I18n.tr("Drop here", "island shelf: a drag over the island") : root.source?.countText ?? ""
    readonly property real labelCap: Theme.iconSize * 9

    readonly property real pad: NotificationMetrics.cardPadding
    // The card's own height once made; a first guess until then.
    property real cardHeight: Theme.iconSize * 14

    compactLength: Theme.spacingM * 2 + root.pileWidth + Theme.spacingS + Math.min(root.labelCap, labelMeasure.implicitWidth)
    expandedWidth: (root.source?.cardWidth ?? Theme.iconSize * 33) + 2 * root.pad
    expandedHeight: root.cardHeight + 2 * root.pad

    StyledText {
        id: labelMeasure

        visible: false
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
    }

    compactContent: Item {
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Item {
                id: pileBox

                // A file just dropped lands on top of the pile with the kit's pop (at once with reduced motion).
                readonly property string newest: root.items[0] ?? ""
                onNewestChanged: {
                    landing.snapTo(0);
                    landing.retarget(1);
                }

                width: root.pileWidth
                height: root.shape
                anchors.verticalCenter: parent.verticalCenter

                SpringMotion {
                    id: landing

                    readonly property var spec: Kit.spring("pop", Theme.currentAnimationBaseDuration)
                    value: 1
                    enabled: Theme.currentAnimationBaseDuration > 0 && !SettingsData.reduceMotion
                    stiffness: spec.stiffness
                    damping: spec.damping
                    mass: spec.mass
                }

                Repeater {
                    model: root.pile

                    // Back cards first; the newest file on top, at the right.
                    delegate: IslandShelfThumb {
                        required property int index

                        readonly property int depth: root.pile - 1 - index

                        x: index * root.step
                        width: root.shape
                        height: root.shape
                        scale: depth === 0 ? 0.6 + 0.4 * landing.value : 1
                        opacity: depth === 0 ? Math.min(1, 2 * landing.value) : 1
                        path: root.items[depth] ?? ""
                        iconSize: root.glyph
                        border.width: 1
                        border.color: Theme.surfaceContainer
                    }
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(root.labelCap, implicitWidth)
                text: root.label
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("Shelf", "island shelf: screen reader name") + ", " + root.label
            Accessible.description: I18n.tr("Click to show the kept files", "island shelf face: screen reader hint")
            // The island grows into the card where it is, never into the bubble beside (a face grows in place).
            onClicked: root.source?.expand()
        }
    }

    // Only the drag or the shortcut opens the island: at rest a hover must not grow it.
    expandedContent: root.kind === "alert" ? sheet : null

    Component {
        id: sheet

        FocusScope {
            id: sheetScope

            // The island as it grows, in this sheet's coordinates (the face's loader sits in the island's content host):
            // the card shows only inside it, never spilling past its edge while it opens or closes.
            readonly property Item face: sheetScope.parent
            readonly property Item host: sheetScope.face?.parent ?? null

            // The island's keyboard goes to the card's list.
            function focusFace() {
                card.forceActiveFocus();
                return true;
            }

            // Escape closes what is open in the card, one thing at a time, never the card (only its close button or Super+S).
            Keys.onEscapePressed: event => {
                event.accepted = true;
                root.source?.closeInner();
            }

            Item {
                id: islandWindow

                x: sheetScope.host ? -sheetScope.face.x : 0
                y: sheetScope.host ? -sheetScope.face.y : 0
                width: sheetScope.host?.width ?? sheetScope.width
                height: sheetScope.host?.height ?? sheetScope.height
                clip: true

                BubbleCardShelf {
                    id: card

                    x: root.pad - islandWindow.x
                    y: root.pad - islandWindow.y
                    width: sheetScope.width - 2 * root.pad
                    bubble: ({
                            "shelf": root.source
                        })
                    onImplicitHeightChanged: root.cardHeight = implicitHeight
                    Component.onCompleted: root.cardHeight = implicitHeight
                }
            }
        }
    }
}
