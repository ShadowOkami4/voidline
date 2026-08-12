pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool historyPersistPending: false

    property var packages: []
    property bool checking: false
    property bool installing: false
    property bool confirmationPending: false
    property int progress: 0
    property string stage: "Not checked"
    property string error: ""
    property var history: []
    property int revision: 0

    readonly property var officialPackages: packages.filter(item => item.source === "official")
    readonly property var aurPackages: packages.filter(item => item.source === "aur")
    readonly property int count: packages.length
    readonly property bool restartRecommended: officialPackages.some(item =>
        /^(linux|linux-lts|linux-zen|linux-hardened|systemd|glibc)$/.test(item.name))

    function check() {
        if (checking || installing)
            return
        checking = true
        error = ""
        stage = "Refreshing package information…"
        packageList.running = true
    }

    function requestInstall() {
        if (installing || officialPackages.length === 0)
            return
        confirmationPending = true
        stage = "Review the update list before installing"
    }

    function cancelInstall() {
        confirmationPending = false
        stage = count > 0 ? count + " updates available" : "System is up to date"
    }

    function confirmInstall() {
        if (!confirmationPending || installing)
            return
        confirmationPending = false
        installing = true
        progress = 4
        error = ""
        stage = "Waiting for system authentication…"
        installProcess.running = true
    }

    function appendHistory(success, detail) {
        const entry = {
            time: new Date().toISOString(),
            success: success,
            packages: officialPackages.length,
            detail: detail
        }
        history = [entry].concat(history).slice(0, 20)
        if (Paths.writableRootsReady) {
            historyFile.setText(JSON.stringify(history, null, 2) + "\n")
            historyPersistPending = false
        } else {
            historyPersistPending = true
        }
    }

    property Connections pathReadiness: Connections {
        target: Paths
        function onWritableRootsReadyChanged() {
            if (Paths.writableRootsReady && root.historyPersistPending) {
                historyFile.setText(JSON.stringify(root.history, null, 2) + "\n")
                root.historyPersistPending = false
            }
        }
    }

    function historyLabel(entry) {
        const when = new Date(entry.time)
        return Qt.formatDateTime(when, "yyyy-MM-dd hh:mm")
    }

    function parseList(contents) {
        const next = []
        const rows = String(contents || "").trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "package" && fields.length >= 5) {
                next.push({
                    source: fields[1],
                    name: fields[2],
                    oldVersion: fields[3],
                    newVersion: fields[4]
                })
            }
        }
        packages = next
        stage = next.length > 0
            ? next.length + (next.length === 1 ? " update available" : " updates available")
            : "System is up to date"
        revision++
    }

    function loadHistory(contents) {
        try {
            const parsed = JSON.parse(String(contents || "[]"))
            history = Array.isArray(parsed) ? parsed : []
        } catch (error) {
            history = []
        }
    }

    property var packageList: Process {
        command: ["sh", Paths.shellRoot + "/scripts/software-updates.sh", "list"]
        stdout: StdioCollector { id: packageOutput }
        stderr: StdioCollector { id: packageError }
        onExited: (exitCode, exitStatus) => {
            root.checking = false
            if (exitCode === 0) {
                root.parseList(packageOutput.text)
            } else {
                root.error = packageError.text.trim().length > 0
                    ? packageError.text.trim() : "Package information could not be refreshed"
                root.stage = "Update check failed"
            }
        }
    }

    property var installProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/software-updates.sh",
            "install-official"]
        stdout: SplitParser {
            onRead: line => {
                const text = String(line || "")
                if (text.indexOf("downloading") >= 0 || text.indexOf("Packages") >= 0) {
                    root.stage = "Downloading packages…"
                    root.progress = Math.max(root.progress, 28)
                } else if (text.indexOf("installing") >= 0 || text.indexOf("upgrading") >= 0) {
                    root.stage = "Installing updates…"
                    root.progress = Math.max(root.progress, 65)
                } else if (text.indexOf("Running post-transaction hooks") >= 0) {
                    root.stage = "Finishing installation…"
                    root.progress = 90
                }
            }
        }
        stderr: StdioCollector { id: installError }
        onExited: (exitCode, exitStatus) => {
            root.installing = false
            if (exitCode === 0) {
                root.progress = 100
                root.stage = "Updates installed"
                root.appendHistory(true, "Official repository update completed")
                updateRefresh.restart()
            } else {
                const details = installError.text.trim()
                root.error = details.length > 0
                    ? details.split("\n").slice(-1)[0] : "The update was cancelled or failed"
                root.stage = "Update failed"
                root.appendHistory(false, root.error)
            }
        }
    }

    property var updateRefresh: Timer {
        interval: 800
        onTriggered: root.check()
    }

    property var historyFile: FileView {
        path: Paths.writableRootsReady
            ? Paths.stateRoot + "/updates-history.json" : ""
        watchChanges: true
        printErrors: false
        onLoaded: root.loadHistory(text())
    }
}
