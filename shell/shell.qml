//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core
import qs.compositor
import qs.bar
import qs.panels

// Voidline 0.4 - a Material 3 Expressive desktop shell for Hyprland and Niri.
ShellRoot {
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
        function minimize(): void { Compositor.minimizeFocused() }
        function restore(): void { Compositor.restoreLast() }
        function compositor(): string { return Compositor.name }
    }
}
