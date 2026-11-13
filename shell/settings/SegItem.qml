import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// One entry of a SegGroup: shaped colour icon, title, description, a trailing
// control, and optional full-width content underneath (`extra`).
Rectangle {
    id: root

    property string icon: ""
    property int hue: 0             // picks the icon colour family
    property int lobes: 0           // icon container shape, see Blob
    property string title: ""
    property string description: ""
    property bool clickable: false
    default property alias control: slot.data
    property alias extra: below.data
    signal clicked()

    // Repeaters and empty loaders are children too; only count real rows.
    readonly property var siblings: parent ? parent.visibleChildren.filter(c => c.height > 0) : []
    readonly property bool first: siblings.length > 0 && siblings[0] === root
    readonly property bool last: siblings.length > 0 && siblings[siblings.length - 1] === root
    readonly property int outer: Theme.cornerXL
    readonly property int inner: area.pressed ? Theme.cornerL : Theme.cornerXS

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + 28
    color: Theme.surfaceContainerHigh
    topLeftRadius: first ? outer : inner
    topRightRadius: first ? outer : inner
    bottomLeftRadius: last ? outer : inner
    bottomRightRadius: last ? outer : inner
    Behavior on topLeftRadius { Spring {} }
    Behavior on topRightRadius { Spring {} }
    Behavior on bottomLeftRadius { Spring {} }
    Behavior on bottomRightRadius { Spring {} }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: parent.topLeftRadius
        topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius
        color: Theme.ink
        opacity: !root.clickable ? 0 : (area.pressed ? 0.12 : (area.containsMouse ? 0.06 : 0))
        Behavior on opacity { Fade {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: layout
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Item {
                visible: root.icon.length > 0
                implicitWidth: 42
                implicitHeight: 42
                Blob {
                    anchors.fill: parent
                    lobes: root.lobes
                    fill: Theme.hueContainer(root.hue)
                }
                MIcon {
                    anchors.centerIn: parent
                    icon: root.icon
                    size: 22
                    filled: true
                    color: Theme.hueInk(root.hue)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.description
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.textLabel + 1
                    color: Theme.inkMuted
                }
            }

            Item {
                id: slot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignVCenter
            }
        }

        ColumnLayout {
            id: below
            Layout.fillWidth: true
            visible: visibleChildren.length > 0
            spacing: 10
        }
    }
}
