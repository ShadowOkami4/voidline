import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

PanelSurface {
    id: root

    open: Shell.panel === "quick"
    anchor: Style.quickAnchor
    panelWidth: 420
    panelHeight: column.implicitHeight + 40

    readonly property var adapter: Bluetooth.defaultAdapter
    property string armed: ""

    onOpenChanged: armed = ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    // Power actions need a second click within three seconds.
    function power(action) {
        if (armed !== action) { armed = action; disarm.restart(); return }
        armed = ""
        Shell.close()
        if (action === "logout") Compositor.quit()
        else Quickshell.execDetached(["systemctl", action])
    }

    ColumnLayout {
        id: column
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        // Header: title + settings and power
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                Layout.fillWidth: true
                leftPadding: 4
                text: "Voidline"
                font.pixelSize: Theme.textHeadline
                font.weight: Font.Black
            }

            IconBtn {
                icon: "settings"
                size: 44
                tonal: true
                onClicked: Shell.openSettings()
            }
            IconBtn {
                icon: "lock"
                size: 44
                tonal: true
                onClicked: Shell.lock()
            }

            Repeater {
                model: [
                    { id: "logout", icon: "logout" },
                    { id: "reboot", icon: "restart_alt" },
                    { id: "poweroff", icon: "power_settings_new" }
                ]
                IconBtn {
                    required property var modelData
                    readonly property bool hot: root.armed === modelData.id
                    icon: hot ? "check" : modelData.icon
                    size: 44
                    tonal: true
                    color: hot ? Theme.errorContainer : Theme.surfaceContainerHighest
                    restRadius: hot ? Theme.cornerM : Theme.cornerFull
                    onClicked: root.power(modelData.id)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Tile {
                Layout.fillWidth: true
                icon: Network.icon
                title: Network.type === "ethernet" ? "Ethernet" : "Wi-Fi"
                subtitle: Network.label
                active: Network.connected
                enabledInput: Network.available
                opacity: Network.available ? 1 : 0.5
                onClicked: Network.setWifi(!Network.wifiEnabled)
            }
            Tile {
                Layout.fillWidth: true
                icon: root.adapter && root.adapter.enabled ? "bluetooth" : "bluetooth_disabled"
                title: "Bluetooth"
                subtitle: !root.adapter ? "Unavailable" : (root.adapter.enabled ? "On" : "Off")
                active: !!root.adapter && root.adapter.enabled
                enabledInput: !!root.adapter
                opacity: root.adapter ? 1 : 0.5
                onClicked: root.adapter.enabled = !root.adapter.enabled
            }
            Tile {
                Layout.fillWidth: true
                icon: Config.doNotDisturb ? "notifications_off" : "notifications"
                title: "Do not disturb"
                subtitle: Config.doNotDisturb ? "On" : "Off"
                active: Config.doNotDisturb
                onClicked: Config.doNotDisturb = !Config.doNotDisturb
            }
            Tile {
                Layout.fillWidth: true
                icon: Config.dark ? "dark_mode" : "light_mode"
                title: "Dark theme"
                subtitle: Config.dark ? "On" : "Off"
                active: Config.dark
                onClicked: Config.dark = !Config.dark
            }
            Tile {
                Layout.fillWidth: true
                visible: Appearance.nightAvailable
                icon: "nightlight"
                title: "Night light"
                subtitle: Config.nightLight ? "On" : "Off"
                active: Config.nightLight
                onClicked: Config.nightLight = !Config.nightLight
            }
            Tile {
                Layout.fillWidth: true
                icon: Capture.recording ? "stop_circle" : "screenshot_region"
                title: Capture.recording ? "Stop recording" : "Screenshot"
                subtitle: Capture.recording ? "Recording" : "Select an area"
                active: Capture.recording
                onClicked: Capture.recording ? Capture.toggleRecording() : Capture.shoot("region")
            }
        }

        ExpSlider {
            Layout.fillWidth: true
            icon: Audio.icon
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
        }
        ExpSlider {
            Layout.fillWidth: true
            visible: Brightness.available
            icon: "brightness_medium"
            value: Brightness.value
            accent: Theme.tertiary
            onMoved: v => Brightness.set(v)
        }

        MediaCard {
            Layout.fillWidth: true
            visible: Media.available
        }

        // Notifications
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Label {
                Layout.fillWidth: true
                text: "Notifications"
                font.pixelSize: Theme.textTitle
                font.weight: Font.Bold
            }
            IconBtn {
                visible: Notifs.list.length > 0 || Notifs.earlier.length > 0
                icon: "clear_all"
                size: 32
                onClicked: Notifs.clear()
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            visible: Notifs.list.length === 0 && Notifs.earlier.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "All quiet"
            color: Theme.inkMuted
        }

        ListView {
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 280)
            visible: count > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.list
            delegate: NotificationCard {
                required property var modelData
                width: ListView.view.width
                notification: modelData
                onDismissed: modelData.dismiss()
            }
        }

        Label {
            visible: Notifs.earlier.length > 0
            Layout.topMargin: 2
            leftPadding: 4
            text: "Earlier"
            font.pixelSize: Theme.textLabel
            font.weight: Font.Bold
            color: Theme.inkMuted
        }
        ListView {
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 190)
            visible: count > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.earlier
            delegate: Rectangle {
                id: old
                required property var modelData
                width: ListView.view.width
                height: 52
                radius: Theme.cornerL
                color: Theme.surfaceContainer
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: gone.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        text: old.modelData.title || old.modelData.app
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.textLabel + 1
                    }
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: Qt.formatDateTime(new Date(old.modelData.time), "ddd HH:mm") + (old.modelData.text ? "  ·  " + old.modelData.text.replace(/\s+/g, " ") : "")
                        font.pixelSize: Theme.textLabelS
                        color: Theme.inkMuted
                    }
                }
                IconBtn {
                    id: gone
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    size: 28
                    onClicked: Notifs.forget(old.modelData.key)
                }
            }
        }
    }
}
