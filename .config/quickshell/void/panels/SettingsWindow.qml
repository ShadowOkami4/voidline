import Quickshell
import QtQuick
import "../core"

FloatingWindow {
    id: root

    title: I18n.tr("settings.windowTitle")
    implicitWidth: 1180
    implicitHeight: 820
    minimumSize: Qt.size(720, 600)
    visible: ShellState.settingsOpen
    color: Theme.panel

    SettingsPage {
        anchors.fill: parent
        active: root.visible
        shellScreen: root.screen
        onBack: ShellState.closeSettings()
    }

    onClosed: ShellState.closeSettings()
}
