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
        onAdapterUpdated: writeAdapter()
        // First run: the file does not exist yet, write the defaults.
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }

        JsonAdapter {
            id: data
            property string style: "voidline"
            property bool dark: true
            property string accent: "#8E6BFF"
            property string wallpaper: ""
            property bool wallpaperColors: true
            property bool clock24h: true
            property bool reduceMotion: false
            property bool doNotDisturb: false
            property list<string> pinnedApps: []
            property int workspaceCount: 5
        }
    }
}
