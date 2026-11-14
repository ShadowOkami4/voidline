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

    function dismissPopup(id) { popupIds = popupIds.filter(i => i !== id) }
    function clear() { for (const n of list) n.dismiss(); store.entries = [] }

    // Earlier notifications, kept across restarts (the newest 40), as
    // { key, app, title, text, time }. `earlier` leaves out the ones still
    // shown above as live notifications.
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/voidline/notifications.json"
    property var liveKeys: ({})
    readonly property var history: store.entries.map(e => { try { return JSON.parse(e) } catch (x) { return null } }).filter(e => !!e)
    readonly property var earlier: {
        const live = list.map(n => liveKeys[n.id]).filter(k => !!k)
        return history.filter(e => !live.includes(e.key)).reverse()
    }
    function remember(n) {
        const key = n.id + "-" + Date.now()
        liveKeys[n.id] = key
        liveKeysChanged()
        const entry = JSON.stringify({ key: key, app: n.appName || "", title: n.summary || "", text: (n.body || "").slice(0, 300), time: Date.now() })
        store.entries = store.entries.concat([entry]).slice(-40)
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
        onNotification: n => {
            n.tracked = true
            root.remember(n)
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
