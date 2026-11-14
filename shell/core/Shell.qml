pragma Singleton

import Quickshell
import QtQuick

// Transient UI state: which panel is open and on which screen.
Singleton {
    id: root

    // "" | "launcher" | "quick"
    property string panel: ""
    property var screen: null
    property bool settingsOpen: false
    readonly property string version: "0.4.0-dev"

    // Exclusive zone for windows that must cover the whole screen, bars and
    // all (wallpaper, lock, dialogs). The protocol wants exactly -1, but the
    // value is multiplied by the UI scale and cut off on its way out, so
    // ExclusionMode.Ignore turns into 0 at scales below 1. This survives it.
    readonly property int coverZone: -Math.ceil(1 / Math.max(0.5, parseFloat(Quickshell.env("QT_SCALE_FACTOR") || "1") || 1))

    // Session lock. Set through lock(); only a correct password clears it.
    property bool locked: false
    function lock() { panel = ""; locked = true }

    property string settingsPage: "style"
    function openSettings(page) {
        if (page !== undefined) settingsPage = page
        panel = ""
        settingsOpen = true
    }

    function toggle(name, onScreen) {
        if (panel === name) { panel = ""; return }
        screen = onScreen || screen || Quickshell.screens[0]
        panel = name
    }
    function close() { panel = "" }
}
