.pragma library

// The island's screen plugged bubble: which niri output just appeared, how to remember a choice for it, and the
// niri "Output" actions (NiriService.send) that apply a choice or undo it. `outputs` is NiriService.outputs
// (name -> niri output, `logical` null when the output is off). A4: pure logic, tested by vm.

var CHOICES = ["extend", "duplicate", "only"];

// Names present now and absent before; the first fill (no previous names) is the boot, not a plug.
function added(previous, outputs) {
    if (!previous)
        return [];
    return Object.keys(outputs || {}).filter(name => previous.indexOf(name) < 0);
}

// Same key for the same monitor on any port: make, model and serial, or the port name when niri gives none.
function key(output, name) {
    const parts = [output?.make, output?.model, output?.serial].filter(p => p && p !== "Unknown");
    return parts.length ? parts.join(" ") : name;
}

// The name a person reads: model, else make, else the port.
function label(output, name) {
    return output?.model || output?.make || name;
}

// The output the new one copies or sits next to: the first other one that is on.
function reference(outputs, name) {
    return Object.keys(outputs || {}).find(n => n !== name && outputs[n]?.logical) || "";
}

// shortcut: niri has no output mirroring, so "duplicate" asks for the reference's position and niri moves the
// output next to it if it refuses an overlap; upgrade to a real mirror once niri ships one.
function actions(choice, name, outputs) {
    if (CHOICES.indexOf(choice) < 0 || !outputs?.[name])
        return [];
    const list = [{
            "output": name,
            "action": "On"
        }];
    if (choice === "extend")
        list.push({
            "output": name,
            "action": {
                "Position": {
                    "position": "Automatic"
                }
            }
        });
    const ref = reference(outputs, name);
    if (choice === "duplicate" && ref)
        list.push({
            "output": name,
            "action": {
                "Position": {
                    "position": {
                        "Specific": {
                            "x": outputs[ref].logical.x,
                            "y": outputs[ref].logical.y
                        }
                    }
                }
            }
        });
    if (choice === "only")
        for (const other of Object.keys(outputs))
            if (other !== name && outputs[other]?.logical)
                list.push({
                    "output": other,
                    "action": "Off"
                });
    return list;
}

// One Output step as `niri msg output` arguments (on, off, position auto or set x y), null for any other action: the
// command answers with its exit code, where the request socket's answer goes unread.
function command(step) {
    const base = ["niri", "msg", "output", String(step?.output ?? "")];
    const a = step?.action;
    if (a === "On" || a === "Off")
        return base.concat([a.toLowerCase()]);
    const p = a?.Position?.position;
    if (p === "Automatic")
        return base.concat(["position", "auto"]);
    if (p?.Specific)
        return base.concat(["position", "set", String(p.Specific.x), String(p.Specific.y)]);
    return null;
}

// Back to `before` (the outputs as niri set them on plug): each output on at its old place, or off. Outputs turned
// on come first so the session never loses its last screen.
function restore(before) {
    const on = [], off = [];
    for (const name of Object.keys(before || {})) {
        const logical = before[name]?.logical;
        if (!logical) {
            off.push({
                "output": name,
                "action": "Off"
            });
            continue;
        }
        on.push({
            "output": name,
            "action": "On"
        }, {
            "output": name,
            "action": {
                "Position": {
                    "position": {
                        "Specific": {
                            "x": logical.x,
                            "y": logical.y
                        }
                    }
                }
            }
        });
    }
    return on.concat(off);
}
