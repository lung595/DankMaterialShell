pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import "../../Common/IslandAuth.js" as Auth

// Polkit requests shown by the island: it claims the request before the dialog, which stays the fallback whenever the
// island is off, locked or absent from the focused screen. The response goes straight to the flow, never stored or logged.
Item {
    id: root

    readonly property string sourceId: "dms:auth"
    property var flow: null
    property string token: ""
    // ask | busy | failed | success
    property string phase: "ask"
    // Bumped on each failure, so the face shakes even when it fails twice in a row.
    property int failures: 0
    readonly property string mode: Auth.mode(root.flow?.isResponseRequired ?? false, root.flow?.supplementaryMessage ?? "")
    readonly property string promptLabel: Auth.promptLabel(root.flow?.inputPrompt ?? "")

    visible: false

    function claim(): bool {
        if (SessionService.locked || root.token)
            return false;
        return root.begin(PolkitService.agent?.flow ?? null);
    }

    function begin(flow): bool {
        if (!flow)
            return false;
        root.flow = flow;
        root.phase = "ask";
        root.token = IslandActivityService.add(root.sourceId, {
            "kind": "alert",
            "expanded": true,
            "showInFullscreen": true,
            "data": {
                "source": root,
                "icon": "lock",
                "title": I18n.tr("Authentication Required", "island polkit request title")
            }
        });
        if (!root.token)
            root.flow = null;
        return !!root.token;
    }

    function submit(response) {
        if (!root.flow || root.phase === "busy" || root.phase === "success" || !root.flow.isResponseRequired)
            return;
        root.phase = "busy";
        root.flow.submit(response);
    }

    function cancel() {
        const flow = root.flow;
        root.finish();
        if (flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
    }

    function finish() {
        doneTimer.stop();
        const token = root.token;
        root.token = "";
        root.flow = null;
        root.phase = "ask";
        if (token)
            IslandActivityService.remove(token, "released");
    }

    // The check stays a moment before the island lets go.
    readonly property int checkMs: 900
    Timer {
        id: doneTimer
        interval: root.checkMs
        onTriggered: root.finish()
    }

    Connections {
        target: root.flow
        enabled: !!root.flow

        function onAuthenticationSucceeded() {
            root.phase = "success";
            doneTimer.restart();
        }

        function onAuthenticationFailed() {
            // PolkitService switching to the user's own identity restarts the session: not the user's failure.
            if (PolkitService._switchingIdentity)
                return;
            root.phase = "failed";
            root.failures++;
        }

        function onAuthenticationRequestCancelled() {
            root.finish();
        }

        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired && root.phase === "busy")
                root.phase = "ask";
        }

        // A new prompt after a failure (a fingerprint or face session starting again) asks again: the scan shows and
        // the PAM hint replaces the failure message.
        function onSupplementaryMessageChanged() {
            if (root.phase === "failed" && root.flow.supplementaryMessage !== "" && !root.flow.supplementaryIsError)
                root.phase = "ask";
        }
    }

    Connections {
        target: IslandActivityService

        // Dropped by anyone but finish() (which clears the token first): polkit hears a cancel.
        function onDropped(token, reason) {
            if (token === root.token)
                root.cancel();
        }
    }

    readonly property bool agentActive: PolkitService.agent?.isActive ?? false
    onAgentActiveChanged: {
        if (!PolkitService.agent || root.flow !== PolkitService.agent.flow)
            return;
        if (!root.agentActive && root.phase !== "success")
            root.finish();
    }

    Component.onCompleted: PolkitService.islandClaim = root.claim
    Component.onDestruction: {
        if (PolkitService.islandClaim === root.claim)
            PolkitService.islandClaim = null;
        root.cancel();
    }
}
