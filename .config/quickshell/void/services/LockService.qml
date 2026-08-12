pragma Singleton

import Quickshell
import Quickshell.Services.Pam
import QtQuick
import "../core"

QtObject {
    id: root

    property bool locked: false
    property bool unlocking: false
    property string pendingResponse: ""
    property string message: ""
    property bool messageIsError: false
    readonly property bool authenticating: pam.active

    signal authenticationFailed()

    function lock() {
        if (locked)
            return
        ShellState.closePanels()
        pendingResponse = ""
        message = ""
        messageIsError = false
        unlocking = false
        locked = true
    }

    function authenticate(password) {
        const response = String(password || "")
        if (!locked || response.length === 0 || pam.active)
            return false
        pendingResponse = response
        message = "Checking password…"
        messageIsError = false
        if (!pam.start()) {
            pendingResponse = ""
            message = "Authentication could not be started"
            messageIsError = true
            authenticationFailed()
            return false
        }
        return true
    }

    function cancelAuthentication() {
        if (pam.active)
            pam.abort()
        pendingResponse = ""
    }

    property var pam: PamContext {
        config: "login"

        onPamMessage: {
            if (responseRequired) {
                respond(root.pendingResponse)
            } else if (message.length > 0) {
                root.message = message
                root.messageIsError = messageIsError
            }
        }

        onCompleted: result => {
            root.pendingResponse = ""
            if (result === PamResult.Success) {
                root.message = I18n.tr("lock.unlocking")
                root.messageIsError = false
                root.unlocking = true
                unlockDelay.restart()
            } else {
                root.message = result === PamResult.MaxTries
                    ? "Too many attempts. Try again in a moment."
                    : "Incorrect password"
                root.messageIsError = true
                root.authenticationFailed()
            }
        }

        onError: error => {
            root.message = "Authentication service error"
            root.messageIsError = true
        }
    }

    property Timer unlockDelay: Timer {
        interval: Appearance.reduceMotion ? 1 : Motion.pageExit + 70
        onTriggered: {
            root.unlocking = false
            root.message = ""
            root.locked = false
        }
    }
}
