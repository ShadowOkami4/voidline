pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property string firewallBackend: ""
    property string firewallStatus: "Checking"
    property string secureBootStatus: "Checking"
    property string encryptionStatus: "Checking"
    property string rootDevice: ""
    property int activeSessions: 0
    property int lockTimeout: 300
    property bool loading: false
    property bool changing: false
    property bool firewallConfirmation: false
    property string error: ""
    property string pendingAction: ""

    readonly property bool firewallAvailable: firewallBackend.length > 0
    readonly property bool firewallEnabled: firewallStatus === "active"
        || firewallStatus === "enabled"

    function refresh() {
        if (!snapshot.running && !changing) {
            loading = true
            snapshot.running = true
        }
    }

    function parseSnapshot(contents) {
        const rows = String(contents || "").trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "firewall") {
                firewallBackend = fields[1] || ""
                firewallStatus = fields[2] || "unavailable"
            } else if (fields[0] === "secureboot") {
                secureBootStatus = fields[1] || "unknown"
            } else if (fields[0] === "encryption") {
                encryptionStatus = fields[1] || "unknown"
                rootDevice = fields[2] || ""
            } else if (fields[0] === "sessions") {
                activeSessions = Number(fields[1]) || 0
            } else if (fields[0] === "lock-timeout") {
                lockTimeout = Number(fields[1]) || 300
            }
        }
        loading = false
    }

    function setLockTimeout(seconds) {
        if (changing)
            return
        lockTimeout = Math.max(30, Math.min(86400, Math.round(seconds)))
        pendingAction = "lock-timeout"
        changing = true
        apply.command = ["sh", Paths.shellRoot + "/scripts/security-service.sh",
            "lock-timeout", lockTimeout.toString()]
        apply.running = true
    }

    function requestFirewallToggle() {
        if (!firewallAvailable || changing)
            return
        firewallConfirmation = true
    }

    function confirmFirewallToggle() {
        if (!firewallConfirmation || changing)
            return
        firewallConfirmation = false
        pendingAction = "firewall"
        changing = true
        apply.command = ["sh", Paths.shellRoot + "/scripts/security-service.sh",
            "firewall", firewallEnabled ? "stop" : "start"]
        apply.running = true
    }

    property var snapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/security-service.sh", "snapshot"]
        stdout: StdioCollector { onStreamFinished: root.parseSnapshot(text) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.loading = false
        }
    }

    property var apply: Process {
        stderr: StdioCollector { id: securityError }
        onExited: (exitCode, exitStatus) => {
            root.changing = false
            if (exitCode !== 0)
                root.error = securityError.text.trim().length > 0
                    ? securityError.text.trim() : "The security setting could not be applied"
            else
                root.error = ""
            securityRefresh.restart()
        }
    }

    property var securityRefresh: Timer {
        interval: 300
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
