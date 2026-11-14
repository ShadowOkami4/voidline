pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// How other apps look: dark or light, icon theme, mouse pointer. These are the
// desktop-wide settings GTK, libadwaita, Qt and Electron apps read (gsettings),
// plus night light.
Singleton {
    id: root

    property bool available: false          // gsettings present
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property var iconThemes: []
    property var cursorThemes: []
    property string nightTool: ""           // "hyprsunset" | "gammastep" | ""

    function gset(key, value) {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", key, String(value)])
    }
    function setIconTheme(name) { iconTheme = name; gset("icon-theme", name) }
    function setCursor(name, size) {
        cursorTheme = name
        cursorSize = size
        gset("cursor-theme", name)
        gset("cursor-size", size)
        // Hyprland applies a new pointer at once; others pick it up for new windows.
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            Quickshell.execDetached(["hyprctl", "setcursor", name, String(size)])
    }

    // Dark / light follows the shell.
    readonly property bool wantDark: Config.dark
    function applyScheme() {
        if (available && Config.loaded && Config.syncAppTheme) gset("color-scheme", Config.dark ? "prefer-dark" : "prefer-light")
    }
    onWantDarkChanged: applyScheme()
    onAvailableChanged: applyScheme()
    Connections {
        target: Config
        function onLoadedChanged() { root.applyScheme() }
        function onSyncAppThemeChanged() { root.applyScheme() }
    }

    Process {
        running: true
        command: ["sh", "-c", `
command -v gsettings >/dev/null || exit 0
echo "ok=1"
g() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
echo "icon=$(g icon-theme)"; echo "cursor=$(g cursor-theme)"; echo "size=$(g cursor-size)"
for d in /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do
    for t in "$d"/*/; do
        [ -d "$t" ] || continue
        n=$(basename "$t")
        [ -d "$t/cursors" ] && echo "c=$n"
        [ -f "$t/index.theme" ] && grep -q '^Directories=' "$t/index.theme" && [ "$n" != hicolor ] && [ "$n" != default ] && [ "$n" != locolor ] && echo "i=$n"
    done
done
command -v hyprsunset >/dev/null && echo "night=hyprsunset"
command -v gammastep >/dev/null && echo "night=gammastep"
exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                const icons = [], cursors = []
                let night = ""
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i < 0) continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "ok") root.available = true
                    else if (k === "icon") root.iconTheme = v
                    else if (k === "cursor") root.cursorTheme = v
                    else if (k === "size") root.cursorSize = parseInt(v) || 24
                    else if (k === "i" && !icons.includes(v)) icons.push(v)
                    else if (k === "c" && !cursors.includes(v)) cursors.push(v)
                    else if (k === "night" && (night === "" || (v === "hyprsunset" && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")))) night = v
                }
                // Hyprland forgets the pointer between sessions; set it again.
                if (root.cursorTheme.length > 0 && root.cursorTheme !== "default" && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
                    Quickshell.execDetached(["hyprctl", "setcursor", root.cursorTheme, String(root.cursorSize)])
                root.iconThemes = icons.sort()
                root.cursorThemes = cursors.sort()
                root.nightTool = night
            }
        }
    }

    // ---- colours for GTK apps -----------------------------------------------------------
    // GTK 4 / libadwaita apps (Files, and most GNOME apps) read named colours
    // from ~/.config/gtk-4.0/gtk.css. Voidline writes its palette to a file of
    // its own (voidline.css) and adds one @import line to gtk.css, so anything
    // already in there stays. Apps pick the colours up when they are started.
    function hex(c) { return String(c).substring(0, 7) }
    readonly property string gtkCss: {
        const t = Theme
        const d = (name, colour) => `@define-color ${name} ${hex(colour)};\n`
        return "/* Written by Voidline (Settings > Apps & startup). Changes are overwritten. */\n"
            + d("accent_color", t.primary) + d("accent_bg_color", t.primary) + d("accent_fg_color", t.inkOnPrimary)
            + d("destructive_color", t.error) + d("destructive_bg_color", t.error) + d("destructive_fg_color", t.surface)
            + d("window_bg_color", t.surface) + d("window_fg_color", t.ink)
            + d("view_bg_color", t.surfaceContainerLow) + d("view_fg_color", t.ink)
            + d("headerbar_bg_color", t.surface) + d("headerbar_fg_color", t.ink)
            + d("headerbar_backdrop_color", t.surface) + d("headerbar_shade_color", t.surface)
            + d("sidebar_bg_color", t.surface) + d("sidebar_fg_color", t.ink)
            + d("sidebar_backdrop_color", t.surface) + d("sidebar_shade_color", t.surface)
            + d("secondary_sidebar_bg_color", t.surfaceContainerLow) + d("secondary_sidebar_fg_color", t.ink)
            + d("secondary_sidebar_backdrop_color", t.surfaceContainerLow)
            + d("card_bg_color", t.surfaceContainerHigh) + d("card_fg_color", t.ink)
            + d("dialog_bg_color", t.surfaceContainerHigh) + d("dialog_fg_color", t.ink)
            + d("popover_bg_color", t.surfaceContainerHigh) + d("popover_fg_color", t.ink)
            + d("thumbnail_bg_color", t.surfaceContainerHigh) + d("thumbnail_fg_color", t.ink)
            // GTK 3 names, for older apps
            + d("theme_selected_bg_color", t.primary) + d("theme_selected_fg_color", t.inkOnPrimary)
            // The rounder shapes of the shell, kept to a few safe places.
            + ".navigation-sidebar row, .sidebar-row, listview row, columnview row { border-radius: 14px; }\n"
            + ".navigation-sidebar row:selected { background-color: alpha(@accent_bg_color, 0.26); }\n"
            + "gridview child { border-radius: 16px; }\n"
            + "button, entry, .linked > button { border-radius: 14px; }\n"
            + "button.circular, button.pill, entry.search, searchbar entry { border-radius: 9999px; }\n"
            + "popover > contents, .card, menu, .menu { border-radius: 18px; }\n"
            + "window.csd { border-radius: 18px; }\n"
    }
    readonly property bool gtkWanted: Config.loaded && Config.appColors
    onGtkCssChanged: gtkWrite.restart()
    onGtkWantedChanged: gtkWrite.restart()
    Timer {
        id: gtkWrite
        interval: 600
        onTriggered: {
            if (!Config.loaded) return
            const script = `
line='@import "voidline.css";'
for v in gtk-4.0 gtk-3.0; do
    dir="\${XDG_CONFIG_HOME:-$HOME/.config}/$v"
    if [ "$1" = on ]; then
        mkdir -p "$dir"
        printf '%s' "$2" > "$dir/voidline.css"
        [ -f "$dir/gtk.css" ] || : > "$dir/gtk.css"
        grep -qxF "$line" "$dir/gtk.css" || { printf '%s\n' "$line"; cat "$dir/gtk.css"; } > "$dir/gtk.css.voidline-new" && [ -f "$dir/gtk.css.voidline-new" ] && mv "$dir/gtk.css.voidline-new" "$dir/gtk.css"
    elif [ -f "$dir/gtk.css" ]; then
        grep -vxF "$line" "$dir/gtk.css" > "$dir/gtk.css.voidline-new"; mv "$dir/gtk.css.voidline-new" "$dir/gtk.css"
        rm -f "$dir/voidline.css"
    fi
done`
            Quickshell.execDetached(["sh", "-c", script, "sh", root.gtkWanted ? "on" : "off", root.gtkCss])
        }
    }

    // Light by day, dark at night.
    function followClock() {
        if (!Config.loaded || !Config.autoTheme) return
        const h = new Date().getHours()
        const dark = !(h >= 7 && h < 19)
        if (Config.dark !== dark) Config.dark = dark
    }
    Timer { interval: 60000; running: Config.autoTheme; repeat: true; triggeredOnStart: true; onTriggered: root.followClock() }

    // Night light: a warmer screen. The tool runs only while it is on.
    readonly property bool nightAvailable: nightTool.length > 0
    readonly property int nightTemp: Math.max(2500, Math.min(6000, Config.nightLightTemp))
    Process {
        id: night
        command: root.nightTool === "hyprsunset" ? ["hyprsunset", "-t", String(root.nightTemp)]
            : ["gammastep", "-O", String(root.nightTemp)]
        running: root.nightAvailable && Config.loaded && Config.nightLight
        onCommandChanged: if (running) { running = false; again.restart() }
    }
    Timer { id: again; interval: 300; onTriggered: night.running = Qt.binding(() => root.nightAvailable && Config.loaded && Config.nightLight) }
}
