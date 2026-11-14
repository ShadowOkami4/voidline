import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.core

// Hyprland (Lua config era, 0.55+): dispatchers are Lua expressions.
// Minimised windows live on the special workspace "special:minimized".
QtObject {
    id: root

    readonly property string stashName: "special:" + Compositor.stash

    readonly property var windows: Hyprland.toplevels.values.map(t => ({
        id: t.address,
        appId: (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || "",
        title: t.title || "",
        // Hyprland keeps the last window "activated" on an empty workspace.
        focused: t.activated && (!Hyprland.focusedWorkspace || !t.workspace || t.workspace.id < 0 || t.workspace.id === Hyprland.focusedWorkspace.id),
        minimized: !!t.workspace && t.workspace.name === root.stashName,
        workspace: t.workspace ? t.workspace.id : 0,
        handle: t.wayland ?? null
    }))

    readonly property var workspaces: {
        const existing = Hyprland.workspaces.values.filter(w => w.id > 0)
        const count = Math.max(Config.workspaceCount, existing.reduce((m, w) => Math.max(m, w.id), 0))
        const focused = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        const used = {}
        for (const w of windows) used[w.workspace] = true
        const list = []
        for (let i = 1; i <= count; ++i)
            list.push({ id: i, name: String(i), index: i, active: i === focused, occupied: !!used[i] })
        return list
    }

    function sel(id) { return "address:0x" + String(id).replace(/^0x/, "") }
    function dsp(lua) { Hyprland.dispatch(lua) }

    function focusWorkspace(ws) { dsp(`hl.dsp.focus({ workspace = ${ws.id} })`) }
    function focusWindow(id) { dsp(`hl.dsp.focus({ window = "${sel(id)}" })`) }
    function closeWindow(id) { dsp(`hl.dsp.window.close({ window = "${sel(id)}" })`) }
    function minimize(id) {
        dsp(`hl.dsp.window.move({ window = "${sel(id)}", workspace = "${stashName}", follow = false })`)
    }
    function restore(id) {
        const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        dsp(`hl.dsp.window.move({ window = "${sel(id)}", workspace = "${ws}", follow = false })`)
        focusWindow(id)
    }
    function quit() { dsp("hl.dsp.exit()") }
    function screenPower(on) { dsp(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`) }

    property var outputs: []
    function refreshOutputs() { monitors.running = true }
    function applyOutput(name, mode, scale) {
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.monitor({ output = "${name}", mode = "${mode}", position = "auto", scale = ${scale} })`])
        refreshLater.restart()
    }

    property Timer refreshLater: Timer { interval: 900; onTriggered: root.refreshOutputs() }
    property Process monitors: Process {
        // "all" also lists screens that mirror another one.
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = JSON.parse(text).map(m => ({
                        name: m.name,
                        description: (m.make + " " + m.model).trim(),
                        mode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`,
                        scale: m.scale,
                        modes: m.availableModes.map(s => s.replace("Hz", "")),
                        x: m.x, y: m.y,
                        w: Math.round((m.transform % 2 === 1 ? m.height : m.width) / m.scale),
                        h: Math.round((m.transform % 2 === 1 ? m.width : m.height) / m.scale),
                        mirror: !!m.mirrorOf && m.mirrorOf !== "none",
                        disabled: !!m.disabled
                    }))
                } catch (e) { console.warn("hyprctl monitors:", e) }
            }
        }
    }
}
