import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

// Now-playing card for the Quick Settings shade.
Rectangle {
    id: root

    implicitHeight: Math.round(92 * Metrics.scale)
    radius: Metrics.radiusXL
    color: Theme.accentContainer
    clip: true

    RowLayout {
        anchors {
            fill: parent
            margins: Metrics.spaceL
        }
        spacing: Metrics.spaceM

        RoundedImage {
            Layout.preferredWidth: Math.round(64 * Metrics.scale)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Metrics.radiusL
            source: MediaService.artwork
            fallbackIcon: "album"
            fallbackColor: Theme.tertiary
            fallbackIconSize: Math.round(40 * Metrics.scale)
            fallbackIconColor: Theme.tertiaryContainerInk
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: MediaService.title
                color: Theme.accentContainerInk
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(16 * Metrics.scale)
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: [MediaService.artist, MediaService.identity].filter(Boolean).join(" · ")
                color: Theme.accentContainerInk
                opacity: 0.75
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(13 * Metrics.scale)
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceS
                height: Math.round(6 * Metrics.scale)
                radius: height / 2
                color: Theme.withAlpha(Theme.accentContainerInk, 0.25)

                Rectangle {
                    width: parent.width * MediaService.progress
                    height: parent.height
                    radius: height / 2
                    color: Theme.accentContainerInk
                }
                TapHandler {
                    onTapped: eventPoint => MediaService.seekTo(
                        eventPoint.position.x / Math.max(1, parent.width))
                }
            }
        }

        Row {
            spacing: Metrics.spaceXS

            IconButton {
                icon: "skip_previous"
                size: Math.round(40 * Metrics.scale)
                accessibleName: I18n.tr("music.previous")
                onClicked: MediaService.previous()
            }
            Rectangle {
                width: Math.round(48 * Metrics.scale)
                height: width
                radius: playTap.pressed ? width / 2 : (MediaService.playing ? Metrics.radiusL : width / 2)
                color: Theme.accent
                Accessible.role: Accessible.Button

                Behavior on radius {
                    NumberAnimation {
                        duration: Motion.springFast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialFast
                    }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    text: MediaService.playing ? "pause" : "play_arrow"
                    size: Math.round(28 * Metrics.scale)
                    fill: 1
                    color: Theme.accentInk
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: playTap
                    onTapped: MediaService.togglePlaying()
                }
            }
            IconButton {
                icon: "skip_next"
                size: Math.round(40 * Metrics.scale)
                accessibleName: I18n.tr("music.next")
                onClicked: MediaService.next()
            }
        }
    }
}
