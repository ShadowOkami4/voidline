pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.core

Singleton {
    id: root

    // All notifications still in the centre, newest first.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    // Ids currently shown as popups.
    property var popupIds: []
    readonly property var popups: list.filter(n => popupIds.includes(n.id))

    function dismissPopup(id) { popupIds = popupIds.filter(i => i !== id) }
    function clear() { for (const n of list) n.dismiss() }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true
            if (Config.doNotDisturb) return
            root.popupIds = root.popupIds.concat([n.id])
            const timeout = n.expireTimeout > 0 ? n.expireTimeout : 5000
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
