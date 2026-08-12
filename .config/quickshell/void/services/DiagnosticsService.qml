pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import "../core"

QtObject {
    id: root

    property string reportText: ""
    property string reportPath: ""
    property string error: ""
    property bool busy: false
    property bool cacheConfirmation: false
    property bool verboseLogging: false
    property bool reportVisible: false

    readonly property int trayCount: SystemTray.items.values.length
    readonly property string assistantStatus: FeatureRegistry.aiInstalled
        ? AssistantService.statusText + " · " + AssistantService.accelerator
        : I18n.tr("assistant.notInstalled")

    function refresh() {
        if (!snapshot.running) {
            busy = true
            snapshot.running = true
        }
    }

    function setVerboseLogging(value) {
        verboseLogging = Boolean(value)
        reportText = ""
        refresh()
    }

    function toggleReport() {
        reportVisible = !reportVisible
        if (reportVisible && reportText.length === 0)
            refresh()
    }

    function copyReport() {
        if (reportText.length === 0) {
            refresh()
            copyAfterRefresh.restart()
            return
        }
        Quickshell.clipboardText = reportText
    }

    function exportReport() {
        if (!exportProcess.running)
            exportProcess.running = true
    }

    function requestClearCache() {
        cacheConfirmation = true
    }

    function confirmClearCache() {
        if (!cacheConfirmation || clearProcess.running)
            return
        cacheConfirmation = false
        clearProcess.running = true
    }

    property var snapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/diagnostics.sh", "snapshot",
            root.verboseLogging ? "verbose" : "normal"]
        stdout: StdioCollector { id: diagnosticOutput }
        stderr: StdioCollector { id: diagnosticError }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode === 0) {
                root.reportText = diagnosticOutput.text
                root.error = ""
            } else {
                root.error = diagnosticError.text.trim().length > 0
                    ? diagnosticError.text.trim() : "Diagnostics could not be collected"
            }
        }
    }

    property var copyAfterRefresh: Timer {
        interval: 350
        onTriggered: {
            if (!root.busy && root.reportText.length > 0)
                Quickshell.clipboardText = root.reportText
        }
    }

    property var exportProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/diagnostics.sh", "export",
            root.verboseLogging ? "verbose" : "normal"]
        stdout: StdioCollector { id: exportOutput }
        stderr: StdioCollector { id: exportError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.reportPath = exportOutput.text.trim()
                root.error = ""
            } else {
                root.error = exportError.text.trim().length > 0
                    ? exportError.text.trim() : "The diagnostic report could not be exported"
            }
        }
    }

    property var clearProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/diagnostics.sh", "clear-cache"]
        onExited: (exitCode, exitStatus) => {
            root.error = exitCode === 0 ? "" : "The shell cache could not be cleared"
        }
    }
}
