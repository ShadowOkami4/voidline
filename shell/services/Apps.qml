pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // ---- what you use most comes first ---------------------------------------------
    // How often each app was started from the launcher, and the ones pinned
    // to the front (right click in the launcher). Kept in a small state file.
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/voidline/apps.json"
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", statePath.replace(/\/[^\/]*$/, "")])
    FileView {
        path: root.statePath
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: store
            property list<string> counts: []      // "firefox=12"
            property list<string> pinned: []
        }
    }
    readonly property var pinned: store.pinned
    readonly property var counts: {
        const out = {}
        for (const e of store.counts) { const i = e.lastIndexOf("="); if (i > 0) out[e.slice(0, i)] = Number(e.slice(i + 1)) || 0 }
        return out
    }
    function isPinned(entry) { return !!entry && pinned.includes(entry.id) }
    function togglePin(entry) {
        if (!entry) return
        store.pinned = isPinned(entry) ? store.pinned.filter(p => p !== entry.id) : store.pinned.concat([entry.id])
    }
    function used(entry) {
        if (!entry) return
        const n = (counts[entry.id] || 0) + 1
        // The 200 most used are plenty.
        store.counts = store.counts.filter(e => !e.startsWith(entry.id + "=")).concat([entry.id + "=" + n])
            .sort((a, b) => Number(b.slice(b.lastIndexOf("=") + 1)) - Number(a.slice(a.lastIndexOf("=") + 1))).slice(0, 200)
    }
    // Pinned apps, then by how often they were started, then by name.
    readonly property var ranked: {
        const c = counts, pins = pinned
        const place = e => { const i = pins.indexOf(e.id); return i < 0 ? 9999 : i }
        return all.slice().sort((a, b) => place(a) - place(b) || (c[b.id] || 0) - (c[a.id] || 0) || a.name.localeCompare(b.name))
    }

    function search(query) {
        const q = query.trim().toLowerCase()
        if (q.length === 0) return ranked
        const c = counts
        const scored = []
        for (const e of all) {
            const name = e.name.toLowerCase()
            let score = -1
            if (name.startsWith(q)) score = 0
            else if (name.includes(q)) score = 1
            else if ((e.genericName || "").toLowerCase().includes(q)) score = 2
            else if ((e.keywords || []).some(k => k.toLowerCase().includes(q))) score = 3
            if (score >= 0) scored.push({ e: e, s: score })
        }
        return scored.sort((a, b) => a.s - b.s || (c[b.e.id] || 0) - (c[a.e.id] || 0) || a.e.name.localeCompare(b.e.name)).map(x => x.e)
    }

    // Desktop entry for a window's app id (used for taskbar/dock icons).
    function forAppId(appId) {
        if (!appId) return null
        const id = appId.toLowerCase()
        return all.find(e => e.id.toLowerCase() === id)
            ?? all.find(e => (e.startupClass || "").toLowerCase() === id)
            ?? all.find(e => e.id.toLowerCase().endsWith("." + id))
            ?? all.find(e => e.name.toLowerCase() === id)
            ?? null
    }

    function iconNameFor(appId) {
        const entry = forAppId(appId)
        return entry && entry.icon ? entry.icon : (appId || "")
    }

    function openUrl(url) {
        Quickshell.execDetached(["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", "xdg-open", url])
    }

    // Started apps must not inherit the shell's own UI scale, and entries
    // marked Terminal=true need a terminal around them.
    function launch(entry) {
        let cmd = entry.command.slice()
        if (cmd.length === 0) { entry.execute(); return }
        if (entry.runInTerminal) cmd = [Config.terminal, "-e"].concat(cmd)
        const context = { command: ["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF"].concat(cmd) }
        if (entry.workingDirectory) context.workingDirectory = entry.workingDirectory
        Quickshell.execDetached(context)
    }
}
