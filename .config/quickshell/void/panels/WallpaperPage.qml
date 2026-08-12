import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

FocusScope {
    id: root

    property bool active: false
    readonly property int requestedBodyWidth: 720
    readonly property int requestedBodyHeight: 610
    signal back()

    focus: active

    onActiveChanged: {
        if (active) {
            WallpaperService.refresh()
            forceActiveFocus()
        }
    }

    Keys.onEscapePressed: event => {
        root.back()
        event.accepted = true
    }

    Keys.onPressed: event => {
        const count = WallpaperService.wallpapers.length
        if (count === 0)
            return
        const columns = 3
        if (event.key === Qt.Key_Left)
            wallpaperGrid.currentIndex = Math.max(0, wallpaperGrid.currentIndex - 1)
        else if (event.key === Qt.Key_Right)
            wallpaperGrid.currentIndex = Math.min(count - 1, wallpaperGrid.currentIndex + 1)
        else if (event.key === Qt.Key_Up)
            wallpaperGrid.currentIndex = Math.max(0, wallpaperGrid.currentIndex - columns)
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
            wallpaperGrid.currentIndex = Math.max(0, Math.min(count - 1,
                wallpaperGrid.currentIndex
                    + (event.key === Qt.Key_Tab
                        ? ((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                        : columns)))
        else if (event.key === Qt.Key_PageUp)
            wallpaperGrid.currentIndex = Math.max(0, wallpaperGrid.currentIndex - columns * 3)
        else if (event.key === Qt.Key_PageDown)
            wallpaperGrid.currentIndex = Math.min(count - 1, wallpaperGrid.currentIndex + columns * 3)
        else if (event.key === Qt.Key_Home)
            wallpaperGrid.currentIndex = 0
        else if (event.key === Qt.Key_End)
            wallpaperGrid.currentIndex = count - 1
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            WallpaperService.applyWallpaper(
                WallpaperService.wallpapers[wallpaperGrid.currentIndex].path)
        else
            return
        wallpaperGrid.positionViewAtIndex(wallpaperGrid.currentIndex, GridView.Contain)
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: Theme.radiusLarge
            color: Theme.surfaceHigh

            IconButton {
                id: backButton
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: "arrow_back"
                accessibleName: "Back to commands"
                onClicked: root.back()
            }
            Rectangle {
                id: headerIcon
                anchors {
                    left: backButton.right
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 48
                height: 48
                radius: Theme.radiusMedium
                color: Theme.accentContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "wallpaper"
                    size: 23
                    color: Theme.accent
                }
            }
            ColumnLayout {
                anchors {
                    left: headerIcon.right
                    leftMargin: 10
                    right: refreshButton.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: "Wallpaper"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: WallpaperService.wallpapers.length + " local backgrounds"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
            IconButton {
                id: refreshButton
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                icon: "refresh"
                accessibleName: "Refresh wallpapers"
                onClicked: WallpaperService.refresh()
            }
        }

        GridView {
            id: wallpaperGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: WallpaperService.wallpapers
            cellWidth: width / 3
            cellHeight: 164
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight

            delegate: Item {
                id: wallpaperCell
                required property var modelData
                required property int index
                readonly property bool selected:
                    WallpaperService.currentPath === modelData.path
                readonly property bool keyboardSelected:
                    wallpaperGrid.currentIndex === index && root.activeFocus
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                Rectangle {
                    anchors {
                        fill: parent
                        margins: 5
                    }
                    radius: Theme.radiusLarge
                    color: wallpaperCell.selected ? Theme.accentContainer : Theme.surface
                    border.width: wallpaperCell.selected || wallpaperCell.keyboardSelected ? 2 : 1
                    border.color: wallpaperCell.keyboardSelected ? Theme.secondary
                        : (wallpaperCell.selected ? Theme.accent : Theme.outlineSoft)
                    clip: true
                    scale: wallpaperTap.pressed ? 0.975 : 1

                    RoundedImage {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 6
                        }
                        height: 112
                        source: "file://" + wallpaperCell.modelData.path
                        radius: Theme.radiusMedium
                        fallbackIcon: "broken_image"
                    }
                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 12
                            rightMargin: 10
                        }
                        height: 40
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: wallpaperCell.modelData.title
                            color: wallpaperCell.selected ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        MaterialIcon {
                            text: wallpaperCell.selected ? "check_circle" : "wallpaper"
                            size: 18
                            color: wallpaperCell.selected ? Theme.accent : Theme.textMuted
                        }
                    }

                    TapHandler {
                        id: wallpaperTap
                        onTapped: WallpaperService.applyWallpaper(wallpaperCell.modelData.path)
                    }
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.instant
                            easing.type: Motion.standardCurve
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: WallpaperService.wallpapers.length === 0
            spacing: 8
            Item { Layout.fillHeight: true }
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: WallpaperService.loading ? "progress_activity" : "image_not_supported"
                size: 34
                color: Theme.textMuted
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: WallpaperService.loading ? "Scanning backgrounds…"
                    : "No wallpapers found"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: WallpaperService.error.length > 0
                    ? WallpaperService.error
                    : "Add images to ~/.background or your Wallpapers folder"
                color: WallpaperService.error.length > 0 ? Theme.danger : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
            Item { Layout.fillHeight: true }
        }
    }
}
