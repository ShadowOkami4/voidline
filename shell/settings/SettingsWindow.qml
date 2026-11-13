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
    implicitWidth: 1040
    implicitHeight: 700
    minimumSize: Qt.size(820, 520)

    property alias page: state.page
    QtObject { id: state; property int page: Shell.settingsPage; onPageChanged: Shell.settingsPage = page }
    readonly property var pages: [
        { icon: "dashboard_customize", lobes: 8, label: "Style", hint: "Voidline, Windows, macOS", words: "style layout taskbar dock bar windows macos voidline", view: "StylePage.qml" },
        { icon: "palette", lobes: 4, label: "Wallpaper & colours", hint: "Theme, accent, wallpaper", words: "wallpaper colour color accent dark light theme palette", view: "ColoursPage.qml" },
        { icon: "select_window", lobes: 8, label: Compositor.name === "niri" ? "Niri" : (Compositor.name === "hyprland" ? "Hyprland" : "Window manager"), hint: "Windows, layout, input", words: "window manager hyprland niri gaps border rounding corner keyboard layout touchpad mouse pointer blur shadow animation vrr focus", view: "WmPage.qml" },
        { icon: "tune", lobes: 0, label: "Interface", hint: "Size, bar, behaviour", words: "interface size scale clock workspaces notifications motion terminal bar", view: "InterfacePage.qml" },
        { icon: "info", lobes: 5, label: "About", hint: "Version " + Shell.version, words: "about version system", view: "AboutPage.qml" }
    ]
    readonly property var shown: {
        const q = search.text.trim().toLowerCase()
        const all = pages.map((p, i) => Object.assign({ index: i }, p))
        return q.length === 0 ? all : all.filter(p => (p.label + " " + p.hint + " " + p.words).toLowerCase().includes(q))
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
                font.pixelSize: 38
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
                    Keys.onReturnPressed: if (window.shown.length > 0) window.page = window.shown[0].index
                    Label {
                        visible: search.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search settings"
                        color: Theme.inkMuted
                    }
                }
            }

            // Categories
            Column {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: window.shown
                    Pressable {
                        id: nav
                        required property var modelData
                        readonly property bool current: window.page === modelData.index
                        width: parent.width
                        height: 72
                        color: current ? Theme.secondaryContainer : "transparent"
                        restRadius: current ? Theme.cornerFull : Theme.cornerXL
                        pressedRadius: Theme.cornerL
                        Behavior on color { Tint {} }
                        onClicked: window.page = modelData.index

                        Item {
                            id: badge
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 44
                            Blob {
                                anchors.fill: parent
                                lobes: nav.modelData.lobes
                                fill: nav.current ? Theme.primary : Theme.hueContainer(nav.modelData.index)
                            }
                            MIcon {
                                anchors.centerIn: parent
                                icon: nav.modelData.icon
                                size: 22
                                filled: true
                                color: nav.current ? Theme.inkOnPrimary : Theme.hueInk(nav.modelData.index)
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
                                text: nav.modelData.label
                                font.pixelSize: Theme.textTitle
                                font.weight: nav.current ? Font.Bold : Font.DemiBold
                                color: nav.current ? Theme.inkOnSecondaryContainer : Theme.ink
                            }
                            Label {
                                width: parent.width
                                text: nav.modelData.hint
                                font.pixelSize: Theme.textLabel
                                color: nav.current ? Theme.inkOnSecondaryContainer : Theme.inkMuted
                                opacity: 0.85
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

            Item { Layout.fillHeight: true }
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
                        text: window.pages[window.page].label
                        font.pixelSize: 30
                        font.weight: Font.Black
                        font.letterSpacing: -0.5
                    }

                    Loader {
                        id: content
                        Layout.fillWidth: true
                        source: window.pages[window.page].view
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
