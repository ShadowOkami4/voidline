pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core
import qs.compositor

// Automatic lock, screen off and sleep.
//
// With swayidle installed (works on Hyprland and Niri) the idle timers run
// there, and it also holds sleep back for the moment it takes to lock. Without
// it, only "lock before sleep" works, by listening for the system's
// about-to-sleep signal.
Singleton {
    id: root

    property bool hasSwayidle: false
    readonly property string call: "qs -c voidline ipc call shell "

    readonly property var args: {
        const a = ["swayidle", "-w"]
        const minutes = v => String(Math.max(1, v) * 60)
        if (Config.lockAfter > 0) a.push("timeout", minutes(Config.lockAfter), call + "lock")
        if (Config.screenOffAfter > 0)
            a.push("timeout", minutes(Config.screenOffAfter), call + "screen off", "resume", call + "screen on")
        if (Config.sleepAfter > 0) a.push("timeout", minutes(Config.sleepAfter), "systemctl suspend")
        if (Config.lockOnSleep) a.push("before-sleep", call + "lock")
        a.push("lock", call + "lock")
        return a
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v swayidle"]
        onExited: code => root.hasSwayidle = code === 0
    }

    // Restarted whenever a setting changes.
    Process {
        id: idle
        command: root.args
        running: root.hasSwayidle && Config.loaded
        onCommandChanged: if (running) { running = false; restart.restart() }
    }
    Timer { id: restart; interval: 300; onTriggered: idle.running = Qt.binding(() => root.hasSwayidle && Config.loaded) }

    // Fallback: lock when the system announces sleep.
    Process {
        running: !root.hasSwayidle && Config.loaded && Config.lockOnSleep
        command: ["dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        stdout: SplitParser {
            onRead: line => { if (line.includes("boolean true")) Shell.lock() }
        }
    }
}
