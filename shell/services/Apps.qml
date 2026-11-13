pragma Singleton

import Quickshell
import QtQuick
import qs.core

Singleton {
    readonly property var all: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    function search(query) {
        const q = query.trim().toLowerCase()
        if (q.length === 0) return all
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
        return scored.sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name)).map(x => x.e)
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
        Quickshell.execDetached(["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "xdg-open", url])
    }

    // Started apps must not inherit the shell's own UI scale, and entries
    // marked Terminal=true need a terminal around them.
    function launch(entry) {
        let cmd = entry.command.slice()
        if (cmd.length === 0) { entry.execute(); return }
        if (entry.runInTerminal) cmd = [Config.terminal, "-e"].concat(cmd)
        const context = { command: ["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE"].concat(cmd) }
        if (entry.workingDirectory) context.workingDirectory = entry.workingDirectory
        Quickshell.execDetached(context)
    }
}
