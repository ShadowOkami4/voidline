pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Reads the backlight from sysfs (no polling: the file is watched) and writes
// through brightnessctl, which handles permissions via logind.
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int current: 0
    readonly property bool available: device.length > 0 && max > 0
    readonly property real value: available ? current / max : 0

    function set(v) {
        if (!available) return
        const clamped = Math.max(0.02, Math.min(1, v))
        current = Math.round(clamped * max)
        Quickshell.execDetached(["brightnessctl", "-q", "-d", device, "set", Math.round(clamped * 100) + "%"])
    }

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"$(basename \"$d\") $(cat \"$d/max_brightness\")\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ")
                if (parts.length === 2) { root.max = parseInt(parts[1]); root.device = parts[0] }
            }
        }
    }

    FileView {
        path: root.device ? "/sys/class/backlight/" + root.device + "/actual_brightness" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.current = parseInt(text()) || 0
    }
}
