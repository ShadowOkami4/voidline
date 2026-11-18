pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import qs.core

Singleton {
    id: root

    // All notifications still in the centre, newest first.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    // Ids currently shown as popups.
    property var popupIds: []
    readonly property var popups: list.filter(n => popupIds.includes(n.id)).slice(0, Math.max(1, Config.notifMaxPopups))

    // Do not disturb with an end time switches itself off.
    Timer {
        interval: 20000
        running: Config.doNotDisturb && Config.dndUntil > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= Config.dndUntil) { Config.doNotDisturb = false; Config.dndUntil = 0 }
    }
    // hours > 0: for that long; hours === -1: until 7:00 tomorrow; 0: until switched off
    function quiet(hours) {
        if (hours === 0) Config.dndUntil = 0
        else if (hours > 0) Config.dndUntil = Date.now() + hours * 3600000
        else {
            const t = new Date()
            t.setDate(t.getDate() + 1)
            t.setHours(7, 0, 0, 0)
            Config.dndUntil = t.getTime()
        }
        Config.doNotDisturb = true
    }
    // Apps seen so far, for the per-app switches in Settings.
    readonly property var apps: {
        const names = []
        for (const e of history) if (e.app && !names.includes(e.app)) names.push(e.app)
        for (const m of Config.notifMuted) if (!names.includes(m)) names.push(m)
        return names.sort((a, b) => a.localeCompare(b))
    }
    function setMuted(app, muted) {
        const rest = Config.notifMuted.filter(a => a !== app)
        Config.notifMuted = muted ? rest.concat([app]) : rest
    }

    // Popups being answered do not run out.
    property var held: []
    function hold(id, on) {
        held = on ? held.concat([id]) : held.filter(i => i !== id)
        if (!on && expiredWhileHeld.includes(id)) { expiredWhileHeld = expiredWhileHeld.filter(i => i !== id); dismissPopup(id) }
    }
    property var expiredWhileHeld: []
    function dismissPopup(id) {
        if (held.includes(id)) { if (!expiredWhileHeld.includes(id)) expiredWhileHeld = expiredWhileHeld.concat([id]); return }
        popupIds = popupIds.filter(i => i !== id)
    }
    // The icon's name, as the card shows it: given as appIcon or wrapped in the image.
    function iconOf(n) {
        const img = String(n.image || "")
        return n.appIcon || (img.startsWith("image://icon/") ? decodeURIComponent(img.slice(13)) : "")
    }
    function clear() { for (const n of list) n.dismiss(); store.entries = [] }

    // Earlier notifications, kept across restarts (the newest 40), as
    // { key, app, title, text, time }. `earlier` leaves out the ones still
    // shown above as live notifications.
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/voidline/notifications.json"
    property var liveKeys: ({})
    readonly property var history: store.entries.map(e => { try { return JSON.parse(e) } catch (x) { return null } }).filter(e => !!e)
    function same(a, b) { return a.app === b.app && a.title === b.title && a.text === b.text && (a.icon || "") === (b.icon || "") }
    readonly property var earlier: {
        const live = list.map(n => liveKeys[n.id]).filter(k => !!k)
        // Entries saved twice by older versions show once.
        const out = []
        for (const e of history) {
            if (live.includes(e.key)) continue
            const last = out[out.length - 1]
            if (last && same(last, e) && Math.abs(e.time - last.time) < 5000) continue
            out.push(e)
        }
        return out.reverse()
    }
    // Writes the notification into the history, once. The server hands the
    // same notification over again when the shell reloads, and apps update
    // one in place (a download's progress); neither is a new entry.
    function remember(n, again) {
        const now = { app: n.appName || "", title: n.summary || "", text: (n.body || "").slice(0, 300), icon: iconOf(n).slice(0, 200) }
        const entries = store.entries.slice()
        let at = -1
        const known = liveKeys[n.id]
        for (let i = entries.length - 1; i >= 0 && at < 0; --i) {
            let e = null
            try { e = JSON.parse(entries[i]) } catch (x) { continue }
            if (known ? e.key === known
                : (again ? e.key.startsWith(n.id + "-") && same(e, now) : same(e, now) && Date.now() - e.time < 3000)) at = i
        }
        if (at >= 0) {
            const old = JSON.parse(entries[at])
            liveKeys[n.id] = old.key
            liveKeysChanged()
            if (same(old, now)) return
            entries[at] = JSON.stringify(Object.assign(old, now))
            store.entries = entries
            return
        }
        const key = n.id + "-" + Date.now()
        liveKeys[n.id] = key
        liveKeysChanged()
        now.key = key
        now.time = Date.now()
        store.entries = entries.concat([JSON.stringify(now)]).slice(-40)
    }
    function forget(key) { store.entries = store.entries.filter(e => !e.includes('"key":"' + key + '"')) }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", statePath.replace(/\/[^\/]*$/, "")])
    FileView {
        path: root.statePath
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: store
            property list<string> entries: []
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true
        onNotification: n => {
            n.tracked = true
            // Carried over from before a reload: already saved, already shown.
            const again = n.lastGeneration === true
            root.remember(n, again)
            if (again) return
            if (Config.doNotDisturb || Config.gameMode) return
            if (Config.notifMuted.includes(n.appName || "")) return
            root.popupIds = root.popupIds.concat([n.id])
            if (Config.notifKeepUrgent && n.urgency === NotificationUrgency.Critical) return
            const timeout = n.expireTimeout > 0 ? n.expireTimeout : Math.max(1, Config.notifTimeout) * 1000
            expire.createObject(root, { nid: n.id, interval: timeout })
        }
    }

    Component {
        id: expire
        Timer {
            property int nid
            running: true
            onTriggered: { root.dismissPopup(nid); destroy() }
        }
    }
}
