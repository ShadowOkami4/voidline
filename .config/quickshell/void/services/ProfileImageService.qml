pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool avatarAvailable: false
    property string cachePath: ""
    property int revision: 0
    property bool busy: false
    property string error: ""
    readonly property string avatarSource: avatarAvailable
        ? "file://" + cachePath + "?revision=" + revision : ""

    function parseStatus(contents) {
        const fields = String(contents || "").trim().split("|")
        avatarAvailable = fields[0] === "ready"
        cachePath = fields[1] || cachePath
        revision++
    }

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true
    }

    function applyCrop(source, zoom, offsetX, offsetY) {
        if (cropProcess.running || String(source || "").length === 0)
            return
        error = ""
        busy = true
        cropProcess.sourcePath = String(source)
        cropProcess.zoom = Number(zoom) || 1
        cropProcess.offsetX = Number(offsetX) || 0
        cropProcess.offsetY = Number(offsetY) || 0
        cropProcess.running = true
    }

    function remove() {
        if (removeProcess.running)
            return
        busy = true
        error = ""
        removeProcess.running = true
    }

    property var statusProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/profile-image.sh", "status"]
        stdout: StdioCollector { id: statusOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.parseStatus(statusOutput.text)
        }
    }

    property var cropProcess: Process {
        property string sourcePath: ""
        property real zoom: 1
        property real offsetX: 0
        property real offsetY: 0
        command: ["sh", Paths.shellRoot + "/scripts/profile-image.sh",
            "crop", sourcePath, String(zoom), String(offsetX), String(offsetY)]
        stdout: StdioCollector { id: cropOutput }
        stderr: StdioCollector { id: cropError }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode === 0)
                root.parseStatus(cropOutput.text)
            else
                root.error = exitCode === 5
                    ? "Install ImageMagick to crop profile pictures"
                    : (cropError.text.trim() || "Unable to save the profile picture")
        }
    }

    property var removeProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/profile-image.sh", "remove"]
        stdout: StdioCollector { id: removeOutput }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode === 0)
                root.parseStatus(removeOutput.text)
            else
                root.error = "Unable to remove the cached profile picture"
        }
    }

    Component.onCompleted: refresh()
}
