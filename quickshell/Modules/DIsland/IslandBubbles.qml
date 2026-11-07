pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DIsland.Activities
import qs.Modules.DIsland.Cards
import qs.Modules.DIsland.Kit
import qs.Modules.Notifications
import qs.Modules.SurfaceWidgets
import qs.Services
import "../../DCommon/Widgets/MaterialShapes.js" as Shapes
import "../../Common/IslandKit.js" as IslandKit
import "../../Common/IslandArrival.js" as Arrival
import "../../Common/IslandActivities.js" as Activities

// Wings of the island: the machine grows out of its leading side, apps out of its trailing one (above and below on a vertical bar).
// At rest the capsule is three segments of one height and radius; a side with nothing to show has no wing.
// The launcher's tall sheet lets the wings go: each stays a pill and buds off beside the sheet's top, under the bar, the way the
// "Launcher transition" setting says (TileJelly, TileLiquid, TilePivot), and buds back on closing. Hover opens a wing into a card listing what waits.
// Nothing runs at rest: every animation is a spring or a curve started by an event, and reduced motion settles them at once.
Item {
    id: root

    required property var surface
    property var sides: null
    property color color: Theme.hostSurface
    property bool reducedMotion: false

    signal activated(var bubble)
    signal dismissed(var bubble)
    signal hovered(var bubble, bool inside)
    signal wheeled(var bubble, var wheel)

    readonly property var controller: root.surface.controller
    readonly property var motion: root.surface.surfaceMotion
    readonly property bool isVertical: root.surface.isVertical
    // Flatter than the island by one theme step above and below, whatever the island shows (home or a face).
    // Bubble corners: "island" takes the island's own radius (a Notch island's curve), "round" makes pills; both float.
    readonly property bool cornersLikeIsland: SettingsData.islandBubbleCorners !== "round"
    readonly property real size: root.controller.compactFaceThickness - 2 * root.slit
    readonly property real pillRadius: root.cornersLikeIsland ? Math.min(root.size / 2, root.controller.pillRadius) : root.size / 2
    readonly property real slit: Theme.spacingXS
    readonly property real sheetGap: Theme.spacingM
    readonly property var machine: root.sides?.machine ?? null
    readonly property var apps: root.sides?.apps ?? []
    readonly property bool anyWing: !!root.machine || root.apps.length > 0

    // What the island shows, read fresh, and as it stood before this turn: a bubble that goes in the same turn as the
    // island's occupant changes (its face or activity closed, or it took the bubble's info back) never fuses.
    function occupantNow() {
        return root.controller.activeActivity + "|" + root.controller.pluginToken;
    }
    property string occupantSettled: ""
    readonly property string occupant: root.occupantNow()
    onOccupantChanged: Qt.callLater(root.settleOccupant)
    function settleOccupant() {
        root.occupantSettled = root.occupantNow();
    }
    Component.onCompleted: root.settleOccupant()

    // Tuning, named with its reason.
    // Rows a card lists before it would crowd the bar.
    readonly property int maxRows: 4
    // Coming in (birth, hover), the wing's spring is this fraction of the island's stiffness: it trails the island,
    // so the bud and the neck read for ~300 ms; slightly underdamped for a small overshoot.
    readonly property real inStiffness: 0.15
    readonly property real inDampingRatio: 0.6
    // Going away it is the island's own stiffness, critically damped: no overshoot, about twice as fast as coming in.
    readonly property real outDampingRatio: 1
    // The wing's 0..1 states ride a spring that settles to a pixel: carried in hundredths, they settle finely.
    readonly property real springUnit: 100
    // A tile leaves the sheet on a spring this much softer than the island's, so the neck is seen stretching and letting go;
    // it overshoots its place (expressive) with the cascade, and settles plainly without it.
    readonly property real tileStiffness: 0.1
    readonly property real tileDampingRatio: Math.max(0.25, Math.min(0.95, 1 - 0.5 * root.motionGain))
    readonly property real tilePlainDampingRatio: 0.85
    // The apps tile is softer, looser than the machine one (never one rigid piece); it breathes (jelly) as it lands.
    readonly property real tileSoftening: 0.85
    readonly property real tileLanded: 0.98
    // A tile leaving beside the open launcher runs its way back this many times faster than it came (stiffness by its square).
    readonly property real tileLeaveSpeed: 2
    // The Liquid transition runs its trip this many times faster than the others (stiffness by its square): its split and
    // merge read quicker, every time in it following the spring.
    readonly property real liquidSpeed: 1.5
    // Fusion close: the shape travels this many pills from where it gathered, across the gap and into the island.
    readonly property real fuseReach: 1.5
    // How far shape and island melt (the blur before the cut), the glow's size at the contact, how far the island's edge
    // swells there (with the user's motion intensity).
    readonly property real gooReach: Theme.spacingS
    readonly property real glowReach: Theme.spacingM
    readonly property real swellReach: Theme.spacingXS * (1 + root.motionGain)
    // How far the contact's halo spreads, in pills: strong by the contact, next to nothing that far off on a long island.
    readonly property real haloReach: root.size * 3
    // A replaced face's shape beats out by this much as it moves on to its next shape.
    readonly property real morphPulse: IslandKit.morphPulse * root.motionGain // A1
    // A card's content shows early in its growth (the kit's card opening, Interior's SURFACE: content early).
    readonly property real revealFrom: 0.35
    // The pointer has to stay this long before a hover opens the card, so a short pass only breathes.
    readonly property int hoverDwell: 220
    // The dwell counts from where the pointer rests: moving more than this restarts it, so a pass never opens the card.
    readonly property real hoverDeadZone: Theme.spacingS
    // Jelly: a new item stretches the wing outward by this fraction of its length and thins it by the other, then it settles.
    readonly property real jellyStretch: 0.16 * root.motionGain
    readonly property real jellySquash: 0.08 * root.motionGain
    // Blur: the old icon leaves shrunk to this fraction, the new one arrives from it.
    readonly property real blurShrink: 0.6
    // Urgency wave: one ring from the backdrop out to this many times its size.
    readonly property real waveReach: 2.6
    // Magnetic hover: the wing swells by this fraction, leans this many pixels toward the pointer and turns its shape this far.
    readonly property real magnetSwell: 0.05 * root.motionGain
    readonly property real magnetLean: Theme.spacingXS / 2 * root.motionGain
    readonly property real magnetTurn: 20 * root.motionGain

    // Icon backdrop: a tonal shape behind the face's icon springs to its grammar shape on each event, holds, and springs home,
    // inside a capsule that never changes. Grammar: the family says what kind of app, lobes how many wait, spikes how urgent.
    readonly property var families: ({
            "message": ["circle", "cookie9", "cookie7"],
            "mail": ["clover8", "cookie6"],
            "machine": ["cookie12", "cookie9", "clover8", "cookie6", "gem", "cookie7"],
            "media": ["circle"],
            // Each copy walks on, as DMS's clipboard field: spamming copies keeps changing the shape.
            "copy": ["cookie9", "clover8", "cookie6", "gem", "cookie12", "sunny", "cookie7", "softBurst"],
            "alert": ["sunny", "gem", "softBurst"],
            // A device that needs a hand (printer out of paper): orange, softer than an alert.
            "warning": ["sunny", "softBurst"]
        })
    readonly property var countShapes: ["cookie6", "cookie7", "cookie9", "cookie12"]
    // Only soft, balanced shapes that survive the polar morph and the half turn (the catalogue tilts oval and pill, the turn flips heart),
    // and none hollower than 0.78 of its reach, so the icon fits every step of the morph (puffy, flower, clover4, cookie4, verySunny dropped).
    readonly property var flowShapes: ["circle", "cookie6", "cookie7", "cookie9", "cookie12", "clover8", "gem", "sunny", "softBurst"]
    // The island-colored rim a round backdrop leaves inside the capsule.
    readonly property real rim: Theme.spacingXS
    readonly property real backdropRadius: root.size / 2 - root.rim
    // An event shape reaches half the rim further than the round backdrop: it swells, and still stays inside the capsule.
    readonly property real eventReach: root.backdropRadius + root.rim / 2
    // How expressive the wings are (dial lean, stretch and overshoot, jelly, magnet, tile overshoot): the user's motion intensity,
    // 1 at 100 %; the defaults below are the 100 % values.
    readonly property real motionGain: SettingsData.islandBubbleMotion / 100
    // Analog dial: as the level moves, the shape turns with it (a full turn over the whole range) on a soft, underdamped
    // spring, so quick steps carry it on and it settles past the mark; its speed stretches it (and the wing leans and stretches with it).
    readonly property real dialStiffness: 0.25
    readonly property real dialDampingRatio: Math.max(0.25, Math.min(0.95, 1 - 0.6 * root.motionGain))
    readonly property real dialStretchPerDeg: 0.0015 * root.motionGain
    readonly property real dialStretchMax: 0.25 * Math.max(0.01, root.motionGain)
    readonly property real dialTilt: 24 * root.motionGain
    // The wing takes this share of the shape's stretch and of the tilt.
    readonly property real dialWingShare: 0.5
    // Level animation style: "wave" fills the wing like a liquid, "lean" tips and stretches it.
    readonly property string dialStyle: SettingsData.islandBubbleDialStyle
    readonly property bool dialLeans: root.dialStyle === "lean"
    readonly property string launcherTransition: SettingsData.islandBubbleLauncherTransition
    // A pill's upright shape forms this much ahead of its flight beside the launcher.
    readonly property real tileShapeLead: 1.25
    // Wave: the liquid's tone over the wing (the theme's tertiary, well apart from the shapes' primary), and its
    // surface's height per unit of dial pull (a fraction of a pill).
    readonly property real waveFillAlpha: IslandKit.fillAlpha
    readonly property real waveTrackAlpha: IslandKit.waveTrackAlpha(SessionData.isLightMode)
    // An alert's liquid: the theme's error, or its container's text tone where the error is too pale for the pill.
    readonly property color alertHue: IslandKit.legible(Theme.error, Theme.onErrorContainer, root.color, root.waveFillAlpha, IslandKit.legibleMin)
    // The track's gap (after the icon and between liquid and empty part), the value's padding inside it.
    readonly property real trackGap: 3
    readonly property real trackPad: Theme.spacingS
    readonly property real waveHeight: 0.9
    // A value kept beside its track (a transfer's time left): the track is this long.
    readonly property real asideTrack: root.size * 2
    // That value ends as far from the pill's end as the icon's ink from the other end (symmetric).
    readonly property real asideEnd: (root.size - root.iconFit) / 2
    // The breath clock follows DMS's animation speed like the springs do.
    readonly property real breathPace: SettingsData.specDefault("animationDuration") / Math.max(1, SettingsData.animationDuration)
    // Polar radii in the indicator's unit box (0.5 = the event reach): [round backdrop, the event shapes].
    readonly property real unitPx: 2 * root.eventReach
    readonly property var backdropProfiles: {
        const scaled = (name, px) => {
            const radii = Shapes.polarProfile(name, 256);
            const peak = Math.max(...radii);
            return radii.map(r => r / peak * px / root.unitPx);
        };
        return [scaled("circle", root.backdropRadius)].concat(root.flowShapes.map(n => scaled(n, root.eventReach)));
    }
    // The largest even icon whose ink (up to half its box from the centre: a cup's saucer reaches the box's sides) stays 1 px inside the
    // hollowest shape's valley, so it fits every step of the morph.
    readonly property real valley: root.unitPx * Math.min(...root.backdropProfiles.map(p => Math.min(...p)))
    readonly property real iconFit: Math.min(Theme.iconSize, 2 * Math.floor((root.valley - 1) / 0.5 / 2))
    // What lives inside the shape (the weather's sky) stays in the disc every step of the morph keeps: even, centred.
    readonly property real valleyDisc: 2 * Math.floor(root.valley)

    // The outline around the wings and the island, off unless the user turns it on.
    readonly property bool outlined: SettingsData.islandBubbleOutline
    readonly property real outlineWidth: root.outlined ? SettingsData.islandBubbleOutlineWidth : 0
    readonly property real outlineAlpha: SettingsData.islandBubbleOutlineOpacity / 100
    readonly property bool outlineByType: SettingsData.islandBubbleOutlineColor !== "accent"

    // An alert: critical or in the error accent; a call never is one, it rings in DMS's main color (his choice of 25/10).
    function alerting(bubble) {
        return bubble?.call !== true && (bubble?.critical === true || bubble?.accent === "error");
    }
    function familyOf(bubble) {
        if (!bubble)
            return "media";
        if (root.alerting(bubble))
            return "alert";
        // A shape without the alert's ring (a battery under 5 % that is not the critical info).
        if (bubble.shapeFamily)
            return bubble.shapeFamily;
        if (bubble.accent === "warning")
            return "warning";
        if (bubble.source === "system")
            return "machine";
        if (bubble.source === "copy")
            return "copy";
        if (bubble.source === "notification")
            return /mail|thunderbird|geary|evolution|outlook/i.test((bubble.app ?? "") + " " + (bubble.appIcon ?? "")) ? "mail" : "message";
        return "media";
    }
    // Container fill, its "on" color for the icon, the full accent for the ring: theme roles only, so it follows the wallpaper.
    function themeToneOf(family) {
        switch (family) {
        case "alert":
            return [Theme.errorContainer, Theme.onErrorContainer, Theme.error];
        case "warning":
            return [Theme.surfaceContainerHighest, Theme.warning, Theme.warning];
        case "machine":
            return [Theme.secondaryContainer, Theme.onSecondaryContainer, Theme.secondary];
        case "media":
        case "copy":
            return [Theme.primaryContainer, Theme.onPrimaryContainer, Theme.primary];
        }
        return [Theme.tertiaryContainer, Theme.onTertiaryContainer, Theme.tertiary];
    }
    // Shape tone: "theme" keeps the theme's roles; a matugen scheme type takes that scheme's accents for the wallpaper
    // (DMS's own scheme previews), alerts keep the theme's error roles.
    readonly property string shapeTone: SettingsData.islandBubbleShapeTone
    onShapeToneChanged: {
        if (root.shapeTone !== "theme")
            MatugenPreviewService.refresh();
    }
    readonly property var schemeAccents: root.shapeTone === "theme" ? null : (MatugenPreviewService.previews[root.shapeTone]?.[SessionData.isLightMode ? "light" : "dark"] ?? null)
    // shortcut: the previews only carry each scheme's primary, secondary and tertiary, so the container and its "on" color
    // keep the accent's hue at the theme's container lightness (HSL, not HCT); upgrade by having `dms matugen preview` also
    // print the container roles.
    function schemeToneOf(family) {
        const role = family === "machine" ? "secondary" : family === "media" || family === "copy" ? "primary" : "tertiary";
        const accent = Qt.color(root.schemeAccents[role] ?? Theme[role]);
        const satOf = c => Math.min(1, accent.hslSaturation * c.hslSaturation / Math.max(0.01, Theme.primary.hslSaturation));
        return [Qt.hsla(accent.hslHue, satOf(Theme.primaryContainer), Theme.primaryContainer.hslLightness, 1), Qt.hsla(accent.hslHue, satOf(Theme.onPrimaryContainer), Theme.onPrimaryContainer.hslLightness, 1), accent];
    }
    // Shape style: "flat" fills the shape with the container tone; "tonal" keeps it a shade off the wing and colors only the icon.
    readonly property bool tonalShapes: SettingsData.islandBubbleShapeStyle === "tonal"
    function toneOf(family) {
        const tone = family === "alert" || family === "warning" || !root.schemeAccents ? root.themeToneOf(family) : root.schemeToneOf(family);
        if (root.tonalShapes)
            return [Theme.surfaceContainerHighest, tone[2], tone[2]];
        // Flat: the shape in the accent's container and the icon in its "on" color, as DMS's expressive password field
        // (DTextField morph); an alert the error container, a matugen scheme its own.
        if (family === "alert")
            return [Theme.errorContainer, Theme.onErrorContainer, Theme.error];
        if (family === "warning")
            return [Theme.warning, Theme.surface, Theme.warning];
        return root.schemeAccents ? tone : [Theme.primaryContainer, Theme.onPrimaryContainer, Theme.primary];
    }

    // Card grammar shared by both sides (STYLE-cartes.md): the notification popup's inner margin, rows of one height.
    readonly property real pad: NotificationMetrics.cardPadding
    readonly property real rowHeight: root.size + Theme.spacingS
    // Every card is as wide as DMS's notification popups on this screen.
    readonly property real cardWidth: Math.min(NotificationMetrics.popupWidth, Math.max(NotificationMetrics.popupMinWidth, root.surface.alongExtent * NotificationMetrics.popupScreenRatio))
    // Short sheets (an alert, a notification) keep pill wings; the launcher's tall sheet lets them go over four pill heights.
    readonly property real cardStart: root.size * 4
    readonly property real cardSpan: root.size * 4
    // A tile sits one bar row down, so the bar's own widgets keep their row.
    readonly property real tileDrop: root.size + Theme.spacingS

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }
    function mix(a, b, t) {
        return a + (b - a) * t;
    }

    // 0 up to a short sheet, 1 once the sheet is a card span taller; read from the island's spring, so it never runs on its own.
    // An arrival card, or a face's bubble card, is the island growing, not a sheet: the wings stay pills and are pushed aside.
    readonly property bool arrivalGrowth: !root.controller.expanded && (root.controller.notificationActive && root.controller.arrivalPhase !== "rest" || root.controller.faceCardAvailable)
    readonly property real cardness: root.isVertical || root.arrivalGrowth ? 0 : root.clamp01((root.surface.currentVisualCross - root.cardStart) / root.cardSpan)
    readonly property real targetCardness: root.isVertical || root.arrivalGrowth ? 0 : root.clamp01((root.motion.targetHeight - root.cardStart) / root.cardSpan)
    // The pill's near edge (the screen edge side), in near-cross coordinates.
    readonly property real nearCross: root.motion.currentOffsetCross

    // The island's edges as the wings follow them: on a soft spring, so they lag a little and overshoot as the island opens,
    // closes or grows (the wings place themselves outside both this and the real edge, so they never touch the island).
    // The spring keeps its look at any DMS animation speed, and the motion intensity sets its looseness.
    readonly property real followSpring: 4 * root.breathPace * root.breathPace
    readonly property real followDamping: Math.max(0.2, Math.min(1, 0.45 / Math.max(0.1, root.motionGain))) * root.breathPace
    // While a tile flies back the edges are the island's own, so it returns along the path it came out on instead of
    // hanging out on the lagging edge; coming out, the soft edge gives the tiles their bounce.
    readonly property bool tilesReturning: (leading.cardTarget === 0 && leading.tile > 0.01) || (trailing.cardTarget === 0 && trailing.tile > 0.01)
    readonly property bool edgesFollow: !root.reducedMotion && root.anyWing && !root.tilesReturning
    property real leadEdge: root.surface.currentAlongPos
    property real trailEdge: root.surface.currentAlongPos + root.surface.currentVisualAlong
    Behavior on leadEdge {
        enabled: root.edgesFollow
        SpringAnimation {
            spring: root.followSpring
            damping: root.followDamping
            epsilon: 0.25
        }
    }
    Behavior on trailEdge {
        enabled: root.edgesFollow
        SpringAnimation {
            spring: root.followSpring
            damping: root.followDamping
            epsilon: 0.25
        }
    }

    // Centered on the island's row: the island's own thickness while it is a pill, its face row once it is a sheet.
    readonly property real rowOffset: (Math.min(root.surface.currentVisualCross, root.controller.compactFaceThickness) - root.size) / 2
    readonly property real targetRowOffset: (Math.min(root.motion.targetHeight, root.controller.compactFaceThickness) - root.size) / 2
    function crossOf(near, extent) {
        return root.surface.farEdge ? root.surface.crossExtent - near - extent : near;
    }

    // Built from the spring target so the input mask is not rewritten every frame.
    readonly property rect envelope: {
        if (!root.anyWing)
            return Qt.rect(0, 0, 0, 0);
        if (root.isVertical) {
            const start = root.surface.targetAlongPos - root.slit - root.size;
            return Qt.rect(root.surface.targetCrossPos, start, root.size, root.surface.targetVisualAlong + 2 * (root.slit + root.size));
        }
        const sheet = root.targetCardness > 0;
        const hoverOpen = leading.hoverOpen || trailing.hoverOpen;
        const gap = sheet ? root.sheetGap : root.slit;
        // Beside the launcher the pills stand up, each as tall as its own content.
        const rest = sheet ? Math.max(root.size, leading.standLength, trailing.standLength) : root.size;
        const h = (sheet ? root.tileDrop : 0) + (hoverOpen ? Math.max(leading.listHeight, trailing.listHeight, rest) : rest);
        // Only the sides that hold something take input.
        const before = Activities.wingReach(leading.has, leading.hoverOpen, leading.cardWant, leading.ownRest, gap);
        const after = Activities.wingReach(trailing.has, trailing.hoverOpen, trailing.cardWant, trailing.ownRest, gap);
        return Qt.rect(root.surface.targetAlongPos - before, root.crossOf(root.motion.targetOffsetCross + root.targetRowOffset, h), root.surface.targetVisualAlong + before + after, h);
    }

    // The island's own outline while it has wings, with the wings' one.
    MorphSurface {
        motion: root.motion
        x: root.surface.currentVisualX
        y: root.surface.currentVisualY
        width: root.surface.currentVisualWidth
        height: root.surface.currentVisualHeight
        z: 1
        color: "transparent"
        border.width: root.outlineWidth
        border.color: Theme.withAlpha(root.outlineByType ? Theme.outlineVariant : Theme.primary, root.outlineAlpha)
        opacity: root.clamp01(Math.max(leading.presence, trailing.presence))
        visible: root.outlined && opacity > 0.01
    }

    // One open card per system kind, each in its own file under Cards/.
    Component {
        id: cardVolume
        BubbleCardVolume {}
    }
    Component {
        id: cardMicro
        BubbleCardMicro {}
    }
    Component {
        id: cardLuminosite
        BubbleCardBrightness {}
    }
    Component {
        id: cardBatterie
        BubbleCardBattery {}
    }
    Component {
        id: cardReseau
        BubbleCardNetwork {}
    }
    Component {
        id: cardDisk
        BubbleCardDisk {}
    }
    // The crashed app's card (AppCrashService).
    Component {
        id: cardFigee
        BubbleCardCrash {}
    }
    // A finished download (DownloadService): the falling file, name, size, Open / Show.
    Component {
        id: cardTelechargement
        BubbleCardDownload {}
    }

    Component {
        id: cardCorbeille
        BubbleCardTrash {}
    }

    Component {
        id: cardCode2fa
        BubbleCardCode2fa {}
    }

    // A file another device sent (Common/IslandReceived.js reads the sender's notification).
    Component {
        id: cardRecu
        BubbleCardReceived {}
    }

    // USB stick (source "usb"): Open / Eject under its name and free space.
    Component {
        id: cardUsb
        BubbleCardUsb {}
    }
    // VPN dropped (source "vpn"): Reconnect / Cut network when it went down on its own.
    Component {
        id: cardVpn
        BubbleCardVpn {}
    }

    // Open Wi-Fi (kind "openwifi"): Turn on VPN / Always for this network.
    Component {
        id: cardWifi
        BubbleCardWifi {}
    }

    // Incoming SSH (source "ssh"): who and since when, Disconnect.
    Component {
        id: cardSsh
        BubbleCardSsh {}
    }

    // Camera (source "camera"): the filming apps, go to the first one.
    Component {
        id: cardCamera
        BubbleCardCamera {}
    }
    // Low peripheral: the header alone (device, level or time to full).
    Component {
        id: cardPeriph
        BubbleCardBase {}
    }
    Component {
        id: cardCharge
        BubbleCardCharge {}
    }
    // The open island's charge face (the island grows into it on plugging in, or hovered while it charges).
    Component {
        id: cardChargeFace
        BubbleChargeFace {}
    }
    Component {
        id: cardYeux
        BubbleCardEyes {}
    }
    Component {
        id: cardEcran
        BubbleCardScreen {}
    }
    Component {
        id: cardEnergie
        BubbleCardPower {}
    }
    Component {
        id: cardKeepAwake
        BubbleCardKeepAwake {}
    }
    Component {
        id: cardNpd
        BubbleCardDnd {}
    }
    Component {
        id: cardSortie
        BubbleCardOutput {}
    }
    Component {
        id: cardCall
        BubbleCardCall {}
    }
    Component {
        id: cardProgression
        BubbleCardProgress {}
    }
    Component {
        id: cardTransferts

        BubbleCardTransfers {}
    }
    Component {
        id: cardShelf

        BubbleCardShelf {}
    }

    Component {
        id: cardImpression
        BubbleCardPrint {}
    }
    Component {
        id: cardCopy
        BubbleCardCopy {}
    }
    Component {
        id: cardWeather
        BubbleCardWeather {}
    }

    // A bubble's own card, the same in its wing and in the island when its face there is hovered or clicked.
    function cardFor(face) {
        switch (face?.source) {
        case "transfer":
            return cardTransferts;
        case "shelf":
            return cardShelf;
        case "camera":
            return cardCamera;
        case "ssh":
            return cardSsh;
        case "vpn":
            return cardVpn;
        case "code2fa":
            return cardCode2fa;
        case "usb":
            return cardUsb;
        case "print":
            return cardImpression;
        case "copy":
            return cardCopy;
        }
        if (face?.received)
            return cardRecu;
        switch (face?.source) {
        case "trash":
            return cardCorbeille;
        case "download":
            return cardTelechargement;
        case "progress":
            return cardProgression;
        case "frozen":
            return cardFigee;
        case "call":
            return cardCall;
        case "system":
            return ({
                    "volume": cardVolume,
                    "mic": cardMicro,
                    "brightness": cardLuminosite,
                    "battery": cardBatterie,
                    "charging": cardCharge,
                    "charged": cardCharge,
                    "chargeface": cardChargeFace,
                    "unplugged": cardBatterie,
                    "batterycritical": cardBatterie,
                    "network": cardReseau,
                    "disk": cardDisk,
                    "eyes": cardYeux,
                    "display": cardEcran,
                    "periph": cardPeriph,
                    "weatheralert": cardWeather,
                    "powerprofile": cardEnergie,
                    "keepawake": cardKeepAwake,
                    "dnd": cardNpd,
                    "output": cardSortie,
                    "openwifi": cardWifi
                })[face.kind] ?? null;
        }
        return null;
    }

    Wing {
        id: leading

        side: -1
        items: root.sides?.machines ?? []
    }

    Wing {
        id: trailing

        side: 1
        items: root.apps
    }

    // A plugin's permanent bubble per side (IslandActivityService.setPermanent), loaded only while one is set or still
    // leaving; above the wings so its dot sits on the event's bubble.
    PermanentSlot {
        side: "left"
        wing: leading
    }

    PermanentSlot {
        side: "right"
        wing: trailing
    }

    component PermanentSlot: Loader {
        id: slot

        required property string side
        required property var wing
        readonly property var spec: IslandActivityService.permanentOn(slot.side)
        readonly property bool itemVisible: slot.item?.visible ?? false
        // Kept while the bubble leaves; let go after the spring step that hid it, since unloading inside it breaks the step.
        property bool keep: false
        onItemVisibleChanged: {
            if (slot.itemVisible)
                slot.keep = true;
            else
                Qt.callLater(() => slot.keep = slot.itemVisible);
        }

        z: 5
        active: !!slot.spec || slot.keep
        sourceComponent: IslandPermanent {
            bubbles: root
            wing: slot.wing
            spec: slot.spec
        }
    }

    component Wing: Item {
        id: wing

        required property int side
        readonly property alias spring: life
        property var items: []
        // Kept while the face fades, so the last face does not blank mid-motion.
        property var shownItems: []
        readonly property bool has: wing.items.length > 0
        readonly property var face: wing.shownItems.length > 0 ? wing.shownItems[0] : null
        // The open card shows one info at a time: the face first, the ones waiting behind it (its 8 px dot) a page each,
        // turned by the wheel, a sideways drag or a page dot, as the island's burst. Back to the face once it changes.
        property int page: 0
        readonly property bool paging: wing.shownItems.length > 1 && !root.isVertical
        readonly property var paged: wing.shownItems[Math.min(wing.page, wing.shownItems.length - 1)] ?? wing.face
        readonly property string pageOwner: wing.face?.id ?? ""
        onPageOwnerChanged: wing.page = 0
        function turnPage(step) {
            const next = Arrival.go({
                "items": wing.shownItems,
                "index": wing.page
            }, wing.page + step);
            if (next)
                wing.pick(next.index);
            return next !== null;
        }
        // The shelf never opens beside the island: its page, turned to, opens it in the island and lets this card go.
        function pick(index) {
            const item = wing.shownItems[index];
            if (index > 0 && item?.source === "shelf") {
                root.hovered(wing.face, false);
                root.activated(item);
                return;
            }
            wing.page = index;
        }
        property var pageWheel: Arrival.wheelIdle()
        // A face with blink (low peripheral) blinks its level gauge a few times as it shows or moves.
        IslandGaugeBlink {
            id: gaugeBlink

            on: wing.face?.blink === true
            // A peripheral's level stands on its tile (standLevel), its progress staying -1.
            level: (wing.face?.progress ?? -1) >= 0 ? wing.face.progress : (wing.face?.standLevel ?? -1)
        }
        // Lists are rebuilt on every update (a ticking timer): only a longer one is a new item.
        property int lastCount: 0
        onItemsChanged: {
            const n = wing.items.length;
            if (n > wing.lastCount && wing.presence > 0.5 && !root.reducedMotion)
                jelly.restart();
            wing.lastCount = n;
            // A held notification's wrapper ticks while it waits: keep the shown list (and its rows) unless what they show changed.
            if (n > 0 && wing.showKey(wing.items) !== wing.showKey(wing.shownItems))
                wing.shownItems = wing.items;
        }
        function showKey(list) {
            // A copy's picture by its length only: joining a whole data URL on every tick would cost more than it says.
            return list.map(b => [b.id, b.title, b.detail, b.text, b.icon, b.image, b.progress, b.critical, b.open, b.details, b.typeIcon, b.thumb?.length, b.standLevel, b.standText].join("\u001f")).join("\u001e");
        }

        readonly property bool alarming: wing.shownItems.some(b => root.alerting(b))
        readonly property string family: wing.alarming ? "alert" : root.familyOf(wing.face)
        readonly property var tone: root.toneOf(wing.family)
        // An app's own icon (no symbol over it): the kit's flower outline, never a filled backdrop.
        readonly property bool appFace: wing.symbol === "" && (wing.face?.image ?? "") !== ""
        readonly property string symbol: wing.face?.call === true ? "call" : wing.face?.received ? "download" : wing.face?.source === "notification" ? (wing.family === "mail" ? "mail" : wing.family === "alert" ? "priority_high" : "chat") : (wing.face?.icon ?? "")
        readonly property string count: wing.items.length > 1 ? "+" + (wing.items.length - 1) : ""
        // A change of what the wing says (birth, occupant, count, alert, a copy's pulse) moves it to its grammar shape.
        // The machine's bubbles share one id: their kind tells them apart.
        readonly property string eventKey: !wing.has ? "" : [wing.items.length, wing.items[0]?.id, wing.items[0]?.kind ?? "", wing.items[0]?.pulse ?? 0, wing.items.some(b => root.alerting(b))].join("|")
        onEventKeyChanged: {
            if (wing.eventKey !== "")
                wing.breathe(true);
        }
        // The level moving (machine value, an app's progress per 10 %) turns the shape like a dial; without the dial, one breath.
        readonly property string levelKey: !wing.has ? "" : String(wing.side < 0 ? wing.items[0]?.text : Math.floor((wing.items[0]?.progress ?? -1) * 10))
        onLevelKeyChanged: {
            if (wing.levelKey !== "" && !wing.dialing)
                wing.breathe(false);
        }

        // Analog dial: the shape's own spring toward a turn of the level, ticking only while it moves.
        readonly property real level: wing.face?.progress ?? -1
        readonly property bool dialing: !root.reducedMotion && wing.level >= 0
        property real dialAngle: 0
        property real dialVel: 0
        property real dialTo: 0
        property string dialOwner: ""
        onLevelChanged: {
            // Without a level the dial just stays where it is.
            if (!wing.dialing) {
                wing.dialTo = wing.dialAngle;
                return;
            }
            const to = wing.level * 360;
            const owner = wing.face?.id ?? "";
            // A stream (a transfer's bytes) adds no energy: only a speed change (face.surgeAt) makes waves.
            if (wing.face?.stream === true && owner === wing.dialOwner) {
                wing.dialAngle += to - wing.dialTo;
                wing.dialTo = to;
                return;
            }
            // Each step of the same level moves the shape on, turning left as it goes down and right as it goes up.
            if (owner === wing.dialOwner && to !== wing.dialTo && wing.presence > 0.5)
                wing.breathe(true, to > wing.dialTo ? 1 : -1);
            wing.dialTo = to;
            // A new owner or no viewer: land at once; the base angle takes the difference, nothing turns on screen.
            if (owner !== wing.dialOwner || !root.visible) {
                wing.dialOwner = owner;
                wing.baseAngle += wing.dialAngle - to;
                wing.dialAngle = to;
                wing.dialVel = 0;
            }
        }
        readonly property bool dialMoving: (Math.abs(wing.dialTo - wing.dialAngle) > 0.05 || Math.abs(wing.dialVel) > 0.5)
        FrameAnimation {
            property real pending: 0
            running: wing.dialMoving
            onTriggered: {
                if (!root.visible) {
                    wing.dialAngle = wing.dialTo;
                    wing.dialVel = 0;
                    return;
                }
                // Ticks under a millisecond apart (several windows driving the clock) are folded into the next one.
                pending += frameTime;
                if (pending < 0.001)
                    return;
                const dt = Math.min(pending, 1 / 30);
                pending = 0;
                const k = root.motion.stiffness * root.dialStiffness;
                const to = wing.dialTo;
                let vel = wing.dialVel, angle = wing.dialAngle;
                vel += (k * (to - angle) - 2 * root.dialDampingRatio * Math.sqrt(k) * vel) * dt;
                angle += vel * dt;
                // Lands once what is left can no longer be seen: under half a degree, and a pull under a quarter pixel.
                if (Math.abs(to - angle) < 0.5 && Math.abs(vel * root.dialStretchPerDeg) * Math.max(root.size, wing.length) < 0.25) {
                    angle = to;
                    vel = 0;
                }
                wing.dialVel = vel;
                wing.dialAngle = angle;
            }
        }
        // How fast the dial turns, signed, as a stretch: 0 at rest.
        readonly property real dialPull: wing.dialing ? Math.max(-root.dialStretchMax, Math.min(root.dialStretchMax, wing.dialVel * root.dialStretchPerDeg)) : 0
        // A change of a stream's speed (face.surgeAt) pushes the spring, harder the bigger the jump, up to the speed where
        // the pull is already at its most; the spring settles it.
        readonly property int surgeAt: wing.face?.surgeAt ?? 0
        onSurgeAtChanged: {
            const push = IslandKit.surgeKick(wing.face?.surge ?? 0, root.motionGain) * 360;
            if (push <= 0 || !wing.dialing || !root.visible || wing.presence < 0.5 || root.reducedMotion)
                return;
            const most = root.dialStretchMax / Math.max(1e-6, root.dialStretchPerDeg);
            wing.dialVel = Math.max(-most, Math.min(most, wing.dialVel + push));
            gaugeLiquid.kick(push / 360);
        }
        // The liquid's tone: the face's own (face.hue, a transfer's state), else tertiary; error on an alert (its container
        // is too close to the wing's surface to read as a level). A face may give its track a tone of its own
        // (face.trackHue) so the liquid keeps its contrast against it.
        // A face may turn it to the alert by a share (face.alertShare, the disk as it fills).
        readonly property color liquidHue: wing.face?.hue ?? (wing.face?.alertShare !== undefined ? Theme.blend(Theme.tertiary, root.alertHue, wing.face.alertShare) : wing.alarming ? root.alertHue : Theme.tertiary)
        readonly property color trackHue: wing.face?.trackHue ?? wing.liquidHue
        readonly property color trackColor: Theme.withAlpha(wing.trackHue, root.waveTrackAlpha)
        readonly property color liquidColor: Theme.withAlpha(wing.liquidHue, root.waveFillAlpha)
        // An alert sends one wave out of the shape.
        onAlarmingChanged: {
            if (wing.alarming && wing.has && !root.reducedMotion)
                wave.play();
        }
        // A ringing call rings on and rocks its shape until it goes.
        readonly property bool ringing: wing.face?.call === true
        readonly property real rock: wave.swing * IslandKit.ringTilt
        onRingingChanged: {
            if (wing.ringing && !root.reducedMotion)
                wave.play();
            else if (!wing.ringing)
                wave.stop();
        }
        // A call under way rings twice as it comes, like any call (his choice of 25/10).
        readonly property bool calling: wing.face?.source === "call"
        onCallingChanged: {
            if (wing.calling && wing.has && !root.reducedMotion)
                wave.play();
        }
        // Leaving for the launcher's side, or coming back, is one more breath of the shape.
        readonly property bool sheeted: wing.cardTarget > 0
        onSheetedChanged: {
            if (wing.has)
                wing.breathe(false);
        }
        // Spikes escalate with each event while an alert waits, lobes follow the count, else the family walks its own shapes.
        // Only what the wing says moves it on (advance); a hover, a click or the launcher keep the shape and just turn it.
        property string shapeKey: ""
        property int variant: 0
        function grammarShape(advance) {
            if (!advance && wing.shapeAt >= 0)
                return root.flowShapes[wing.shapeAt];
            const count = Math.min(wing.items.length, root.countShapes.length + 1);
            const fam = wing.items.some(b => root.alerting(b)) ? "alert" : root.familyOf(wing.items[0]);
            const key = fam + "|" + count;
            wing.variant = key === wing.shapeKey ? wing.variant + 1 : 0;
            wing.shapeKey = key;
            const shapes = root.families[fam];
            if (fam === "alert")
                return shapes[Math.min(wing.variant, shapes.length - 1)];
            // A copy walks its shapes even with more waiting: each copy must show.
            if (count > 1 && fam !== "copy")
                return root.countShapes[count - 2];
            return shapes[wing.variant % shapes.length];
        }
        // Breath clock (ms since the event): one per wing, ticking only for the ~0.3 s of a morph, past its end at rest.
        // The shape stays: it rests on its grammar shape (round until the first event) and morphs from one to the next.
        // Profile 0 is the shape on screen when an event cuts a morph short, so the next one starts from it: no jump.
        property var caught: root.backdropProfiles[0]
        readonly property var breathProfiles: [wing.caught].concat(root.backdropProfiles)
        property real clock: 1e9
        property int shapeAt: -1
        property int fromAt: 1
        property real baseAngle: 0
        readonly property real endAt: backdrop.settleTime * 1000
        readonly property int peakAt: wing.shapeAt < 0 ? 1 : 2 + wing.shapeAt
        readonly property real morph: backdrop.springAt(wing.clock / 1000)
        // Only the two shapes of the morph: each new list costs an indicator its bounds and texture, row by row.
        readonly property var shapes: [wing.breathProfiles[wing.fromAt], wing.breathProfiles[wing.peakAt]]
        // Half a turn per morph lands two-fold shapes upright; a hover leans it toward the pointer; the dial turns it with the level.
        // The dial turns it with the level (lean) or lets it float (wave).
        readonly property bool leans: root.dialLeans
        readonly property real dialTurn: wing.leans ? wing.dialAngle : 0
        // The way the current morph turns: right (clockwise) unless a level going down turns it left.
        property int turnDir: 1
        readonly property real shapeAngle: wing.baseAngle + wing.turnDir * 180 * wing.morph + root.magnetTurn * wing.lean + wing.dialTurn
        function breathe(advance, dir) {
            if (wing.clock < wing.endAt) {
                // The shader shows the mix clamped to 0..1, so the caught shape is exactly what is on screen.
                const from = wing.breathProfiles[wing.fromAt];
                const to = wing.breathProfiles[wing.peakAt];
                const m = root.clamp01(wing.morph);
                wing.caught = from.map((r, i) => r + (to[i] - r) * m);
                wing.fromAt = 0;
            } else {
                wing.fromAt = wing.peakAt;
            }
            wing.baseAngle = (wing.baseAngle + wing.turnDir * 180 * wing.morph) % 360;
            wing.turnDir = dir ?? 1;
            wing.shapeAt = Math.max(0, root.flowShapes.indexOf(wing.grammarShape(advance)));
            wing.clock = root.reducedMotion || !root.visible || !root.controller.bubblesEnabled ? 1e9 : 0;
        }
        FrameAnimation {
            property real pending: 0
            running: wing.clock < wing.endAt
            onTriggered: {
                // Ticks under a millisecond apart are folded into the next one, as for the dial.
                pending += frameTime;
                if (pending < 0.001 && root.visible)
                    return;
                wing.clock = root.visible ? wing.clock + pending * 1000 * root.breathPace : 1e9;
                pending = 0;
            }
        }
        property bool dwelt: false
        Timer {
            id: dwell

            interval: root.hoverDwell
            onTriggered: wing.dwelt = true
        }
        // Dead zone: while the dwell runs, a pointer that travels more than the zone starts it over from where it is.
        property point dwellFrom: Qt.point(0, 0)
        readonly property point pointerAt: hover.point.position
        onPointerAtChanged: {
            if (!hover.hovered || wing.dwelt)
                return;
            if (Math.hypot(wing.pointerAt.x - wing.dwellFrom.x, wing.pointerAt.y - wing.dwellFrom.y) <= root.hoverDeadZone)
                return;
            wing.dwellFrom = wing.pointerAt;
            dwell.restart();
        }

        // The pill is the icon alone, one size for every bubble (STYLE-cartes.md); the counter sits on its corner.
        readonly property real counterNeed: 0
        // Every level dial keeps its track's room with the value centered in it (only the wave style fills it with liquid);
        // the sleep bubble keeps its countdown or a living infinity beside its cup.
        readonly property bool levelled: wing.level >= 0 && wing.face !== null && !root.isVertical
        readonly property bool tracked: root.dialStyle === "wave" && wing.levelled
        // A state that lasts with a value (a call's duration: face.valued) keeps it beside its icon too.
        readonly property bool labelled: (wing.levelled || wing.face?.infinite !== undefined || wing.face?.valued === true) && !root.isVertical
        // A value that is not the level itself (a transfer's time left; face.aside) sits past the end of a fixed track, so
        // the front never runs under it; standing, the pill keeps its icon alone.
        readonly property bool aside: wing.levelled && wing.face?.aside === true
        // A level for the upright pill only (face.standLevel, the disk's used share) shows standing as a level does, the flat
        // pill keeps its icon alone; a value alone (face.standText: the weather's "15′") stands under the icon, no gauge.
        readonly property bool standValued: !wing.levelled && ((wing.face?.standLevel ?? -1) >= 0 || (wing.face?.standText ?? "") !== "") && !root.isVertical
        readonly property bool standTracked: root.dialStyle === "wave" && wing.standValued && (wing.face?.standLevel ?? -1) >= 0
        // A transfer's track (face.waveBar) is DMS's wave progress (Kit/IslandWaveProgress), not the liquid.
        readonly property bool waveBar: wing.aside && wing.face?.waveBar === true
        // A value too long for the upright pill may give a shorter one for it (face.standText: a call's "12m").
        readonly property string caption: wing.labelled ? (wing.upright && wing.face?.standText ? wing.face.standText : wing.face?.text ?? "") : wing.standValued ? wing.face.standText ?? "" : ""
        readonly property bool infinite: wing.labelled && wing.face.infinite === true && wing.caption === ""
        readonly property real labelWidth: wing.infinite ? infinity.width : compactLabel.implicitWidth
        // A face's action mark (face.mark, reopen's "replay"): a second icon slot, one pill wide, beside the app icon.
        readonly property string mark: root.isVertical ? "" : wing.face?.mark ?? ""
        // Past the value: the track's round end, clear of the last glyph.
        readonly property real stopRoom: root.size / 2 + root.trackGap
        readonly property real glyphSlack: wing.face?.battery && wing.labelled && !wing.upright ? Math.max(0, (root.size - root.iconFit * IslandKit.batteryPileUnits / IslandKit.batteryBoxUnits) / 2 - Theme.spacingS) : 0
        // The pill's length: its icon, then what it carries (a track aside, a level track, a label or the infinity, an
        // action mark), nothing more otherwise.
        readonly property real need: {
            if (!wing.has)
                return 0;
            if (wing.aside)
                return root.size + root.trackGap + root.asideTrack + root.trackPad + root.asideEnd + wing.labelWidth;
            if (wing.levelled)
                return root.size + root.trackGap + root.trackPad + wing.stopRoom + wing.labelWidth;
            if (wing.labelled && (wing.caption !== "" || wing.infinite))
                return root.size + wing.labelWidth + Theme.spacingS - wing.glyphSlack;
            return root.size + (wing.mark !== "" ? root.size : 0);
        }
        // Text shows only in the last few pixels of the wing's growth, at its final width, never cut on the way.
        readonly property real labelRoom: root.clamp01(((wing.upright ? wing.thick - wing.standLength : Math.max(wing.length, wing.thick) - wing.need)) / Theme.spacingS + 1)
        property real listHeight: root.pad * 2 + (kindCard.item ? kindCard.implicitHeight : root.rowHeight)
        // An open card whose list changes resizes instead of jumping.
        Behavior on listHeight {
            enabled: !root.reducedMotion && wing.hoverGrow > 0.01
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }

        // The wing's own spring, drawn from the island's (width = presence, height = hover, offsetCross = tile, in springUnit).
        VectorSpringMotion {
            id: life

            reducedMotion: root.reducedMotion
            mass: root.motion.mass
            Component.onCompleted: life.snapTo(wing.lifeTarget())
        }
        // Any sheet tall enough makes whole tiles on both sides, never a half-way shape.
        // Only a side that holds something is a tile: one arriving flies down from the sheet's corner, one leaving flies back.
        // A side about to close in place (fusion or fade) keeps its tile until it is gone, whichever of has and this updates first.
        readonly property real cardTarget: (wing.has || wing.closesInPlace) && wing.carded && root.targetCardness > 0 ? 1 : 0
        function lifeTarget() {
            return {
                "width": wing.has && !wing.bornAfterFold ? root.springUnit : 0,
                "height": wing.hoverOpen ? root.springUnit : 0,
                "offsetAlong": 0,
                "offsetCross": wing.cardTarget * root.springUnit,
                "topLeftRadius": 0,
                "topRightRadius": 0,
                "bottomLeftRadius": 0,
                "bottomRightRadius": 0
            };
        }
        function retarget(entering) {
            if (!entering && wing.leaving)
                return;
            const spring = wing.springFor(entering);
            life.stiffness = spring.k;
            life.damping = spring.c;
            life.setTarget(wing.lifeTarget());
        }
        // A card opening or closing on hover rides the island's own spring, as the island grows into its face's card (his
        // choice of 25/10: the same motion and speed for both).
        function retargetCard() {
            if (!wing.hoverOpen && wing.leaving)
                return;
            life.stiffness = root.motion.stiffness;
            life.damping = root.motion.damping;
            life.setTarget(wing.lifeTarget());
        }
        // The wing's own spring in and out: stiffness k and damping c.
        function springFor(entering) {
            const k = root.motion.stiffness * (entering ? root.inStiffness : 1);
            return {
                "k": k,
                "c": 2 * (entering ? root.inDampingRatio : root.outDampingRatio) * Math.sqrt(k * life.mass)
            };
        }
        // With the sheet, the wing rides a softer spring than the island's, so its bud is seen stretching and letting go.
        function followSheet() {
            if (!wing.has && wing.leaving)
                return;
            life.stiffness = root.motion.stiffness * root.tileStiffness * (wing.side > 0 && !root.reducedMotion ? root.tileSoftening : 1) * (wing.has ? 1 : root.tileLeaveSpeed * root.tileLeaveSpeed) * (wing.tx === tileLiquid ? root.liquidSpeed * root.liquidSpeed : 1);
            // Leaving, the same spring fully damped, so the tile never bounces back into sight once it is gone.
            life.damping = 2 * (!wing.has ? 1 : !root.reducedMotion ? root.tileDampingRatio : root.tilePlainDampingRatio) * Math.sqrt(life.stiffness * life.mass);
            life.setTarget(wing.lifeTarget());
        }
        // Cascade: the apps side leaves (and comes back) a beat after the machine side.
        Timer {
            id: cascade

            interval: Theme.shorterDuration
            onTriggered: wing.followSheet()
        }
        onCardTargetChanged: {
            if (wing.side > 0 && !root.reducedMotion)
                cascade.restart();
            else
                wing.followSheet();
        }
        readonly property bool alive: wing.has
        // Closing where it stands (a pill, or a tile beside the launcher, seen and not opened as a card): the fusion, or with
        // reduced motion a plain fade.
        readonly property bool closesInPlace: IslandKit.closesInPlace({
            "ready": wing.visible && wing.presence > 0.5 && (wing.tile > 0.5 || root.cardness < 0.01),
            "hoverGrow": wing.hoverGrow,
            "selfOpened": wing.selfOpened,
            "hovered": hover.hovered
        })
        // Kept past the face's end: by the time the wing closes, its face may already be gone.
        property bool selfOpened: false
        Binding {
            target: wing
            property: "selfOpened"
            value: wing.face?.open === true
            when: wing.face !== null
            restoreMode: Binding.RestoreNone
        }
        // Kept the same way: the island taking this source's own info as the face leaves is the bubble going in.
        property string lastSource: ""
        Binding {
            target: wing
            property: "lastSource"
            value: wing.face?.source ?? ""
            when: wing.face !== null
            restoreMode: Binding.RestoreNone
        }
        // A bubble coming out of the island as it folds (the shelf's card closed) is born once the island has its size,
        // at its edge, instead of riding the shrinking edge in from afar.
        readonly property bool islandFolding: root.surface.currentVisualAlong > root.surface.targetVisualAlong + 1
        // Out of the island itself (it held this source's card the turn before): it waits for the island to close, too,
        // unless the island now holds something else open (a launcher folded the card): then once it has its size.
        readonly property bool islandBusy: wing.islandFolding || root.controller.expanded && IslandKit.tookIn(root.occupant, wing.lastSource)
        property bool bornAfterFold: false
        // Checked a turn later: the island closes (expanded false) a moment before its fold starts.
        onIslandBusyChanged: {
            if (!wing.islandBusy && wing.bornAfterFold)
                Qt.callLater(wing.bornAfter);
        }
        function bornAfter() {
            if (wing.islandBusy || !wing.bornAfterFold)
                return;
            wing.bornAfterFold = false;
            if (wing.alive)
                wing.retarget(true);
        }
        onAliveChanged: {
            wing.bornAfterFold = false;
            if (wing.alive) {
                wing.stopClose();
                const comingOut = IslandKit.tookIn(root.occupantSettled, wing.face?.source) && wing.islandBusy;
                if ((wing.islandFolding || comingOut) && wing.presence < 0.01 && !root.reducedMotion)
                    wing.bornAfterFold = true;
                else
                    wing.retarget(true);
                return;
            }
            const style = IslandKit.closeStyle({
                "inPlace": wing.closesInPlace,
                "reduced": root.reducedMotion,
                "occupantBefore": root.occupantSettled,
                "occupantNow": root.occupantNow(),
                "source": wing.lastSource
            });
            if (style === "fuse") {
                // Exit spring (the island's stiffness, critical damping); the shape meets the island this far along.
                const spring = wing.springFor(false);
                wing.fuseOmega = Math.sqrt(spring.k / life.mass);
                wing.fuseContact = IslandKit.fuseContact(wing.gap, root.size, root.fuseReach);
                wing.fuse = 0;
                wing.fuseEdge = wing.edgeNow;
                wing.fusing = true;
                // A card it opened itself folds onto its shape on the same spring while the shape gathers; the pill stays.
                const target = wing.lifeTarget();
                target.width = root.springUnit;
                target.height = 0;
                life.stiffness = spring.k;
                life.damping = spring.c;
                life.setTarget(target);
                return;
            }
            if (style === "fade") {
                wing.fading = true;
                fadeRun.restart();
                return;
            }
            // A tile beside the open launcher leaves the way it came, reversed: it flies back up to the sheet's corner on the
            // tile spring, shrinking and fading, its shape morphing back to round the other way.
            if (wing.carded && wing.tile > 0.5 && wing.presence > 0.5 && !root.reducedMotion) {
                wing.breathe(false, -1);
                wing.shapeAt = -1;
                wing.followSheet();
                return;
            }
            wing.retarget(false);
        }
        readonly property real presence: Math.max(0, life.currentWidth / root.springUnit)

        // Fusion (fuse = ω·t on the exit spring, IslandKit.fusionPhases): the text fades, the wing gathers onto its shape,
        // then the shape flows into the island and melts into its edge (the goo layer, below), a halo spreading from the
        // contact. The wing's spring is left alone until the end, so nothing else moves it meanwhile.
        property bool fusing: false
        property bool fading: false
        readonly property bool leaving: wing.fusing || wing.fading
        property real fuse: 0
        property real fade: 1
        property real fuseOmega: 0
        property real fuseContact: 1
        readonly property var phase: IslandKit.fusionPhases(wing.fuse, wing.fuseContact)
        // Along the bar: where the wing's shape sits, and the island's edge on its side.
        function iconAlong() {
            return root.isVertical ? wing.y + wing.iconY : wing.x + wing.iconX;
        }
        function edgeAlong() {
            return wing.side < 0 ? root.surface.currentAlongPos : root.surface.currentAlongPos + root.surface.currentVisualAlong;
        }
        function stopClose() {
            fadeRun.stop();
            wing.fusing = false;
            wing.fading = false;
            wing.fuse = 0;
            wing.fade = 1;
        }
        function endClose() {
            wing.stopClose();
            // Gone: no tile left to fly home.
            const target = wing.lifeTarget();
            target.offsetCross = 0;
            life.snapTo(target);
        }
        // The run on a 60 per second clock (a Timer, not an animation: a running animation redraws the whole island at
        // every frame of the screen, 240 a second, even between two steps).
        Timer {
            property real last: 0

            interval: 16
            repeat: true
            running: wing.fusing
            onRunningChanged: last = Date.now()
            onTriggered: {
                const now = Date.now();
                const dt = (now - last) / 1000;
                last = now;
                if (!root.visible) {
                    wing.endClose();
                    return;
                }
                // The phase binding computes the step once; endClose drops it at once if it is the last.
                wing.fuse += dt * wing.fuseOmega;
                if (wing.phase.done)
                    wing.endClose();
            }
        }
        // Reduced motion: the whole bubble fades where it is, no shape, no spring.
        NumberAnimation {
            id: fadeRun

            target: wing
            property: "fade"
            from: 1
            to: 0
            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveFastEffects, false)
            onFinished: wing.endClose()
        }

        // A tile breathes as it lands, and again as it lands back beside the island: one jelly beat each way.
        readonly property bool landed: wing.carded && wing.tile > root.tileLanded
        onLandedChanged: {
            if (wing.landed && !root.reducedMotion)
                jelly.restart();
        }
        readonly property bool home: wing.tile < 1 - root.tileLanded
        onHomeChanged: {
            if (wing.home && wing.cardTarget === 0 && wing.presence > 0.5 && !root.reducedMotion)
                jelly.restart();
        }

        // Jelly: out fast past the stretch, back past rest, then settled (both curves overshoot).
        property real stretch: 0
        SequentialAnimation {
            id: jelly

            NumberAnimation {
                target: wing
                property: "stretch"
                to: 1
                duration: Theme.expressiveDurations.expressiveFastEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: wing
                property: "stretch"
                to: 0
                duration: Theme.expressiveDurations.expressiveSlowSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveSlowSpatial
            }
        }

        // Magnetic hover: swell toward the pointer and lean its way, on an expressive curve in and out.
        property real magnet: hover.hovered && wing.has && wing.hoverGrow < 0.01 && !root.reducedMotion ? 1 : 0
        Behavior on magnet {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }
        readonly property real pointerLean: hover.hovered && wing.width > 0 ? Math.max(-1, Math.min(1, (hover.point.position.x - wing.width / 2) / (wing.width / 2))) : 0
        readonly property real lean: wing.magnet * wing.pointerLean

        // Face content fades in on arrival and out faster when the side empties.
        // A tile leaving beside the open launcher fades as it came in, not on the quick exit.
        // A fading side keeps it whole: the bubble fades as one; a fusing one fades it on the fusion's own run.
        readonly property bool leavingTile: !wing.has && wing.carded && wing.tile > 0.5 && !wing.fusing
        property real content: wing.has || wing.leavingTile || wing.leaving ? 1 : 0
        Behavior on content {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: wing.has || wing.leavingTile ? Theme.expressiveDurations.expressiveEffects : Theme.variantDuration(Theme.expressiveDurations.expressiveFastEffects, false)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: wing.has || wing.leavingTile ? Theme.expressiveCurves.expressiveEffects : Theme.variantExitCurve
            }
        }

        // The outer of the sheet's target and current edges: still the open sheet's edge in the frame its close begins, whichever
        // of the island's targets updates first, so a tile on its way back never loses its room mid-flight.
        readonly property real sheetEdge: wing.side < 0 ? Math.min(root.surface.targetAlongPos, root.surface.currentAlongPos) : Math.max(root.surface.targetAlongPos + root.surface.targetVisualAlong, root.surface.currentAlongPos + root.surface.currentVisualAlong)
        readonly property real screenRoom: wing.side < 0 ? wing.sheetEdge - root.sheetGap - Theme.spacingS : root.surface.alongExtent - wing.sheetEdge - root.sheetGap - Theme.spacingS
        // A pill beside the launcher only where the screen leaves room for it, else this side folds into the sheet.
        readonly property bool carded: (root.anyWing || wing.presence > 0.01) && wing.screenRoom >= root.size && !root.isVertical
        // The hover card, as wide as the screen leaves beside the pill (it may cover the bar's own widgets).
        readonly property real cardWant: wing.paged?.cardWidth ?? root.cardWidth
        readonly property real cardLength: Math.min(wing.cardWant, wing.screenRoom)
        // Follows the sheet on its spring: the wing leaves the pill's side, buds off, and settles as a tile.
        readonly property real tile: Math.max(0, life.currentOffsetCross / root.springUnit)
        // How far this side is into the sheet: its tile, or the island's own for a side that folds in.
        readonly property real sheetness: wing.carded ? Math.min(1, wing.tile) : root.cardness

        // Hover opens the wing into its card while the island is a pill, on the same spring: in soft with its overshoot, out stiff.
        // Beside the launcher the apps pill opens on hover too (what was copied), and a click toggles its list.
        property bool tileOpen: false
        readonly property bool tileOpenable: wing.has && wing.carded && wing.side > 0 && wing.shownItems.length > 1 && root.targetCardness > 0
        onTileOpenableChanged: {
            if (!wing.tileOpenable)
                wing.tileOpen = false;
        }
        // A bubble that grows the island (weather) opens no card beside it: the dwell of a hover brings it into the island,
        // which grows into its card there, the bubble leaving the normal way.
        readonly property bool growsIsland: wing.face?.island === true && root.cardness < 0.5
        onDweltChanged: {
            if (wing.dwelt && hover.hovered && wing.growsIsland)
                root.activated(wing.face);
        }
        // The shelf never opens beside the island on a hover: a click grows it in the island.
        readonly property bool hoverOpen: IslandKit.cardOpen({ "has": wing.has, "vertical": root.isVertical, "faceOpen": wing.face?.open === true, "tileOpen": wing.tileOpen, "tileOpenable": wing.tileOpenable, "hovered": hover.hovered && !wing.growsIsland, "dwelt": wing.dwelt, "source": wing.face?.source ?? "", "heldOpen": wing.side < 0 && root.controller.machineCardOpen, "cardness": root.cardness, "carded": () => wing.carded })
        onHoverOpenChanged: wing.retargetCard()
        onHasChanged: {
            if (!wing.has && wing.side < 0)
                root.controller.machineCardOpen = false;
        }
        readonly property real hoverGrow: Math.max(0, life.currentHeight / root.springUnit)
        // The card's rows show once the card has (nearly) its size, and leave at once when it starts closing.
        property real reveal: wing.hoverOpen && wing.hoverGrow >= root.revealFrom ? 1 : 0
        // Reduced motion: the card's rows only fade in, in place, on the wing's crossfade; they leave with the snapped card.
        Behavior on reveal {
            id: revealFade

            NumberAnimation {
                duration: root.reducedMotion ? (revealFade.targetValue > 0 ? Theme.variantDuration(Theme.expressiveDurations.expressiveFastEffects, true) : 0) : wing.hoverOpen ? Theme.expressiveDurations.expressiveEffects : Theme.shorterDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.reducedMotion || wing.hoverOpen ? Theme.expressiveCurves.expressiveEffects : Theme.variantExitCurve
            }
        }

        // Each side rests at its own widest face (his choice of 25/10: a long "Copied" never stretches the other side).
        // Kept when the last item leaves, so the wing melts back from its own width instead of vanishing; a new value
        // resizes it on the island's own spring.
        property real ownRest: 0
        onNeedChanged: wing.ownRest = Activities.wingRest(wing.ownRest, wing.need)
        readonly property real restTarget: wing.ownRest
        onRestTargetChanged: restSpring.retarget(wing.restTarget)
        SpringMotion {
            id: restSpring

            enabled: wing.presence > 0.5
            reducedMotion: root.reducedMotion
            stiffness: root.motion.stiffness
            damping: root.motion.damping
            mass: root.motion.mass
            Component.onCompleted: restSpring.snapTo(wing.restTarget)
        }
        readonly property real restLength: restSpring.value * wing.presence
        readonly property real tileT: Math.min(1, wing.tile)
        // The pill's shape forms a little ahead of its flight beside the launcher.
        readonly property real tileShape: Math.min(1, wing.tile * root.tileShapeLead)
        // Beside the launcher the pill stands up (the transition, tx, drives it), as tall as its own content.
        readonly property real openLength: root.isVertical ? root.size * wing.presence : wing.carded ? root.mix(wing.tx.length, wing.cardLength, wing.hoverGrow) : root.mix(wing.restLength * (1 - root.cardness), wing.cardLength, wing.hoverGrow)
        readonly property real openThick: root.isVertical ? root.size : root.mix(wing.carded ? wing.tx.thick : root.size, wing.carded ? Math.max(wing.standLength * wing.presence, wing.listHeight) : wing.listHeight, wing.hoverGrow)
        // Every upright pill stands three pills tall, a level's liquid or not, so they all read alike. A value shows under
        // the icon only if it fits the pill's width (a call's 0:13, not « Copied! »).
        readonly property bool fitsStanding: compactLabel.implicitWidth <= root.size - Theme.spacingXS
        readonly property real standLength: root.size * 3
        readonly property bool upright: wing.tileOf > 0.5 && wing.hoverGrow < 0.01
        // The value's center: in the track (or beside the icon) on the flat pill; in the gauge under the icon once upright.
        readonly property real trackValueX: liquid.start + (wing.aside ? root.asideTrack + root.trackPad : root.trackPad) + wing.labelWidth / 2
        readonly property real valueX: root.mix(wing.levelled ? (wing.side < 0 ? wing.trackValueX : wing.width - wing.trackValueX) : wing.side < 0 ? (root.size - wing.glyphSlack + wing.width) / 2 : (wing.width - wing.iconShift - root.size + wing.glyphSlack) / 2, wing.width / 2, wing.tileOf)
        readonly property real valueY: root.mix(root.size / 2, (root.size + root.trackGap + wing.height - Theme.spacingXS) / 2, wing.tileOf)
        // Jelly and the dial's pull stretch the size itself, never a scale, so the corners stay the island's.
        // Fusing, it gathers onto its shape: down to one pill, its island side held, so it closes toward the island.
        readonly property real baseThick: root.mix(wing.openThick, root.size, wing.phase.gather)
        readonly property real gathered: root.mix(wing.openLength, root.size, wing.phase.gather)
        readonly property real length: wing.gathered * (1 + wing.stretch * root.jellyStretch + Math.abs(wing.wingPull) * root.dialWingShare)
        readonly property real thick: wing.baseThick * (1 - wing.stretch * root.jellySquash - Math.abs(wing.wingPull) * root.dialWingShare / 2)
        readonly property real gap: root.mix(root.slit, root.sheetGap, wing.sheetness)
        readonly property real drop: (wing.carded ? root.tileDrop * wing.tile : 0) + (wing.baseThick - wing.thick) / 2
        // Its corners: the island's as a pill or tile, the popups' as a card; only the icon's shape morphs.
        readonly property real radius: Math.min(wing.thick / 2, wing.length / 2, root.mix(root.pillRadius, NotificationMetrics.popupRadius, root.clamp01(wing.hoverGrow)))

        readonly property real edgeNow: wing.side < 0 ? Math.min(root.leadEdge, root.surface.currentAlongPos) : Math.max(root.trailEdge, root.surface.currentAlongPos + root.surface.currentVisualAlong)
        // Fusing, it stays where it melts: an island growing at that moment (the shelf's card) spreads over it, never pushes it.
        property real fuseEdge: 0
        readonly property real alongPos: wing.side < 0 ? (wing.fusing ? wing.fuseEdge : wing.edgeNow) - wing.gap - wing.length : (wing.fusing ? wing.fuseEdge : wing.edgeNow) + wing.gap

        x: root.isVertical ? root.crossOf(root.nearCross + root.rowOffset, root.size) : wing.alongPos
        y: root.isVertical ? wing.alongPos : root.crossOf(root.nearCross + root.rowOffset + wing.drop, wing.thick)
        width: root.isVertical ? root.size : Math.max(0, wing.length)
        height: root.isVertical ? Math.max(0, wing.length) : wing.thick
        visible: wing.length > 0.5
        // Born floating, it fades in growing from the island's edge; the "copied" bubble takes the apps side's place.
        // Fusing, the wing is gone once the shape flows (the goo layer carries it on); fading, it all fades.
        opacity: root.clamp01(wing.presence * 1.5) * wing.fade * wing.tx.fade * (wing.fusing && wing.phase.flowing ? 0 : 1)
        // Card content has its final width from the start: the wing reveals it, never re-wraps it.
        clip: wing.hoverGrow > 0
        // Jelly stretches it outward from the island side (and the dial's pull leans and stretches it);
        // the magnet swells it a little and leans it toward the pointer. The transforms compose, so they can all play at once.
        readonly property real wingPull: wing.leans ? wing.dialPull : 0
        transform: [
            Rotation {
                origin.x: wing.iconX
                origin.y: wing.iconY
                angle: wing.tx.turn
            },
            // Born floating: it grows from half its size at the island's edge, on its own spring (presence overshoots).
            Scale {
                origin.x: wing.side < 0 ? wing.width : 0
                origin.y: wing.height / 2
                xScale: root.mix(0.5, 1, root.clamp01(wing.presence))
                yScale: xScale
            },
            Rotation {
                origin.x: wing.side < 0 ? wing.width : 0
                origin.y: wing.height / 2
                // Only ever down: the outer end dips by the pull's size, whatever the way the level goes, and the spring's
                // swing back (the pull changing sign) dips it again rather than lifting it above the line.
                angle: Math.abs(wing.wingPull) / root.dialStretchMax * root.dialTilt * (wing.side < 0 ? -1 : 1) * root.dialWingShare
            },
            Scale {
                origin.x: wing.width / 2
                origin.y: wing.height / 2
                xScale: 1 + wing.magnet * root.magnetSwell
                yScale: xScale
            },
            Translate {
                x: wing.lean * root.magnetLean
            },
            // Pivot: the upright frame is turned flat at the pill's place, so it is shifted there while it flies.
            Translate {
                x: wing.tx === tilePivot ? tilePivot.shiftX : 0
                y: wing.tx === tilePivot ? tilePivot.shiftY : 0
            }
        ]

        Rectangle {
            id: body
            anchors.fill: parent
            visible: wing.tx.bodyShown
            radius: wing.radius
            color: root.color
            // Fusing, the body melts away over the gather's second half: only the shape is left to flow, never a rim.
            opacity: 1 - root.clamp01(2 * wing.phase.gather - 1)
            border.width: root.outlineWidth
            border.color: Theme.withAlpha(root.outlineByType ? wing.tone[2] : Theme.primary, root.outlineAlpha * root.clamp01(wing.presence))
        }

        // The launcher transitions, one file each (the mockup's maquette-transition); the chosen one drives the wing from its
        // pill to the upright pill beside the launcher (icon on top, a level's liquid falling to the bottom).
        readonly property TileTransition tx: root.launcherTransition === "jelly" ? tileJelly : root.launcherTransition === "pivot" ? tilePivot : tileLiquid
        TileLiquid {
            id: tileLiquid
            active: wing.tx === tileLiquid
            wing: wing
            pace: root.breathPace
            cardTarget: wing.cardTarget
            reducedMotion: root.reducedMotion
            blocked: wing.hoverGrow > 0.01
            side: wing.side
            iconShift: wing.iconShift
            cornerRadius: root.pillRadius
            dropBy: root.tileDrop
            farEdge: root.surface.farEdge
            shapeLead: root.tileShapeLead
            stiffness: life.stiffness
            mass: life.mass
            presence: wing.presence
            level: wing.level
            gaugeOpacity: wing.content * gaugeBlink.value
            trackColor: wing.trackColor
            liquidColor: wing.liquidColor
            inset: Theme.spacingXS
            trackGap: root.trackGap
            fillColor: body.color
            edgeColor: body.border.color
            edgeWidth: body.border.width
            carded: wing.carded
            tile: wing.tile
            tileShape: wing.tileShape
            tileOf: wing.tileOf
            restLength: wing.restLength
            pillThick: root.size
            tileSide: root.size
            tileThick: wing.standLength * wing.presence
            pillIconY: root.size / 2
            tileIconY: root.size / 2
            gauged: wing.tracked
        }
        TileJelly {
            id: tileJelly
            active: wing.tx === tileJelly
            wing: wing
            pace: root.breathPace
            goal: life.targetOffsetCross / root.springUnit
            reducedMotion: root.reducedMotion
            level: wing.level
            side: wing.side
            radius: wing.radius
            iconShift: wing.iconShift
            trackGap: root.trackGap
            content: wing.content
            pillLiquid: true
            trackColor: wing.trackColor
            liquidColor: wing.liquidColor
            carded: wing.carded
            tile: wing.tile
            tileShape: wing.tileShape
            tileOf: wing.tileOf
            restLength: wing.restLength
            pillThick: root.size
            tileSide: root.size
            tileThick: wing.standLength * wing.presence
            pillIconY: root.size / 2
            tileIconY: root.size / 2
            gauged: wing.tracked
        }
        TilePivot {
            id: tilePivot
            active: wing.tx === tilePivot
            open: wing.cardTarget > 0
            side: wing.side
            level: wing.level
            trackColor: wing.trackColor
            liquidColor: wing.liquidColor
            trackGap: root.trackGap
            radius: wing.radius
            content: wing.content
            reduced: root.reducedMotion
            farEdge: root.surface.farEdge
            wing: wing
            pace: root.breathPace
            carded: wing.carded
            tile: wing.tile
            tileShape: wing.tileShape
            tileOf: wing.tileOf
            restLength: wing.restLength
            pillThick: root.size
            tileSide: root.size
            tileThick: wing.standLength * wing.presence
            pillIconY: root.size / 2
            tileIconY: root.size / 2
            gauged: wing.tracked
        }

        // The upright pill's gauge at rest: under the icon's shape by the flat track's gap (the transitions' own end), its
        // liquid rising flat from the bottom; the icon stands alone on top.
        Item {
            id: gauge

            readonly property real inset: Theme.spacingXS
            readonly property real radius: Math.max(0, wing.radius - gauge.inset)

            z: 0.5
            x: gauge.inset
            y: IslandKit.uprightGaugeTop(root.size, root.trackGap, gauge.inset, wing.tileOf)
            width: Math.max(0, wing.width - 2 * gauge.inset)
            height: IslandKit.uprightGaugeHeight(wing.height, root.size, root.trackGap, gauge.inset, wing.tileOf)
            visible: opacity > 0.01 && (wing.tracked || wing.standTracked) && wing.tx.gaugeShown && wing.hoverGrow < 0.01
            opacity: wing.tileOf * wing.content * gaugeBlink.value

            Rectangle {
                anchors.fill: parent
                radius: gauge.radius
                color: wing.trackColor
            }

            IslandLiquid {
                id: gaugeLiquid

                anchors.fill: parent
                radius: gauge.radius
                // A stand-only level has no flat liquid to bring along: it rises from the bottom once the pill stands.
                level: Math.max(0, wing.standValued ? (wing.tileOf > 0.5 ? wing.face.standLevel : 0) : wing.level)
                color: wing.liquidColor
                wave: wing.face?.battery?.wave ?? null
            }
        }

        // Weather alert: the mockup's sky falls through the whole pill, flat or upright, behind its icon and text, calm at
        // rest and full on hover (his choice of 25/10: never the shape alone).
        Loader {
            z: 0.6
            x: gauge.x
            y: gauge.y
            width: gauge.width
            height: gauge.height
            active: !!wing.face?.weather
            sourceComponent: IslandWeatherFx {
                radius: gauge.radius
                event: wing.face?.weather?.event ?? ""
                level: wing.face?.weather?.level ?? 0
                strength: hover.hovered ? 1 : 0.55
                opacity: wing.content
            }
        }

        // Wave: the capsule's free part (past the icon's circle, inset by a margin) filled up to the level; its front is a wave
        // mirrored top to bottom, whose height follows the dial's speed and whose phase follows its turn, so it slops while
        // the level moves and lies flat once it settles.
        Shape {
            id: liquid

            readonly property real along: wing.width
            readonly property real across: wing.height
            readonly property bool flip: wing.side >= 0
            readonly property real inset: Theme.spacingXS
            readonly property real start: root.size + wing.iconShift + root.trackGap
            readonly property real end: Math.max(liquid.start, wing.aside ? liquid.start + root.asideTrack : liquid.along - liquid.inset)
            readonly property real fillTo: liquid.start + Math.max(0, wing.level) * (liquid.end - liquid.start)
            readonly property real lipTop: liquid.inset
            readonly property real lipBottom: liquid.across - liquid.inset
            readonly property real amp: Math.min(root.size * 0.3, Math.abs(wing.dialPull) * root.waveHeight * root.size)
            readonly property real phase: wing.dialAngle * Math.PI / 90
            // The track's corners are the bubble's own, inset (concentric): round on a pill, tighter on a Notch bubble.
            readonly property real mid: (liquid.lipTop + liquid.lipBottom) / 2
            readonly property real half: (liquid.lipBottom - liquid.lipTop) / 2
            readonly property real corner: Math.min(liquid.half, Math.max(0, wing.radius - liquid.inset))
            // The rows of both paths (outer end at x = 0 on the leading side, mirrored on the trailing one): each row's y,
            // how far the round end bulges in there, and its distance from the middle. Properties are read once per
            // evaluation, as both paths re-run several times a frame while the wing moves. Kept until the track's shape
            // changes: the wave's frames reuse it (a plain holder, so writing it notifies nothing).
            readonly property var rowsKept: ({})
            function rows(n) {
                const top = liquid.lipTop, bottom = liquid.lipBottom, mid = liquid.mid, half = liquid.half, corner = liquid.corner;
                const kept = liquid.rowsKept;
                if (kept.n === n && kept.top === top && kept.bottom === bottom && kept.mid === mid && kept.half === half && kept.corner === corner)
                    return kept.rows;
                const out = [];
                for (let i = 0; i <= n; i++) {
                    const y = top + (bottom - top) * i / n;
                    const dy = Math.max(0, Math.abs(y - mid) - (half - corner));
                    out.push({
                        "y": y,
                        "b": corner - Math.sqrt(Math.max(0, corner * corner - dy * dy)),
                        "d": Math.abs(y - mid) / Math.max(1, half)
                    });
                }
                Object.assign(kept, { "n": n, "top": top, "bottom": bottom, "mid": mid, "half": half, "corner": corner, "rows": out });
                return out;
            }
            // The empty part of the track, split from the liquid by a gap that follows its front.
            readonly property var track: {
                // Hidden (no gauge, a tile, another dial style): skip the points, they would follow every frame for nothing.
                if (!liquid.visible)
                    return [];
                const pts = [];
                const n = 24, r = liquid.rows(n);
                const flip = liquid.flip, w = liquid.along, start = liquid.start, end = liquid.end;
                const at = v => (flip ? w - v : v);
                const fillTo = liquid.fillTo, amp = liquid.amp, phase = liquid.phase, gap = root.trackGap;
                for (let i = 0; i <= n; i++)
                    pts.push(Qt.point(at(end - r[i].b), r[i].y));
                for (let i = n; i >= 0; i--) {
                    const front = fillTo + IslandKit.wave(r[i].d, amp, phase) + gap;
                    const x = Math.max(start + r[i].b, Math.min(end - r[i].b, front));
                    pts.push(Qt.point(at(x), r[i].y));
                }
                return pts;
            }
            readonly property var outline: {
                if (!liquid.visible)
                    return [];
                const pts = [];
                const n = 24, r = liquid.rows(n);
                const flip = liquid.flip, w = liquid.along, start = liquid.start, end = liquid.end;
                const at = v => (flip ? w - v : v);
                const fillTo = liquid.fillTo, amp = liquid.amp, phase = liquid.phase;
                // The front: one wave per half, mirrored so both move alike, held inside the track's round ends.
                for (let i = 0; i <= n; i++) {
                    const x = Math.max(start + r[i].b, Math.min(end - r[i].b, fillTo + IslandKit.wave(r[i].d, amp, phase)));
                    pts.push(Qt.point(at(x), r[i].y));
                }
                for (let i = n; i >= 0; i--)
                    pts.push(Qt.point(at(start + r[i].b), r[i].y));
                return pts;
            }

            z: 0.5
            anchors.fill: parent
            // Beside the launcher the transition and the upright gauge take over.
            visible: wing.tracked && !wing.waveBar && wing.iconOpacity > 0.01 && wing.tileOf < 0.01 && wing.tx.bodyShown
            opacity: wing.iconOpacity * gaugeBlink.value
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: wing.trackColor
                strokeColor: "transparent"
                strokeWidth: 0

                PathPolyline {
                    path: liquid.track
                }
            }

            ShapePath {
                fillColor: wing.liquidColor
                strokeColor: "transparent"
                strokeWidth: 0

                PathPolyline {
                    path: liquid.outline
                }
            }
        }
        // DMS's wave progress on a transfer's track, filling from the icon like the liquid would.
        IslandWaveProgress {
            z: 0.5
            x: liquid.flip ? liquid.along - liquid.end : liquid.start
            y: Math.round((liquid.across - height) / 2)
            width: Math.max(0, liquid.end - liquid.start)
            height: Theme.spacingL
            visible: wing.waveBar && wing.iconOpacity > 0.01 && wing.tileOf < 0.01 && wing.tx.bodyShown
            opacity: wing.iconOpacity
            value: Math.max(0, wing.level)
            moving: wing.face?.flowing === true
            mirrored: liquid.flip
            fillColor: wing.liquidHue
            playheadColor: wing.liquidHue
        }

        // The icon on its backdrop: at the pill's outer end (inside the counter on the apps side), in the middle beside the
        // launcher, at the top of a hover card.
        readonly property real tileOf: wing.carded ? wing.tileT : 0
        property real iconShift: wing.side > 0 ? wing.counterNeed : 0
        Behavior on iconShift {
            enabled: !root.reducedMotion && wing.presence > 0.5
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }
        readonly property real iconX: root.mix(wing.side < 0 ? root.size / 2 : wing.width - wing.iconShift - root.size / 2, wing.width / 2, wing.tileOf) + wing.tx.iconDx
        readonly property real iconY: wing.tx.iconY
        readonly property real iconOpacity: root.clamp01(1 - 2 * wing.reveal) * wing.content * (wing.carded ? 1 : 1 - root.cardness) * wing.phase.text

        DLoadingIndicator {
            id: backdrop
            z: 1

            running: false
            shapes: wing.shapes
            fromShape: 0
            toShape: 1
            morph: wing.morph
            angle: wing.shapeAngle
            // Under an app's logo, the tone that contrasts with the logo (dark under a white Android silhouette).
            color: wing.appFace ? currentGlyph.logoShapeColor : wing.tone[0]
            width: root.unitPx / backdrop.activeRatio
            height: width
            x: wing.iconX - width / 2
            y: wing.iconY - height / 2
            rotation: -wing.tx.turn + wing.rock
            // The dial's speed swells the shape out past its ring and smears it along the wing, so the turn reads.
            // In the wave style it bobs on the liquid instead.
            transform: [
                Scale {
                    origin.x: backdrop.width / 2
                    origin.y: backdrop.height / 2
                    xScale: (1 + (wing.leans ? Math.abs(wing.dialPull) : 0)) * (1 + root.morphPulse * wing.pulse)
                    yScale: (1 + (wing.leans ? Math.abs(wing.dialPull) / 2 : 0)) * (1 + root.morphPulse * wing.pulse)
                },
                Translate {
                    y: liquid.visible ? IslandKit.wave(0, liquid.amp / 2, liquid.phase) : 0 // A1
                }
            ]
            // Fusing, the shape stays whole while the rest fades, until the goo takes it.
            opacity: wing.fusing ? 1 : wing.iconOpacity
            visible: opacity > 0.01 && wing.face !== null

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
        }

        // Urgency wave: one ring of the alert's accent leaving the shape and fading.
        IslandAlertWave {
            id: wave
            z: 2

            base: root.backdropRadius * 2
            reach: root.waveReach
            rings: wing.ringing || wing.calling ? 2 : 1
            // A call rings in DMS's main color, never the alert's red.
            color: wing.ringing || wing.calling ? Theme.primary : Theme.error
            cycles: wing.ringing ? 0 : 1
            spring: wing.ringing ? [root.motion.stiffness, root.inDampingRatio, root.motion.mass] : null
            // Its card open, the rings go with the shape, never over the card.
            opacity: wing.iconOpacity
            x: wing.iconX - width / 2
            y: wing.iconY - height / 2
        }

        // Morph: a new face beats its shape out and back as it moves on to its next shape; the old symbol dissolves in a blur and
        // the new one blooms out of it. Reduced motion only crossfades them.
        property real pulse: 0
        SequentialAnimation {
            id: pulseRun

            NumberAnimation {
                target: wing
                property: "pulse"
                to: 1
                duration: Theme.expressiveDurations.expressiveFastSpatial / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: wing
                property: "pulse"
                to: 0
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }
        // The value is set once face and caption have both settled, so a new face's value rolls up whatever its figures.
        property string labelText: ""
        property string labelOwner: ""
        function settleLabel() {
            const owner = (wing.face?.id ?? "") + "\u001f" + (wing.face?.kind ?? "");
            compactLabel.up = owner !== wing.labelOwner;
            wing.labelOwner = owner;
            wing.labelText = wing.caption;
        }
        onCaptionChanged: Qt.callLater(wing.settleLabel)
        onFaceChanged: Qt.callLater(wing.settleLabel)

        // On its backdrop the face shows a symbol in the backdrop's tone.
        Item {
            id: iconSwap
            z: 3

            property real swap: 1
            property var outFace: null
            property string outSymbol: ""
            property color outIcon: wing.tone[1]
            property color outAccent: wing.tone[2]
            property string lastKey: ""
            property var lastFace: null
            readonly property string key: (wing.face?.id ?? "") + "\u001f" + (wing.face?.kind ?? "") + "\u001f" + wing.symbol
            onKeyChanged: {
                if (iconSwap.lastFace && wing.face && wing.presence > 0.5) {
                    iconSwap.outFace = iconSwap.lastFace;
                    iconSwap.outSymbol = iconSwap.lastKey.split("\u001f")[2] ?? "";
                    swapRun.restart();
                    if (!root.reducedMotion)
                        pulseRun.restart();
                }
                iconSwap.lastFace = wing.face;
                iconSwap.lastKey = iconSwap.key;
            }

            width: root.size - Theme.spacingXS * 2
            height: width
            x: wing.iconX - width / 2
            y: wing.iconY - height / 2
            rotation: -wing.tx.turn + wing.rock
            // It rides the shape it sits on.
            transform: Translate {
                y: liquid.visible ? IslandKit.wave(0, liquid.amp / 2, liquid.phase) : 0 // A1
            }
            opacity: wing.iconOpacity
            visible: opacity > 0.01

            NumberAnimation {
                id: swapRun

                target: iconSwap
                property: "swap"
                from: 0
                to: 1
                duration: root.reducedMotion ? Theme.variantDuration(Theme.expressiveDurations.expressiveFastEffects, true) : Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.reducedMotion ? Theme.expressiveCurves.expressiveEffects : Theme.expressiveCurves.expressiveDefaultSpatial
            }

            Glyph {
                anchors.fill: parent
                visible: iconSwap.swap < 1
                bubble: iconSwap.outFace
                symbol: iconSwap.outSymbol
                iconColor: iconSwap.outIcon
                accent: iconSwap.outAccent
                shapeColor: wing.appFace ? root.color : wing.tone[0]
                onBackdrop: true
                opacity: 1 - root.clamp01(iconSwap.swap)
                scale: root.reducedMotion ? 1 : root.mix(1, root.blurShrink, root.clamp01(iconSwap.swap))
                layer.enabled: visible && !root.reducedMotion
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: Theme.spacingM
                    blur: root.clamp01(iconSwap.swap)
                }
            }

            Glyph {
                id: currentGlyph

                anchors.fill: parent
                bubble: wing.face
                symbol: wing.symbol
                iconColor: wing.tone[1]
                accent: wing.tone[2]
                shapeColor: wing.appFace ? root.color : wing.tone[0]
                onBackdrop: true
                opacity: root.clamp01(iconSwap.swap)
                scale: root.reducedMotion ? 1 : root.mix(root.blurShrink, 1, iconSwap.swap)
                layer.enabled: iconSwap.swap < 1 && !root.reducedMotion
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: Theme.spacingM
                    blur: 1 - root.clamp01(iconSwap.swap)
                }
            }
        }

        // The value and the "more" dot fade with the face; they stay on a pill beside the launcher.
        // Fusing, the text fades out before the wing has closed over it.
        readonly property real faceOpacity: root.clamp01(1 - 2 * wing.reveal) * wing.content * (wing.carded ? 1 : 1 - root.cardness) * wing.phase.text

        RollText {
            id: compactLabel
            // A replacement rolls toward the island: the right wing leftward, the left one rightward; standing, up.
            across: wing.upright ? 0 : -wing.side
            z: 4

            // Whole pixels, so the digits stay sharp.
            x: Math.round(wing.valueX - width / 2)
            y: Math.round(wing.valueY - height / 2)
            // A value kept beside its track (a transfer's time left) never stands: upright, the icon is alone.
            visible: wing.caption !== "" && (wing.labelled && (!wing.upright || wing.fitsStanding && !wing.aside) || wing.standValued && wing.upright && wing.fitsStanding) && opacity > 0.01
            // Standing, the pill is narrow: the unit sits tight against the number ("52%").
            text: wing.upright ? wing.labelText.replace(/\s+%$/, "%") : wing.labelText
            pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            opacity: wing.labelRoom * wing.faceOpacity * wing.tx.valueOpacity
        }

        // The action mark, centred in its own slot on the flat pill; standing, the icon is alone.
        DIcon {
            z: 4
            x: Math.round(wing.valueX - width / 2)
            y: Math.round(wing.valueY - height / 2)
            visible: wing.mark !== "" && !wing.upright && opacity > 0.01
            name: wing.mark
            size: root.iconFit
            color: Theme.surfaceText
            opacity: wing.labelRoom * wing.faceOpacity * wing.tx.valueOpacity
        }

        // Standing, a copy shows what it was under the check: its kind's icon, or a copied image's own picture, round.
        BubbleCopyType {
            z: 4
            x: wing.valueX - width / 2
            y: wing.valueY - height / 2
            visible: wing.upright && wing.face?.source === "copy" && opacity > 0.01
            face: wing.face
            size: root.iconFit
            opacity: wing.faceOpacity
        }

        IslandInfinity {
            id: infinity
            z: 4
            x: wing.valueX - width / 2
            y: wing.valueY - height / 2
            height: Theme.fontSizeSmall
            visible: wing.infinite && !root.isVertical && opacity > 0.01
            color: Theme.surfaceText
            glow: Theme.primary
            opacity: wing.labelRoom * wing.faceOpacity * wing.tx.valueOpacity
        }

        // More waits behind the face: a dot on the pill's outer bottom corner (bottom right on the right, bottom left on the
        // left), centered on the rim's 45° point so it sits on the round corner.
        Rectangle {
            id: counter
            z: 4

            readonly property real inset: wing.radius * (1 - Math.SQRT1_2)
            width: Theme.spacingS
            height: width
            radius: width / 2
            x: (wing.side < 0 ? counter.inset : wing.width - counter.inset) - width / 2
            y: wing.height - counter.inset - height / 2
            color: Theme.primary
            // Several transfers share one bubble (one liquid for the total): the dot says so too.
            visible: (wing.count !== "" || wing.face?.more === true) && !root.isVertical
            opacity: wing.faceOpacity
        }

        // Card face: one row per waiting item; it rises into place as it fades in.
        Column {
            id: cardFace
            z: 4

            // Held from the island side, which does not move while the card overshoots outward.
            x: wing.side < 0 ? wing.width - width - root.pad : root.pad
            y: root.pad + (root.reducedMotion ? 0 : Theme.spacingS * (1 - wing.reveal))
            width: Math.max(0, wing.cardLength - root.pad * 2)
            visible: opacity > 0.01 && wing.has && !kindCard.item
            opacity: root.clamp01(2 * wing.reveal - 1) * wing.content

            Repeater {
                // One row, the shown page; the others wait behind the page dots.
                model: wing.has ? 1 : 0

                Item {
                    id: row

                    required property int index
                    readonly property var modelData: wing.paged ?? ({})
                    width: cardFace.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: rowMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"
                    }

                    Glyph {
                        id: rowGlyph

                        bubble: row.modelData
                        // A copy's row is headed by its kind's icon.
                        symbol: row.modelData.typeIcon ?? ""
                        x: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.size - Theme.spacingXS
                        height: width
                    }

                    // A copied image's picture at the row's end.
                    BubbleCopyType {
                        id: rowThumb
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        size: rowGlyph.width
                        visible: (row.modelData.thumb ?? "") !== "" && cardFace.visible
                        face: row.modelData
                    }

                    Column {
                        anchors.left: rowGlyph.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: rowThumb.visible ? rowThumb.left : parent.right
                        anchors.rightMargin: rowThumb.visible ? Theme.spacingS : Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            text: row.modelData.title || row.modelData.text || row.modelData.source
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            visible: text !== ""
                            text: row.modelData.detail ?? ""
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => mouse.button === Qt.RightButton ? root.dismissed(row.modelData) : root.activated(row.modelData)
                    }
                }
            }
        }

        // A system bubble's card is its kind's own file (Cards/BubbleCard<Kind>.qml), loaded only while the card is open;
        // the wing grows to its implicitHeight. Other bubbles keep the row list above.
        readonly property Component cardComponent: root.cardFor(wing.paged)
        Loader {
            id: kindCard

            z: 4
            x: cardFace.x
            y: cardFace.y
            width: cardFace.width
            active: wing.cardComponent !== null && !root.isVertical && (wing.hoverOpen || wing.hoverGrow > 0.01)
            sourceComponent: wing.cardComponent
            opacity: cardFace.opacity
            visible: opacity > 0.01

            Binding {
                target: kindCard.item
                property: "bubble"
                value: wing.paged
                when: kindCard.status === Loader.Ready
            }
            Connections {
                target: kindCard.item
                ignoreUnknownSignals: true

                function onActivated(bubble) {
                    root.activated(bubble);
                }
                function onDismissed(bubble) {
                    root.dismissed(bubble);
                }
            }
        }

        // Over the open card the wheel turns its pages (as over the island's burst); else it keeps the bubble's own role.
        function wheelPage(wheel) {
            if (!wing.paging || !wing.hoverOpen || !SettingsData.islandArrivalWheel)
                return false;
            const delta = Arrival.wheelDelta(wheel.pixelDelta, wheel.angleDelta);
            wing.pageWheel = Arrival.wheel(wing.pageWheel, SettingsData.islandArrivalWheelInverted ? -delta : delta, Date.now());
            if (wing.pageWheel.step !== 0)
                wing.turnPage(wing.pageWheel.step);
            return true;
        }

        // The card's page dots, top right as on the island's card; hovered, the countdown is frozen and empty.
        IslandPager {
            id: pager

            z: 5
            x: cardFace.x + cardFace.width - width
            y: Math.round((root.pad - height) / 2)
            visible: wing.paging && opacity > 0.01
            opacity: cardFace.opacity
            count: wing.shownItems.length
            index: Math.min(wing.page, wing.shownItems.length - 1)
            countdown: Arrival.freezeEmpty(Arrival.countdown(0, 0), 0, 0)
            reducedMotion: root.reducedMotion
            onPicked: index => wing.pick(index)
        }

        DragHandler {
            target: null
            enabled: wing.paging && wing.hoverOpen
            yAxis.enabled: false
            onActiveChanged: {
                if (active)
                    return;
                const turn = Arrival.swipe(activeTranslation.x, 0);
                if (turn === "next" || turn === "prev")
                    wing.turnPage(turn === "next" ? 1 : -1);
            }
        }

        HoverHandler {
            id: hover

            onHoveredChanged: {
                if (wing.face && wing.has)
                    root.hovered(wing.face, hover.hovered);
                wing.dwelt = false;
                if (!hover.hovered) {
                    dwell.stop();
                    return;
                }
                wing.dwellFrom = hover.point.position;
                dwell.restart();
                if (wing.has && root.cardness < 0.5)
                    wing.breathe(false);
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: wing.has
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            // The pill says what it shows: its face's title (the device and its state), the detail as description.
            Accessible.role: Accessible.Button
            Accessible.name: wing.face?.title ?? ""
            Accessible.description: wing.face?.detail ?? ""
            onClicked: mouse => {
                wing.breathe(false);
                if (mouse.button === Qt.LeftButton)
                    currentGlyph.poke();
                if (mouse.button === Qt.RightButton)
                    root.dismissed(wing.items[0]);
                else if (wing.tileOpenable)
                    wing.tileOpen = !wing.tileOpen;
                else
                    root.activated(wing.items[0]);
            }
            onWheel: wheel => {
                if (!wing.wheelPage(wheel))
                    root.wheeled(wing.items[0], wheel);
            }
        }

        // The shelf's bubble takes a file dragged onto it, as the island does: lit under the drag, one drop.
        IslandShelfDrop {
            id: bubbleDrop

            anchors.fill: parent
            atBubble: true
            shelf: wing.face?.source === "shelf" ? wing.face.shelf ?? null : null
        }
        Rectangle {
            anchors.fill: parent
            visible: bubbleDrop.containsDrag
            radius: Math.min(width, height) / 2
            color: Theme.withAlpha(Theme.primaryContainer, IslandKit.dropLitAlpha)
            border.width: Theme.outlineWidthFocused
            border.color: Theme.primary
        }
    }

    // Figures that change like a mechanical counter: each changed character rolls in from below (up) or above (down), one
    // after the other from the right; plain text when the animation is off. A new owner's text (up) always rolls up.
    // Reduced motion crossfades each changed character in place instead.
    component RollText: Row {
        id: roll

        property string text: ""
        property bool up: false
        // A new owner (a replacement) rolls toward the island instead: -1 leftward, 1 rightward, 0 up.
        property int across: 0
        property real pixelSize: Theme.fontSizeSmall
        property color color: Theme.surfaceText
        readonly property bool rolling: !root.reducedMotion
        readonly property bool fades: root.reducedMotion

        Repeater {
            model: roll.text.length

            Item {
                id: cell

                required property int index
                readonly property string ch: roll.text.charAt(cell.index)
                // Set once, not bound: a binding would already hold the new character when the change handler runs.
                property string was: ""
                property string cur: ""
                Component.onCompleted: {
                    cell.was = cell.ch;
                    cell.cur = cell.ch;
                }
                property real t: 1
                property int dir: 1
                property bool sideways: false
                onChChanged: {
                    cell.was = cell.cur;
                    cell.cur = cell.ch;
                    if (!roll.rolling && !roll.fades || cell.was === cell.ch) {
                        cell.t = 1;
                        return;
                    }
                    cell.sideways = roll.up && roll.across !== 0;
                    cell.dir = cell.sideways ? roll.across : roll.up || cell.ch > cell.was ? 1 : -1;
                    turn.restart();
                }
                width: now.implicitWidth
                height: now.implicitHeight
                clip: cell.t < 1

                SequentialAnimation {
                    id: turn

                    ScriptAction {
                        script: cell.t = 0
                    }
                    PauseAnimation {
                        duration: roll.fades ? 0 : (roll.text.length - 1 - cell.index) * Theme.shorterDuration / 2
                    }
                    NumberAnimation {
                        target: cell
                        property: "t"
                        to: 1
                        duration: roll.fades ? Theme.variantDuration(Theme.expressiveDurations.expressiveFastEffects, true) : Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: roll.fades ? Theme.expressiveCurves.expressiveEffects : Theme.expressiveCurves.expressiveDefaultSpatial
                    }
                }

                StyledText {
                    x: roll.fades || !cell.sideways ? 0 : cell.dir * cell.width * cell.t
                    y: roll.fades || cell.sideways ? 0 : -cell.dir * cell.height * cell.t
                    opacity: roll.fades ? 1 - cell.t : 1
                    visible: cell.t < 1
                    text: cell.was
                    font.pixelSize: roll.pixelSize
                    font.weight: Font.Medium
                    // Tabular digits: a ticking value keeps its width.
                    font.features: {
                        "tnum": 1
                    }
                    color: roll.color
                }

                StyledText {
                    id: now

                    x: roll.fades || !cell.sideways ? 0 : -cell.dir * cell.width * (1 - cell.t)
                    y: roll.fades || cell.sideways ? 0 : cell.dir * cell.height * (1 - cell.t)
                    opacity: roll.fades ? cell.t : 1
                    text: cell.ch
                    font.pixelSize: roll.pixelSize
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    color: roll.color
                }
            }
        }
    }

    // A level ring or an icon, or the sender's picture for a notification; a notification without one gets the bell, in the accent.
    component Glyph: Item {
        id: glyph

        property var bubble: null
        readonly property bool notification: glyph.bubble?.source === "notification"
        // The ring glides from one level to the next; a ring that appears, goes or changes owner just snaps.
        readonly property real targetProgress: glyph.notification ? -1 : glyph.bubble?.progress ?? -1
        property real shownProgress: -1
        Component.onCompleted: glyph.shownProgress = glyph.targetProgress
        onTargetProgressChanged: {
            glide.stop();
            // Unseen (a closed card's rows) it snaps too: a glide nobody sees would still run every frame.
            if (root.reducedMotion || !glyph.visible || glyph.shownProgress < 0 || glyph.targetProgress < 0) {
                glyph.shownProgress = glyph.targetProgress;
                return;
            }
            glide.to = glyph.targetProgress;
            glide.start();
        }
        NumberAnimation {
            id: glide

            target: glyph
            property: "shownProgress"
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }

        // A face on its backdrop shows this symbol in the backdrop's tones instead.
        property string symbol: ""
        property color accent: Theme[glyph.bubble?.accent ?? "primary"] ?? Theme.primary
        property color iconColor: glyph.accent
        property color shapeColor: Theme.surface
        // On the shape the bare icon sits flat, like the shape's own print: a level ring there covered the shape and read as
        // a sticker; the wing's value and its wave show the level instead.
        property bool onBackdrop: false
        // The backdrop tone that reads under this glyph's logo (IslandAppIcon samples it).
        readonly property color logoShapeColor: picture.logoShapeColor

        function poke() {
            picture.poke();
        }
        IslandAppIcon {
            id: picture

            anchors.fill: parent
            visible: glyph.symbol === "" && (glyph.bubble?.image ?? "") !== "" && !glyph.password
            size: glyph.width
            bare: glyph.onBackdrop
            iconSize: glyph.onBackdrop ? root.iconFit : Math.round(glyph.width * 0.7)
            source: visible ? glyph.bubble.image : ""
            iconName: "notifications"
        }

        // Charging: the battery filling up in a wave, under its bolt.
        // A battery (the laptop's, a device's): the A1 battery at the one icon size, the device's badge on the corner.
        readonly property bool charge: !!glyph.bubble?.battery
        Loader {
            anchors.fill: parent
            active: glyph.charge && !picture.visible
            sourceComponent: BubbleChargeGlyph {
                battery: glyph.bubble?.battery ?? null
                iconSize: glyph.onBackdrop ? root.iconFit : Theme.iconSize
                lineColor: glyph.iconColor
                ringColor: glyph.shapeColor
            }
        }
        // Sleep blocked: the app keeping the session awake, on the cup's corner.
        BubbleKeepAwakeGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            ringColor: glyph.shapeColor
        }
        // Call: the microphone, struck through when cut, on the app icon's corner.
        BubbleCallGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            ringColor: glyph.shapeColor
        }
        // Transfers: failed, paused or done, as a badge on the app icon's corner.
        BubbleTransferGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            ringColor: glyph.shapeColor
        }
        // Incoming SSH: a red dot on the terminal while a session is open.
        BubbleSshGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            ringColor: glyph.shapeColor
        }

        // Camera: the green dot on the filming app's icon.
        BubbleCameraGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            ringColor: glyph.shapeColor
        }

        // Reopen: the closed app's icon in a ring that empties with the countdown.
        BubbleReopenGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            // On the shape the ring takes the icon's tone, as the charging glyph does.
            accent: glyph.onBackdrop ? glyph.iconColor : glyph.accent
            bare: picture.bare
            iconSize: picture.iconSize
        }

        // Password copied: its manager's icon in the ring that empties until the clipboard is cleared.
        readonly property bool password: glyph.bubble?.source === "password"
        BubblePasswordGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            accent: glyph.accent
        }

        // Printing: a sheet slides out of the tray on each page.
        BubblePrintGlyph {
            anchors.fill: parent
            z: 1
            bubble: glyph.bubble
            sheetColor: glyph.iconColor
        }

        ReadyActivityRing {
            anchors.fill: parent
            visible: !picture.visible && !glyph.charge && !glyph.password && glyph.bubble?.source !== "reopen"
            iconName: glyph.symbol || (glyph.notification ? (glyph.bubble?.call === true ? "call" : "notifications") : glyph.bubble?.icon ?? "")
            progress: glyph.onBackdrop ? -1 : glyph.shownProgress
            iconSize: glyph.onBackdrop ? root.iconFit : progress >= 0 ? Theme.iconSizeSmall : Theme.iconSize
            accent: glyph.accent
            iconColor: glyph.iconColor
        }
    }

    // Built for the fusion only (from its start, so nothing stalls as the shape leaves): the shader never runs otherwise.
    // Drawn above the island, for the bridge at its edge and the glow inside it; the shader hides the shape within it.
    Loader {
        parent: root.surface
        z: 1
        active: leading.fusing
        sourceComponent: Goo {
            wing: leading
        }
    }

    Loader {
        parent: root.surface
        z: 1
        active: trailing.fusing
        sourceComponent: Goo {
            wing: trailing
        }
    }

    // A fusing wing's shape flowing into the island, stretched along its way and thinned by its speed, shrinking as it goes
    // in; shape and island are blurred into one field and cut (goo.frag), so a viscous bridge holds them as they meet;
    // inside the island the shape is hidden, as if under it, and a halo in its color spreads from the contact point like a
    // wave, paling with the distance, while the edge swells there and back. Its frame spans the shape's way and the halo's
    // reach around the contact, never the whole island (a long one, beside the launcher, is not lit end to end). Along and
    // across follow the bar's axis.
    component Goo: Item {
        id: goo

        required property Wing wing
        readonly property bool vertical: root.isVertical
        readonly property var phase: goo.wing.phase
        // Plain numbers, not points: a point read in a binding is a new object every frame.
        readonly property real fromA: goo.wing.iconAlong()
        readonly property real fromC: goo.vertical ? goo.wing.x + goo.wing.iconX : goo.wing.y + goo.wing.iconY
        readonly property real edgeA: goo.wing.edgeAlong()
        // Across the gap and into the island.
        readonly property real toA: goo.fromA - goo.wing.side * root.size * root.fuseReach
        readonly property real nowA: root.mix(goo.fromA, goo.toA, goo.phase.along)
        readonly property real pad: root.size / 2 + root.glowReach + root.gooReach
        readonly property real reach: root.haloReach + root.glowReach
        readonly property real startA: Math.min(goo.fromA - goo.pad, goo.toA - goo.pad, goo.edgeA - goo.reach)
        readonly property real endA: Math.max(goo.fromA + goo.pad, goo.toA + goo.pad, goo.edgeA + goo.reach)
        readonly property real startC: goo.fromC - Math.max(goo.pad, goo.reach)
        readonly property real endC: goo.fromC + Math.max(goo.pad, goo.reach)

        x: goo.vertical ? goo.startC : goo.startA
        y: goo.vertical ? goo.startA : goo.startC
        width: goo.vertical ? goo.endC - goo.startC : goo.endA - goo.startA
        height: goo.vertical ? goo.endA - goo.startA : goo.endC - goo.startC
        layer.enabled: true
        // The blob is blurred and cut anyway: half its pixels are enough, the cut is drawn at full size.
        layer.textureSize: Qt.size(Math.ceil(goo.width * root.surface.dpr / 2), Math.ceil(goo.height * root.surface.dpr / 2))
        layer.smooth: true
        layer.effect: ShaderEffect {
            property var source
            // The melt sets in as the shape leaves, so it never pops.
            readonly property real blurPx: root.gooReach * root.clamp01(goo.phase.along * 5)
            readonly property real islandRadius: root.surface.currentSurfaceRadius
            readonly property real glow: goo.phase.glow
            readonly property real glowPx: root.glowReach
            // The halo's front, from the glow's size at the contact out to its reach, and how fast it pales with distance.
            readonly property real wavePx: root.glowReach + root.haloReach * goo.phase.wave
            readonly property real fallPx: root.haloReach / 2
            readonly property real swell: root.swellReach * goo.phase.swell
            readonly property size sizePx: Qt.size(goo.width, goo.height)
            readonly property point contact: goo.vertical ? Qt.point(goo.fromC - goo.x, goo.edgeA - goo.y) : Qt.point(goo.edgeA - goo.x, goo.fromC - goo.y)
            readonly property rect island: Qt.rect(root.surface.currentVisualX - goo.x, root.surface.currentVisualY - goo.y, root.surface.currentVisualWidth, root.surface.currentVisualHeight)
            readonly property vector4d islandColor: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
            readonly property vector4d blobColor: Qt.vector4d(goo.wing.tone[0].r, goo.wing.tone[0].g, goo.wing.tone[0].b, goo.wing.tone[0].a)

            fragmentShader: Qt.resolvedUrl("../../Shaders/qsb/goo.frag.qsb")
        }

        DLoadingIndicator {
            id: blob

            running: false
            shapes: goo.wing.shapes
            fromShape: 0
            toShape: 1
            morph: goo.wing.morph
            angle: goo.wing.shapeAngle
            color: goo.wing.tone[0]
            width: root.unitPx / blob.activeRatio
            height: width
            x: (goo.vertical ? goo.fromC - goo.startC : goo.nowA - goo.startA) - width / 2
            y: (goo.vertical ? goo.nowA - goo.startA : goo.fromC - goo.startC) - height / 2
            // The wing shows its own shape until it leaves.
            opacity: goo.phase.flowing ? goo.phase.blob : 0
            transform: Scale {
                origin.x: blob.width / 2
                origin.y: blob.height / 2
                xScale: goo.vertical ? goo.phase.scaleCross : goo.phase.scaleAlong
                yScale: goo.vertical ? goo.phase.scaleAlong : goo.phase.scaleCross
            }
        }
    }
}
