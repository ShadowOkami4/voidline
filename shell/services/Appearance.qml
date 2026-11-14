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
            + d("voidline_container", t.surfaceContainerHigh) + d("voidline_container_high", t.surfaceContainerHighest)
            + d("voidline_selected", t.secondaryContainer) + d("voidline_on_selected", t.inkOnSecondaryContainer)
            + d("voidline_tonal", t.primaryContainer) + d("voidline_on_tonal", t.inkOnPrimaryContainer)
            + d("voidline_muted", t.inkMuted) + d("voidline_outline", t.outlineVariant)
            + shapes
    }

    // Shapes and details, the same for every colour scheme. The first part
    // applies to all GTK 4 apps, the second is written for Files (Nautilus)
    // and uses the names from its own stylesheet.
    readonly property string shapes: `
/* ---- every app ---------------------------------------------------------- */
window.csd { border-radius: 20px; }
headerbar { min-height: 52px; }
button, entry, spinbutton, dropdown > button, .linked > button { border-radius: 14px; }
button.circular, button.pill, button.image-button, headerbar button, menubutton > button,
entry.search, searchbar entry, .search-entry { border-radius: 9999px; }
button.suggested-action, button.destructive-action { border-radius: 9999px; font-weight: 700; }
popover > contents, menu, .menu { border-radius: 20px; padding: 6px; }
popover modelbutton, popover .model, menu menuitem { border-radius: 12px; min-height: 34px; }
.card, list.boxed-list, .boxed-list { border-radius: 20px; }
tooltip, tooltip.background { border-radius: 12px; background-color: @voidline_container_high; color: @window_fg_color; }
scrollbar slider { border-radius: 9999px; min-width: 6px; min-height: 6px; background-color: alpha(@accent_bg_color, 0.55); }
scrollbar slider:hover { background-color: @accent_bg_color; }
rubberband, .rubberband { border-radius: 10px; border: 1px solid @accent_bg_color; background-color: alpha(@accent_bg_color, 0.18); }
switch { border-radius: 9999px; }
switch:checked { background-color: @accent_bg_color; }
progressbar trough, progressbar progress, levelbar trough, levelbar block, scale trough, scale highlight { border-radius: 9999px; min-height: 8px; }
progressbar progress, levelbar block.filled, scale highlight { background-color: @accent_bg_color; }
tabbar tab, .tab-bar tab { border-radius: 14px; }
tabbar tab:selected { background-color: @voidline_selected; color: @voidline_on_selected; }
dialog.background, window.dialog, window.messagedialog { border-radius: 26px; }

/* sidebars: pill rows, the selected one filled */
.navigation-sidebar { padding: 6px; }
.navigation-sidebar row, .sidebar-row { border-radius: 9999px; min-height: 42px; margin: 1px 2px; }
.navigation-sidebar row:hover { background-color: alpha(@window_fg_color, 0.07); }
.navigation-sidebar row:selected { background-color: @voidline_selected; color: @voidline_on_selected; font-weight: 700; }

/* ---- Files (Nautilus) --------------------------------------------------- */
/* where you are: one pill, the current folder filled */
.nautilus-pathbar { background-color: @voidline_container; border-radius: 9999px; padding: 3px 5px; min-height: 38px; }
.nautilus-path-button { border-radius: 9999px; padding: 4px 12px; margin: 0 1px; font-weight: 600; color: @voidline_muted; }
.nautilus-path-button:hover { background-color: alpha(@window_fg_color, 0.08); color: @window_fg_color; }
.nautilus-path-button.current-dir, .nautilus-path-button.current-dir:not(:drop(active)) {
    background-color: @voidline_tonal; color: @voidline_on_tonal; font-weight: 800; }

/* icon view: roomy tiles with a soft selection */
.nautilus-grid-view gridview { padding: 14px; }
.nautilus-grid-view gridview > child { border-radius: 24px; padding: 8px 4px; margin: 3px; transition: background-color 140ms ease-out; }
.nautilus-grid-view gridview > child:hover { background-color: alpha(@window_fg_color, 0.06); }
.nautilus-grid-view gridview > child:selected { background-color: @voidline_selected; color: @voidline_on_selected; }
.nautilus-grid-view gridview > child:selected:hover { background-color: shade(@voidline_selected, 1.12); }
.nautilus-grid-view .nautilus-view-cell { border-radius: 20px; }
.nautilus-grid-view:drop(active), .nautilus-list-view .nautilus-view-cell:drop(active) {
    border-radius: 20px; box-shadow: inset 0 0 0 2px @accent_bg_color; background-color: alpha(@accent_bg_color, 0.12); }

/* list view */
.nautilus-list-view columnview > listview > row { border-radius: 16px; }
.nautilus-list-view columnview > listview > row:hover { background-color: alpha(@window_fg_color, 0.06); }
.nautilus-list-view columnview > listview > row:selected { background-color: @voidline_selected; color: @voidline_on_selected; }
.nautilus-list-view columnview > header > button { border-radius: 12px; font-weight: 700; color: @voidline_muted; }

/* pictures get soft corners, hidden files step back */
.nautilus-image.file-thumbnail { border-radius: 12px; }
.view .hidden-file { opacity: 0.5; }
button.star:hover, button.star.interacted.starred image { color: @accent_color; }

/* the little status bubble in the corner */
.floating-bar { background-color: @voidline_tonal; color: @voidline_on_tonal; border: none; border-radius: 9999px;
    padding: 6px 16px; margin: 12px; font-weight: 600; box-shadow: 0 4px 14px alpha(black, 0.3); }
.floating-bar:backdrop { background-color: @voidline_container; color: @voidline_muted; }
.floating-bar button { border-radius: 9999px; }

/* disk space in properties and the sidebar */
.disk-space-used { color: @accent_bg_color; }
.disk-space-free { color: @voidline_container_high; }
.batch-rename-preview { border-radius: 14px; }
.nautilus-network-view listview, placesview list { border-radius: 20px; }
`

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
