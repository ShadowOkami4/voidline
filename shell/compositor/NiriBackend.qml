import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
        handle: ToplevelManager.toplevels.values.find(t => t.appId === (w.app_id || "") && t.title === (w.title || "")) ?? null,
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

    // ---- placing windows -------------------------------------------------------------
    // Niri lays windows out in scrolling columns; a snapped window floats on
    // top of them, like on Hyprland.
    function tile(id) { act(["move-window-to-tiling", "--id", String(id)]) }
    function toggleMaximize(id) {
        Quickshell.execDetached(["sh", "-c", `niri msg action move-window-to-tiling --id ${Number(id)}; niri msg action maximize-window-to-edges --id ${Number(id)}`])
    }
    // Room the shell itself takes at the screen edges (bar, frame, dock).
    function reserved() {
        const f = Style.frameWidth, bar = Style.barHeight, dock = Style.dock ? Style.dockHeight + 6 : 0
        const bottomBar = Style.barEdge === "bottom"
        return { left: f, right: f, top: bottomBar ? 0 : bar, bottom: (bottomBar ? bar : f) + dock }
    }
    // zone: { x, y, w, h } as shares of the free area of the screen.
    property var snapJob: null
    function snap(id, zone) { snapJob = { id: Number(id), zone: zone }; snapArea.running = true }
    Process {
        id: snapArea
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                const job = root.snapJob
                let o = null
                try { o = JSON.parse(text) } catch (e) { return }
                if (!job || !o || !o.logical) return
                const r = root.reserved(), gap = Math.max(0, Config.desktop.gaps), z = job.zone
                const aw = o.logical.width - r.left - r.right - 2 * gap
                const ah = o.logical.height - r.top - r.bottom - 2 * gap
                const x0 = r.left + gap + z.x * aw + (z.x > 0.001 ? gap / 2 : 0), x1 = r.left + gap + (z.x + z.w) * aw - (z.x + z.w < 0.999 ? gap / 2 : 0)
                const y0 = r.top + gap + z.y * ah + (z.y > 0.001 ? gap / 2 : 0), y1 = r.top + gap + (z.y + z.h) * ah - (z.y + z.h < 0.999 ? gap / 2 : 0)
                job.x = Math.round(x0); job.y = Math.round(y0)
                const id = job.id
                snapPlace.command = ["sh", "-c", `
niri msg action move-window-to-floating --id ${id}
niri msg action set-window-width --id ${id} ${Math.round(x1 - x0)}
niri msg action set-window-height --id ${id} ${Math.round(y1 - y0)}
niri msg action move-floating-window --id ${id} -x ${job.x} -y ${job.y}
sleep 0.2
niri msg --json windows`]
                snapPlace.running = true
            }
        }
    }
    // Niri may count the position from the free area instead of the screen
    // corner: look where the window ended up and correct by the difference.
    Process {
        id: snapPlace
        stdout: StdioCollector {
            onStreamFinished: {
                const job = root.snapJob
                root.snapJob = null
                let list = []
                try { list = JSON.parse(text) } catch (e) { return }
                const w = list.find(x => x.id === job.id)
                const at = w && w.layout ? w.layout.tile_pos_in_workspace_view : null
                if (!at) return
                const dx = Math.round(job.x - at[0]), dy = Math.round(job.y - at[1])
                if (Math.abs(dx) > 1 || Math.abs(dy) > 1)
                    root.act(["move-floating-window", "--id", String(job.id), "-x", (dx >= 0 ? "+" : "") + dx, "-y", (dy >= 0 ? "+" : "") + dy])
            }
        }
    }

    // ---- screen sharing ---------------------------------------------------------------
    // stream_id -> active
    property var casts: ({})
    readonly property bool sharing: Object.keys(casts).some(k => casts[k])

    function moveToWorkspace(id, ws) { act(["move-window-to-workspace", "--window-id", String(id), "--focus", "false", String(ws.index)]) }

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
        } else if (ev.CastsChanged) {
            const next = {}
            for (const c of ev.CastsChanged.casts || []) next[c.stream_id] = !!c.is_active
            casts = next
        } else if (ev.CastStartedOrChanged) {
            const c = ev.CastStartedOrChanged.cast
            const next = Object.assign({}, casts)
            next[c.stream_id] = !!c.is_active
            casts = next
        } else if (ev.CastStopped) {
            const next = Object.assign({}, casts)
            delete next[ev.CastStopped.stream_id]
            casts = next
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
                            mirror: false, disabled: false
                        }
                    })
                } catch (e) { console.warn("niri outputs:", e) }
            }
        }
    }
}
