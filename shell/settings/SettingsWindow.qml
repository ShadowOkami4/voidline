import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Voidline Settings: a normal window (floating by rule) with a navigation
// rail. Every control writes straight to Config, which saves and applies it.
FloatingWindow {
    id: window

    title: "Voidline Settings"
    color: Theme.surface
    implicitWidth: 920
    implicitHeight: 640
    minimumSize: Qt.size(720, 480)

    property int page: 0
    readonly property var pages: [
        { icon: "palette", label: "Appearance" },
        { icon: "desktop_windows", label: "Desktop" },
        { icon: "info", label: "About" }
    ]

    Component.onCompleted: Wallpapers.refresh()
    onVisibleChanged: if (!visible) Shell.settingsOpen = false

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- navigation rail ------------------------------------------------
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 200
            color: Theme.surfaceContainerLow

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Label {
                    text: "Settings"
                    font.pixelSize: Theme.textHeadline
                    font.weight: Font.Black
                    leftPadding: 10
                    topPadding: 8
                    bottomPadding: 14
                }

                Repeater {
                    model: window.pages
                    Pressable {
                        id: nav
                        required property var modelData
                        required property int index
                        readonly property bool current: window.page === index
                        width: parent.width
                        height: 48
                        color: current ? Theme.secondaryContainer : "transparent"
                        restRadius: current ? Theme.cornerFull : Theme.cornerL
                        Behavior on color { Tint {} }
                        onClicked: window.page = index

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 16
                            spacing: 12
                            MIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: nav.modelData.icon
                                size: 22
                                filled: nav.current
                                color: nav.current ? Theme.inkOnSecondaryContainer : Theme.inkMuted
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: nav.modelData.label
                                font.weight: nav.current ? Font.Bold : Font.Medium
                                color: nav.current ? Theme.inkOnSecondaryContainer : Theme.ink
                            }
                        }
                    }
                }
            }
        }

        // ---- page -------------------------------------------------------------
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: content
                x: 28
                y: 24
                width: flick.width - 56
                sourceComponent: [appearance, desktop, about][window.page]
                onSourceComponentChanged: flick.contentY = 0
            }
        }
    }

    // ======================= Appearance =======================================
    Component {
        id: appearance
        ColumnLayout {
            spacing: 22

            Group {
                title: "Theme"
                Setting {
                    icon: "dark_mode"
                    title: "Dark theme"
                    Toggle { checked: Config.dark; onToggled: v => Config.dark = v }
                }
                Setting {
                    icon: "colorize"
                    title: "Colours from wallpaper"
                    description: "Build the palette from the wallpaper instead of the accent colour."
                    Toggle { checked: Config.wallpaperColors; onToggled: v => Config.wallpaperColors = v }
                }
                Setting {
                    icon: "palette"
                    title: "Accent colour"
                    description: Config.wallpaperColors && Config.wallpaper.length > 0 ? "Used when wallpaper colours are off." : ""
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["#8E6BFF", "#4C8DFF", "#22B8A6", "#5FAE4B", "#E0A21B", "#F2743A", "#E5484D", "#E255A1"]
                            Rectangle {
                                id: swatch
                                required property string modelData
                                readonly property bool current: Config.accent.toLowerCase() === modelData.toLowerCase()
                                width: 32
                                height: 32
                                radius: current ? Theme.cornerM : 16
                                color: modelData
                                border.width: current ? 3 : 0
                                border.color: Theme.ink
                                Behavior on radius { Spring {} }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.accent = swatch.modelData
                                }
                            }
                        }
                    }
                }
            }

            Group {
                title: "Wallpaper"
                Label {
                    Layout.margins: 18
                    Layout.fillWidth: true
                    visible: Wallpapers.files.length === 0
                    wrapMode: Text.Wrap
                    color: Theme.inkMuted
                    text: "No wallpapers found. Put images in " + Wallpapers.dataDir + " or ~/Pictures/Wallpapers."
                }
                GridView {
                    id: papers
                    Layout.fillWidth: true
                    Layout.margins: 12
                    visible: Wallpapers.files.length > 0
                    implicitHeight: Math.ceil(count / Math.max(1, Math.floor(width / cellWidth))) * cellHeight
                    interactive: false
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 190)))
                    cellHeight: Math.round(cellWidth * 0.625)
                    model: [""].concat(Wallpapers.files)

                    delegate: Item {
                        id: paper
                        required property string modelData
                        readonly property bool current: Config.wallpaper === modelData
                        width: papers.cellWidth
                        height: papers.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: Theme.cornerL
                            color: Theme.surfaceContainerHighest
                            border.width: paper.current ? 3 : 0
                            border.color: Theme.primary
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: paper.current ? 3 : 0
                                visible: paper.modelData.length > 0
                                source: paper.modelData.length > 0 ? "file://" + paper.modelData : ""
                                sourceSize.width: 380
                                sourceSize.height: 240
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Column {
                                anchors.centerIn: parent
                                visible: paper.modelData.length === 0
                                spacing: 4
                                MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "hide_image"; size: 26; color: Theme.inkMuted }
                                Label { text: "None"; font.pixelSize: Theme.textLabel; color: Theme.inkMuted }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.wallpaper = paper.modelData
                            }
                        }
                    }
                }
            }

            Group {
                title: "Size and motion"
                Setting {
                    icon: "format_size"
                    title: "Interface size"
                    description: "The shell restarts briefly to apply this."
                    Choice {
                        segmentWidth: 78
                        value: Config.uiScale
                        options: [
                            { value: 0.65, label: "Small" },
                            { value: 0.75, label: "Default" },
                            { value: 0.9, label: "Large" },
                            { value: 1.0, label: "Huge" }
                        ]
                        onPicked: v => Config.uiScale = v
                    }
                }
                Setting {
                    icon: "animation"
                    title: "Reduce motion"
                    description: "Turn animations off."
                    Toggle { checked: Config.reduceMotion; onToggled: v => Config.reduceMotion = v }
                }
            }
        }
    }

    // ======================= Desktop ===========================================
    Component {
        id: desktop
        ColumnLayout {
            spacing: 22

            Group {
                title: "Style"
                Setting {
                    icon: "dashboard_customize"
                    title: "Desktop style"
                    description: Config.style === "windows" ? "Taskbar at the bottom with a start menu."
                        : (Config.style === "macos" ? "Menu bar at the top and a dock."
                            : "Connected bar, screen frame and attached panels.")
                    Choice {
                        value: Config.style
                        options: [
                            { value: "voidline", label: "Voidline" },
                            { value: "windows", label: "Windows" },
                            { value: "macos", label: "macOS" }
                        ]
                        onPicked: v => Config.style = v
                    }
                }
            }

            Group {
                title: "Bar"
                Setting {
                    icon: "schedule"
                    title: "24-hour clock"
                    Toggle { checked: Config.clock24h; onToggled: v => Config.clock24h = v }
                }
                Setting {
                    visible: Compositor.name === "hyprland"
                    icon: "workspaces"
                    title: "Workspaces shown"
                    description: "Minimum number of workspace dots in the bar."
                    Row {
                        spacing: 10
                        IconBtn { icon: "remove"; size: 34; tonal: true; onClicked: Config.workspaceCount = Math.max(1, Config.workspaceCount - 1) }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: Config.workspaceCount
                            font.weight: Font.Bold
                        }
                        IconBtn { icon: "add"; size: 34; tonal: true; onClicked: Config.workspaceCount = Math.min(20, Config.workspaceCount + 1) }
                    }
                }
            }

            Group {
                title: "Behaviour"
                Setting {
                    icon: "notifications_off"
                    title: "Do not disturb"
                    description: "Collect notifications without showing popups."
                    Toggle { checked: Config.doNotDisturb; onToggled: v => Config.doNotDisturb = v }
                }
                Setting {
                    icon: "terminal"
                    title: "Terminal"
                    description: "Used for apps that run in a terminal."
                    Rectangle {
                        width: 180
                        height: 38
                        radius: Theme.cornerM
                        color: Theme.surfaceContainerHighest
                        border.width: term.activeFocus ? 2 : 0
                        border.color: Theme.primary
                        TextInput {
                            id: term
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            text: Config.terminal
                            color: Theme.ink
                            selectionColor: Theme.primaryContainer
                            font.family: Theme.font
                            font.pixelSize: Theme.textBody
                            clip: true
                            onEditingFinished: if (text.trim().length > 0) Config.terminal = text.trim()
                        }
                    }
                }
            }
        }
    }

    // ======================= About =============================================
    Component {
        id: about
        ColumnLayout {
            spacing: 22

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 150
                radius: Theme.cornerXXL
                color: Theme.primaryContainer

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 32
                    spacing: 2
                    Label {
                        text: "Voidline"
                        font.pixelSize: Theme.textDisplay
                        font.weight: Font.Black
                        color: Theme.inkOnPrimaryContainer
                    }
                    Label {
                        text: "Version " + Shell.version + "  ·  development preview"
                        color: Theme.inkOnPrimaryContainer
                        opacity: 0.8
                    }
                }
            }

            Group {
                title: "System"
                Setting { icon: "window"; title: "Window manager"; Label { text: Compositor.name === "hyprland" ? "Hyprland" : (Compositor.name === "niri" ? "Niri" : "Not detected"); color: Theme.inkMuted } }
                Setting { icon: "widgets"; title: "Toolkit"; Label { text: "Quickshell"; color: Theme.inkMuted } }
                Setting { icon: "folder"; title: "Settings file"; Label { text: Config.path.replace(Quickshell.env("HOME"), "~"); color: Theme.inkMuted } }
            }

            Group {
                title: "Project"
                Setting {
                    icon: "code"
                    title: "Source code"
                    description: "github.com/ShadowOkami4/voidline"
                    IconBtn { icon: "open_in_new"; tonal: true; onClicked: Apps.openUrl("https://github.com/ShadowOkami4/voidline") }
                }
                Setting {
                    icon: "public"
                    title: "Website"
                    description: "shadowokami.com/Voidline"
                    IconBtn { icon: "open_in_new"; tonal: true; onClicked: Apps.openUrl("https://shadowokami.com/Voidline") }
                }
            }
        }
    }
}
