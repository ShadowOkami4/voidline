pragma Singleton

import Quickshell
import Quickshell.Services.Polkit
import QtQuick
import "../core"

QtObject {
    id: root

    property string screenName: ""
    readonly property bool registered: agent.isRegistered
    readonly property bool active: agent.isActive && agent.flow !== null
    readonly property var flow: agent.flow
    readonly property string actionId: flow ? flow.actionId : ""
    readonly property string message: flow ? flow.message : ""
    readonly property string iconName: flow ? flow.iconName : ""
    readonly property string inputPrompt: flow ? flow.inputPrompt : "Password"
    readonly property bool responseVisible: flow ? flow.responseVisible : false
    readonly property string supplementaryMessage: flow ? flow.supplementaryMessage : ""
    readonly property bool supplementaryIsError: flow ? flow.supplementaryIsError : false
    readonly property bool responseRequired: flow ? flow.isResponseRequired : false
    readonly property bool failed: flow ? flow.failed : false
    readonly property var identities: flow ? flow.identities : []

    function applicationLabel() {
        const id = actionId.toLowerCase()
        if (id.indexOf("packagekit") >= 0 || id.indexOf("pacman") >= 0)
            return I18n.tr("polkit.applications.updates")
        if (id.indexOf("systemd") >= 0 || id.indexOf("login1") >= 0)
            return I18n.tr("polkit.applications.system")
        if (id.indexOf("network") >= 0)
            return I18n.tr("polkit.applications.network")
        if (id.indexOf("udisks") >= 0)
            return I18n.tr("polkit.applications.storage")
        return I18n.tr("polkit.applications.service")
    }

    function explanation() {
        if (message.length > 0)
            return message
        if (actionId.length > 0)
            return I18n.tr("polkit.explanationAction", { action: actionId })
        return I18n.tr("polkit.explanation")
    }

    function selectIdentity(identity) {
        if (flow)
            flow.selectedIdentity = identity
    }

    function submit(value) {
        if (flow && flow.isResponseRequired)
            flow.submit(String(value || ""))
    }

    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest()
    }

    property var agent: PolkitAgent {
        path: "/org/voidline/Polkit"
        onIsActiveChanged: {
            if (isActive)
                root.screenName = ShellState.requestedScreenName()
        }
    }
}
