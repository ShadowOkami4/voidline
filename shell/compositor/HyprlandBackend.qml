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
    function moveToWorkspace(id, ws) { dsp(`hl.dsp.window.move({ window = "${sel(id)}", workspace = ${Number(ws.id)}, follow = false })`) }
    function quit() { dsp("hl.dsp.exit()") }

    // ---- placing windows -------------------------------------------------------------
    function toggleMaximize(id) { dsp(`hl.dsp.window.fullscreen({ window = "${sel(id)}", mode = "maximized", action = "toggle" })`) }
    function tile(id) {
        dsp(`hl.dsp.window.fullscreen({ window = "${sel(id)}", mode = "maximized", action = "unset" })`)
        dsp(`hl.dsp.window.float({ window = "${sel(id)}", action = "disable" })`)
    }
    // zone: { x, y, w, h } as shares of the screen's free area (without bar
    // and dock). The window floats there, with the usual gaps around it.
    property var snapJob: null
    function snap(id, zone) { snapJob = { id: id, zone: zone }; snapArea.running = true }
    property Process snapArea: Process {
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const job = root.snapJob
                root.snapJob = null
                let list = []
                try { list = JSON.parse(text) } catch (e) { return }
                const m = list.find(x => x.focused) ?? list[0]
                if (!job || !m) return
                const turned = m.transform % 2 === 1
                const r = m.reserved, gap = Math.max(0, Config.desktop.gaps), z = job.zone
                const ax = m.x + r[0] + gap, ay = m.y + r[1] + gap
                const aw = (turned ? m.height : m.width) / m.scale - r[0] - r[2] - 2 * gap
                const ah = (turned ? m.width : m.height) / m.scale - r[1] - r[3] - 2 * gap
                // Half a gap on every edge that meets another zone.
                const x0 = ax + z.x * aw + (z.x > 0.001 ? gap / 2 : 0), x1 = ax + (z.x + z.w) * aw - (z.x + z.w < 0.999 ? gap / 2 : 0)
                const y0 = ay + z.y * ah + (z.y > 0.001 ? gap / 2 : 0), y1 = ay + (z.y + z.h) * ah - (z.y + z.h < 0.999 ? gap / 2 : 0)
                const w = `window = "${root.sel(job.id)}"`
                root.dsp(`hl.dsp.window.fullscreen({ ${w}, mode = "maximized", action = "unset" })`)
                root.dsp(`hl.dsp.window.float({ ${w}, action = "enable" })`)
                root.dsp(`hl.dsp.window.resize({ ${w}, x = ${Math.round(x1 - x0)}, y = ${Math.round(y1 - y0)} })`)
                root.dsp(`hl.dsp.window.move({ ${w}, x = ${Math.round(x0)}, y = ${Math.round(y0)} })`)
            }
        }
    }
    function screenPower(on) { dsp(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`) }

    property var outputs: []
    function refreshOutputs() { monitors.running = true }
    function applyOutput(name, mode, scale) {
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.monitor({ output = "${name}", mode = "${mode}", position = "auto", scale = ${scale} })`])
        refreshLater.restart()
    }

    property Timer refreshLater: Timer { interval: 900; onTriggered: root.refreshOutputs() }
    // A screen was plugged in or pulled out.
    property Connections plug: Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name.startsWith("monitoradded") || event.name.startsWith("monitorremoved")) root.refreshLater.restart() }
    }
    property Process monitors: Process {
        // "all" also lists screens that mirror another one.
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = JSON.parse(text).map(m => ({
                        name: m.name,
                        description: (m.make + " " + m.model).trim(),
                        // Tells two screens apart that use the same socket in turn.
                        identity: (m.make + " " + m.model + " " + (m.serial || "")).trim(),
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
