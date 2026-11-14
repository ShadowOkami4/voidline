import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Now playing: cover, title, artist, transport buttons and progress.
// Expressive detail: the play button is round while paused and turns into a
// rounded square while playing.
Rectangle {
    id: root

    readonly property var player: Media.player
    readonly property bool timed: !!player && player.positionSupported && player.lengthSupported && player.length > 0
    readonly property real progress: timed ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    implicitHeight: body.implicitHeight + 28
    radius: Theme.cornerXL
    color: Theme.secondaryContainer

    // Players do not announce every second; ask while this card is on screen.
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && Media.playing && root.timed
        onTriggered: root.player.positionChanged()
    }

    ColumnLayout {
        id: body
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ClippingRectangle {
                implicitWidth: 64
                implicitHeight: 64
                radius: Theme.cornerL
                color: Theme.alpha(Theme.inkOnSecondaryContainer, 0.12)
                MIcon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    icon: "music_note"
                    filled: true
                    size: 30
                    color: Theme.inkOnSecondaryContainer
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 160
                    sourceSize.height: 160
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    Layout.fillWidth: true
                    text: Media.title || "Nothing playing"
                    elide: Text.ElideRight
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.Bold
                    color: Theme.inkOnSecondaryContainer
                }
                Label {
                    Layout.fillWidth: true
                    text: Media.artist || Media.source
                    elide: Text.ElideRight
                    font.pixelSize: Theme.textLabel + 1
                    color: Theme.inkOnSecondaryContainer
                    opacity: 0.8
                }
            }
        }

        // Progress
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.timed
            spacing: 4
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.alpha(Theme.inkOnSecondaryContainer, 0.18)
                Rectangle {
                    width: Math.max(height, parent.width * root.progress)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: root.timed ? root.clock(root.player.position) : ""
                    font.pixelSize: Theme.textLabelS
                    color: Theme.inkOnSecondaryContainer
                    opacity: 0.7
                }
                Label {
                    text: root.timed ? root.clock(root.player.length) : ""
                    font.pixelSize: Theme.textLabelS
                    color: Theme.inkOnSecondaryContainer
                    opacity: 0.7
                }
            }
        }

        // Transport
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            IconBtn {
                icon: "skip_previous"
                size: 46
                iconSize: 26
                enabledInput: !!root.player && root.player.canGoPrevious
                opacity: enabledInput ? 1 : 0.4
                onClicked: Media.previous()
            }
            Pressable {
                implicitWidth: 76
                implicitHeight: 54
                color: Theme.primary
                tint: Theme.inkOnPrimary
                restRadius: Media.playing ? Theme.cornerL : Theme.cornerFull
                pressedRadius: Theme.cornerM
                onClicked: Media.toggle()
                MIcon {
                    anchors.centerIn: parent
                    icon: Media.playing ? "pause" : "play_arrow"
                    filled: true
                    size: 30
                    color: Theme.inkOnPrimary
                }
            }
            IconBtn {
                icon: "skip_next"
                size: 46
                iconSize: 26
                enabledInput: !!root.player && root.player.canGoNext
                opacity: enabledInput ? 1 : 0.4
                onClicked: Media.next()
            }
        }
    }
}
