pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../core"

QtObject {
    id: root

    readonly property bool doNotDisturb: Appearance.doNotDisturb
    readonly property var notifications: server.trackedNotifications.values
    readonly property int count: notifications.length
    property var popupNotification: null
    property var popupQueue: []
    property bool popupVisible: false
    property string popupScreenName: ""

    property var server: NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true
            if (!notification.lastGeneration)
                root.enqueuePopup(notification)
        }
    }

    function setDoNotDisturb(enabled) {
        Appearance.setDoNotDisturb(enabled)
        if (enabled)
            closePopup()
    }

    function enqueuePopup(notification) {
        if (!notification || doNotDisturb || !Appearance.notificationPopups)
            return
        popupQueue = popupQueue.concat([notification])
        if (!popupVisible && popupNotification === null)
            showNextPopup()
    }

    function showNextPopup() {
        if (doNotDisturb || !Appearance.notificationPopups || popupQueue.length === 0) {
            popupNotification = null
            popupVisible = false
            return
        }
        const queue = popupQueue.slice()
        popupNotification = queue.shift()
        popupQueue = queue
        popupScreenName = ShellState.requestedScreenName()
        popupVisible = true
        popupTimer.interval = popupNotification && popupNotification.expireTimeout > 0
            ? Math.max(3000, Math.min(12000, popupNotification.expireTimeout))
            : 6000
        popupTimer.restart()
    }

    function closePopup() {
        popupTimer.stop()
        popupVisible = false
        popupAdvance.restart()
    }

    function dismissPopup() {
        const notification = popupNotification
        closePopup()
        if (notification && notification.tracked)
            notification.dismiss()
    }

    function invokePopupAction(action) {
        if (action)
            action.invoke()
        closePopup()
    }

    function dismiss(notification) {
        if (notification && notification.tracked)
            notification.dismiss()
    }

    function clearAll() {
        const items = notifications.slice()
        for (let i = items.length - 1; i >= 0; --i)
            items[i].dismiss()
    }

    property var popupTimer: Timer {
        interval: 6000
        onTriggered: root.closePopup()
    }

    property var popupAdvance: Timer {
        interval: Motion.exit + 30
        onTriggered: {
            root.popupNotification = null
            root.showNextPopup()
        }
    }

    property var popupWatcher: Connections {
        target: root.popupNotification
        ignoreUnknownSignals: true
        function onClosed(reason) {
            root.popupNotification = null
            root.popupVisible = false
            popupTimer.stop()
            popupAdvance.restart()
        }
    }
}
