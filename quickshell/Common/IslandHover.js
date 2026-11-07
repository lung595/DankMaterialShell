.pragma library

// s is the island controller. hoverHeld: a right-click face swap resized the island under the pointer, so hover-open
// waits until the pointer leaves.
function hoverExpandAllowed(s) {
    if (s.inputSuspended || s.hoverHeld || !s.hoverExpandEnabled || s.activeActivity === "powermenu")
        return false;
    // A burst opens its own card on hover (arrivalReopen), never the sheet.
    return !(s.notificationActive && s.arrivalCount > 0);
}
