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
    // Popups: seconds on screen, how many at once, urgent ones stay until dismissed.
    property alias notifTimeout: data.notifTimeout
    property alias notifMaxPopups: data.notifMaxPopups
    property alias notifKeepUrgent: data.notifKeepUrgent
    property alias clockSeconds: data.clockSeconds
    // Changed shortcuts, one "action=SUPER+SHIFT+N" entry each ("action=" is off).
    property alias keybinds: data.keybinds
    property alias pinnedApps: data.pinnedApps
    property alias workspaceCount: data.workspaceCount
    // Close / minimise / fill buttons for the active window, in the bar.
    property alias windowButtons: data.windowButtons
    // Whole-shell size factor (0.5 - 1.5). Applied at start by start.sh.
    property alias uiScale: data.uiScale
    // Terminal used for apps that need one (launched as: <terminal> -e <command>).
    property alias terminal: data.terminal
    property bool loaded: false

    // Minutes of inactivity before each step; 0 switches the step off.
    property alias lockAfter: data.lockAfter
    property alias screenOffAfter: data.screenOffAfter
    property alias sleepAfter: data.sleepAfter
    property alias lockOnSleep: data.lockOnSleep
    property alias nightLight: data.nightLight
    property alias nightLightTemp: data.nightLightTemp
    // Keep GTK/libadwaita apps in step with the shell's dark or light theme.
    property alias syncAppTheme: data.syncAppTheme
    // Give GTK apps (the file manager, settings dialogs, ...) Voidline's colours.
    property alias appColors: data.appColors
    // Do not disturb switches itself off at this time (ms since 1970); 0 = stays on.
    property alias dndUntil: data.dndUntil
    // By the clock: night light in the evening, do not disturb at night.
    property alias nightLightAuto: data.nightLightAuto
    property alias nightLightFrom: data.nightLightFrom
    property alias nightLightTo: data.nightLightTo
    property alias dndAuto: data.dndAuto
    property alias dndFrom: data.dndFrom
    property alias dndTo: data.dndTo
    // Apps whose notifications never pop up (they still land in the list).
    property alias notifMuted: data.notifMuted
    property alias desktopIcons: data.desktopIcons
    property alias batteryWarnings: data.batteryWarnings
    // Stronger text and outlines.
    property alias highContrast: data.highContrast
    // On-screen keyboard on show, and the screen reader (Orca) running.
    property alias onScreenKeyboard: data.onScreenKeyboard
    property alias screenReader: data.screenReader
    // Tablet mode: a keyboard button in the bar and swiping between
    // workspaces on a touch screen.
    property alias tabletMode: data.tabletMode
    // Open a screenshot in the editor (swappy) before saving, when installed.
    property alias screenshotEdit: data.screenshotEdit
    // Town for the weather in the calendar; empty = no weather, nothing is requested.
    property alias weatherPlace: data.weatherPlace
    // Where the launcher's "search the web" goes; %s stands for the words.
    property alias webSearch: data.webSearch
    // iCal addresses of calendars shown next to your own events.
    property alias calendars: data.calendars
    // Alarms, "HH:MM|repeat|on", and clocks for other places (time zones).
    property alias alarms: data.alarms
    property alias worldClocks: data.worldClocks
    // A notification ten minutes before an event with a time.
    property alias eventReminders: data.eventReminders
    // Language of the shell: "" follows the system, otherwise "en", "de", ...
    property alias language: data.language
    // A different picture on single screens, one "screen name=path" entry each.
    property alias screenWallpapers: data.screenWallpapers
    function screenWallpaper(name) {
        const e = screenWallpapers.find(x => x.startsWith(name + "="))
        return e ? e.slice(name.length + 1) : ""
    }
    function setScreenWallpaper(name, path) {
        const rest = screenWallpapers.filter(x => !x.startsWith(name + "="))
        screenWallpapers = path.length > 0 ? rest.concat([name + "=" + path]) : rest
    }
    // Names for workspaces, one "number=name" entry each.
    property alias workspaceNames: data.workspaceNames
    function workspaceName(index) {
        const e = workspaceNames.find(x => x.startsWith(index + "="))
        return e ? e.slice(String(index).length + 1) : ""
    }
    function setWorkspaceName(index, name) {
        const rest = workspaceNames.filter(x => !x.startsWith(index + "="))
        const clean = String(name).trim().slice(0, 24)
        workspaceNames = clean.length > 0 ? rest.concat([index + "=" + clean]) : rest
    }
    // Make plugged-in drives ready and offer to open them.
    property alias automount: data.automount
    // A notification when updates are waiting.
    property alias updateNotify: data.updateNotify
    // Also search the AUR (packages made by other Arch users, not checked).
    property alias aurSearch: data.aurSearch
    // The day the last update notice was shown, so restarts do not repeat it.
    property alias updateToldOn: data.updateToldOn
    // The VPN the quick settings tile switched on last.
    property alias vpnLast: data.vpnLast
    property alias welcomed: data.welcomed
    // Light during the day (7:00 to 19:00), dark at night.
    property alias autoTheme: data.autoTheme
    // Font for the shell; "" picks the best one installed.
    property alias font: data.font
    // Game mode: effects off, live wallpaper paused, no popups.
    property alias gameMode: data.gameMode
    // Where extra screens sit, one "name=left|right|up|down|mirror" entry each.
    property alias displayPlaces: data.displayPlaces

    // Window-manager settings. `desktop` is shared by every compositor so the
    // look carries over when you switch; `hyprland` and `niri` hold extras.
    property alias desktop: data.desktop
    property alias hyprland: data.hyprland
    property alias niri: data.niri
    // Saved display modes, one "name|mode|scale" entry per output.
    property alias displays: data.displays
    // The display setup of every set of screens seen so far, one JSON entry
    // each: { key, places, displays }. Kept up to date by WmConfig.
    property alias displayProfiles: data.displayProfiles

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
        // A picture chosen for this screen alone wins.
        const own = screen ? screenWallpaper(screen.name) : ""
        if (own.length > 0) {
            const mine = own.match(/\/voidline\/wallpapers\/16x(?:9|10)\/([^\/]+)$/)
            return mine ? dir + mine[1] : own
        }
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
            property int notifTimeout: 5
            property int notifMaxPopups: 3
            property bool notifKeepUrgent: true
            property bool clockSeconds: false
            property list<string> keybinds: []
            property int lockAfter: 10
            property int screenOffAfter: 15
            property int sleepAfter: 0
            property bool lockOnSleep: true
            property bool nightLight: false
            property int nightLightTemp: 4000
            property bool syncAppTheme: true
            property bool appColors: true
            property real dndUntil: 0
            property bool nightLightAuto: false
            property string nightLightFrom: "20:00"
            property string nightLightTo: "07:00"
            property bool dndAuto: false
            property string dndFrom: "22:00"
            property string dndTo: "07:00"
            property list<string> notifMuted: []
            property bool desktopIcons: true
            property bool batteryWarnings: true
            property bool highContrast: false
            property bool onScreenKeyboard: false
            property bool screenReader: false
            property bool tabletMode: false
            property bool screenshotEdit: false
            property string weatherPlace: ""
            property string webSearch: "https://duckduckgo.com/?q=%s"
            property list<string> calendars: []
            property list<string> alarms: []
            property list<string> worldClocks: []
            property bool eventReminders: true
            property string language: ""
            property list<string> screenWallpapers: []
            property bool automount: true
            property bool updateNotify: true
            property bool aurSearch: false
            property string updateToldOn: ""
            property string vpnLast: ""
            property bool welcomed: false
            property bool autoTheme: false
            property string font: ""
            property bool gameMode: false
            property list<string> displayPlaces: []
            property list<string> pinnedApps: []
            property int workspaceCount: 5
            property list<string> workspaceNames: []
            property bool windowButtons: true
            property real uiScale: 0.75
            property string terminal: "kitty"

            property list<string> displays: []
            property list<string> displayProfiles: []
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
                // Touchpad gestures: fingers used, and what each swipe does
                // ("" = nothing; see Keybinds.gestureActions).
                property int gestureFingers: 3
                property bool gestureWorkspaces: true
                property string gestureUp: "switcher"
                property string gestureDown: "minimize"
            }
            property JsonObject niri: JsonObject {
                property bool hideTitleBars: true
                property string centerColumn: "never"
                property real columnWidth: 0.5
            }
        }
    }
}
