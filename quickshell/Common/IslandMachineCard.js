.pragma library

// The machine bubble's card (a peripheral charging and its time to full) without a pointer (island card): "open" opens
// it as a dwelt hover does, "close" closes it, "toggle" switches. `host` is the island's host (DIsland.hostForScreen).
// Returns the card's wanted state (true: open) or the refusal to answer; the caller writes the state.
function ipc(host, action) {
    if (!["open", "close", "toggle"].includes(action))
        return "ISLAND_CARD_ACTIONS: open close toggle";
    if (!host?.islandController)
        return "ISLAND_UNAVAILABLE";
    if (!host.body?.bubbleSides?.machine)
        return "ISLAND_CARD_UNAVAILABLE: no machine bubble";
    return action === "toggle" ? !host.islandController.machineCardOpen : action === "open";
}
