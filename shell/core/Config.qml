pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// User settings. Stored as plain JSON in ~/.config/voidline/config.json so they
// can be edited by hand, by the shell, or by voidlinectl. Unknown keys are kept.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/voidline"
    readonly property string path: dir + "/config.json"

    // "voidline" | "windows" | "macos"
    property alias style: data.style
    property alias dark: data.dark
    property alias accent: data.accent
    property alias wallpaper: data.wallpaper
    property alias wallpaperColors: data.wallpaperColors
    property alias clock24h: data.clock24h
    property alias reduceMotion: data.reduceMotion
    property alias doNotDisturb: data.doNotDisturb
    property alias pinnedApps: data.pinnedApps
    property alias workspaceCount: data.workspaceCount
    // Whole-shell size factor (0.5 - 1.5). Applied at start by start.sh.
    property alias uiScale: data.uiScale
    // Terminal used for apps that need one (launched as: <terminal> -e <command>).
    property alias terminal: data.terminal
    property bool loaded: false

    // Window-manager settings. `desktop` is shared by every compositor so the
    // look carries over when you switch; `hyprland` and `niri` hold extras.
    property alias desktop: data.desktop
    property alias hyprland: data.hyprland
    property alias niri: data.niri
    // Saved display modes, one "name|mode|scale" entry per output.
    property alias displays: data.displays

    // "default" is the bundled Orbit wallpaper, "" is none, "live:<id>" a live
    // wallpaper package, anything else an image path.
    readonly property string liveDir: wallpaperDir + "/live"
    readonly property string liveId: wallpaper.startsWith("live:") ? wallpaper.slice(5).replace(/[^A-Za-z0-9_-]/g, "") : ""
    property alias liveOptions: data.liveOptions
    property alias livePauseOnBattery: data.livePauseOnBattery
    property alias livePauseWhenCovered: data.livePauseWhenCovered
    property alias liveFps: data.liveFps

    // Saved option values of live wallpaper `id`, as { key: "value" }.
    function liveSaved(id) {
        const out = {}
        for (const e of liveOptions) {
            const m = e.match(/^([^.=]+)\.([^.=]+)=(.*)$/)
            if (m && m[1] === id) out[m[2]] = m[3]
        }
        return out
    }
    function setLiveOption(id, key, value) {
        const prefix = id + "." + key + "="
        liveOptions = liveOptions.filter(e => !e.startsWith(prefix)).concat([prefix + value])
    }

    readonly property string wallpaperDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/voidline/wallpapers"
    function aspectDir(screen) {
        return screen && screen.height > 0 && screen.width / screen.height < 1.69 ? "16x10" : "16x9"
    }
    // The file to show on `screen`: bundled wallpapers switch to the
    // composition made for that screen's aspect ratio.
    function wallpaperFor(screen) {
        const dir = wallpaperDir + "/" + aspectDir(screen) + "/"
        if (wallpaper === "default") return dir + "voidline-orbit.png"
        // Live wallpapers: the still preview stands in while loading and
        // provides the colours for the palette.
        if (liveId.length > 0) return liveDir + "/" + liveId + "/preview.png"
        const bundled = wallpaper.match(/\/voidline\/wallpapers\/16x(?:9|10)\/([^\/]+)$/)
        return bundled ? dir + bundled[1] : wallpaper
    }
    readonly property string wallpaperPath: wallpaperFor(Quickshell.screens[0] ?? null)

    readonly property var styles: ["voidline", "windows", "macos"]

    function cycleStyle() {
        style = styles[(styles.indexOf(style) + 1) % styles.length]
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loaded = true
        onAdapterUpdated: writeAdapter()
        // First run: the file does not exist yet, write the defaults.
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) { writeAdapter(); root.loaded = true } }

        JsonAdapter {
            id: data
            property string style: "voidline"
            property bool dark: true
            property string accent: "#8E6BFF"
            property string wallpaper: "default"
            property bool wallpaperColors: true
            property bool clock24h: true
            property bool reduceMotion: false
            property bool doNotDisturb: false
            property list<string> pinnedApps: []
            property int workspaceCount: 5
            property real uiScale: 0.75
            property string terminal: "kitty"

            property list<string> displays: []
            property list<string> liveOptions: []
            property bool livePauseOnBattery: true
            property bool livePauseWhenCovered: true
            property int liveFps: 30

            property JsonObject desktop: JsonObject {
                // false: Voidline writes nothing and your own config decides.
                property bool managed: true
                property int gaps: 10
                property int border: 2
                property int rounding: 14
                property bool themedBorders: true
                property bool animations: true
                property string kbLayout: ""
                property bool naturalScroll: true
                property bool tapToClick: true
                property bool focusFollowsMouse: true
                property real pointerSpeed: 0
            }
            property JsonObject hyprland: JsonObject {
                property string layout: "dwindle"
                property bool blur: true
                property bool shadows: true
                property bool dimInactive: false
                property bool vrr: true
            }
            property JsonObject niri: JsonObject {
                property bool hideTitleBars: true
                property string centerColumn: "never"
                property real columnWidth: 0.5
            }        }
    }
}
