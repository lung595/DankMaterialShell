.pragma library

// always: islandUseOverlayLayer. onRequest: islandOverlayOnRequest. entry: the shown activity entry, whose
// showInFullscreen (polkit, plugins that ask for it) lifts the island over fullscreen windows until it goes away.
function wantsOverlay(always, onRequest, entry) {
    return always === true || (onRequest === true && entry?.showInFullscreen === true);
}
