pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.core
import qs.compositor

// Accessibility helpers: the on-screen keyboard's typing and the screen reader.
//  - Typing goes through "wtype", which hands key presses to the compositor.
//    It types characters as such, so the keyboard does not depend on the
//    layout set for the real keyboard.
//  - The screen reader is Orca. The shell only starts and stops it and tells
//    apps to describe themselves; Voidline's own bar and panels are not read.
Singleton {
    id: root

    property bool canType: false
    property bool hasReader: false
    // Asked for by the page and the shell so the checks run once.
    readonly property bool ready: canType || hasReader

    Process {
        running: true
        command: ["sh", "-c", "command -v wtype >/dev/null && echo type; command -v orca >/dev/null && echo reader"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.canType = text.includes("type")
                root.hasReader = text.includes("reader")
            }
        }
    }

    // ---- magnifier and colour filters (Hyprland) ------------------------------------------
    readonly property bool canSee: Compositor.name === "hyprland"
    // The filter as a shader file of the shell, or "" for none.
    readonly property var filters: ["grayscale", "invert", "protan", "deutan", "tritan"]
    readonly property string filterPath: canSee && filters.includes(Config.colourFilter) ? Quickshell.shellDir + "/shaders/" + Config.colourFilter + ".frag" : ""

    // The zoom changes in steps from the keyboard, so it is handed to
    // Hyprland directly instead of rewriting and reloading its config.
    function setZoom(z) {
        Config.zoom = Math.max(1, Math.min(8, Math.round(z * 4) / 4))
        applyZoom()
    }
    function zoomIn() { setZoom(Config.zoom < 1.5 ? 1.5 : Config.zoom + 0.5) }
    function zoomOut() { setZoom(Config.zoom <= 1.5 ? 1 : Config.zoom - 0.5) }
    function applyZoom() {
        if (canSee) Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { zoom_factor = " + Number(Config.zoom).toFixed(2) + " } })"])
    }
    // A reloaded config would start at no zoom again.
    Connections {
        target: root.canSee ? Hyprland : null
        function onRawEvent(event) { if (event.name === "configreloaded" && Config.zoom > 1) zoomBack.restart() }
    }
    Timer { id: zoomBack; interval: 300; onTriggered: root.applyZoom() }
    Timer { interval: 3000; running: Config.loaded && Config.zoom > 1; onTriggered: root.applyZoom() }

    // ---- on-screen keyboard ---------------------------------------------------------
    function toggleKeyboard() { Config.onScreenKeyboard = !Config.onScreenKeyboard }

    // text: characters to type. mods: held while typing, e.g. ["ctrl"].
    function type(text, mods) {
        if (!canType) return
        const args = ["wtype"]
        for (const m of mods || []) args.push("-M", m)
        args.push("--", text)
        Quickshell.execDetached(args)
    }
    // A named key: BackSpace, Return, Tab, Escape, Left, Right, Up, Down.
    function key(name, mods) {
        if (!canType) return
        const args = ["wtype"]
        for (const m of mods || []) args.push("-M", m)
        args.push("-k", name)
        Quickshell.execDetached(args)
    }

    // ---- screen reader --------------------------------------------------------------
    readonly property bool reading: Config.screenReader && hasReader
    onReadingChanged: {
        const v = reading ? "true" : "false"
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "toolkit-accessibility", v])
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.a11y.applications", "screen-reader-enabled", v])
    }
    Process {
        running: root.reading
        command: ["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", "orca"]
    }
}
