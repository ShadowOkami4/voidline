pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.compositor

// Automatic lock, screen off and sleep. The compositor tells the shell when
// nobody has touched keyboard or mouse for a while (idle-notify protocol), so
// no extra program is needed. Video players and calls can hold this back.
Singleton {
    id: root

    // Kept for the Settings page: the timers always work now.
    readonly property bool hasSwayidle: true
    readonly property bool ready: Config.loaded

    IdleMonitor {
        enabled: root.ready && Config.lockAfter > 0
        timeout: Math.max(1, Config.lockAfter) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Shell.lock()
    }
    IdleMonitor {
        enabled: root.ready && Config.screenOffAfter > 0
        timeout: Math.max(1, Config.screenOffAfter) * 60
        respectInhibitors: true
        onIsIdleChanged: Compositor.screenPower(!isIdle)
    }
    IdleMonitor {
        enabled: root.ready && Config.sleepAfter > 0
        timeout: Math.max(1, Config.sleepAfter) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "suspend"])
    }

    // Lock when the system announces sleep (lid closed, sleep button, timer),
    // and when something asks for the session to be locked (loginctl lock-session).
    Process {
        running: root.ready && Config.lockOnSleep
        command: ["dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        stdout: SplitParser { onRead: line => { if (line.includes("boolean true")) Shell.lock() } }
    }
    Process {
        running: root.ready
        command: ["dbus-monitor", "--system", "type='signal',interface='org.freedesktop.login1.Session',member='Lock'"]
        stdout: SplitParser { onRead: line => { if (line.includes("member=Lock")) Shell.lock() } }
    }
}
