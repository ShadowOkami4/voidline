pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.core
import qs.compositor

// Which keyboard layout is active, for people who type in more than one
// (say German and English). The bar shows it only when there are several.
Singleton {
    id: root

    // ["de", "us"]
    property var layouts: []
    property int index: 0
    readonly property bool several: layouts.length > 1
    readonly property string current: several ? String(layouts[Math.min(index, layouts.length - 1)]).slice(0, 2).toUpperCase() : ""
    readonly property bool hypr: Compositor.name === "hyprland"

    function refresh() { if (!look.running) look.running = true }
    function next() {
        if (!several) return
        Quickshell.execDetached(hypr ? ["hyprctl", "switchxkblayout", "current", "next"] : ["niri", "msg", "action", "switch-layout", "next"])
        later.restart()
    }

    Process {
        id: look
        running: true
        command: root.hypr ? ["hyprctl", "-j", "devices"] : ["niri", "msg", "-j", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (root.hypr) {
                        const boards = data.keyboards || []
                        const main = boards.find(k => k.main) || boards[0]
                        if (!main) return
                        root.layouts = String(main.layout || "").split(",").map(l => l.trim()).filter(l => l.length > 0)
                        root.index = Math.max(0, main.active_layout_index || 0)
                    } else {
                        root.layouts = data.names || []
                        root.index = data.current_idx || 0
                    }
                } catch (e) {}
            }
        }
    }
    Timer { id: later; interval: 250; onTriggered: root.refresh() }
    // Hyprland says when the layout changes; Niri is asked now and then.
    Connections {
        target: root.hypr ? Hyprland : null
        function onRawEvent(event) { if (event.name === "activelayout" || event.name === "configreloaded") later.restart() }
    }
    Timer { interval: 2500; running: !root.hypr && root.several; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 4000; running: true; onTriggered: root.refresh() }
}
