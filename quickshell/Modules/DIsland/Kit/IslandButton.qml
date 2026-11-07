pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets
import "../../../Common/IslandKit.js" as Kit

// Kit category: every button (primary, secondary, danger, toggle, icon only, text link, copy); the hold and undo buttons
// build on it. The island's one button, a tile on DMS's corner setting, never a pill or a circle:
// - primary: filled, sinks on Interior's CELL spring when pressed; success turns it to the primary color with a check;
// - tonal (secondary): a dark tile with a thin outline; an error turns it red and shakes it;
// - danger: filled red; quiet (text link): no fill, a tile shows on hover;
// - toggle: on = filled with the primary color; no text = a small outlined tile;
// - level (0..1): the volume's live liquid inside (IslandLiquid), its label inverted under it.
StyledButton {
    id: root

    // "primary" (filled), "tonal" or "plain" (the secondary tile), "danger" (filled red), "quiet" (text link).
    property string role: "tonal"
    property string iconName: ""
    // A toggle (mic cut, deafened, VPN): "on" fills it; iconOn and textOn say the state it is in.
    property bool toggle: false
    property bool isOn: false
    property string iconOn: ""
    property string textOn: ""
    // Share of an IslandButtonRow or a BubbleActions row.
    property real weight: 1
    // 0..1 liquid in the button (hold to confirm, undo countdown); -1 hides it.
    property real level: -1
    // The tile sinks when pressed; a hold button stays still and lets its liquid speak.
    property bool sinks: true
    // Working on it (VPN, USB, SSH): DMS's spinner in the icon's place.
    property bool busy: false
    property int buttonHeight: Theme.buttonHeightS
    // Its keyboard shortcut, shown as keys at its right edge (the label then starts at the left).
    property var keys: []
    readonly property real fullKeyRoom: root.keys.length ? keysRow.implicitWidth + Theme.spacingS : 0
    // Too narrow for the label beside its keys: the label wins, the keys go.
    readonly property bool keysShown: root.keys.length > 0 && (root.iconOnly || face.labelWidth + Theme.spacingS * 2 + root.fullKeyRoom <= root.width)
    readonly property real keyRoom: root.keysShown ? root.fullKeyRoom : 0
    // Label at the left (a column of buttons with shortcuts), not centered.
    property bool leading: root.keys.length > 0

    // "success" | "error" for a moment after flash(): the icon becomes a check or a warning, an error shakes.
    property string feedback: ""
    property string feedbackText: ""
    // Keeps the outcome shown while true (a copied secret never goes back to "Copy"); dropping it clears the outcome.
    property bool keepFeedback: false
    onKeepFeedbackChanged: if (!root.keepFeedback)
        root.feedback = ""

    readonly property bool iconOnly: root.shownText === ""
    readonly property string shownText: root.feedback !== "" && root.feedbackText !== "" ? root.feedbackText : (root.toggle && root.isOn && root.textOn !== "" ? root.textOn : root.text)
    readonly property string shownIcon: root.feedback === "success" ? "check" : root.feedback === "error" ? "error" : (root.toggle && root.isOn && root.iconOn !== "" ? root.iconOn : root.iconName)
    readonly property bool still: Theme.currentAnimationBaseDuration <= 0 || SettingsData.reduceMotion
    readonly property bool metered: root.level >= 0
    readonly property bool lit: root.toggle && root.isOn
    readonly property bool outlined: root.role !== "primary" && root.role !== "danger" && root.role !== "quiet" && !root.lit && root.feedback === "" && !root.metered

    readonly property color baseColor: {
        if (root.feedback !== "")
            return root.feedback === "success" ? Theme.primary : Theme.error;
        if (root.lit)
            return Theme.primary;
        switch (root.role) {
        case "primary":
            return root.metered ? Theme.primaryContainer : Theme.primary;
        case "danger":
            return root.metered ? Theme.errorContainer : Theme.error;
        case "quiet":
            return "transparent";
        default:
            return Theme.surfaceContainerHigh;
        }
    }
    readonly property color inkColor: {
        if (!root.enabled)
            return Theme.onSurface_38;
        if (root.feedback !== "")
            return root.feedback === "success" ? Theme.onPrimary : Theme.onError;
        if (root.lit)
            return Theme.onPrimary;
        switch (root.role) {
        case "primary":
            return root.metered ? Theme.onPrimaryContainer : Theme.onPrimary;
        case "danger":
            return root.metered ? Theme.onErrorContainer : Theme.onError;
        case "quiet":
            return Theme.primary;
        default:
            return Theme.surfaceText;
        }
    }
    // The liquid: the role's strong color, the label inverted under it.
    readonly property color fillColor: root.role === "danger" ? Theme.error : Theme.primary
    readonly property color fillInk: root.role === "danger" ? Theme.onError : Theme.onPrimary

    function flash(ok) {
        root.feedback = ok ? "success" : "error";
        feedbackClear.restart();
        if (ok && !root.still)
            checkDraw.restart();
        if (!ok && !root.still)
            shakeAnim.restart();
    }

    function kick(motion, from, to) {
        if (root.still) {
            motion.snapTo(to);
            return;
        }
        motion.snapTo(from);
        motion.retarget(to);
    }

    implicitWidth: root.iconOnly ? root.buttonHeight : Math.max(root.buttonHeight, face.naturalWidth + Theme.spacingS * 2 + root.fullKeyRoom)
    implicitHeight: root.buttonHeight
    radius: Math.min(Theme.cornerRadius, height / 2)
    // Disabled as DMS's buttons: a faint tile and ink; a text link keeps no tile.
    color: root.enabled || root.role === "quiet" ? root.baseColor : Theme.onSurface_12
    border.width: root.outlined ? Theme.layerOutlineWidth : 0
    border.color: Theme.outlineMedium
    Accessible.role: Accessible.Button
    // An icon's ligature is no name: a button without text gets its Accessible.name from the caller, through I18n.tr().
    Accessible.name: root.shownText
    Accessible.checkable: root.toggle
    Accessible.checked: root.lit

    property real _shakeX: 0
    property real _checkProgress: 1
    // The face's x: centred, or at the start of the reading for a leading face (a plain x is not mirrored).
    readonly property real _faceX: !root.leading ? (root.width - face.width) / 2 : I18n.isRtl ? root.width - face.width - Theme.spacingS : Theme.spacingS
    readonly property real sink: root.sinks ? press.value : 0

    transform: Translate {
        x: root._shakeX
        y: root.sink * Theme.spacingXXS
    }
    scale: 1 - (1 - Theme.pressScale) * 1.5 * root.sink

    onDownChanged: press.retarget(root.down ? 1 : 0)
    onShownIconChanged: root.kick(iconPop, root.feedback === "success" ? 0.2 : 0.7, 1)

    Behavior on color {
        enabled: !root.still
        DColorAnim {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    // Interior CELL: presses; POP only for the success check.
    SpringMotion {
        id: press

        readonly property var spec: Kit.spring("cell", Theme.currentAnimationBaseDuration)
        enabled: !root.still
        stiffness: spec.stiffness
        damping: spec.damping
        mass: spec.mass
    }

    SpringMotion {
        id: iconPop

        readonly property var spec: Kit.spring(root.feedback === "success" ? "pop" : "cell", Theme.currentAnimationBaseDuration)
        enabled: !root.still
        stiffness: spec.stiffness
        damping: spec.damping
        mass: spec.mass
        Component.onCompleted: snapTo(1)
    }

    // One shot: Interior's copy and hold buttons go back to rest a moment after their outcome.
    Timer {
        id: feedbackClear

        interval: Kit.feedbackMs
        onTriggered: if (!root.keepFeedback)
            root.feedback = ""
    }

    NumberAnimation {
        id: checkDraw

        target: root
        property: "_checkProgress"
        from: 0
        to: 1
        duration: Kit.beat("checkDraw", Theme.currentAnimationBaseDuration)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.standardDecel
    }

    component ShakeStep: NumberAnimation {
        target: root
        property: "_shakeX"
        duration: shakeAnim.stepMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.standardDecel
    }

    // Interior's error shake (otp-input): one pass, out curve, four steps of 80 ms (320 ms) at DMS's default speed.
    SequentialAnimation {
        id: shakeAnim

        // One step's share of DMS's animation speed.
        readonly property real stepShare: 0.32
        readonly property int stepMs: Math.round(Theme.currentAnimationBaseDuration * shakeAnim.stepShare)
        ShakeStep { to: Kit.shake[1] * Theme.spacingXS }
        ShakeStep { to: Kit.shake[2] * Theme.spacingXS }
        ShakeStep { to: Kit.shake[3] * Theme.spacingXS }
        ShakeStep { to: Kit.shake[4] * Theme.spacingXS }
    }

    // The state layer: hover and press tint the tile (a text link shows as a tile on hover).
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.withAlpha(root.inkColor, root.down ? Theme.stateLayerPressed : root.hovered ? Theme.stateLayerHover : 0)

        Behavior on color {
            enabled: !root.still
            DColorAnim {
                duration: Theme.shorterDuration
                easing.bezierCurve: Theme.expressiveCurves.standardDecel
            }
        }
    }

    // The keyboard's ring (Tab), outside the tile so a filled button shows it too; never after a click.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2 * Theme.outlineWidthFocused
        visible: root.visualFocus
        radius: root.radius + 2 * Theme.outlineWidthFocused
        color: "transparent"
        border.width: Theme.outlineWidthFocused
        border.color: Theme.primary
    }

    IslandLiquid {
        id: liquid

        anchors.fill: parent
        level: Math.max(0, root.level)
        color: root.fillColor
        radius: root.radius
    }

    // The label above the liquid's mean line (all of it without liquid), inverted under it.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: liquid.visible ? liquid.line : root.height
        clip: liquid.visible

        IslandButtonFace {
            id: face

            button: root
            iconScale: iconPop.value

            x: root._faceX
            y: (root.height - height) / 2
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height - liquid.line
        visible: liquid.visible
        clip: true

        IslandButtonFace {
            button: root
            iconScale: iconPop.value
            x: root._faceX
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (root.height - implicitHeight) / 2
            ink: root.fillInk
        }
    }

    Row {
        id: keysRow

        visible: root.keysShown
        x: I18n.isRtl ? Theme.spacingS : root.width - Theme.spacingS - implicitWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXXS
        Accessible.ignored: true

        Repeater {
            model: root.keys

            DKeycap {
                required property string modelData

                text: modelData
                textColor: root.enabled ? Theme.secondary : Theme.onSurface_38
            }
        }
    }
}
