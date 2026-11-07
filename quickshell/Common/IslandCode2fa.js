.pragma library

// The island's one-time code bubble: a notification (an SMS relayed by a phone app, a mail, an authenticator) that
// carries a 4 to 8 digit code next to a word such as "code", "OTP" or "verification". Never stored, never logged.

// shortcut: English and French keywords only; add a language when someone reports a missed code.
const keyword = /\b(?:code|codes|otp|2fa|mfa|passcode|pin|verif\w*|v[ée]rif\w*|one[- ]time|usage unique|security|s[ée]curit[ée]|log[- ]?in|sign[- ]?in|connexion|authenti\w*)\b/i;
// 4 to 8 digits, or 3+3 / 4+4 digits split by a space or a dash; never inside a longer number, a time, an amount or a phone.
const number = /(?:^|[^\d:.,/+€$£])(\d{4}[ -]\d{4}|\d{3}[ -]\d{3}|\d{4,8})(?!\d|[:.,/]\d|\s?[€$£%])/g;

function plain(s) {
    return String(s ?? "").replace(/<[^>]*>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
}

function spans(re, text) {
    const out = [];
    const all = new RegExp(re.source, "gi");
    let m;
    while ((m = all.exec(text)) !== null) {
        const start = m.index + m[0].length - (m[1] ?? m[0]).length;
        out.push({
            "start": start,
            "end": m.index + m[0].length,
            "digits": m[1] ?? ""
        });
    }
    return out;
}

// Digits that are not the code: part of a date ("2026-10-31"), a time ("18:30") or a year ("Oct 31, 2026"), unless a
// keyword names it right before ("code: 2026"); a colon after the code ("Code 482913: do not share it") keeps it.
function notCode(text, n, words) {
    if (/^(?:-\d|:\d\d)/.test(text.slice(n.end)) || /\d-$/.test(text.slice(0, n.start)))
        return true;
    return /^(?:19|20)\d\d$/.test(n.digits) && !words.some(w => w.end <= n.start && /^[\s:#]*(?:is[\s:]*)?$/i.test(text.slice(w.end, n.start)));
}

function gap(a, b) {
    return a.end <= b.start ? b.start - a.end : a.start - b.end;
}

// A number's distance to a keyword, in characters; one in another sentence ("code. Ref 20261031") counts as far.
var otherSentence = 1000;
function distance(text, w, n) {
    const between = text.slice(Math.min(w.end, n.end), Math.max(w.start, n.start));
    return gap(w, n) + (/[.!?;]\s/.test(between) ? otherSentence : 0);
}

// The code ("123456") a notification carries, or "" when it carries none: of its numbers, the one nearest a keyword; on a
// tie, the one after its keyword ("code is 482913"), then the longer.
function find(summary, body) {
    const text = plain(summary) + "\n" + plain(body);
    const words = spans(keyword, text);
    if (words.length === 0)
        return "";
    const near = n => Math.min(...words.map(w => distance(text, w, n)));
    const after = n => words.some(w => w.end <= n.start && distance(text, w, n) === near(n)) ? 0 : 1;
    const codes = spans(number, text).filter(n => !notCode(text, n, words)).sort((a, b) => near(a) - near(b) || after(a) - after(b) || b.digits.length - a.digits.length);
    return codes.length > 0 ? codes[0].digits.replace(/[ -]/g, "") : "";
}

// "123 456", "1234 5678", "1234": digits in halves when the code is 6 or 8 long.
function grouped(code) {
    const s = String(code ?? "");
    return s.length === 6 || s.length === 8 ? s.slice(0, s.length / 2) + " " + s.slice(s.length / 2) : s;
}

// The same shape, every digit hidden: "••• •••".
function masked(code) {
    return grouped(code).replace(/\d/g, "•");
}

// The digits only while hovered, and never during a screen share.
function shown(code, hovered, sharing) {
    return hovered && !sharing ? grouped(code) : masked(code);
}

// The core takes the code as a secret: it wipes it and keeps it out of the history. Without the server, wl-copy reads it
// on its standard input (an argument is readable by any process) and serves it for one paste.
function copyPlan(code, server) {
    if (server)
        return {
            "request": "clipboard.copy",
            "params": {
                "text": code,
                "secret": true
            }
        };
    return {
        "command": ["wl-copy", "--paste-once"],
        "stdin": code
    };
}

// The timer hover holds in the bubble: the code's life, or once copied its leave countdown; none while on the island,
// whose own timer decides.
function heldTimer(entry, token, copied) {
    if (!entry || token)
        return "";
    return copied ? "leave" : "life";
}

// Rule 0 ter: the ms a code in its bubble takes back to the freed island, or 0. Never from under the pointer, nor once
// copied (it is leaving), nor for a last moment too short to be read there.
function backToIsland(s) {
    if (!s.free || !s.entry || s.token || s.copied || s.hovered)
        return 0;
    return s.left >= 1000 ? s.left : 0;
}
