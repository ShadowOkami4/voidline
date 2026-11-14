import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Clipboard history: type to filter, Enter or click to copy an entry again.
PanelSurface {
    id: root

    open: Shell.panel === "clipboard"
    anchor: Style.launcherAnchor
    panelWidth: 560
    panelHeight: 520

    readonly property var shown: {
        const q = search.text.trim().toLowerCase()
        return q.length === 0 ? Clipboard.entries : Clipboard.entries.filter(e => e.text.toLowerCase().includes(q))
    }
    onOpenChanged: if (open) { search.text = ""; view.currentIndex = 0; search.forceActiveFocus() }

    function take(entry) {
        if (!entry) return
        Clipboard.pick(entry.id)
        Shell.close()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: height / 2
                color: Theme.surfaceContainerHighest
                MIcon { id: glass; x: 18; anchors.verticalCenter: parent.verticalCenter; icon: "content_paste_search"; size: 22; color: Theme.inkMuted }
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
                    Keys.onReturnPressed: root.take(root.shown[view.currentIndex])
                    Keys.onDownPressed: view.incrementCurrentIndex()
                    Keys.onUpPressed: view.decrementCurrentIndex()
                    Label {
                        visible: search.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search the clipboard"
                        color: Theme.inkMuted
                        font.pixelSize: Theme.textTitle
                    }
                }
            }
            IconBtn {
                visible: Clipboard.entries.length > 0
                icon: "delete_sweep"
                size: 52
                tonal: true
                onClicked: Clipboard.clear()
            }
        }

        ListView {
            id: view
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown
            highlightMoveDuration: Motion.effects

            delegate: Pressable {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: view.currentIndex === index
                width: view.width
                height: 54
                color: current ? Theme.secondaryContainer : "transparent"
                restRadius: current ? Theme.cornerFull : Theme.cornerL
                pressedRadius: Theme.cornerM
                onClicked: root.take(modelData)
                onHoveredChanged: if (hovered) view.currentIndex = index

                MIcon {
                    id: kind
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    icon: row.modelData.image ? "image" : "notes"
                    size: 20
                    color: row.current ? Theme.inkOnSecondaryContainer : Theme.inkMuted
                }
                Label {
                    anchors.left: kind.right
                    anchors.leftMargin: 14
                    anchors.right: bin.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: row.modelData.image ? "Picture" : row.modelData.text.replace(/\s+/g, " ")
                    color: row.current ? Theme.inkOnSecondaryContainer : Theme.ink
                }
                IconBtn {
                    id: bin
                    visible: row.hovered || row.current
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    size: 36
                    onClicked: Clipboard.remove(row.modelData.id)
                }
            }

            Label {
                anchors.centerIn: parent
                width: parent.width - 60
                visible: view.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: !Clipboard.available ? "Clipboard history needs the packages “cliphist” and “wl-clipboard”."
                    : (search.text.length > 0 ? "Nothing matches" : "Nothing copied yet")
                color: Theme.inkMuted
            }
        }
    }
}
