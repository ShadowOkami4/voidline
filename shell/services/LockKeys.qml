pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Caps lock and num lock, read from the keyboard's lights. Those files do
// not announce changes, so they are read four times a second; reading them
// costs next to nothing (no program is started for it).
Singleton {
    id: root

    property string capsPath: ""
    property string numPath: ""
    property bool caps: false
    property bool num: false
    readonly property bool ready: capsPath.length > 0 || numPath.length > 0

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null | head -n 1; echo @@; ls -d /sys/class/leds/*::numlock 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@")
                root.capsPath = (parts[0] || "").trim()
                root.numPath = (parts[1] || "").trim()
            }
        }
    }

    FileView {
        id: capsLight
        path: root.capsPath.length > 0 ? root.capsPath + "/brightness" : ""
        printErrors: false
        onLoaded: root.caps = Number(text().trim()) > 0
    }
    FileView {
        id: numLight
        path: root.numPath.length > 0 ? root.numPath + "/brightness" : ""
        printErrors: false
        onLoaded: root.num = Number(text().trim()) > 0
    }
    Timer {
        interval: 250
        running: root.ready
        repeat: true
        onTriggered: { if (root.capsPath) capsLight.reload(); if (root.numPath) numLight.reload() }
    }
}
