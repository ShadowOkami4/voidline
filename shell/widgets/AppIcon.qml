import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.core

// Themed app icon. If the icon theme has no match, shows a tonal tile with
// the app's first letter instead of a broken-image placeholder.
Item {
    id: root

    property string icon: ""
    property string name: ""
    property int size: 32
    readonly property string path: icon.startsWith("/") ? "file://" + icon
        : (icon.length > 0 ? Quickshell.iconPath(icon, true) : "")

    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        visible: root.path.length > 0
        source: root.path
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: root.path.length === 0
        radius: width * 0.3
        color: Theme.tertiaryContainer
        Text {
            anchors.centerIn: parent
            text: (root.name || "?").charAt(0).toUpperCase()
            color: Theme.inkOnTertiaryContainer
            font.family: Theme.font
            font.pixelSize: root.size * 0.5
            font.weight: Font.Bold
        }
    }
}
