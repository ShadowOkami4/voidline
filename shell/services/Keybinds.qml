pragma Singleton

import Quickshell
import QtQuick
import qs.core

// Voidline's keyboard shortcuts. A shortcut is stored as "SUPER+SHIFT+N":
// modifiers in the order SUPER, CTRL, ALT, SHIFT, then one key by its XKB
// name. WmConfig turns them into binds for the running compositor.
Singleton {
    id: root

    // `ipc` is passed to "qs -c voidline ipc call shell"; `hypr` and `niri`
    // are used instead where the compositor does the work itself.
    readonly property var actions: [
        { id: "launcher", icon: "apps", label: "Open the launcher", combo: "SUPER+space", ipc: ["toggle", "launcher"] },
        { id: "quick", icon: "tune", label: "Open quick settings", combo: "SUPER+A", ipc: ["toggle", "quick"] },
        { id: "settings", icon: "settings", label: "Open Settings", combo: "SUPER+I", ipc: ["settings"] },
        { id: "switcher", icon: "tab", label: "Switch between windows", combo: "SUPER+Tab", ipc: ["switcher"] },
        { id: "clipboard", icon: "content_paste", label: "Open the clipboard history", combo: "SUPER+SHIFT+V", ipc: ["toggle", "clipboard"] },
        { id: "shot", icon: "screenshot_monitor", label: "Take a screenshot", combo: "Print", ipc: ["screenshot", "screen"] },
        { id: "shotRegion", icon: "screenshot_region", label: "Screenshot part of the screen", combo: "SHIFT+Print", ipc: ["screenshot", "region"] },
        { id: "record", icon: "radio_button_checked", label: "Start or stop a screen recording", combo: "CTRL+Print", ipc: ["record"] },
        { id: "lock", icon: "lock", label: "Lock the screen", combo: "SUPER+L", ipc: ["lock"] },
        { id: "minimize", icon: "minimize", label: "Minimise the window", combo: "SUPER+N", ipc: ["minimize"] },
        { id: "restore", icon: "open_in_full", label: "Bring back the last minimised window", combo: "SUPER+SHIFT+N", ipc: ["restore"] },
        { id: "peek", icon: "stacks", label: "Show minimised windows", combo: "SUPER+CTRL+N", ipc: [],
          hypr: 'hl.dsp.workspace.toggle_special("minimized")', niri: 'focus-workspace "minimized"' },
        { id: "style", icon: "dashboard_customize", label: "Switch to the next style", combo: "SUPER+ALT+S", ipc: ["style", "next"] }
    ]

    readonly property var mods: ["SUPER", "CTRL", "ALT", "SHIFT"]
    function valid(combo) { return /^((SUPER|CTRL|ALT|SHIFT)\+)*[A-Za-z0-9_]+$/.test(combo) }

    readonly property var saved: {
        const out = {}
        for (const e of Config.keybinds) {
            const i = e.indexOf("=")
            if (i > 0) out[e.slice(0, i)] = e.slice(i + 1)
        }
        return out
    }
    // "" when the action has no shortcut.
    function combo(id) {
        const action = actions.find(a => a.id === id)
        if (!action) return ""
        const v = saved[id]
        if (v === undefined) return action.combo
        return valid(v) ? v : ""
    }
    function isDefault(id) { return saved[id] === undefined }
    readonly property bool allDefault: Config.keybinds.length === 0

    function assign(id, value) {
        let list = Config.keybinds.filter(e => !e.startsWith(id + "="))
        // One shortcut, one action: take it away from whoever had it.
        if (value.length > 0)
            for (const a of actions)
                if (a.id !== id && combo(a.id).toLowerCase() === value.toLowerCase())
                    list = list.filter(e => !e.startsWith(a.id + "=")).concat([a.id + "="])
        const action = actions.find(a => a.id === id)
        if (action && value !== action.combo) list = list.concat([id + "=" + value])
        Config.keybinds = list
    }
    function reset(id) { Config.keybinds = Config.keybinds.filter(e => !e.startsWith(id + "=")) }
    function resetAll() { Config.keybinds = [] }

    // ---- display ---------------------------------------------------------------------
    readonly property var keyNames: ({ space: "Space", Return: "Enter", Prior: "Page Up", Next: "Page Down", comma: ",", period: ".",
        minus: "-", equal: "=", slash: "/", backslash: "\\", semicolon: ";", apostrophe: "'", bracketleft: "[", bracketright: "]", grave: "`" })
    readonly property var modNames: ({ SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" })
    // ["Super", "Shift", "N"]
    function parts(value) {
        if (!value) return []
        return value.split("+").map(p => modNames[p] ?? keyNames[p] ?? p)
    }

    // ---- compositor output -----------------------------------------------------------
    function hyprland() {
        let out = ""
        for (const a of actions) {
            const c = combo(a.id)
            if (c.length === 0) continue
            const what = a.hypr ?? `hl.dsp.exec_cmd("qs -c voidline ipc call shell ${a.ipc.join(" ")}")`
            out += `hl.bind("${c.split("+").join(" + ")}", ${what})\n`
        }
        return out
    }
    function niri() {
        let out = ""
        for (const a of actions) {
            const c = combo(a.id)
            if (c.length === 0) continue
            const p = c.split("+")
            const key = p.pop()
            const keys = p.map(m => ({ SUPER: "Mod", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" })[m]).concat([key]).join("+")
            const what = a.niri ?? "spawn " + ["qs", "-c", "voidline", "ipc", "call", "shell"].concat(a.ipc).map(w => `"${w}"`).join(" ")
            out += `    ${keys} hotkey-overlay-title="Voidline: ${a.label}" { ${what}; }\n`
        }
        return out.length > 0 ? "binds {\n" + out + "}\n" : ""
    }
}
