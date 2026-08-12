pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property var capabilities: ({})
    property var states: ({
        sticky: false, slow: false, bounce: false,
        clickAssist: false, dwell: false,
        screenReader: false, screenKeyboard: false
    })
    property string error: ""
    property string pendingKey: ""
    property bool pendingValue: false

    function available(name) {
        return capabilities[name] === true
    }

    function parse(contents) {
        const next = {}
        const nextStates = Object.assign({}, states)
        const rows = String(contents || "").trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "cap")
                next[fields[1]] = fields[2] === "1"
            else if (fields[0] === "schema")
                next[fields[1]] = fields[2] === "1"
            else if (fields[0] === "state")
                nextStates[fields[1]] = fields[2] === "true"
        }
        capabilities = next
        states = nextStates
    }

    function setFeature(key, value) {
        const allowed = ["sticky", "slow", "bounce", "click-assist",
            "dwell", "screen-reader", "screen-keyboard"]
        if (allowed.indexOf(key) < 0 || setter.running)
            return
        pendingKey = key
        pendingValue = Boolean(value)
        const next = Object.assign({}, states)
        const stateKey = key.replace(/-([a-z])/g, (match, character) => character.toUpperCase())
        next[stateKey] = pendingValue
        states = next
        setter.running = true
    }

    function launchKeyboard() {
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/accessibility-service.sh",
                "launch-keyboard"]
        })
    }

    function launchReader() {
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/accessibility-service.sh",
                "launch-reader"]
        })
    }

    property var snapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/accessibility-service.sh",
            "snapshot"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    property var setter: Process {
        command: ["sh", Paths.shellRoot + "/scripts/accessibility-service.sh",
            "set", root.pendingKey, root.pendingValue ? "true" : "false"]
        stderr: StdioCollector { id: setterError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.error = setterError.text.trim().length > 0
                    ? setterError.text.trim() : "This accessibility feature is unavailable"
            else
                root.error = ""
        }
    }
}
