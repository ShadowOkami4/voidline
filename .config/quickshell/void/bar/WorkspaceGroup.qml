import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"

Item {
    id: root

    property var shellScreen

    implicitWidth: centerRow.implicitWidth
    implicitHeight: Theme.barHeight

    RowLayout {
        id: centerRow
        anchors.centerIn: parent
        spacing: 7

        MusicButton {
            shellScreen: root.shellScreen
            visible: Appearance.musicPlacement === "bar"
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: Theme.outlineSoft
            visible: Appearance.musicPlacement === "bar"
        }

        IconButton {
            icon: "apps"
            accessibleName: "Launcher"
            active: ShellState.isLauncherScreen(root.shellScreen)
            onClicked: ShellState.toggleLauncher(root.shellScreen)
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: Theme.outlineSoft
            visible: Appearance.workspacePlacement === "center"
        }

        WorkspaceIndicator {
            visible: Appearance.workspacePlacement === "center"
        }
    }
}
