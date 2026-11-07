pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DIsland.Cards
import qs.Modules.DIsland.Kit
import "../../../Common/IslandKit.js" as Kit

DestinationCompact {
    id: root

    required property var systemModel

    readonly property bool linksControlCenter: root.systemModel.controlCenterSection !== ""
    // Copied: the copy bubble's own face (IslandCopySource.face).
    readonly property var copy: root.systemModel.ownFace?.copy ?? null
    readonly property real glyphSize: Theme.iconSize + Theme.spacingS

    activityId: root.systemModel.kind
    iconName: root.systemModel.iconName
    // Hovered, the island grows into its bubble's card (what was copied under the title there): the face never changes.
    label: root.systemModel.title
    value: root.systemModel.displayValue
    // A face another source owns says an alert (disk almost full, a crash) in the error color.
    iconColor: root.systemModel.ownFace?.accent === "error" ? Theme.error : Theme.primary
    labelElide: root.systemModel.ownFace?.file ? Text.ElideMiddle : Text.ElideRight
    // Password copied: the manager's icon in its 30 s ring. Copied: the check on a shape, as on its bubble.
    // A call: the app's icon on its shape, the microphone or deafness badge on its corner, as on its bubble.
    // A battery: the A1 battery on its shape (warning to 15 %, the alert's to 5 %); critical, the alert rings once.
    leading: root.systemModel.kind === "password" ? passwordGlyph : root.copy ? copyCheck : root.callFace?.image ? callGlyph : root.battery ? batteryGlyph : null
    readonly property var battery: root.systemModel.ownFace?.battery ?? null
    readonly property var callFace: root.systemModel.kind === "call" ? root.systemModel.call?.face ?? null : null
    trailing: root.copy ? copyType : null
    trailingInk: root.copy && !root.copy.thumb ? root.copy.typeIcon ?? "" : ""

    Component {
        id: passwordGlyph

        BubblePasswordGlyph {
            bubble: root.systemModel.password?.face ?? null
        }
    }

    Component {
        id: callGlyph

        IslandAppIcon {
            id: callIcon

            size: root.glyphSize
            source: root.callFace?.image ?? ""
            iconName: "call"

            // Like any call, it rings twice out of its shape as it comes, in DMS's main color.
            IslandAlertWave {
                z: -1
                anchors.centerIn: parent
                base: callIcon.width
                reach: 2
                rings: 2
                color: Theme.primary
                Component.onCompleted: play()
            }

            BubbleCallGlyph {
                anchors.fill: parent
                z: 1
                bubble: root.callFace
                ringColor: callIcon.shapeColor
            }
        }
    }

    Component {
        id: batteryGlyph

        IslandAppIcon {
            id: batteryShape

            readonly property var face: root.systemModel.ownFace
            readonly property bool alert: face?.accent === "error" || face?.shapeFamily === "alert"
            // Folded in light mode an alert's pale container says nothing: error and onError (IslandKit.alertRoles).
            readonly property var roles: Kit.alertRoles("critical", true, Theme.isLightMode)

            size: root.glyphSize
            iconName: ""
            shapeColor: batteryShape.alert ? Theme[batteryShape.roles[0]] : face?.accent === "warning" ? Theme.warning : Theme.primaryContainer
            iconColor: batteryShape.alert ? Theme[batteryShape.roles[1]] : face?.accent === "warning" ? Theme.surface : Theme.onPrimaryContainer

            // The critical info rings twice out of its shape as it comes, once.
            IslandAlertWave {
                z: -1
                anchors.centerIn: parent
                readonly property bool critical: batteryShape.face?.accent === "error"

                visible: critical
                base: batteryShape.width
                reach: 2
                rings: 2
                color: Theme.error
                // Not `visible`: the face is not shown yet when it is built, and its kind may land just after.
                Component.onCompleted: {
                    if (critical)
                        play();
                }
                onCriticalChanged: {
                    if (critical)
                        play();
                }
            }

            BubbleChargeGlyph {
                anchors.fill: parent
                battery: root.battery
                iconSize: Math.round(batteryShape.size * 0.62)
                lineColor: batteryShape.iconColor
                ringColor: batteryShape.shapeColor
            }
        }
    }

    Component {
        id: copyCheck

        IslandAppIcon {
            id: check

            size: root.glyphSize
            iconName: "check"
            // Each new copy takes the next shape with a pulse, as the bubble does.
            readonly property int pulse: root.copy?.pulse ?? 0
            onPulseChanged: check.poke()
        }
    }

    Component {
        id: copyType

        BubbleCopyType {
            face: root.copy
            size: Math.round(root.glyphSize * 0.7)
        }
    }

    IslandSlotHoverArea {
        id: hover

        anchors.fill: parent
        controller: root.controller
        cursorShape: root.linksControlCenter || !!root.systemModel.ownFace?.click || root.systemModel.kind === "output" || root.systemModel.kind === "reopen" || root.systemModel.kind === "password" || root.systemModel.kind === "openwifi" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            // A face with a bubble card expands in place (the hover already opened it); its actions are that card's buttons.
            if (root.controller.faceCardAvailable)
                return;
            // Audio output changed: the face's "Undo" switches back to the output before.
            if (root.systemModel.kind === "output")
                root.systemModel.output.undo();
            if (root.systemModel.kind === "reopen")
                root.systemModel.reopen.reopen("");
            if (root.systemModel.kind === "password")
                root.systemModel.password.clearNow();
            if (root.systemModel.kind === "openwifi")
                root.systemModel.wifi.enableVpn(false);
            // Trash, screen plugged: the face's Undo or Choose, which ends the face itself.
            const click = root.systemModel.ownFace?.click;
            if (click)
                return click();
            if (root.linksControlCenter) {
                root.controller.requestControlCenter(root.systemModel.controlCenterSection, false);
                return;
            }
            root.controller.requestCollapse();
        }
    }
}
