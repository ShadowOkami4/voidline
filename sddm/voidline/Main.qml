import QtQuick
import SddmComponents 2.0

// Voidline login screen for SDDM (Qt 6). Self-contained: it cannot use the
// shell's files, so the few colours and shapes it needs are defined here.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0B0A10"

    readonly property color accent: config.accent || "#8E6BFF"
    readonly property color ink: "#EDE9F4"
    readonly property color inkMuted: "#A8A2B5"
    readonly property color field: "#24212C"
    readonly property color bad: "#FFB4AB"
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property real u: Math.max(0.7, Math.min(width / 1920, height / 1080))

    property int session: sessionModel.lastIndex
    property string note: ""
    property bool wrong: false
    property date now: new Date()

    function login() {
        if (user.text.length === 0) { user.grab(); return }
        root.wrong = false
        root.note = "Signing in…"
        sddm.login(user.text, pass.text, root.session)
    }

    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    Connections {
        target: sddm
        function onLoginFailed() { root.wrong = true; root.note = "Wrong name or password"; pass.text = ""; pass.grab() }
        function onLoginSucceeded() { root.note = "" }
    }

    Image {
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: "#0B0A10"; opacity: 0.66 }

    // Session names live in a model; this reads the selected one.
    Repeater {
        id: sessions
        model: sessionModel
        Item { required property string name; required property int index }
    }
    readonly property string sessionName: sessions.count > 0 && sessions.itemAt(session) ? sessions.itemAt(session).name : "Session"

    component Field: Rectangle {
        id: box
        property alias text: input.text
        property alias echoMode: input.echoMode
        property string hint: ""
        property string glyph: ""
        signal accepted()
        function grab() { input.forceActiveFocus() }
        width: parent ? parent.width : 0
        height: 58 * root.u
        radius: input.activeFocus ? 18 * root.u : height / 2
        color: root.field
        border.width: 2
        border.color: input.activeFocus ? root.accent : "transparent"
        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Text {
            id: mark
            x: 22 * root.u
            anchors.verticalCenter: parent.verticalCenter
            text: box.glyph
            color: root.inkMuted
            font.family: root.iconFont
            font.pixelSize: 22 * root.u
        }
        TextInput {
            id: input
            anchors.left: mark.right
            anchors.leftMargin: 14 * root.u
            anchors.right: parent.right
            anchors.rightMargin: 22 * root.u
            anchors.verticalCenter: parent.verticalCenter
            color: root.ink
            selectionColor: root.accent
            font.pixelSize: 17 * root.u
            clip: true
            onAccepted: box.accepted()
            Text {
                visible: input.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: box.hint
                color: root.inkMuted
                font.pixelSize: 17 * root.u
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: 430 * root.u
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, config.clock24h === "false" ? "h:mm" : "HH:mm")
            color: root.ink
            font.pixelSize: 150 * root.u
            font.weight: Font.Black
            font.letterSpacing: -6 * root.u
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: root.accent
            font.pixelSize: 22 * root.u
            font.weight: Font.DemiBold
        }
        Item { width: 1; height: 54 * root.u }

        Field {
            id: user
            glyph: "person"
            hint: "Name"
            text: userModel.lastUser
            onAccepted: pass.grab()
        }
        Item { width: 1; height: 10 * root.u }
        Field {
            id: pass
            glyph: "lock"
            hint: "Password"
            echoMode: TextInput.Password
            onAccepted: root.login()
        }
        Item { width: 1; height: 14 * root.u }

        Rectangle {
            width: parent.width
            height: 56 * root.u
            radius: go.pressed ? 16 * root.u : height / 2
            color: root.accent
            Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Text { anchors.centerIn: parent; text: "Sign in"; color: "#17122B"; font.pixelSize: 17 * root.u; font.weight: Font.Bold }
            MouseArea { id: go; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
        }
        Item { width: 1; height: 14 * root.u }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.note
            color: root.wrong ? root.bad : root.inkMuted
            font.pixelSize: 15 * root.u
            font.weight: Font.DemiBold
        }
    }

    // Bottom: session on the left, power on the right.
    component Chip: Rectangle {
        id: chip
        property string glyph: ""
        property string label: ""
        signal clicked()
        width: row.implicitWidth + 30 * root.u
        height: 46 * root.u
        radius: tap.pressed ? 14 * root.u : height / 2
        color: tap.containsMouse ? "#322E3D" : root.field
        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8 * root.u
            Text { anchors.verticalCenter: parent.verticalCenter; text: chip.glyph; color: root.ink; font.family: root.iconFont; font.pixelSize: 20 * root.u }
            Text { visible: chip.label.length > 0; anchors.verticalCenter: parent.verticalCenter; text: chip.label; color: root.ink; font.pixelSize: 15 * root.u; font.weight: Font.DemiBold }
        }
        MouseArea { id: tap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    Chip {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 36 * root.u
        glyph: "desktop_windows"
        label: root.sessionName
        // Click to go to the next installed session (Hyprland, Niri, ...).
        onClicked: root.session = (root.session + 1) % Math.max(1, sessions.count)
    }
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 36 * root.u
        spacing: 8 * root.u
        Chip { visible: sddm.canSuspend; glyph: "bedtime"; onClicked: sddm.suspend() }
        Chip { visible: sddm.canReboot; glyph: "restart_alt"; onClicked: sddm.reboot() }
        Chip { visible: sddm.canPowerOff; glyph: "power_settings_new"; onClicked: sddm.powerOff() }
    }

    Component.onCompleted: (user.text.length > 0 ? pass : user).grab()
}
