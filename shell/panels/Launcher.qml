import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// App launcher: type to search, arrows to move, Enter to launch, Esc to close.
PanelSurface {
    id: root

    open: Shell.panel === "launcher"
    anchor: Style.launcherAnchor
    panelWidth: 680
    panelHeight: 540

    readonly property int columns: 6
    property var results: Apps.search(search.text)

    onOpenChanged: {
        if (open) { search.text = ""; grid.currentIndex = 0; search.forceActiveFocus() }
    }
    onResultsChanged: grid.currentIndex = 0

    function launch(entry) {
        if (!entry) return
        Apps.launch(entry)
        Shell.close()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: height / 2
            color: Theme.surfaceContainerHighest

            MIcon {
                id: searchIcon
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                icon: "search"
                size: 22
                color: Theme.inkMuted
            }
            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                selectionColor: Theme.primaryContainer
                selectedTextColor: Theme.inkOnPrimaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.textTitle
                clip: true

                Keys.onEscapePressed: Shell.close()
                Keys.onReturnPressed: root.launch(root.results[grid.currentIndex])
                Keys.onEnterPressed: root.launch(root.results[grid.currentIndex])
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onUpPressed: grid.moveCurrentIndexUp()

                Label {
                    visible: search.text.length === 0
                    text: "Search apps"
                    color: Theme.inkMuted
                    font.pixelSize: Theme.textTitle
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Math.floor(width / root.columns)
            cellHeight: 104
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Motion.effects
            highlight: Rectangle {
                radius: Theme.cornerLInc
                color: Theme.secondaryContainer
            }

            delegate: Pressable {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                restRadius: Theme.cornerLInc
                pressedRadius: Theme.cornerM
                onClicked: root.launch(modelData)
                onHoveredChanged: if (hovered) grid.currentIndex = index

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 44
                        icon: cell.modelData.icon
                        name: cell.modelData.name
                        scale: cell.pressed ? 0.88 : 1
                        Behavior on scale { Spring {} }
                    }
                    Label {
                        width: cell.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.Medium
                        color: grid.currentIndex === cell.index ? Theme.inkOnSecondaryContainer : Theme.ink
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: "No apps found"
                color: Theme.inkMuted
            }
        }
    }
}
