.pragma library

// What a polkit request is waiting for, read from its flow: the island draws a field, a finger or a face.
// pam_fprintd and howdy only send info lines while they wait; a response is asked for by the password prompt alone.
const fingerPattern = /finger|fprint|empreinte|doigt/i;
const facePattern = /face|howdy|visage|camera|caméra/i;

function mode(responseRequired, supplementary) {
    if (responseRequired)
        return "password";
    const info = typeof supplementary === "string" ? supplementary : "";
    if (fingerPattern.test(info))
        return "fingerprint";
    if (facePattern.test(info))
        return "face";
    return "wait";
}

// "Password: " reads "Password" as a field label.
function promptLabel(prompt) {
    return (typeof prompt === "string" ? prompt : "").replace(/[\s:]+$/, "");
}

function modeIcon(m) {
    switch (m) {
    case "fingerprint":
        return "fingerprint";
    case "face":
        return "face";
    }
    return "lock";
}
