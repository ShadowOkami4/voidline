import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
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
    // The password was right: the screen takes a moment to wave goodbye.
    property bool leaving: false
    Timer { id: leave; interval: Math.max(1, 280 * Motion.scale); onTriggered: { Shell.locked = false; root.leaving = false } }

    function submit(text) {
        if (busy || text.length === 0) return
        pending = text
        wrong = false
        note = ""
        if (!pam.start()) { pending = ""; note = Lang.t("The password check could not be started.") ; wrong = true }
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
            if (result === PamResult.Success) { root.note = ""; root.leaving = true; leave.restart() }
            else {
                root.wrong = true
                root.note = result === PamResult.MaxTries ? Lang.t("Too many attempts. Wait a moment and try again.") : Lang.t("Wrong password")
            }
        }
        onError: error => { root.pending = ""; root.wrong = true; root.note = Lang.t("The password check failed (") + PamError.toString(error) + ")." }
    }

    // Caps lock is the classic reason for a "wrong" password.
    property bool caps: false
    Process {
        id: capsLook
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -n 1"]
        stdout: StdioCollector { onStreamFinished: root.caps = Number(text.trim()) > 0 }
    }
    Timer { interval: 600; running: Shell.locked; repeat: true; triggeredOnStart: true; onTriggered: capsLook.running = true }

    WlSessionLock {
        id: lock
        locked: Shell.locked

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            SystemClock { id: clock; precision: SystemClock.Minutes }

            // Locking: the picture settles, then clock, lock and password
            // field arrive one after the other.
            property real enter: 0
            NumberAnimation on enter { from: 0; to: 1; duration: Math.max(1, 1100 * Motion.scale) }
            function at(step) {
                const t = Math.max(0, Math.min(1, (enter - step * 0.09) / 0.45))
                return 1 - Math.pow(1 - t, 3)
            }
            Connections {
                target: root
                function onWrongChanged() { if (root.wrong) shake.restart() }
            }

            Image {
                anchors.fill: parent
                opacity: surface.at(0)
                scale: 1.12 - 0.12 * surface.at(0) + (root.leaving ? 0.06 : 0)
                Behavior on scale { enabled: root.leaving; Spring { duration: Motion.spatialSlow } }
                source: Config.wallpaper.length > 0 ? "file://" + Config.wallpaperFor(surface.screen) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
            }
            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.surface, 0.72)
                opacity: root.leaving ? 0 : surface.at(0)
                Behavior on opacity { enabled: root.leaving; Fade { duration: Motion.effectsSlow } }
            }

            // Clicking anywhere brings the keyboard back to the password field.
            MouseArea { anchors.fill: parent; onClicked: secret.forceActiveFocus() }

            ColumnLayout {
                anchors.centerIn: parent
                width: 420
                spacing: 0
                opacity: root.leaving ? 0 : 1
                scale: root.leaving ? 1.1 : 1
                Behavior on opacity { Fade {} }
                Behavior on scale { Spring {} }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    opacity: surface.at(1)
                    scale: 0.82 + 0.18 * surface.at(1)
                    transform: Translate { y: (surface.at(1) - 1) * 50 }
                    text: Qt.formatDateTime(clock.date, Config.clock24h ? "HH:mm" : "h:mm")
                    font.pixelSize: 150
                    font.weight: Font.Black
                    font.letterSpacing: -6
                    color: Theme.ink
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -10
                    opacity: surface.at(2.2)
                    transform: Translate { y: (surface.at(2.2) - 1) * 24 }
                    text: Lang.date(clock.date, Lang.t("dddd, d MMMM"))
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: Theme.primary
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 56
                    implicitWidth: 76
                    implicitHeight: 76
                    opacity: surface.at(3.4)
                    scale: 0.3 + 0.7 * surface.at(3.4)
                    rotation: (surface.at(3.4) - 1) * 120
                    Blob {
                        anchors.fill: parent
                        lobes: 8
                        fill: root.wrong ? Theme.errorContainer : Theme.primaryContainer
                        rotation: root.busy ? 45 : 0
                        Behavior on rotation { Spring { duration: Motion.spatialSlow; easing.bezierCurve: Motion.spatialSlowCurve } }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        icon: root.leaving ? "lock_open" : (root.busy ? "hourglass_top" : "lock")
                        filled: true
                        size: 34
                        color: root.wrong ? Theme.inkOnErrorContainer : Theme.inkOnPrimaryContainer
                    }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14
                    opacity: surface.at(4.2)
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
                    Behavior on border.color { Tint {} }
                    opacity: surface.at(5)
                    // Rises into place; a wrong password shakes it.
                    transform: Translate { id: nudge; y: (1 - surface.at(5)) * 36 }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: nudge; property: "x"; to: -14; duration: 50 }
                        NumberAnimation { target: nudge; property: "x"; to: 12; duration: 70 }
                        NumberAnimation { target: nudge; property: "x"; to: -8; duration: 70 }
                        NumberAnimation { target: nudge; property: "x"; to: 5; duration: 60 }
                        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
                    }

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
                            text: root.busy ? Lang.t("Checking…") : Lang.t("Password")
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
                    text: root.caps && !root.busy ? Lang.t("Caps lock is on") : root.note
                    opacity: text.length > 0 ? 1 : 0
                    Behavior on opacity { Fade {} }
                    font.weight: Font.DemiBold
                    color: root.wrong ? Theme.error : Theme.inkMuted
                }
            }

            // Battery and what is playing, bottom centre.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40 - (1 - surface.at(6)) * 30
                opacity: root.leaving ? 0 : surface.at(6)
                spacing: 18
                Row {
                    visible: Battery.available
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Battery.charging ? "battery_charging_full" : "battery_full"; size: 20; color: Theme.inkMuted }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: Battery.percent + "%"; color: Theme.inkMuted; font.weight: Font.DemiBold }
                }
                // How many notifications wait; what they say stays hidden.
                Row {
                    visible: Notifs.list.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "notifications"; filled: true; size: 20; color: Theme.inkMuted }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: Notifs.list.length; color: Theme.inkMuted; font.weight: Font.DemiBold }
                }
                // What is playing, with the three buttons you want without unlocking.
                Rectangle {
                    visible: Media.available
                    anchors.verticalCenter: parent.verticalCenter
                    width: tune.implicitWidth + 20
                    height: 52
                    radius: height / 2
                    color: Theme.alpha(Theme.surfaceContainerHigh, 0.9)
                    Row {
                        id: tune
                        anchors.centerIn: parent
                        spacing: 4
                        IconBtn { anchors.verticalCenter: parent.verticalCenter; icon: "skip_previous"; size: 38; onClicked: { Media.previous(); secret.forceActiveFocus() } }
                        IconBtn { anchors.verticalCenter: parent.verticalCenter; icon: Media.playing ? "pause" : "play_arrow"; size: 40; selected: true; onClicked: { Media.toggle(); secret.forceActiveFocus() } }
                        IconBtn { anchors.verticalCenter: parent.verticalCenter; icon: "skip_next"; size: 38; onClicked: { Media.next(); secret.forceActiveFocus() } }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 8
                            rightPadding: 10
                            width: Math.min(implicitWidth, 380)
                            elide: Text.ElideRight
                            text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
                            color: Theme.ink
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
