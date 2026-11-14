pragma Singleton

import Quickshell
import QtQuick

// The only place the shell talks to a window manager. Everything else uses the
// neutral model below, so supporting another compositor means writing one more
// backend file with the same properties and functions.
//
//   workspaces: [{ id, name, index, active, occupied }]
//   windows:    [{ id, appId, title, focused, minimized, workspace }]
//   outputs:    [{ name, description, mode, scale, modes: ["WxH@R"],
//                  x, y, w, h (place and size on the desktop), mirror }]  (after refreshOutputs)
Singleton {
    id: root

    readonly property string name: Quickshell.env("NIRI_SOCKET") ? "niri"
        : (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : "none")
    readonly property bool supported: name !== "none"

    readonly property var backend: loader.item
    readonly property var workspaces: backend ? backend.workspaces : []
    readonly property var windows: backend ? backend.windows : []
    readonly property var focusedWindow: windows.find(w => w.focused) ?? null
    readonly property var minimizedWindows: windows.filter(w => w.minimized)

    // Name of the hidden workspace that holds minimised windows.
    readonly property string stash: "minimized"

    function focusWorkspace(ws) { if (backend) backend.focusWorkspace(ws) }
    function focusWindow(id) { if (backend) backend.focusWindow(id) }
    function closeWindow(id) { if (backend) backend.closeWindow(id) }
    function minimize(id) { if (backend) backend.minimize(id) }
    function restore(id) { if (backend) backend.restore(id) }
    function quit() { if (backend) backend.quit() }
    // Turns all screens off or on (they also wake on input).
    function screenPower(on) { if (backend) backend.screenPower(on) }

    readonly property var outputs: backend ? backend.outputs : []
    function refreshOutputs() { if (backend) backend.refreshOutputs() }
    // Applies a mode and scale right away, without saving it.
    function applyOutput(name, mode, scale) { if (backend) backend.applyOutput(name, mode, scale) }

    function minimizeFocused() { if (focusedWindow) minimize(focusedWindow.id) }
    function restoreLast() {
        const m = minimizedWindows
        if (m.length > 0) restore(m[m.length - 1].id)
    }

    // Taskbar / dock behaviour: focused -> minimise, minimised -> restore,
    // otherwise focus.
    function activate(win) {
        if (win.minimized) restore(win.id)
        else if (win.focused) minimize(win.id)
        else focusWindow(win.id)
    }

    Loader {
        id: loader
        source: root.name === "hyprland" ? "HyprlandBackend.qml"
            : (root.name === "niri" ? "NiriBackend.qml" : "")
    }
}
