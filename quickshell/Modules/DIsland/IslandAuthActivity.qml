pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Notifications
import qs.Modules.DIsland.Cards
import "../../Common/IslandAuth.js" as Auth

// The polkit request as the island's own activity: a masked field, or a finger / face scan, then a check, or the kit's
// error (red and a shake) on Authenticate. On the notification popup's grid: the badge on the left,
// the title and the message stacked, the field, then Cancel and Authenticate as the kit's full width row at the bottom.
IslandActivityComponent {
    id: root

    readonly property var source: root.activityData.source ?? null
    readonly property string mode: root.source?.mode ?? "wait"
    readonly property string phase: root.source?.phase ?? "ask"
    readonly property bool still: SettingsData.reduceMotion || SettingsData.animationDuration <= 0
    property real bodyHeight: 0

    readonly property string failedText: I18n.tr("Authentication failed - try again", "island polkit request: a failed attempt")
    // The lock and its short title on the pill.
    readonly property real pillLength: 220

    compactLength: root.pillLength
    expandedWidth: NotificationMetrics.popupWidth
    expandedHeight: root.bodyHeight

    // The island opens on the request and hands it the keyboard; the island takes it back when the activity ends.
    onExpandedChanged: {
        if (!root.expanded)
            return;
        for (const island of IslandActivityService.islandsFor(root.screen)) {
            if (island.pluginToken === root.token && island.expanded && !island.keyboardDismissRequested)
                island.requestToggle(true);
        }
    }

    compactContent: Item {
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.phase === "success" ? "check_circle" : Auth.modeIcon(root.mode)
                size: Theme.iconSizeSmall
                color: root.phase === "failed" ? Theme.error : Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Authentication", "noun, polkit dialog title and settings section title")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    expandedContent: FocusScope {
        id: sheet

        function focusFace() {
            if (passwordField.visible && passwordField.enabled)
                passwordField.forceActiveFocus();
            else
                sheet.forceActiveFocus();
            return true;
        }

        Keys.onEscapePressed: event => {
            event.accepted = true;
            root.source?.cancel();
        }

        // Kept after the sheet folds, so the next opening starts at the right height.
        Binding {
            target: root
            property: "bodyHeight"
            value: column.implicitHeight + NotificationMetrics.cardPadding * 2
            restoreMode: Binding.RestoreNone
        }

        // Bound handlers also fire once at creation: only changes after it count.
        property bool settled: false
        Component.onCompleted: sheet.settled = true

        readonly property int failures: root.source?.failures ?? 0
        onFailuresChanged: {
            if (!sheet.settled)
                return;
            passwordField.text = "";
            if (passwordField.visible)
                authButton.flash(false);
        }

        readonly property string sourcePhase: root.source?.phase ?? ""
        onSourcePhaseChanged: {
            if (sheet.settled && sheet.sourcePhase === "ask")
                Qt.callLater(sheet.focusFace);
        }

        Column {
            id: column

            anchors.fill: parent
            anchors.margins: NotificationMetrics.cardPadding
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: NotificationMetrics.iconSpacing

                // Finger and face scan like Face ID: the Material shape morphs around the glyph until PAM answers.
                Item {
                    id: badge

                    readonly property bool scanning: (root.mode === "fingerprint" || root.mode === "face") && root.phase !== "success"

                    anchors.verticalCenter: parent.verticalCenter
                    width: NotificationMetrics.appIconSize
                    height: width

                    DLoadingIndicator {
                        anchors.fill: parent
                        size: parent.width
                        contained: true
                        visible: badge.scanning && root.phase !== "failed"
                        running: visible && root.expanded && !root.still
                    }

                    DMaterialShape {
                        id: done

                        anchors.fill: parent
                        visible: !badge.scanning || root.phase === "failed"
                        shape: root.phase === "success" ? "cookie9" : "circle"
                        color: root.phase === "success" ? Theme.primary : root.phase === "failed" ? Theme.errorContainer : Theme.primaryContainer
                        scale: root.phase === "success" ? 1 : 0.9

                        Behavior on scale {
                            enabled: !root.still
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    DIcon {
                        anchors.centerIn: parent
                        name: root.phase === "success" ? "check" : Auth.modeIcon(root.mode)
                        size: Theme.iconSize
                        // On the scan the glyph sits on the indicator's onPrimaryContainer shape, so it takes the container tone.
                        color: root.phase === "success" ? Theme.onPrimary : root.phase === "failed" ? Theme.onErrorContainer : badge.scanning ? Theme.primaryContainer : Theme.onPrimaryContainer
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - badge.width - parent.spacing
                    spacing: NotificationMetrics.contentSpacing / 2

                    StyledText {
                        width: parent.width
                        text: root.phase === "success" ? I18n.tr("Authenticated", "island polkit request title: the request passed") : root.activityData.title ?? ""
                        color: Theme.surfaceText
                        font.pixelSize: NotificationMetrics.summarySize
                        font.weight: Theme.fontWeightMedium
                        wrapMode: Text.Wrap
                        maximumLineCount: NotificationMetrics.collapsedLines
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: root.source?.flow?.message ?? ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: NotificationMetrics.bodySize
                        wrapMode: Text.Wrap
                        maximumLineCount: NotificationMetrics.collapsedLines
                        elide: Text.ElideRight
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: text !== "" && root.phase !== "success" && root.mode !== "password"
                text: root.phase === "failed" ? root.failedText : root.source?.flow?.supplementaryMessage ?? ""
                color: root.phase === "failed" || (root.source?.flow?.supplementaryIsError ?? false) ? Theme.error : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                maximumLineCount: NotificationMetrics.collapsedLines
                elide: Text.ElideRight
            }

            DTextField {
                id: passwordField

                width: parent.width
                visible: root.mode === "password" && root.phase !== "success"
                expressive: true
                morph: true
                busy: root.phase === "busy"
                enabled: root.phase !== "busy"
                labelText: root.source?.promptLabel || I18n.tr("Password", "island polkit password field label")
                isError: root.phase === "failed"
                supportingText: isError ? root.failedText : ""
                leftIconName: "lock"
                showPasswordToggle: !(root.source?.flow?.responseVisible ?? false)
                echoMode: (root.source?.flow?.responseVisible ?? false) || passwordVisible ? TextInput.Normal : TextInput.Password
                onAccepted: {
                    root.source?.submit(text);
                    text = "";
                }
            }

            BubbleActions {
                visible: root.phase !== "success"

                BubbleAction {
                    text: I18n.tr("Cancel", "island polkit request: cancel button")
                    onClicked: root.source?.cancel()
                }

                BubbleAction {
                    id: authButton

                    visible: passwordField.visible
                    role: "primary"
                    iconName: "lock_open"
                    text: I18n.tr("Authenticate", "verb, polkit password dialog submit button")
                    busy: root.phase === "busy"
                    enabled: root.phase !== "busy"
                    onClicked: passwordField.accepted()
                }
            }
        }
    }
}
