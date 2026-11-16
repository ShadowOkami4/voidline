//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import qs.core
import qs.compositor
import qs.bar
import qs.panels
import qs.settings
import qs.services

// Voidline 0.4 - a Material 3 Expressive desktop shell for Hyprland and Niri.
ShellRoot {
    // Quickshell reloads itself when one of its files changes. During an
    // update many files change at once and the reload in the middle of it
    // crashed, so the installer restarts the shell instead. Developers who
    // want it back start the shell with VOIDLINE_HOT_RELOAD=1.
    Component.onCompleted: if (Quickshell.env("VOIDLINE_HOT_RELOAD") !== "1") Quickshell.watchFiles = false

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            LazyLoader {
                active: Config.wallpaper.length > 0
                Wallpaper { screen: perScreen.modelData }
            }

            Bar { screen: perScreen.modelData }

            LazyLoader {
                active: Style.framed
                Frame { screen: perScreen.modelData }
            }

            LazyLoader {
                active: Style.dock
                Dock { screen: perScreen.modelData }
            }

            PanelHost { screen: perScreen.modelData }
        }
    }

    NotificationPopups { screen: Quickshell.screens[0] }
    AuthDialog {}
    PairDialog {}
    OpenWithDialog {}
    Keyboard {}
    LockScreen {}
    Osd {}

    LazyLoader {
        active: Config.loaded && !Config.welcomed
        Welcome {}
    }

    // Background services start by being mentioned once.
    readonly property var services: [Idle.hasSwayidle, Clipboard.available, Appearance.available, Autostart.launched, Capture.canShoot, Access.ready, Events.ready, Drives.ready, Packages.available]

    LazyLoader {
        active: Shell.settingsOpen
        SettingsWindow {}
    }

    // Keeps the compositor's generated settings file in step with the config.
    readonly property string wmSettingsPath: WmConfig.path

    // The UI scale is fixed when the process starts. When the setting no
    // longer matches what we were started with, restart through start.sh.
    readonly property real startedScale: parseFloat(Quickshell.env("VOIDLINE_UI_SCALE") || "0")
    readonly property real wantedScale: Math.max(0.5, Math.min(1.5, Config.uiScale))
    readonly property bool scaleStale: Config.loaded && startedScale > 0 && Math.abs(wantedScale - startedScale) > 0.004
    onScaleStaleChanged: if (scaleStale) Quickshell.execDetached(["sh", Quickshell.shellDir + "/start.sh"])

    // Control surface for keybinds and voidlinectl:
    //   qs -c voidline ipc call shell toggle launcher
    IpcHandler {
        target: "shell"

        function toggle(panel: string): void { Shell.toggle(panel, null) }
        function close(): void { Shell.close() }
        function style(name: string): void {
            if (name === "next") Config.cycleStyle()
            else if (Config.styles.includes(name)) Config.style = name
        }
        function settings(): void { Shell.openSettings() }
        function settingsPage(page: string): void { Shell.openSettings(page) }
        // Change one setting, e.g.  set desktop.gaps 16   or   set style macos
        function set(key: string, value: string): string {
            const parts = key.split(".")
            let target = Config
            for (let i = 0; i < parts.length - 1; ++i) {
                target = target[parts[i]]
                if (!target) return "unknown setting: " + key
            }
            const name = parts[parts.length - 1]
            const old = target[name]
            if (old === undefined || typeof old === "function" || typeof old === "object") return "unknown setting: " + key
            if (typeof old === "boolean") target[name] = value === "true" || value === "on" || value === "1"
            else if (typeof old === "number") { if (isNaN(Number(value))) return "not a number: " + value; target[name] = Number(value) }
            else target[name] = value
            return "ok"
        }
        function lock(): void { Shell.lock() }
        // Put the active window somewhere, for scripts and own shortcuts:
        //   snap left | right | top-left | top-right | bottom-left | bottom-right | centre | fill | tile
        function snap(where: string): string {
            const win = Compositor.focusedWindow
            if (!win) return "no active window"
            const zones = {
                "left": [0, 0, 0.5, 1], "right": [0.5, 0, 0.5, 1],
                "top-left": [0, 0, 0.5, 0.5], "top-right": [0.5, 0, 0.5, 0.5],
                "bottom-left": [0, 0.5, 0.5, 0.5], "bottom-right": [0.5, 0.5, 0.5, 0.5],
                "centre": [0.15, 0.1, 0.7, 0.8]
            }
            if (where === "fill") Compositor.toggleMaximize(win.id)
            else if (where === "tile") Compositor.tile(win.id)
            else if (zones[where]) { const z = zones[where]; Compositor.snap(win.id, { x: z[0], y: z[1], w: z[2], h: z[3] }) }
            else return "unknown place"
            return "ok"
        }
        // Send the active window to workspace n (1 = first); the view stays.
        function moveWindow(workspace: string): string {
            const win = Compositor.focusedWindow
            const ws = Compositor.workspaces[Number(workspace) - 1]
            if (!win) return "no active window"
            if (!ws) return "no such workspace"
            Compositor.moveToWorkspace(win.id, ws)
            return "ok"
        }
        // Name workspace n; an empty name removes it.
        function nameWorkspace(workspace: string, name: string): void { Config.setWorkspaceName(Number(workspace), name) }
        // Open the menu of workspace n (what a right click on its dot does).
        function workspaceMenu(workspace: string): void { Shell.openWorkspace(Compositor.workspaces[Number(workspace) - 1], null) }
        // Open the page for installing apps and search for something.
        function install(query: string): void { Shell.findApp(query) }
        // Ask which app should open a file.
        function openWith(path: string): void { Shell.openWith(path) }
        // Tray icons, for scripts and testing:
        //   tray list            names of the icons
        //   tray menu <n>        open the menu of icon n (0 = first)
        //   tray click <n>       what a left click does
        //   tray entries         the entries of the open menu
        function tray(what: string, index: string): string {
            const items = SystemTray.items.values
            if (what === "list") return items.map((t, i) => i + ": " + (t.title || t.id) + (t.hasMenu ? " [menu]" : "")).join("\n") || "no tray icons"
            const item = items[Number(index) || 0]
            if (!item) return "no such icon"
            if (what === "menu") { Shell.trayItem = null; Shell.openTray(item, null); return "ok" }
            if (what === "click") { item.activate(); return "ok" }
            return "unknown command"
        }
        // bluetooth on | off
        function bluetooth(state: string): void { Bt.setOn(state !== "off") }
        // Shows a pairing question without a device, to look at the dialog:
        //   pairing confirm | show | pin | passkey | accept | service | none
        function pairing(kind: string): void { Bt.ask = kind === "none" ? null : { kind: kind, code: "482913" } }
        function switcher(): void { Shell.switcher() }
        // screenshot screen | region
        function screenshot(mode: string): void { Capture.shoot(mode) }
        function record(): void { Capture.toggleRecording() }
        function colour(): void { Capture.pickColour() }
        // Show or hide the on-screen keyboard.
        function keyboard(): void { Access.toggleKeyboard() }
        // quiet 1 | 3 | -1 (until tomorrow 7:00) | 0 (until switched off)
        function quiet(hours: string): void { Notifs.quiet(Number(hours) || 0) }
        // screen on | off
        function screen(state: string): void { Compositor.screenPower(state !== "off") }
        // media toggle | next | previous
        function media(action: string): void {
            if (action === "next") Media.next()
            else if (action === "previous") Media.previous()
            else Media.toggle()
        }
        function minimize(): void { Compositor.minimizeFocused() }
        function restore(): void { Compositor.restoreLast() }
        function compositor(): string { return Compositor.name }
    }
}
