import QtQuick
import "../components"
import "../core"

IconButton {
    id: root

    property var shellScreen
    icon: "music_note"
    accessibleName: "Media"
    active: ShellState.isMusicScreen(shellScreen)
    onClicked: ShellState.toggleMusic(shellScreen)
}
