.pragma library

// A window calling for attention (niri's urgent flag): which one just started, from NiriService's window list.
// A4: pure logic, tested by island-urgent.test.mjs.

function urgentIds(windows) {
    return (Array.isArray(windows) ? windows : []).filter(w => w && w.is_urgent).map(w => w.id);
}

// The last window that turned urgent since `known` (the ids seen urgent before), or null.
function fresh(windows, known) {
    const seen = Array.isArray(known) ? known : [];
    const calling = (Array.isArray(windows) ? windows : []).filter(w => w && w.is_urgent && seen.indexOf(w.id) === -1);
    return calling.length ? calling[calling.length - 1] : null;
}
