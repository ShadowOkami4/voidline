import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    spacing: 24

    readonly property bool fromWallpaper: Config.wallpaperColors && Config.wallpaper.length > 0

    // ---- Light / dark: two large tonal buttons --------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [
                { dark: false, icon: "light_mode", label: "Light" },
                { dark: true, icon: "dark_mode", label: "Dark" }
            ]
            Pressable {
                id: mode
                required property var modelData
                readonly property bool current: Config.dark === modelData.dark
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 76
                color: current ? Theme.primary : Theme.surfaceContainerHigh
                tint: current ? Theme.inkOnPrimary : Theme.ink
                restRadius: current ? Theme.cornerFull : Theme.cornerXL
                pressedRadius: Theme.cornerL
                Behavior on color { Tint {} }
                onClicked: Config.dark = modelData.dark

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: mode.modelData.icon
                        size: 26
                        filled: mode.current
                        color: mode.current ? Theme.inkOnPrimary : Theme.ink
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: mode.modelData.label
                        font.pixelSize: Theme.textTitle + 2
                        font.weight: Font.Bold
                        color: mode.current ? Theme.inkOnPrimary : Theme.ink
                    }
                }
            }
        }
    }

    // ---- Wallpaper carousel ------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        Label {
            Layout.leftMargin: 8
            text: "Wallpaper"
            font.weight: Font.Bold
            color: Theme.primary
        }

        ListView {
            id: carousel
            Layout.fillWidth: true
            implicitHeight: 150
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: [""].concat(Wallpapers.files)

            delegate: Item {
                id: paper
                required property string modelData
                readonly property bool current: Config.wallpaper === modelData
                // The selected item is wider, as in an M3 carousel.
                width: current ? 250 : (modelData.length === 0 ? 110 : 180)
                height: carousel.height
                Behavior on width { Spring { duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }

                ClippingRectangle {
                    id: frame
                    anchors.fill: parent
                    radius: Theme.cornerXL
                    color: Theme.surfaceContainerHigh

                    Image {
                        anchors.fill: parent
                        visible: paper.modelData.length > 0
                        source: paper.modelData.length > 0 ? "file://" + paper.modelData : ""
                        sourceSize.width: 500
                        sourceSize.height: 300
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Column {
                        anchors.centerIn: parent
                        visible: paper.modelData.length === 0
                        spacing: 4
                        MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "hide_image"; size: 26; color: Theme.inkMuted }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "None"; font.pixelSize: Theme.textLabel; color: Theme.inkMuted }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: frame.radius
                        color: "transparent"
                        border.width: paper.current ? 4 : 0
                        border.color: Theme.primary
                    }
                }

                Item {
                    x: parent.width - width - 10
                    y: 10
                    width: 30
                    height: 30
                    scale: paper.current ? 1 : 0
                    Behavior on scale { Spring {} }
                    Blob { anchors.fill: parent; lobes: 8; fill: Theme.primary }
                    MIcon { anchors.centerIn: parent; icon: "check"; size: 18; color: Theme.inkOnPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.wallpaper = paper.modelData
                }
            }
        }

        Label {
            Layout.leftMargin: 8
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textLabel
            color: Theme.inkMuted
            text: "Add your own images to " + Wallpapers.dataDir.replace(Wallpapers.home, "~") + " or ~/Pictures/Wallpapers."
        }
    }

    // ---- Colours -----------------------------------------------------------------
    SegGroup {
        title: "Colours"

        SegItem {
            icon: "wallpaper"
            hue: 0
            lobes: 8
            title: "Use wallpaper colours"
            description: Config.wallpaper.length > 0 ? "The palette follows the wallpaper." : "Pick a wallpaper to use this."
            Toggle { checked: Config.wallpaperColors; onToggled: v => Config.wallpaperColors = v }
        }

        SegItem {
            icon: "palette"
            hue: 2
            lobes: 4
            title: "Accent colour"
            description: page.fromWallpaper ? "Used when wallpaper colours are off." : "Every surface is tinted from this colour."
            opacity: page.fromWallpaper ? 0.55 : 1

            extra: Flow {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: ["#8E6BFF", "#4C8DFF", "#22B8A6", "#5FAE4B", "#E0A21B", "#F2743A", "#E5484D", "#E255A1"]
                    Item {
                        id: swatch
                        required property string modelData
                        readonly property bool current: Config.accent.toLowerCase() === modelData.toLowerCase()
                        width: 52
                        height: 52

                        Blob {
                            anchors.fill: parent
                            lobes: swatch.current ? 8 : 0
                            fill: swatch.modelData
                        }
                        MIcon {
                            anchors.centerIn: parent
                            icon: "check"
                            size: 24
                            color: "#FFFFFF"
                            scale: swatch.current ? 1 : 0
                            Behavior on scale { Spring {} }
                        }
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
}
