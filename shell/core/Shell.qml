pragma Singleton

import Quickshell
import QtQuick

// Transient UI state: which panel is open and on which screen.
Singleton {
    id: root

    // "" | "launcher" | "quick"
    property string panel: ""
    property var screen: null

    function toggle(name, onScreen) {
        if (panel === name) { panel = ""; return }
        screen = onScreen || screen || Quickshell.screens[0]
        panel = name
    }
    function close() { panel = "" }
}
