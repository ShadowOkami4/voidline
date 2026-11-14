import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// The lock screen. Uses the compositor's session-lock protocol, so nothing
// underneath is shown or takes input while locked, and the system's own
// password check (PAM, the "login" rules) to unlock. The password is handed
// to PAM and forgotten; the shell never stores or compares it.
Scope {
    id: root

    property string pending: ""
    property string note: ""
    property bool wrong: false
    readonly property bool busy: pam.active

    function submit(text) {
        if (busy || text.length === 0) return
        pending = text
        wrong = false
        note = ""
        if (!pam.start()) { pending = ""; note = "The password check could not be started." ; wrong = true }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired) { respond(root.pending); root.pending = "" }
            else if (message.length > 0) root.note = message
        }
        onCompleted: result => {
            root.pending = ""
            if (result === PamResult.Success) { root.note = ""; Shell.locked = false }
            else {
                root.wrong = true
                root.note = result === PamResult.MaxTries ? "Too many attempts. Wait a moment and try again." : "Wrong password"
            }
        }
        onError: error => { root.pending = ""; root.wrong = true; root.note = "The password check failed (" + PamError.toString(error) + ")." }
    }

    WlSessionLock {
        id: lock
        locked: Shell.locked

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            SystemClock { id: clock; precision: SystemClock.Minutes }

            Image {
                anchors.fill: parent
                source: Config.wallpaper.length > 0 ? "file://" + Config.wallpaperFor(surface.screen) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
            }
            Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.surface, 0.72) }

            // Clicking anywhere brings the keyboard back to the password field.
            MouseArea { anchors.fill: parent; onClicked: secret.forceActiveFocus() }

            ColumnLayout {
                anchors.centerIn: parent
                width: 420
                spacing: 0

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, Config.clock24h ? "HH:mm" : "h:mm")
                    font.pixelSize: 150
                    font.weight: Font.Black
                    font.letterSpacing: -6
                    color: Theme.ink
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -10
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: Theme.primary
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 56
                    implicitWidth: 76
                    implicitHeight: 76
                    Blob {
                        anchors.fill: parent
                        lobes: 8
                        fill: root.wrong ? Theme.errorContainer : Theme.primaryContainer
                        rotation: root.busy ? 45 : 0
                        Behavior on rotation { Spring { duration: Motion.spatialSlow; easing.bezierCurve: Motion.spatialSlowCurve } }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        icon: root.busy ? "hourglass_top" : "lock"
                        filled: true
                        size: 34
                        color: root.wrong ? Theme.inkOnErrorContainer : Theme.inkOnPrimaryContainer
                    }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14
                    text: Quickshell.env("USER") || ""
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 22
                    implicitHeight: 58
                    radius: secret.activeFocus ? Theme.cornerL : height / 2
                    color: Theme.surfaceContainerHigh
                    border.width: 2
                    border.color: root.wrong ? Theme.error : (secret.activeFocus ? Theme.primary : "transparent")
                    Behavior on radius { Spring {} }

                    TextInput {
                        id: secret
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 60
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        enabled: !root.busy
                        echoMode: TextInput.Password
                        color: Theme.ink
                        selectionColor: Theme.primaryContainer
                        font.family: Theme.font
                        font.pixelSize: Theme.textTitle
                        clip: true
                        Component.onCompleted: forceActiveFocus()
                        onEnabledChanged: if (enabled) forceActiveFocus()
                        onTextEdited: root.wrong = false
                        function go() { const t = text; text = ""; root.submit(t) }
                        Keys.onReturnPressed: go()
                        Keys.onEnterPressed: go()
                        Keys.onEscapePressed: text = ""
                        Label {
                            visible: secret.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.busy ? "Checking…" : "Password"
                            color: Theme.inkMuted
                        }
                    }
                    IconBtn {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "arrow_forward"
                        size: 42
                        selected: secret.text.length > 0
                        onClicked: secret.go()
                    }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.note
                    opacity: text.length > 0 ? 1 : 0
                    font.weight: Font.DemiBold
                    color: root.wrong ? Theme.error : Theme.inkMuted
                }
            }

            // Battery and what is playing, bottom centre.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                spacing: 18
                Row {
                    visible: Battery.available
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Battery.charging ? "battery_charging_full" : "battery_full"; size: 20; color: Theme.inkMuted }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: Battery.percent + "%"; color: Theme.inkMuted; font.weight: Font.DemiBold }
                }
                Row {
                    visible: Media.playing
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "music_note"; size: 20; color: Theme.inkMuted }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 420)
                        elide: Text.ElideRight
                        text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
                        color: Theme.inkMuted
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
