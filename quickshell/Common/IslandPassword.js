.pragma library

// Password copied bubble: reads DMS's clipboard state (secret = password manager copies seen, never stored;
// secretActive = the clipboard holds one) and names the password manager that copied it.
// A4: this bubble's pure logic, tested by vm (tests/island-password.test.mjs).

// Known password managers, as their app ids read lowercased with only letters and digits kept.
const managers = ["protonpass", "keepassxc", "keepassx", "bitwarden", "1password", "enpass", "orggnomeworldsecrets", "passwordsafe"];

// The app id when it is a password manager, else "" (the bubble then shows a padlock).
function managerOf(appId) {
    const id = String(appId || "");
    const plain = id.toLowerCase().replace(/[^a-z0-9]/g, "");
    return plain !== "" && managers.some(m => plain.indexOf(m) !== -1) ? id : "";
}

// One clipboard state after the last one seen (last < 0: none yet, so a copy already held is not new).
// copied: a new password copy is held; gone: the clipboard no longer holds one.
function step(data, last) {
    const seq = Number(data && data.secret) || 0;
    const active = !!(data && data.secretActive);
    return {
        "copied": last >= 0 && active && seq !== last,
        "gone": !active,
        "last": seq
    };
}
