import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Voidline Settings, Material 3 Expressive list-detail layout: categories with
// shaped colour icons on the left, the selected page in a large rounded pane
// on the right. Every control writes straight to Config.
FloatingWindow {
    id: window

    title: "Voidline Settings"
    color: Theme.surface
    implicitWidth: 1080
    implicitHeight: 760
    minimumSize: Qt.size(820, 520)

    property alias page: state.page
    QtObject { id: state; property string page: Shell.settingsPage; onPageChanged: Shell.settingsPage = page }
    readonly property string wmName: Compositor.name === "niri" ? "Niri" : (Compositor.name === "hyprland" ? "Hyprland" : "Window manager")
    readonly property var pages: [
        { section: "Connections" },
        { id: "network", icon: "wifi", lobes: 8, label: "Network", hint: "Wi-Fi and wired", words: "network wifi wlan internet ethernet lan password", view: "NetworkPage.qml" },
        { id: "bluetooth", icon: "bluetooth", lobes: 0, label: "Bluetooth", hint: "Headphones, mice, keyboards", words: "bluetooth pair headphones speaker mouse keyboard device", view: "BluetoothPage.qml" },
        { section: "Device" },
        { id: "display", icon: "monitor", lobes: 4, label: "Display", hint: "Resolution, refresh rate, scale", words: "display monitor screen resolution refresh rate hz scale brightness", view: "DisplayPage.qml" },
        { id: "sound", icon: "volume_up", lobes: 5, label: "Sound", hint: "Volume, devices, apps", words: "sound audio volume speaker microphone output input mute", view: "SoundPage.qml" },
        { id: "power", icon: "battery_full", lobes: 8, label: "Battery & power", hint: "Power mode, sleep, shut down", words: "battery power mode performance saver sleep suspend restart shutdown logout", view: "PowerPage.qml" },
        { section: "Personalisation" },
        { id: "style", icon: "dashboard_customize", lobes: 8, label: "Style", hint: "Voidline, Windows, macOS", words: "style layout taskbar dock bar windows macos voidline", view: "StylePage.qml" },
        { id: "colours", icon: "palette", lobes: 4, label: "Wallpaper & colours", hint: "Theme, accent, wallpaper", words: "wallpaper colour color accent dark light theme palette", view: "ColoursPage.qml" },
        { id: "wm", icon: "select_window", lobes: 0, label: wmName, hint: "Windows, layout, input", words: "window manager hyprland niri gaps border rounding corner keyboard layout touchpad mouse pointer blur shadow animation vrr focus", view: "WmPage.qml" },
        { id: "interface", icon: "tune", lobes: 5, label: "Interface", hint: "Size, bar, behaviour", words: "interface size scale clock workspaces notifications motion terminal bar do not disturb", view: "InterfacePage.qml" },
        { section: "System" },
        { id: "about", icon: "info", lobes: 4, label: "About", hint: "Version " + Shell.version, words: "about version system computer processor memory graphics kernel", view: "AboutPage.qml" }
    ]
    readonly property var current: pages.find(p => p.id === page) ?? pages[1]
    readonly property var shown: {
        const q = search.text.trim().toLowerCase()
        let hue = 0
        const all = pages.map(p => p.section ? p : Object.assign({ hue: hue++ }, p))
        return q.length === 0 ? all : all.filter(p => !p.section && (p.label + " " + p.hint + " " + p.words).toLowerCase().includes(q))
    }
    Component.onCompleted: Wallpapers.refresh()
    onVisibleChanged: if (!visible) Shell.settingsOpen = false

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ---- list pane ----------------------------------------------------------
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            spacing: 14

            Label {
                Layout.leftMargin: 12
                Layout.topMargin: 14
                text: "Settings"
                font.pixelSize: 34
                font.weight: Font.Black
                font.letterSpacing: -0.8
            }

            // Search
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: search.activeFocus ? Theme.cornerL : height / 2
                color: Theme.surfaceContainerHigh
                Behavior on radius { Spring {} }

                MIcon { id: glass; x: 18; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 22; color: Theme.inkMuted }
                TextInput {
                    id: search
                    anchors.left: glass.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.ink
                    selectionColor: Theme.primaryContainer
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    clip: true
                    Keys.onEscapePressed: text = ""
                    Keys.onReturnPressed: if (window.shown.length > 0) window.page = window.shown[0].id
                    Label {
                        visible: search.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search settings"
                        color: Theme.inkMuted
                    }
                }
            }

            // Categories, grouped into sections
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: window.shown

                        Item {
                            id: row
                            required property var modelData
                            readonly property bool header: !!modelData.section
                            readonly property bool current: !header && window.page === modelData.id
                            width: list.width
                            height: header ? 34 : 60

                            Label {
                                visible: row.header
                                x: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: row.modelData.section ?? ""
                                font.pixelSize: Theme.textLabel
                                font.weight: Font.Bold
                                color: Theme.primary
                            }

                            Pressable {
                                visible: !row.header
                                anchors.fill: parent
                                color: row.current ? Theme.secondaryContainer : "transparent"
                                restRadius: row.current ? Theme.cornerFull : Theme.cornerXL
                                pressedRadius: Theme.cornerL
                                Behavior on color { Tint {} }
                                onClicked: window.page = row.modelData.id

                                Item {
                                    id: badge
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    height: 40
                                    Blob {
                                        anchors.fill: parent
                                        lobes: row.modelData.lobes ?? 0
                                        fill: row.current ? Theme.primary : Theme.hueContainer(row.modelData.hue ?? 0)
                                    }
                                    MIcon {
                                        anchors.centerIn: parent
                                        icon: row.modelData.icon ?? ""
                                        size: 21
                                        filled: true
                                        color: row.current ? Theme.inkOnPrimary : Theme.hueInk(row.modelData.hue ?? 0)
                                    }
                                }
                                Column {
                                    anchors.left: badge.right
                                    anchors.leftMargin: 14
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    Label {
                                        width: parent.width
                                        text: row.modelData.label ?? ""
                                        font.pixelSize: Theme.textBody + 1
                                        font.weight: row.current ? Font.Bold : Font.DemiBold
                                        color: row.current ? Theme.inkOnSecondaryContainer : Theme.ink
                                    }
                                    Label {
                                        width: parent.width
                                        text: row.modelData.hint ?? ""
                                        font.pixelSize: Theme.textLabel
                                        color: row.current ? Theme.inkOnSecondaryContainer : Theme.inkMuted
                                        opacity: 0.85
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        visible: window.shown.length === 0
                        leftPadding: 14
                        topPadding: 10
                        text: "Nothing found"
                        color: Theme.inkMuted
                    }
                }
            }
        }
        // ---- detail pane ----------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerXL
            color: Theme.surfaceContainerLow
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: detail.implicitHeight + 56
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: detail
                    x: 28
                    y: 26
                    width: flick.width - 56
                    spacing: 22

                    Label {
                        text: window.current.label
                        font.pixelSize: 30
                        font.weight: Font.Black
                        font.letterSpacing: -0.5
                    }

                    Loader {
                        id: content
                        Layout.fillWidth: true
                        source: window.current.view
                        onSourceChanged: { flick.contentY = 0; enter.restart() }

                        // Pages spring up into place.
                        transform: Translate { id: shift }
                        ParallelAnimation {
                            id: enter
                            Spring { target: shift; property: "y"; from: 28; to: 0; duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve }
                            Fade { target: content; property: "opacity"; from: 0; to: 1 }
                        }
                    }
                }
            }
        }
    }
}
