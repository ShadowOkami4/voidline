import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// The menu of a tray icon (Discord, Steam, ...), drawn in Voidline's own look.
// Submenus open in place with a back button instead of flying out sideways.
PanelSurface {
    id: root

    open: Shell.panel === "tray" && !!Shell.trayItem
    anchor: Style.quickAnchor
    panelWidth: 320
    panelHeight: column.implicitHeight + 28

    readonly property var item: Shell.trayItem
    // Submenus entered so far; the last one is on show.
    property var trail: []
    onOpenChanged: trail = []
    onItemChanged: trail = []

    QsMenuOpener {
        id: opener
        menu: root.trail.length > 0 ? root.trail[root.trail.length - 1] : (root.item ? root.item.menu : null)
    }
    readonly property var entries: opener.children ? opener.children.values : []

    ColumnLayout {
        id: column
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            spacing: 10
            IconBtn {
                visible: root.trail.length > 0
                icon: "arrow_back"
                size: 36
                tonal: true
                onClicked: root.trail = root.trail.slice(0, -1)
            }
            IconImage {
                visible: root.trail.length === 0
                Layout.leftMargin: 6
                implicitSize: 22
                source: root.item ? root.item.icon : ""
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.trail.length > 0 ? root.trail[root.trail.length - 1].text.replace(/_/g, "")
                    : (root.item ? (root.item.tooltipTitle || root.item.title || root.item.id) : "")
                font.pixelSize: Theme.textTitle
                font.weight: Font.Black
            }
        }

        Label {
            visible: root.entries.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            horizontalAlignment: Text.AlignHCenter
            text: root.item && root.item.hasMenu ? "Loading…" : "This icon has no menu"
            color: Theme.inkMuted
        }

        Repeater {
            model: root.entries

            Item {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: modelData.isSeparator ? 9 : 40

                Rectangle {
                    visible: row.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Theme.outlineVariant
                }
                Pressable {
                    visible: !row.modelData.isSeparator
                    anchors.fill: parent
                    enabledInput: row.modelData.enabled
                    opacity: row.modelData.enabled ? 1 : 0.45
                    restRadius: Theme.cornerM
                    pressedRadius: Theme.cornerS
                    onClicked: {
                        if (row.modelData.hasChildren) root.trail = root.trail.concat([row.modelData])
                        else { row.modelData.triggered(); Shell.close() }
                    }

                    // Tick or radio mark, then the entry's own icon, then the text.
                    MIcon {
                        id: mark
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        visible: row.modelData.buttonType !== QsMenuButtonType.None
                        icon: row.modelData.checkState === Qt.Checked
                            ? (row.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio_button_checked" : "check")
                            : (row.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio_button_unchecked" : "")
                        size: 18
                        color: Theme.primary
                    }
                    IconImage {
                        id: glyph
                        x: mark.visible ? 36 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.icon.length > 0
                        implicitSize: 18
                        source: row.modelData.icon
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: (mark.visible ? 36 : 10) + (glyph.visible ? 28 : 4)
                        anchors.right: more.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        // Menus mark keyboard shortcuts with an underscore.
                        text: row.modelData.text.replace(/_/g, "")
                    }
                    MIcon {
                        id: more
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.hasChildren
                        icon: "chevron_right"
                        size: 20
                        color: Theme.inkMuted
                    }
                }
            }
        }
    }
}
