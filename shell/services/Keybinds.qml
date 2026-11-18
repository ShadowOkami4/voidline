pragma Singleton

import Quickshell
import Quickshell.Io
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
        { id: "launcher", icon: "apps", label: Lang.t("Open the launcher"), combo: "SUPER+space", ipc: ["toggle", "launcher"] },
        // Tapping Super on its own, as on Windows and GNOME. Fires when Super
        // is let go with nothing pressed in between (Hyprland only).
        { id: "launcherTap", icon: "apps", label: Lang.t("Open the launcher by tapping Super"), combo: "SUPER+Super_L", ipc: ["toggle", "launcher"], release: true, hyprOnly: true },
        { id: "terminal", icon: "terminal", label: Lang.t("Open the terminal"), combo: "SUPER+T", ipc: ["terminal"] },
        { id: "quick", icon: "tune", label: Lang.t("Open quick settings"), combo: "SUPER+A", ipc: ["toggle", "quick"] },
        { id: "settings", icon: "settings", label: Lang.t("Open Settings"), combo: "SUPER+I", ipc: ["settings"] },
        { id: "switcher", icon: "tab", label: Lang.t("Switch between windows"), combo: "SUPER+Tab", ipc: ["switcher"] },
        { id: "clipboard", icon: "content_paste", label: Lang.t("Open the clipboard history"), combo: "SUPER+SHIFT+V", ipc: ["toggle", "clipboard"] },
        { id: "shot", icon: "screenshot_monitor", label: Lang.t("Take a screenshot"), combo: "Print", ipc: ["screenshot", "screen"] },
        { id: "shotRegion", icon: "screenshot_region", label: Lang.t("Screenshot part of the screen"), combo: "SHIFT+Print", ipc: ["screenshot", "region"] },
        // The same for keyboards without a Print key.
        { id: "shotRegionKeys", icon: "screenshot_region", label: Lang.t("Screenshot part of the screen (without Print key)"), combo: "SUPER+SHIFT+A", ipc: ["screenshot", "region"] },
        { id: "record", icon: "radio_button_checked", label: Lang.t("Start or stop a screen recording"), combo: "SUPER+ALT+R", ipc: ["record"] },
        { id: "emoji", icon: "mood", label: Lang.t("Open the emoji picker"), combo: "SUPER+period", ipc: ["toggle", "emoji"] },
        { id: "colour", icon: "colorize", label: Lang.t("Pick a colour from the screen"), combo: "SUPER+SHIFT+C", ipc: ["colour"] },
        { id: "layout", icon: "language", label: Lang.t("Switch keyboard layout"), combo: "SUPER+ALT+space", ipc: [],
          hypr: 'hl.dsp.exec_cmd("hyprctl switchxkblayout all next")', niri: 'switch-layout "next"' },
        { id: "zoomIn", icon: "zoom_in", label: Lang.t("Magnify (zoom in)"), combo: "SUPER+ALT+plus", ipc: ["zoom", "in"] },
        { id: "zoomOut", icon: "zoom_out", label: Lang.t("Zoom out"), combo: "SUPER+ALT+minus", ipc: ["zoom", "out"] },
        { id: "osk", icon: "keyboard", label: Lang.t("Show or hide the on-screen keyboard"), combo: "SUPER+ALT+K", ipc: ["keyboard"] },
        { id: "snap", icon: "view_quilt", label: Lang.t("Arrange the window (snap layouts)"), combo: "SUPER+Z", ipc: ["toggle", "snap"] },
        { id: "keys", icon: "keyboard_command_key", label: Lang.t("Show all shortcuts"), combo: "SUPER+H", ipc: ["toggle", "keys"] },
        { id: "lock", icon: "lock", label: Lang.t("Lock the screen"), combo: "SUPER+L", ipc: ["lock"] },
        { id: "minimize", icon: "minimize", label: Lang.t("Minimise the window"), combo: "SUPER+N", ipc: ["minimize"] },
        { id: "restore", icon: "open_in_full", label: Lang.t("Bring back the last minimised window"), combo: "SUPER+SHIFT+N", ipc: ["restore"] },
        { id: "peek", icon: "stacks", label: Lang.t("Show minimised windows"), combo: "SUPER+CTRL+N", ipc: [],
          hypr: 'hl.dsp.workspace.toggle_special("minimized")', niri: 'focus-workspace "minimized"' },
        { id: "style", icon: "dashboard_customize", label: Lang.t("Switch to the next style"), combo: "SUPER+ALT+S", ipc: ["style", "next"] }
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
    readonly property var keyNames: ({ space: Lang.t("Space"), Return: Lang.t("Enter"), Super_L: Lang.t("tap alone"), Prior: Lang.t("Page Up"), Next: Lang.t("Page Down"), comma: ",", period: ".",
        minus: "-", equal: "=", slash: "/", backslash: "\\", semicolon: ";", apostrophe: "'", bracketleft: "[", bracketright: "]", grave: "`" })
    readonly property var modNames: ({ SUPER: "Super", CTRL: Lang.t("Ctrl"), ALT: "Alt", SHIFT: Lang.t("Shift") })
    // ["Super", "Shift", "N"]
    function parts(value) {
        if (!value) return []
        return value.split("+").map(p => modNames[p] ?? keyNames[p] ?? p)
    }

    // ---- compositor output -----------------------------------------------------------
    // ---- touchpad gestures (Hyprland) -----------------------------------------------
    // What a swipe up or down can do. `action` is one of Hyprland's own
    // gesture actions, `ipc` a call into the shell.
    readonly property var gestureActions: [
        { value: "", label: Lang.t("Nothing") },
        { value: "switcher", label: Lang.t("Window switcher"), ipc: "switcher" },
        { value: "launcher", label: Lang.t("Launcher"), ipc: "toggle launcher" },
        { value: "quick", label: Lang.t("Quick settings"), ipc: "toggle quick" },
        { value: "minimize", label: Lang.t("Minimise"), ipc: "minimize" },
        { value: "fullscreen", label: Lang.t("Full screen"), action: "fullscreen" },
        { value: "close", label: Lang.t("Close window"), action: "close" }
    ]
    // Gestures the user's own hyprland.lua already defines. Hyprland reports
    // an error when the same swipe is defined twice, so those are left alone
    // and Settings says so.
    FileView {
        id: ownConfig
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/hyprland.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property var ownGestures: {
        const text = (ownConfig.text() || "").replace(/--[^\n]*/g, "")
        const found = []
        const each = /hl\.gesture\s*\(\s*\{([^}]*)\}/g
        let m
        while ((m = each.exec(text)) !== null) {
            const f = m[1].match(/fingers\s*=\s*(\d+)/), d = m[1].match(/direction\s*=\s*"(\w+)"/)
            if (f && d) found.push({ fingers: Number(f[1]), direction: d[1] })
        }
        return found
    }
    // dir: "horizontal", "up" or "down", for the finger count in use.
    function gestureTaken(dir) {
        const n = Config.hyprland.gestureFingers === 4 ? 4 : 3
        const same = dir === "horizontal" ? ["horizontal", "left", "right", "swipe"] : [dir, "vertical", "swipe"]
        return ownGestures.some(g => g.fingers === n && same.includes(g.direction))
    }

    function gestures() {
        const h = Config.hyprland
        const n = h.gestureFingers === 4 ? 4 : 3
        let out = ""
        if (h.gestureWorkspaces && !gestureTaken("horizontal"))
            out += `hl.gesture({ fingers = ${n}, direction = "horizontal", action = "workspace" })\n`
        for (const [dir, pick] of [["up", h.gestureUp], ["down", h.gestureDown]]) {
            const a = gestureActions.find(x => x.value === pick)
            if (!a || a.value === "" || gestureTaken(dir)) continue
            const what = a.action ? `"${a.action}"` : `function() hl.exec_cmd("qs -c voidline ipc call shell ${a.ipc}") end`
            out += `hl.gesture({ fingers = ${n}, direction = "${dir}", action = ${what} })\n`
        }
        // Swipe through the workspaces by number, empty ones included, the way
        // the dots in the bar show them. Hyprland's default skips empty ones,
        // which makes a swipe do nothing as soon as the neighbour is empty.
        out += `hl.config({ gestures = { workspace_swipe_use_r = true, workspace_swipe_touch = ${Config.tabletMode} } })\n`
        return out
    }

    function hyprland() {
        let out = gestures()
        for (const a of actions) {
            const c = combo(a.id)
            if (c.length === 0) continue
            const what = a.hypr ?? `hl.dsp.exec_cmd("qs -c voidline ipc call shell ${a.ipc.join(" ")}")`
            out += `hl.bind("${c.split("+").join(" + ")}", ${what}${a.release ? ", { release = true }" : ""})\n`
        }
        return out
    }
    function niri() {
        let out = ""
        for (const a of actions) {
            const c = combo(a.id)
            if (c.length === 0 || a.hyprOnly) continue
            const p = c.split("+")
            const key = p.pop()
            const keys = p.map(m => ({ SUPER: "Mod", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" })[m]).concat([key]).join("+")
            const what = a.niri ?? "spawn " + ["qs", "-c", "voidline", "ipc", "call", "shell"].concat(a.ipc).map(w => `"${w}"`).join(" ")
            out += `    ${keys} hotkey-overlay-title="Voidline: ${a.label}" { ${what}; }\n`
        }
        return out.length > 0 ? "binds {\n" + out + "}\n" : ""
    }
}
