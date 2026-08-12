import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"
import "../core"
import "../services"

PanelWindow {
    id: root

    property var parentBar
    property bool isClosing: false
    property bool surfaceExpanded: false
    property bool contentReady: false
    property bool lyricsVisible: false
    property real trackReveal: 1

    readonly property bool isOpen: parentBar && ShellState.isMusicScreen(parentBar.screen)
    readonly property bool surfaceActive: isOpen || isClosing
    readonly property int cornerSize: Metrics.concaveRadius
    readonly property int bodyWidth: Metrics.panelMedium
    readonly property int bodyHeight: 578 + (lyricsVisible ? 126 : 0)
    readonly property int collapsedWidth: 112

    screen: parentBar ? parentBar.screen : null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    focusable: isOpen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-music"
    visible: true
    color: "transparent"

    mask: Region {
        x: root.surfaceActive ? attachedSurface.x : 0
        y: root.surfaceActive ? attachedSurface.y : 0
        width: root.surfaceActive ? attachedSurface.width : 0
        height: root.surfaceActive ? attachedSurface.height : 0
    }
    HyprlandWindow.visibleMask: Region {
        x: root.surfaceActive ? attachedSurface.x : 0
        y: root.surfaceActive ? attachedSurface.y : 0
        width: root.surfaceActive ? attachedSurface.width : 0
        height: root.surfaceActive ? attachedSurface.height : 0
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeTimer.stop()
            isClosing = false
            surfaceExpanded = false
            contentReady = false
            expandTimer.restart()
            revealTimer.restart()
        } else {
            expandTimer.stop()
            revealTimer.stop()
            contentReady = false
            surfaceExpanded = false
            isClosing = true
            closeTimer.restart()
        }
        MediaService.panelActive = isOpen
    }

    Connections {
        target: MediaService.activePlayer
        ignoreUnknownSignals: true
        function onPostTrackChanged() {
            trackChange.restart()
        }
    }

    SequentialAnimation {
        id: trackChange
        NumberAnimation {
            target: root; property: "trackReveal"; to: 0
            duration: Motion.fast; easing.type: Motion.exitCurve
        }
        NumberAnimation {
            target: root; property: "trackReveal"; to: 1
            duration: Motion.pageEnter; easing.type: Motion.enterCurve
        }
    }

    Timer {
        id: expandTimer
        interval: 12
        onTriggered: root.surfaceExpanded = true
    }
    Timer {
        id: revealTimer
        interval: Motion.launcherContentDelay
        onTriggered: root.contentReady = true
    }
    Timer {
        id: closeTimer
        interval: Motion.launcherMorph + 16
        onTriggered: root.isClosing = false
    }

    HyprlandFocusGrab {
        active: root.isOpen
        windows: [root]
        onCleared: ShellState.closePanels()
    }

    Item {
        id: attachedSurface
        readonly property bool topAttached: Appearance.barPosition === "top"
        readonly property bool bottomAttached: Appearance.barPosition === "bottom"
        readonly property bool leftAttached: Appearance.barPosition === "left"
        readonly property bool rightAttached: Appearance.barPosition === "right"
        readonly property bool horizontalAttached: topAttached || bottomAttached
        readonly property string placement: Appearance.musicPlacement
        x: horizontalAttached
            ? (placement === "clock" ? 18
                : (placement === "action" ? root.width - width - 70
                    : Math.round((root.width - width) / 2)))
            : (Appearance.barPosition === "left"
                ? Theme.sideBarWidth - 1
                : root.width - Theme.sideBarWidth - width + 1)
        y: topAttached ? Theme.barHeight - 1
            : (bottomAttached ? root.height - Theme.barHeight - height + 1
                : (placement === "clock" ? 18
                    : (placement === "action"
                        ? Math.max(18, root.height - height - 170)
                        : Math.round((root.height - height) / 2))))
        width: root.surfaceExpanded
            ? root.bodyWidth + ((topAttached || bottomAttached)
                ? root.cornerSize * 2 : 0)
            : (topAttached || bottomAttached ? root.collapsedWidth : 0)
        height: root.surfaceExpanded
            ? root.bodyHeight + (topAttached || bottomAttached
                ? 0 : root.cornerSize * 2)
            : (topAttached || bottomAttached ? 0 : root.collapsedWidth)
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Motion.launcherMorph
                easing.type: Motion.morphCurve
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Motion.launcherMorph
                easing.type: Motion.morphCurve
            }
        }

        Shape {
            anchors { top: parent.top; left: parent.left }
            width: root.cornerSize
            height: root.cornerSize
            preferredRendererType: Shape.CurveRenderer
            visible: attachedSurface.topAttached
            ShapePath {
                id: leftJoinPath
                readonly property real curve: 0.5522847498
                strokeColor: "transparent"
                fillColor: Theme.panel
                startX: 0
                startY: 0
                PathLine { x: root.cornerSize; y: 0 }
                PathLine { x: root.cornerSize; y: root.cornerSize }
                PathCubic {
                    control1X: root.cornerSize
                    control1Y: root.cornerSize * (1 - leftJoinPath.curve)
                    control2X: root.cornerSize * leftJoinPath.curve
                    control2Y: 0
                    x: 0
                    y: 0
                }
            }
        }

        Shape {
            anchors { top: parent.top; right: parent.right }
            width: root.cornerSize
            height: root.cornerSize
            preferredRendererType: Shape.CurveRenderer
            visible: attachedSurface.topAttached
            ShapePath {
                id: rightJoinPath
                readonly property real curve: 0.5522847498
                strokeColor: "transparent"
                fillColor: Theme.panel
                startX: root.cornerSize
                startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: root.cornerSize }
                PathCubic {
                    control1X: 0
                    control1Y: root.cornerSize * (1 - rightJoinPath.curve)
                    control2X: root.cornerSize * (1 - rightJoinPath.curve)
                    control2Y: 0
                    x: root.cornerSize
                    y: 0
                }
            }
        }

        ConcaveJoin {
            x: 0
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-left"
            visible: attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-right"
            visible: attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: 0
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "left-top"
            visible: attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: 0
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "left-bottom"
            visible: attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "right-top"
            visible: attachedSurface.rightAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "right-bottom"
            visible: attachedSurface.rightAttached
        }

        Rectangle {
            id: panelBody
            x: attachedSurface.topAttached || attachedSurface.bottomAttached
                ? root.cornerSize : 0
            y: attachedSurface.topAttached || attachedSurface.bottomAttached
                ? 0 : root.cornerSize
            width: Math.max(1, attachedSurface.width
                - ((attachedSurface.topAttached || attachedSurface.bottomAttached)
                    ? root.cornerSize * 2 : 0))
            height: Math.max(1, attachedSurface.height
                - (attachedSurface.topAttached || attachedSurface.bottomAttached
                    ? 0 : root.cornerSize * 2))
            radius: Theme.panelRadius
            color: Theme.panel
            clip: true

            // Keep the attached edge flush with the bar while retaining the
            // large rounded corners at the bottom of the panel.
            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.topAttached
            }
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.bottomAttached
            }
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.leftAttached
            }
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.rightAttached
            }

            Item {
                anchors.fill: parent
                anchors.margins: Metrics.panelPadding
                opacity: root.contentReady ? 1 : 0
                transform: Translate {
                    y: root.contentReady ? 0 : -8
                    Behavior on y {
                        NumberAnimation {
                            duration: Motion.launcherContent
                            easing.type: root.isOpen ? Motion.enterCurve : Motion.exitCurve
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.launcherContent
                        easing.type: root.isOpen ? Motion.enterCurve : Motion.exitCurve
                    }
                }
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: Theme.radiusMedium
                            color: Theme.accentContainer
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "music_note"
                                size: 22
                                color: Theme.accent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                    Layout.fillWidth: true
                                    text: "Now playing"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                    font.pixelSize: 19
                                font.weight: Font.Bold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: MediaService.available
                                    ? MediaService.identity + (MediaService.players.length > 1
                                        ? " · click to switch player" : "")
                                    : "Media"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: playerChipLabel.implicitWidth + 22
                            Layout.preferredHeight: 34
                            radius: Theme.radiusMedium
                            color: playerChipHover.hovered && MediaService.players.length > 1
                                ? Theme.accentContainer : Theme.surfaceLow
                            visible: MediaService.available

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialIcon {
                                    text: "speaker"
                                    size: 15
                                    color: Theme.accent
                                }
                                Text {
                                    id: playerChipLabel
                                    text: MediaService.players.length > 1
                                        ? I18n.plural("music.players", MediaService.players.length)
                                        : I18n.tr("music.active")
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                            HoverHandler { id: playerChipHover }
                            TapHandler {
                                enabled: MediaService.players.length > 1
                                onTapped: MediaService.selectNextPlayer()
                            }
                        }
                        IconButton {
                            icon: "close"
                            accessibleName: I18n.tr("music.close")
                            onClicked: ShellState.closePanels()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 190
                        radius: Theme.radiusExtraLarge
                        color: Theme.groupSurfaceRaised
                        clip: true

                        Rectangle {
                            anchors {
                                right: parent.right
                                top: parent.top
                            }
                            width: 176
                            height: 112
                            radius: Theme.radiusExtraLarge
                            color: Theme.accentContainer
                            opacity: 0.36
                            transform: Rotation {
                                angle: -9
                                origin.x: 88
                                origin.y: 56
                            }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                margins: 14
                            }
                            spacing: 16

                            Rectangle {
                                Layout.preferredWidth: 162
                                Layout.preferredHeight: 162
                                radius: Theme.radiusLarge
                                color: Theme.accentContainer
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.accent, 0.34)
                                scale: (MediaService.playing ? 1 : 0.975)
                                    * (0.96 + root.trackReveal * 0.04)
                                opacity: 0.38 + root.trackReveal * 0.62

                                RoundedImage {
                                    anchors {
                                        fill: parent
                                        margins: 6
                                    }
                                    radius: Theme.radiusMedium
                                    source: MediaService.artwork
                                    fallbackIcon: "album"
                                    fallbackColor: Theme.surfaceHigh
                                    imageScale: MediaService.playing ? 1.02 : 1
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Motion.pageEnter
                                        easing.type: Motion.enterCurve
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                Item { Layout.fillHeight: true }
                                Rectangle {
                                    Layout.preferredWidth: sourceLabel.implicitWidth + 18
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusSmall
                                    color: Theme.accentContainer

                                    Text {
                                        id: sourceLabel
                                        anchors.centerIn: parent
                                        text: MediaService.identity
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: MediaService.title
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 23
                                    font.weight: Font.Bold
                                    font.letterSpacing: -0.3
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: MediaService.artist
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: MediaService.album
                                    visible: text.length > 0
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 62
                        radius: Theme.radiusLarge
                        color: Theme.surfaceHigh

                        ColumnLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                                topMargin: 10
                                bottomMargin: 8
                            }
                            spacing: 4

                            Rectangle {
                                id: progressTrack
                                Layout.fillWidth: true
                                Layout.preferredHeight: 10
                                radius: Metrics.trackRadius
                                color: Theme.surfaceLow

                                Rectangle {
                                    width: Math.max(height, parent.width * MediaService.progress)
                                    height: parent.height
                                    radius: Metrics.trackRadius
                                    color: Theme.accent
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Motion.launcherContent
                                            easing.type: Motion.standardCurve
                                        }
                                    }
                                }
                                Rectangle {
                                    x: Math.max(0, Math.min(parent.width - width,
                                        parent.width * MediaService.progress - width / 2))
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: progressHover.hovered || progressTap.pressed ? 16 : 10
                                    height: width
                                    radius: width / 2
                                    color: Theme.accent
                                    border.width: 2
                                    border.color: Theme.surfaceHigh

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Motion.fast
                                            easing.type: Motion.expressiveCurve
                                        }
                                    }
                                }
                                HoverHandler { id: progressHover }
                                TapHandler {
                                    id: progressTap
                                    enabled: MediaService.available
                                        && MediaService.activePlayer.canSeek
                                    onTapped: event => MediaService.seekTo(
                                        event.position.x / parent.width)
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: MediaService.formatTime(MediaService.position)
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: MediaService.length > 0
                                        ? "−" + MediaService.formatTime(
                                            Math.max(0, MediaService.length - MediaService.position))
                                        : "0:00"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    ExpressiveSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Metrics.sliderHeight
                        title: I18n.tr("music.volume")
                        subtitle: MediaService.available
                            && MediaService.activePlayer.volumeSupported
                            ? MediaService.identity : AudioService.outputName
                        valueText: Math.round((MediaService.available
                            && MediaService.activePlayer.volumeSupported
                                ? MediaService.activePlayer.volume
                                : AudioService.outputVolume) * 100) + "%"
                        from: 0
                        to: 1
                        value: MediaService.available
                            && MediaService.activePlayer.volumeSupported
                            ? MediaService.activePlayer.volume : AudioService.outputVolume
                        icon: "volume_up"
                        activeColor: Theme.tertiary
                        leadingColor: Theme.tertiaryContainer
                        leadingIconColor: Theme.tertiary
                        onMoved: value => {
                            if (MediaService.available
                                    && MediaService.activePlayer.volumeSupported)
                                MediaService.setPlayerVolume(value)
                            else
                                AudioService.setOutputVolume(value)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Metrics.controlL
                        spacing: Metrics.spaceS

                        ActionChip {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: "shuffle"
                            label: I18n.tr("music.shuffle")
                            active: MediaService.shuffled
                            available: MediaService.shuffleSupported
                            visible: MediaService.shuffleSupported
                            onClicked: MediaService.toggleShuffle()
                        }
                        ActionChip {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: MediaService.loopState === 1 ? "repeat_one" : "repeat"
                            label: I18n.tr("music.repeat")
                            active: MediaService.loopSupported && MediaService.loopState !== 0
                            available: MediaService.loopSupported
                            visible: MediaService.loopSupported
                            onClicked: MediaService.cycleLoop()
                        }
                        ActionChip {
                            visible: false
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: "queue_music"
                            label: I18n.tr("music.queue")
                            available: false
                        }
                        ActionChip {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: "lyrics"
                            label: I18n.tr("music.lyrics")
                            active: root.lyricsVisible
                            available: MediaService.lyrics.length > 0
                            visible: MediaService.lyrics.length > 0
                            onClicked: root.lyricsVisible = !root.lyricsVisible
                        }
                        ActionChip {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: "speaker"
                            label: I18n.tr("music.output")
                            onClicked: ShellState.openControlCenter("sound", root.screen)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.lyricsVisible ? 116 : 0
                        visible: height > 0
                        radius: Metrics.cardRadius
                        color: Theme.surfaceLow
                        clip: true
                        Text {
                            anchors.fill: parent
                            anchors.margins: Metrics.spaceM
                            text: MediaService.lyrics
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: Motion.panelResize; easing.type: Motion.morphCurve }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        radius: Theme.radiusLarge
                        color: Theme.surfaceLow

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 14

                            IconButton {
                                size: 42
                                icon: "replay_10"
                                accessibleName: I18n.tr("music.backTen")
                                enabled: MediaService.available
                                    && MediaService.activePlayer.canSeek
                                onClicked: MediaService.seekRelative(-10)
                            }
                            IconButton {
                                size: 46
                                icon: "skip_previous"
                                accessibleName: I18n.tr("music.previous")
                                enabled: MediaService.available
                                    && MediaService.activePlayer.canGoPrevious
                                onClicked: MediaService.previous()
                            }
                            Rectangle {
                                Layout.preferredWidth: 58
                                Layout.preferredHeight: 58
                                radius: Theme.radiusLarge
                                color: playTap.pressed
                                    ? Theme.accentStrong : Theme.accent
                                opacity: MediaService.available
                                    && MediaService.activePlayer.canTogglePlaying ? 1 : 0.45
                                scale: playTap.pressed ? 0.92 : 1
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: MediaService.playing ? "pause" : "play_arrow"
                                    size: 31
                                    color: Theme.accentInk
                                }
                                TapHandler {
                                    id: playTap
                                    enabled: MediaService.available
                                        && MediaService.activePlayer.canTogglePlaying
                                    onTapped: MediaService.togglePlaying()
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Motion.instant
                                        easing.type: Motion.expressiveCurve
                                    }
                                }
                            }
                            IconButton {
                                size: 46
                                icon: "skip_next"
                                accessibleName: I18n.tr("music.next")
                                enabled: MediaService.available
                                    && MediaService.activePlayer.canGoNext
                                onClicked: MediaService.next()
                            }
                            IconButton {
                                size: 42
                                icon: "forward_10"
                                accessibleName: I18n.tr("music.forwardTen")
                                enabled: MediaService.available
                                    && MediaService.activePlayer.canSeek
                                onClicked: MediaService.seekRelative(10)
                            }
                        }
                    }
                }
            }
        }
    }
}
