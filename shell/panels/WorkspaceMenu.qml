import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Right click on a workspace dot: name the workspace, bring the active
// window over, or jump to one of the windows that live there.
PanelSurface {
    id: root

    open: Shell.panel === "workspace" && !!Shell.workspaceTarget
    anchor: Style.calendarAnchor
    panelWidth: 340
    panelHeight: column.implicitHeight + 32
    Behavior on panelHeight { Spring { duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }

    // The workspace as the compositor lists it now (the one that was clicked
    // may be an old copy by the time a button is pressed).
    readonly property var target: Shell.workspaceTarget
    readonly property var space: target ? (Compositor.workspaces.find(w => w.id === target.id) ?? target) : null
    readonly property var windows: space ? Compositor.windows.filter(w => w.workspace === space.id && !w.minimized) : []
    readonly property var active: Compositor.focusedWindow
    readonly property bool canBring: !!active && !!space && active.workspace !== space.id

    onOpenChanged: if (open && space) name.text = Config.workspaceName(space.index)

    ColumnLayout {
        id: column
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 10

        Label {
            leftPadding: 6
            text: root.space ? Lang.t("Workspace %1", root.space.index) : ""
            font.pixelSize: Theme.textTitle
            font.weight: Font.Black
            opacity: root.shown(0)
        }

        // The name is saved as you type.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 46
            radius: name.activeFocus ? Theme.cornerM : height / 2
            color: Theme.surfaceContainerHighest
            border.width: name.activeFocus ? 2 : 0
            border.color: Theme.primary
            opacity: root.shown(0.8)
            Behavior on radius { Spring {} }
            MIcon { id: pen; x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "edit"; size: 18; color: Theme.inkMuted }
            TextInput {
                id: name
                anchors.left: pen.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 14
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: 24
                color: Theme.ink
                selectionColor: Theme.primaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                clip: true
                onTextEdited: if (root.space) Config.setWorkspaceName(root.space.index, text)
                Keys.onReturnPressed: Shell.close()
                Keys.onEnterPressed: Shell.close()
                Keys.onEscapePressed: Shell.close()
                Label {
                    visible: name.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lang.t("Give it a name")
                    color: Theme.inkMuted
                }
            }
        }

        Pressable {
            Layout.fillWidth: true
            implicitHeight: 46
            enabledInput: root.canBring
            opacity: (root.canBring ? 1 : 0.45) * root.shown(1.6)
            color: Theme.primary
            restRadius: Theme.cornerFull
            onClicked: { Compositor.moveToWorkspace(root.active.id, root.space); Shell.close() }
            Row {
                anchors.centerIn: parent
                spacing: 8
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "move_item"; size: 20; color: Theme.inkOnPrimary }
                Label { anchors.verticalCenter: parent.verticalCenter; text: Lang.t("Move the active window here"); font.weight: Font.Bold; color: Theme.inkOnPrimary }
            }
        }

        Label {
            Layout.topMargin: 4
            leftPadding: 6
            text: root.windows.length > 0 ? Lang.t("Windows here") : Lang.t("No windows here")
            font.pixelSize: Theme.textLabel
            font.weight: Font.Bold
            color: Theme.inkMuted
            opacity: root.shown(2.4)
        }

        Repeater {
            model: root.windows.slice(0, 8)
            Pressable {
                id: row
                required property var modelData
                required property int index
                readonly property real arrived: root.shown(3 + index * 0.5)
                Layout.fillWidth: true
                implicitHeight: 46
                color: Theme.surfaceContainerHigh
                restRadius: Theme.cornerL
                opacity: arrived
                transform: Translate { y: (1 - row.arrived) * 14 }
                onClicked: { Shell.close(); Compositor.activate(modelData) }

                AppIcon {
                    id: face
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: 26
                    icon: Apps.iconNameFor(row.modelData.appId)
                    name: row.modelData.appId
                }
                Label {
                    anchors.left: face.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.title || row.modelData.appId
                    font.weight: row.modelData.focused ? Font.Bold : Font.Medium
                }
            }
        }
    }
}
