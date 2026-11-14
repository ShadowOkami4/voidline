import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets
import "../services/EmojiData.js" as EmojiData

// Emoji picker: type to search by name, Enter or click copies the emoji to
// the clipboard (paste it with Ctrl+V).
PanelSurface {
    id: root

    open: Shell.panel === "emoji"
    anchor: Style.launcherAnchor
    panelWidth: 520
    panelHeight: 460

    readonly property var shown: {
        const words = search.text.trim().toLowerCase().split(/\s+/).filter(w => w.length > 0)
        if (words.length === 0) return EmojiData.list
        return EmojiData.list.filter(e => words.every(w => e[1].includes(w)))
    }
    onOpenChanged: if (open) { search.text = ""; grid.currentIndex = 0; search.forceActiveFocus() }
    onShownChanged: grid.currentIndex = 0

    function take(entry) {
        if (!entry) return
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", entry[0]])
        Shell.close()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: height / 2
            color: Theme.surfaceContainerHighest
            MIcon { id: glass; x: 18; anchors.verticalCenter: parent.verticalCenter; icon: "mood"; size: 22; color: Theme.inkMuted }
            TextInput {
                id: search
                anchors.left: glass.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                selectionColor: Theme.primaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.textTitle
                clip: true
                Keys.onEscapePressed: Shell.close()
                Keys.onReturnPressed: root.take(root.shown[grid.currentIndex])
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Label {
                    visible: search.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search emoji"
                    color: Theme.inkMuted
                    font.pixelSize: Theme.textTitle
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Math.floor(width / 9)
            cellHeight: cellWidth
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Motion.effects
            highlight: Rectangle { radius: Theme.cornerL; color: Theme.secondaryContainer }

            delegate: Pressable {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                restRadius: Theme.cornerL
                pressedRadius: Theme.cornerM
                onClicked: root.take(modelData)
                onHoveredChanged: if (hovered) grid.currentIndex = index
                Text {
                    anchors.centerIn: parent
                    text: cell.modelData[0]
                    font.pixelSize: 28
                    font.family: "Noto Color Emoji"
                }
            }

            Label {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: "No emoji found"
                color: Theme.inkMuted
            }
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.shown[grid.currentIndex] ? root.shown[grid.currentIndex][1] : ""
            font.pixelSize: Theme.textLabel
            color: Theme.inkMuted
        }
    }
}
