pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    readonly property string voidlineVersion: "0.3.0dev"
    property bool active: false
    property bool loading: false
    property string osName: "Arch Linux"
    property string hostName: ""
    property string kernel: ""
    property string kernelType: ""
    property string uptime: ""
    property string quickshellVersion: ""
    property string hyprlandVersion: ""
    property string windowManager: "Hyprland"
    property string desktopShell: "Voidline on Quickshell"
    property string cpu: ""
    property string gpu: ""
    property string installedRam: ""
    property string storageCapacity: ""
    property string storageUsed: ""
    property int usbDevices: 0
    property int printers: 0
    property bool printerBackendAvailable: false
    property string trafficInterface: "none"
    property string receivedData: "0 B"
    property string sentData: "0 B"
    property string updateStatus: "Not checked"
    property bool checkingUpdates: false

    function setActive(value) {
        active = value
        if (value) {
            refresh()
            refreshTimer.restart()
        } else {
            refreshTimer.stop()
        }
    }

    function refresh() {
        if (!snapshotProcess.running) {
            loading = true
            snapshotProcess.running = true
        }
    }

    function parseSnapshot(contents) {
        const rows = contents.trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "os") osName = fields.slice(1).join("|")
            else if (fields[0] === "hostname") hostName = fields[1] || ""
            else if (fields[0] === "kernel") kernel = fields[1] || ""
            else if (fields[0] === "kerneltype") kernelType = fields[1] || ""
            else if (fields[0] === "uptime") uptime = fields[1] || ""
            else if (fields[0] === "quickshell") quickshellVersion = fields.slice(1).join("|")
            else if (fields[0] === "hyprland") hyprlandVersion = fields.slice(1).join("|")
            else if (fields[0] === "windowmanager") windowManager = fields.slice(1).join("|")
            else if (fields[0] === "desktopshell") desktopShell = fields.slice(1).join("|")
            else if (fields[0] === "cpu") cpu = fields.slice(1).join("|")
            else if (fields[0] === "gpu") gpu = fields.slice(1).join("|")
            else if (fields[0] === "memory") installedRam = fields.slice(1).join("|")
            else if (fields[0] === "storage") {
                storageCapacity = fields[1] || ""
                storageUsed = fields[2] || ""
            }
            else if (fields[0] === "usb") usbDevices = Number(fields[1]) || 0
            else if (fields[0] === "printers") {
                printers = Number(fields[1]) || 0
                printerBackendAvailable = fields[2] === "ready"
            } else if (fields[0] === "traffic") {
                trafficInterface = fields[1] || "none"
                receivedData = fields[2] || "0 B"
                sentData = fields[3] || "0 B"
            }
        }
        loading = false
    }

    function checkUpdates() {
        if (updateProcess.running)
            return
        checkingUpdates = true
        updateStatus = "Checking…"
        updateProcess.running = true
    }

    property var refreshTimer: Timer {
        interval: 5000
        repeat: true
        onTriggered: root.refresh()
    }

    property var snapshotProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/settings-snapshot.sh", "snapshot"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSnapshot(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.loading = false
        }
    }

    property var updateProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/settings-snapshot.sh", "updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split("|")
                if (fields[1] === "missing")
                    root.updateStatus = "Install pacman-contrib to check updates"
                else {
                    const count = Number(fields[1]) || 0
                    root.updateStatus = count === 0 ? "System is up to date"
                        : count + (count === 1 ? " update available" : " updates available")
                }
            }
        }
        onExited: (exitCode, exitStatus) => root.checkingUpdates = false
    }
}
