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
            // Start with the wallpaper in use in view.
            onCountChanged: {
                const i = model.indexOf(Config.wallpaper.length > 0 ? Config.wallpaperPath : "")
                if (i > 0) positionViewAtIndex(i, ListView.Center)
            }

            delegate: Item {
                id: paper
                required property string modelData
                readonly property bool current: (Config.wallpaper.length > 0 ? Config.wallpaperPath : "") === modelData
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

    // ---- Live wallpapers -------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: Wallpapers.live.length > 0
        spacing: 10

        Label {
            Layout.leftMargin: 8
            text: "Live wallpapers"
            font.weight: Font.Bold
            color: Theme.primary
        }

        ListView {
            id: liveCarousel
            Layout.fillWidth: true
            implicitHeight: 150
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Wallpapers.live

            delegate: Item {
                id: card
                required property var modelData
                readonly property bool current: Config.liveId === modelData.id
                width: current ? 250 : 180
                height: liveCarousel.height
                Behavior on width { Spring { duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.cornerXL
                    color: Theme.surfaceContainerHigh

                    Image {
                        anchors.fill: parent
                        source: "file://" + card.modelData.preview
                        sourceSize.width: 500
                        sourceSize.height: 300
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    // Name plate
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 40
                        color: Theme.alpha(Theme.surface, 0.72)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14
                            spacing: 6
                            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "play_circle"; filled: true; size: 18; color: Theme.primary }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: card.modelData.name; font.weight: Font.Bold }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerXL
                        color: "transparent"
                        border.width: card.current ? 4 : 0
                        border.color: Theme.primary
                    }
                }

                Item {
                    x: parent.width - width - 10
                    y: 10
                    width: 30
                    height: 30
                    scale: card.current ? 1 : 0
                    Behavior on scale { Spring {} }
                    Blob { anchors.fill: parent; lobes: 8; fill: Theme.primary }
                    MIcon { anchors.centerIn: parent; icon: "check"; size: 18; color: Theme.inkOnPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.wallpaper = "live:" + card.modelData.id
                }
            }
        }

        Label {
            Layout.leftMargin: 8
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textLabel
            color: Theme.inkMuted
            text: "Live wallpapers are small programs. Only add ones you trust, in " + Config.liveDir.replace(Wallpapers.home, "~") + "."
        }
    }

    // ---- Options of the live wallpaper in use -------------------------------------------
    SegGroup {
        id: liveOptions
        readonly property var info: Wallpapers.liveInfo(Config.liveId)
        readonly property var values: Wallpapers.liveValues(Config.liveId)
        visible: !!info
        title: info ? info.name : ""

        Repeater {
            model: liveOptions.info ? liveOptions.info.options : []

            SegItem {
                id: opt
                required property var modelData
                required property int index
                readonly property var value: liveOptions.values[modelData.key]
                readonly property string kind: modelData.type || (typeof modelData.default === "boolean" ? "toggle" : "slider")
                readonly property real lo: modelData.min ?? 0
                readonly property real hi: modelData.max ?? 1
                readonly property real stepSize: modelData.step ?? 0.01
                function save(v) { Config.setLiveOption(Config.liveId, modelData.key, String(v)) }

                icon: kind === "toggle" ? "toggle_on" : (kind === "choice" ? "format_list_bulleted" : "tune")
                hue: index + 1
                lobes: [8, 4, 0, 5][index % 4]
                title: modelData.label || modelData.key

                Row {
                    spacing: 8
                    Label {
                        visible: opt.kind === "slider"
                        anchors.verticalCenter: parent.verticalCenter
                        text: Number(opt.value ?? 0).toFixed(opt.stepSize >= 1 ? 0 : (opt.stepSize >= 0.1 ? 1 : 2))
                        font.pixelSize: Theme.textTitle + 2
                        font.weight: Font.Black
                        color: Theme.primary
                    }
                    Toggle {
                        visible: opt.kind === "toggle"
                        checked: opt.value === true
                        onToggled: v => opt.save(v)
                    }
                }

                extra: [
                    ExpSlider {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        visible: opt.kind === "slider"
                        value: (Number(opt.value ?? opt.lo) - opt.lo) / Math.max(0.0001, opt.hi - opt.lo)
                        onMoved: v => {
                            const snapped = Math.round((opt.lo + v * (opt.hi - opt.lo)) / opt.stepSize) * opt.stepSize
                            if (Math.abs(snapped - Number(opt.value)) > 0.00001) opt.save(Number(snapped.toFixed(4)))
                        }
                    },
                    Choice {
                        Layout.fillWidth: true
                        visible: opt.kind === "choice"
                        segmentWidth: (width - 8) / Math.max(1, options.length)
                        value: opt.value
                        options: opt.modelData.choices || []
                        onPicked: v => opt.save(v)
                    }
                ]
            }
        }

        SegItem {
            icon: "battery_saver"
            hue: 0
            lobes: 5
            title: "Pause on battery"
            description: "Freeze live wallpapers while the laptop is unplugged."
            Toggle { checked: Config.livePauseOnBattery; onToggled: v => Config.livePauseOnBattery = v }
        }
        SegItem {
            icon: "tab_inactive"
            hue: 2
            lobes: 8
            title: "Pause behind windows"
            description: "Animate only while the desktop is visible."
            Toggle { checked: Config.livePauseWhenCovered; onToggled: v => Config.livePauseWhenCovered = v }
        }
        SegItem {
            icon: "slow_motion_video"
            hue: 4
            lobes: 4
            title: "Smoothness"
            description: "Higher is smoother and uses more power."
            extra: Choice {
                Layout.fillWidth: true
                segmentWidth: (width - 8) / 3
                value: Config.liveFps
                options: [
                    { value: 15, label: "15 fps" },
                    { value: 30, label: "30 fps" },
                    { value: 60, label: "60 fps" }
                ]
                onPicked: v => Config.liveFps = v
            }
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
