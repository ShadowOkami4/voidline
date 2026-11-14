import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Niri: state comes from `niri msg --json event-stream`, actions go through
// `niri msg action`. Niri has no hidden workspaces, so minimised windows are
// parked on a named workspace ("minimized") that the shell never lists.
Item {
    id: root

    property var rawWorkspaces: []
    property var rawWindows: []

    readonly property var stashWs: rawWorkspaces.find(w => w.name === Compositor.stash) ?? null
    readonly property var focusedWs: rawWorkspaces.find(w => w.is_focused) ?? null

    readonly property var windows: rawWindows.map(w => ({
        id: w.id,
        appId: w.app_id || "",
        title: w.title || "",
        focused: !!w.is_focused,
        minimized: !!root.stashWs && w.workspace_id === root.stashWs.id,
        workspace: w.workspace_id
    }))

    readonly property var workspaces: {
        const output = focusedWs ? focusedWs.output : null
        const used = {}
        for (const w of rawWindows) used[w.workspace_id] = true
        return rawWorkspaces
            .filter(w => w.name !== Compositor.stash && (!output || w.output === output))
            .sort((a, b) => a.idx - b.idx)
            .map((w, i) => ({ id: w.id, name: w.name || String(i + 1), index: w.idx, active: !!w.is_active, occupied: !!used[w.id] }))
    }

    function act(args) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)) }

    function focusWorkspace(ws) { act(["focus-workspace", String(ws.index)]) }
    function focusWindow(id) { act(["focus-window", "--id", String(id)]) }
    function closeWindow(id) { act(["close-window", "--id", String(id)]) }
    function quit() { act(["quit", "--skip-confirmation"]) }
    function screenPower(on) { act([on ? "power-on-monitors" : "power-off-monitors"]) }

    property var outputs: []
    function refreshOutputs() { outputQuery.running = true }
    function applyOutput(name, mode, scale) {
        Quickshell.execDetached(["sh", "-c",
            `niri msg output "${name}" mode "${mode}"; niri msg output "${name}" scale ${scale}`])
        refreshLater.restart()
    }

    function minimize(id) {
        // Create the parking workspace on first use: name the trailing empty
        // workspace, which niri then keeps alive.
        if (!stashWs) {
            const last = rawWorkspaces.filter(w => !focusedWs || w.output === focusedWs.output)
                .sort((a, b) => b.idx - a.idx)[0]
            if (!last) return
            Quickshell.execDetached(["sh", "-c",
                `niri msg action set-workspace-name --workspace ${last.idx} ${Compositor.stash} && ` +
                `niri msg action move-window-to-workspace --window-id ${id} --focus false ${Compositor.stash}`])
            return
        }
        act(["move-window-to-workspace", "--window-id", String(id), "--focus", "false", Compositor.stash])
    }

    function restore(id) {
        const target = focusedWs && focusedWs.name !== Compositor.stash ? String(focusedWs.idx) : "1"
        Quickshell.execDetached(["sh", "-c",
            `niri msg action move-window-to-workspace --window-id ${id} --focus false ${target} && ` +
            `niri msg action focus-window --id ${id}`])
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            rawWorkspaces = ev.WorkspacesChanged.workspaces
        } else if (ev.WindowsChanged) {
            rawWindows = ev.WindowsChanged.windows
        } else if (ev.WindowOpenedOrChanged) {
            const win = ev.WindowOpenedOrChanged.window
            let list = rawWindows.filter(w => w.id !== win.id)
            if (win.is_focused) list = list.map(w => Object.assign({}, w, { is_focused: false }))
            list.push(win)
            rawWindows = list.sort((a, b) => a.id - b.id)
        } else if (ev.WindowClosed) {
            rawWindows = rawWindows.filter(w => w.id !== ev.WindowClosed.id)
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id
            rawWindows = rawWindows.map(w => Object.assign({}, w, { is_focused: w.id === id }))
        } else if (ev.WorkspaceActivated) {
            const e = ev.WorkspaceActivated
            const target = rawWorkspaces.find(w => w.id === e.id)
            if (!target) return
            rawWorkspaces = rawWorkspaces.map(w => {
                const sameOutput = w.output === target.output
                return Object.assign({}, w, {
                    is_active: sameOutput ? w.id === e.id : w.is_active,
                    is_focused: e.focused ? w.id === e.id : w.is_focused
                })
            })
        }
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try { root.handle(JSON.parse(line)) } catch (e) { console.warn("niri event:", e) }
            }
        }
        onExited: restart.start()
    }

    Timer { id: restart; interval: 1000; onTriggered: stream.running = true }
    Timer { id: refreshLater; interval: 900; onTriggered: root.refreshOutputs() }

    Process {
        id: outputQuery
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text)
                    const fmt = m => `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`
                    root.outputs = Object.keys(all).map(k => {
                        const o = all[k]
                        return {
                            name: o.name,
                            description: ((o.make || "") + " " + (o.model || "")).trim(),
                            mode: o.current_mode !== null && o.modes[o.current_mode] ? fmt(o.modes[o.current_mode]) : "",
                            scale: o.logical ? o.logical.scale : 1,
                            modes: o.modes.map(fmt),
                            x: o.logical ? o.logical.x : 0, y: o.logical ? o.logical.y : 0,
                            w: o.logical ? o.logical.width : 0, h: o.logical ? o.logical.height : 0,
                            mirror: false
                        }
                    })
                } catch (e) { console.warn("niri outputs:", e) }
            }
        }
    }
}
