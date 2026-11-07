pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "../../Common/IslandSsh.js" as Ssh

// Incoming SSH bubble (apps side, source "ssh"): a remote sshd session that opens plays in the free island first
// (arrived()), then stays as a bubble (terminal, red dot, address) for as long as a session lasts; its card says who,
// since when, and cuts a session. logind's SessionNew / SessionRemoved (DMS's D-Bus bridge, gdbus monitor without it)
// re-read loginctl; no polling.
// B9: coded step by step (source, glyph, card); B2: apps side.
QtObject {
    id: root

    property bool enabled: true

    property var liveSessions: []
    readonly property var sessions: root.liveSessions
    readonly property var newest: root.sessions.length > 0 ? root.sessions[root.sessions.length - 1] : null
    property bool dismissed: false
    property bool cardOpen: false
    property bool primed: false
    property bool busy: false
    readonly property bool shown: root.enabled && !!root.newest && !root.dismissed
    // While the screen is shared the address stays off screen.
    readonly property bool masked: root.shown && PrivacyService.screensharingActive

    signal arrived

    readonly property string address: root.masked || !root.newest ? "" : root.newest.host
    readonly property var face: ({
            "id": "ssh",
            "source": "ssh",
            "kind": "ssh",
            "seq": 1e5,
            "icon": "terminal",
            "progress": -1,
            "text": "",
            "title": root.address || I18n.tr("SSH connection", "island ssh bubble: title when the address is unknown or hidden"),
            "detail": root.sessions.length > 1 ? I18n.tr("%1 SSH sessions", "island ssh bubble: number of open sessions").arg(root.sessions.length) : root.address ? I18n.tr("SSH connection", "island ssh bubble: under the address") : (root.newest?.user ?? ""),
            "accent": "primary",
            "open": root.cardOpen,
            "ssh": root
        })

    onShownChanged: root.shown ? PrivacyService.addRef() : PrivacyService.removeRef()
    Component.onDestruction: {
        if (root.shown)
            PrivacyService.removeRef();
    }

    onSessionsChanged: {
        const now = root.sessions;
        const before = root._last;
        root._last = now;
        if (now.length === 0)
            root.cardOpen = false;
        // The sessions already open at start do not "arrive".
        if (!root.primed) {
            root.primed = true;
            return;
        }
        if (Ssh.arrived(before, now)) {
            root.dismissed = false;
            if (root.enabled)
                root.arrived();
        }
    }
    property var _last: []

    function dismiss() {
        root.dismissed = true;
        root.cardOpen = false;
    }

    // Cuts one session, or several at once from an array of ids (logind asks polkit for another user's).
    function terminate(ids) {
        const list = [].concat(ids).map(String);
        if (root.busy || list.length === 0)
            return;
        root.busy = true;
        cut.command = ["loginctl", "terminate-session"].concat(list);
        cut.running = true;
    }

    readonly property Process cut: Process {
        stderr: StdioCollector {
            id: cutErr
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                ToastService.showError(I18n.tr("Could not end the SSH session", "island ssh bubble: loginctl failed"), cutErr.text.trim());
        }
    }

    function refresh() {
        if (root.enabled)
            list.running = true;
    }

    // Signals come in pairs (a session and its manager): one read this long after the last of them.
    readonly property int settleMs: 300
    readonly property Timer settle: Timer {
        interval: root.settleMs
        onTriggered: root.refresh()
    }

    readonly property Process list: Process {
        command: ["loginctl", "list-sessions", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = Ssh.ids(text);
                if (ids.length === 0) {
                    root.liveSessions = [];
                    return;
                }
                root.show.command = ["loginctl", "show-session"].concat(ids).concat(["-p", "Id", "-p", "Name", "-p", "Remote", "-p", "RemoteHost", "-p", "Service", "-p", "Timestamp"]);
                root.show.running = true;
            }
        }
    }

    // A session gone between the two calls only makes show-session fail for it: the others still print.
    readonly property Process show: Process {
        environment: ({
                "LC_ALL": "C"
            })
        stdout: StdioCollector {
            onStreamFinished: root.liveSessions = Ssh.sessions(text)
        }
    }

    onEnabledChanged: root.refresh()
    Component.onCompleted: root.refresh()

    // logind's session signals through DMS's D-Bus bridge.
    readonly property IslandDbusSignals logind: IslandDbusSignals {
        enabled: root.enabled
        service: "org.freedesktop.login1"
        matches: [["org.freedesktop.login1.Manager", "SessionNew", "/org/freedesktop/login1"], ["org.freedesktop.login1.Manager", "SessionRemoved", "/org/freedesktop/login1"]]
        onReceived: root.settle.restart()
    }

    // Without DMS's backend: logind's own signals through gdbus (blocks on its pipe, no CPU at rest).
    readonly property Process monitor: Process {
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        running: root.enabled && !DMSService.isConnected
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("Session") !== -1)
                    root.settle.restart();
            }
        }
    }
}
