pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Transient UI state: which panel is open and on which screen.
Singleton {
    id: root

    // "" | "launcher" | "quick" | "calendar" | "clipboard" | "switcher" | "emoji" | "tray" | "snap" | "keys" | "workspace"
    property string panel: ""
    property var screen: null
    property bool settingsOpen: false
    readonly property string version: "0.4.0-dev"

    // Exclusive zone for windows that must cover the whole screen, bars and
    // all (wallpaper, lock, dialogs). The protocol wants exactly -1, but the
    // value is multiplied by the UI scale and cut off on its way out, so
    // ExclusionMode.Ignore turns into 0 at scales below 1. This survives it.
    readonly property int coverZone: -Math.ceil(1 / Math.max(0.5, parseFloat(Quickshell.env("QT_SCALE_FACTOR") || "1") || 1))

    // Session lock. Set through lock(); only a correct password clears it.
    property bool locked: false
    function lock() { panel = ""; locked = true }

    // A shell that goes down while locked (a crash, an update, a restart)
    // takes its lock screen with it. A marker in the session's private
    // folder remembers the lock, and the next shell locks again at once.
    readonly property string lockMark: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/voidline-locked"
    property bool lockKnown: false
    onLockedChanged: if (lockKnown) Quickshell.execDetached(locked ? ["touch", lockMark] : ["rm", "-f", lockMark])
    property Process lockCheck: Process {
        running: true
        command: ["test", "-e", root.lockMark]
        onExited: code => { if (code === 0) root.lock(); root.lockKnown = true; if (root.locked) Quickshell.execDetached(["touch", root.lockMark]) }
    }

    property string settingsPage: "style"
    // What the page for installing apps should search for when it opens.
    property string installQuery: ""
    function findApp(text) { installQuery = String(text).trim(); openSettings("install") }
    function openSettings(page) {
        if (page !== undefined) settingsPage = page
        panel = ""
        settingsOpen = true
    }

    function toggle(name, onScreen) {
        if (panel === name) { panel = ""; return }
        screen = onScreen || screen || Quickshell.screens[0]
        panel = name
    }
    function close() { panel = "" }

    // File the "Open with" dialog is asking about; empty = closed.
    property string openWithPath: ""
    function openWith(path) { openWithPath = String(path).replace(/^file:\/\//, "") }

    // An app asked to share the screen: { answer (file the choice goes to),
    // windows: [{ id, app, title }] }. Null when nobody is asking.
    property var shareRequest: null
    function sharePick(answer, list) {
        // Only ever a file of our own in the session's private folder.
        if (!/^\/[\w\/.-]*\/voidline-share-\d+$/.test(answer) || answer.includes("..")) return
        if (shareRequest) shareAnswer("")
        const windows = []
        for (const part of String(list).split("[HA>]")) {
            const m = part.match(/^(\d+)\[HC>\]([\s\S]*?)\[HT>\]([\s\S]*?)\[HE>\]/)
            if (m) windows.push({ id: m[1], app: m[2], title: m[3] })
        }
        panel = ""
        shareRequest = { answer: answer, windows: windows }
    }
    // text: "[SELECTION]/screen:eDP-1" and the like; "" = do not share.
    function shareAnswer(text) {
        if (!shareRequest) return
        const file = shareRequest.answer
        shareRequest = null
        // Choice and file name go in as data, never as part of the command.
        // "Do not share" leaves the file empty.
        Quickshell.execDetached(["sh", "-c", "[ -n \"$1\" ] && printf '%s\\n' \"$1\" > \"$2\" || : > \"$2\"", "sh", String(text).replace(/[\r\n]/g, ""), file])
    }

    // Tray icon whose menu is open.
    property var trayItem: null
    function openTray(item, onScreen) {
        if (panel === "tray" && trayItem === item) { panel = ""; return }
        trayItem = item
        screen = onScreen || screen || Quickshell.screens[0]
        panel = "tray"
    }

    // Workspace whose menu is open (an entry of Compositor.workspaces).
    property var workspaceTarget: null
    function openWorkspace(ws, onScreen) {
        if (!ws) return
        if (panel === "workspace" && workspaceTarget && workspaceTarget.id === ws.id) { panel = ""; return }
        workspaceTarget = ws
        screen = onScreen || screen || Quickshell.screens[0]
        panel = "workspace"
    }

    // Window switcher: the first call opens it, further calls move on.
    signal switcherStep()
    function switcher() {
        if (panel === "switcher") switcherStep()
        else { screen = screen || Quickshell.screens[0]; panel = "switcher" }
    }
}
