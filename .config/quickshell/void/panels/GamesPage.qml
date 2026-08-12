import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

FocusScope {
    id: root

    property bool active: false
    property string query: ""
    property int selectedIndex: 0
    property int artworkSelectedIndex: 0
    property bool artworkPickerOpen: false
    property var shellScreen

    signal back()
    signal requestSearchFocus()

    readonly property int availableWidth: shellScreen ? shellScreen.width : 1920
    readonly property int requestedBodyWidth: Math.max(520, Math.min(880, availableWidth - 100))
    readonly property int requestedBodyHeight: 500
    readonly property var visibleGames: SteamGameService.filteredGames(query)
    readonly property var artworkChoices: SteamGameService.artworkChoices || []

    function selectOffset(offset) {
        if (visibleGames.length === 0)
            return
        selectedIndex = (selectedIndex + offset + visibleGames.length) % visibleGames.length
        gameCarousel.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function launchSelected() {
        if (selectedIndex < 0 || selectedIndex >= visibleGames.length)
            return
        SteamGameService.launch(visibleGames[selectedIndex])
        ShellState.closePanels()
    }

    function openArtworkPicker(game) {
        if (!game)
            return
        artworkPickerOpen = true
        artworkSelectedIndex = 0
        SteamGameService.requestArtworkChoices(game)
        forceActiveFocus()
    }

    function closeArtworkPicker() {
        artworkPickerOpen = false
        requestSearchFocus()
    }

    function moveArtworkSelection(offset) {
        const choices = root.artworkChoices
        if (choices.length === 0)
            return
        artworkSelectedIndex = Math.max(0,
            Math.min(choices.length - 1, artworkSelectedIndex + offset))
        artworkGrid.positionViewAtIndex(artworkSelectedIndex, GridView.Contain)
    }

    function applySelectedArtwork() {
        const choices = root.artworkChoices
        if (artworkSelectedIndex < 0 || artworkSelectedIndex >= choices.length)
            return
        SteamGameService.selectArtwork(choices[artworkSelectedIndex])
    }

    onActiveChanged: {
        if (!active)
            return
        selectedIndex = 0
        artworkPickerOpen = false
        SteamGameService.refresh(false)
    }

    onVisibleGamesChanged: selectedIndex = visibleGames.length > 0
        ? Math.min(selectedIndex, visibleGames.length - 1) : -1

    Keys.onPressed: event => {
        if (artworkPickerOpen && (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace)) {
            root.closeArtworkPicker()
            event.accepted = true
        } else if (artworkPickerOpen && event.key === Qt.Key_Left) {
            root.moveArtworkSelection(-1)
            event.accepted = true
        } else if (artworkPickerOpen && event.key === Qt.Key_Right) {
            root.moveArtworkSelection(1)
            event.accepted = true
        } else if (artworkPickerOpen && event.key === Qt.Key_Up) {
            root.moveArtworkSelection(-4)
            event.accepted = true
        } else if (artworkPickerOpen && event.key === Qt.Key_Down) {
            root.moveArtworkSelection(4)
            event.accepted = true
        } else if (artworkPickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.applySelectedArtwork()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            root.back()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.selectOffset(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            root.selectOffset((event.modifiers & Qt.ShiftModifier) !== 0 ? -1 : 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launchSelected()
            event.accepted = true
        }
    }

    ColumnLayout {
        id: libraryPage
        anchors.fill: parent
        spacing: 14
        visible: !root.artworkPickerOpen

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: Theme.radiusLarge
            color: Theme.surfaceHigh

            IconButton {
                id: gamesBack
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: "arrow_back"
                accessibleName: I18n.tr("games.backToCommands")
                onClicked: root.back()
            }
            Rectangle {
                id: gamesHeaderIcon
                anchors {
                    left: gamesBack.right
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 48
                height: 48
                radius: Theme.radiusMedium
                color: Theme.accentContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "sports_esports"
                    size: 25
                    color: Theme.accent
                }
            }
            IconButton {
                id: gamesRefresh
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: "refresh"
                accessibleName: I18n.tr("games.refresh")
                onClicked: SteamGameService.refresh(true)
            }
            Rectangle {
                id: artworkStatus
                anchors {
                    right: gamesRefresh.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: artworkStatusContent.implicitWidth + 24
                height: 36
                radius: Theme.radiusMedium
                color: SteamGameService.apiConfigured
                    ? Theme.accentContainer : Theme.surface
                RowLayout {
                    id: artworkStatusContent
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon {
                        text: SteamGameService.artworkRefreshing ? "progress_activity"
                            : (SteamGameService.apiConfigured ? "imagesmode" : "cloud_off")
                        size: 16
                        color: SteamGameService.apiConfigured ? Theme.accent : Theme.textMuted
                    }
                    Text {
                        text: SteamGameService.artworkRefreshing ? I18n.tr("games.updating")
                            : (SteamGameService.apiConfigured ? I18n.tr("games.artwork")
                                : I18n.tr("games.offlineArtwork"))
                        color: SteamGameService.apiConfigured ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }
            ColumnLayout {
                anchors {
                    left: gamesHeaderIcon.right
                    leftMargin: 10
                    right: artworkStatus.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: -1
                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("games.title")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.plural("games.ready", root.visibleGames.length)
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        ListView {
            id: gameCarousel
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            visible: root.visibleGames.length > 0
            model: root.visibleGames
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            highlightMoveDuration: Motion.launcherContent
            cacheBuffer: 420

            delegate: Item {
                id: gameCard
                required property var modelData
                required property int index
                readonly property bool selected: index === root.selectedIndex
                width: 214
                height: gameCarousel.height
                scale: gameTap.pressed ? 0.98 : 1

                Rectangle {
                    id: gameSurface
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 4
                    radius: Theme.radiusExtraLarge
                    color: gameCard.selected ? Theme.accentContainer : Theme.surfaceHigh

                    RoundedImage {
                        id: gridImage
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 7
                        }
                        height: Math.max(220, parent.height - 76)
                        radius: Theme.radiusLarge
                        source: modelData.image
                        sourceSize: Qt.size(428, 642)
                        fallbackIcon: "sports_esports"
                        fallbackColor: Theme.surfaceLow

                    }

                    Rectangle {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 18
                        }
                        width: 40
                        height: 40
                        radius: Theme.radiusMedium
                        color: artworkHover.hovered
                            ? Theme.accent : Qt.rgba(0, 0, 0, 0.68)
                        z: 3
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "imagesmode"
                            size: 20
                            color: artworkHover.hovered ? Theme.accentInk : "white"
                        }
                        HoverHandler { id: artworkHover }
                        TapHandler { onTapped: root.openArtworkPicker(modelData) }
                        Behavior on color { ColorAnimation { duration: Motion.hover } }
                    }

                    Rectangle {
                        id: gameInfo
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            margins: 7
                        }
                        height: 61
                        radius: Theme.radiusMedium
                        color: gameCard.selected ? Theme.surface : Theme.surfaceLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 9
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: gameCard.selected ? Theme.accent : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.artworkSource
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: Theme.radiusMedium
                                color: gameHover.hovered || gameCard.selected
                                    ? Theme.accent : Theme.surfaceHigh
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "play_arrow"
                                    size: 23
                                    color: gameHover.hovered || gameCard.selected
                                        ? Theme.accentInk : Theme.textMuted
                                }
                                Behavior on color { ColorAnimation { duration: Motion.hover } }
                            }
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                HoverHandler {
                    id: gameHover
                    onHoveredChanged: {
                        if (hovered)
                            root.selectedIndex = gameCard.index
                    }
                }
                TapHandler {
                    id: gameTap
                    enabled: !artworkHover.hovered
                    onTapped: {
                        SteamGameService.launch(modelData)
                        ShellState.closePanels()
                    }
                }
                Behavior on scale { NumberAnimation { duration: Motion.instant; easing.type: Motion.standardCurve } }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !SteamGameService.apiConfigured
            spacing: 7
            MaterialIcon { text: "info"; size: 15; color: Theme.textMuted }
            Text {
                Layout.fillWidth: true
                text: I18n.tr("games.apiHint")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.visibleGames.length === 0
            spacing: 8
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: SteamGameService.loading ? "progress_activity" : "sports_esports"
                size: 36
                color: Theme.textMuted
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: SteamGameService.loading ? I18n.tr("games.scanning")
                    : (root.query.length > 0 ? I18n.tr("games.noMatches")
                        : SteamGameService.message)
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    ColumnLayout {
        id: artworkPage
        anchors.fill: parent
        spacing: 12
        visible: root.artworkPickerOpen

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: Theme.radiusLarge
            color: Theme.surfaceHigh

            IconButton {
                id: artworkBack
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: "arrow_back"
                accessibleName: I18n.tr("games.backToGames")
                onClicked: root.closeArtworkPicker()
            }
            Rectangle {
                id: artworkHeaderIcon
                anchors {
                    left: artworkBack.right
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 48
                height: 48
                radius: Theme.radiusMedium
                color: Theme.accentContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "imagesmode"
                    size: 24
                    color: Theme.accent
                }
            }
            Rectangle {
                id: pickerStatus
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: pickerSource.implicitWidth + 24
                height: 36
                radius: Theme.radiusMedium
                color: Theme.accentContainer
                RowLayout {
                    id: pickerSource
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon { text: "verified"; size: 15; color: Theme.accent }
                    Text {
                        text: I18n.tr("games.staticOnly")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }
            ColumnLayout {
                anchors {
                    left: artworkHeaderIcon.right
                    leftMargin: 10
                    right: pickerStatus.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: -1
                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("games.chooseArtwork")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: (SteamGameService.artworkChoiceGame
                        ? SteamGameService.artworkChoiceGame.name + " · " : "")
                        + I18n.tr("games.alternateStatic")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        GridView {
            id: artworkGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.artworkChoices.length > 0
            model: root.artworkChoices
            cellWidth: width / 4
            cellHeight: 300
            currentIndex: root.artworkSelectedIndex
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight

            delegate: Item {
                id: artworkChoice
                required property var modelData
                required property int index
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(194, parent.width - 10)
                    height: 288
                    radius: Theme.radiusExtraLarge
                    color: artworkChoice.index === root.artworkSelectedIndex
                        ? Theme.accentContainer : Theme.surfaceHigh
                    scale: choiceTap.pressed ? 0.98 : 1

                    RoundedImage {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: Theme.radiusLarge
                        source: modelData.thumb
                        sourceSize: Qt.size(388, 576)
                        fallbackIcon: "image"
                        fallbackColor: Theme.surfaceLow

                    }

                    Rectangle {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 14
                        }
                        width: 40
                        height: 40
                        radius: Theme.radiusMedium
                        color: artworkChoice.index === root.artworkSelectedIndex
                            ? Theme.accent : Qt.rgba(0, 0, 0, 0.64)
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: SteamGameService.artworkSelecting
                                && artworkChoice.index === root.artworkSelectedIndex
                                ? "progress_activity" : "check"
                            size: 20
                            color: artworkChoice.index === root.artworkSelectedIndex
                                ? Theme.accentInk : "white"
                        }
                        Behavior on color { ColorAnimation { duration: Motion.hover } }
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                root.artworkSelectedIndex = artworkChoice.index
                        }
                    }
                    TapHandler {
                        id: choiceTap
                        enabled: !SteamGameService.artworkSelecting
                        onTapped: {
                            root.artworkSelectedIndex = artworkChoice.index
                            SteamGameService.selectArtwork(modelData)
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Motion.hover } }
                    Behavior on scale { NumberAnimation { duration: Motion.instant; easing.type: Motion.standardCurve } }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.artworkChoices.length === 0
            spacing: 9
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: SteamGameService.artworkChoicesLoading ? "progress_activity" : "image_not_supported"
                size: 34
                color: Theme.textMuted
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: SteamGameService.artworkChoicesLoading
                    ? I18n.tr("games.loadingArtwork") : SteamGameService.artworkChoiceMessage
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    Connections {
        target: SteamGameService
        function onArtworkApplied(appId) {
            root.closeArtworkPicker()
        }
    }
}
