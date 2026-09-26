import QtQuick
import QtQuick.Layouts
import "../core"

Column {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color iconContainerColor: Theme.accentContainer
    property color iconColor: Theme.accent
    property bool fullWidth: false
    default property alias contentData: bodyColumn.data

    width: parent && parent.isSettingsMasonry
        ? parent.itemWidth(fullWidth) : (parent ? parent.width : 0)
    spacing: Metrics.sectionHeaderGap

    RowLayout {
        width: parent.width
        height: root.subtitle.length > 0
            ? Metrics.sectionHeaderHeight : Metrics.controlS
        spacing: Metrics.spaceS

        Rectangle {
            visible: root.icon.length > 0
            Layout.preferredWidth: Metrics.controlS
            Layout.preferredHeight: Metrics.controlS
            radius: Metrics.iconContainerRadius
            color: root.iconContainerColor

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Metrics.iconM
                color: root.iconColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextTitle
                font.weight: Font.DemiBold
                font.variableAxes: { "wght": 650, "wdth": 98, "opsz": 16 }
            }
            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextCaption
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }

    // Material 3 Expressive segmented group: every visible row sits on its own
    // tonal segment. Segments are separated by a small gap; the group's outer
    // corners are large while the corners between neighbours stay tight.
    Item {
        id: body
        width: parent.width
        implicitHeight: bodyColumn.implicitHeight

        function rowShown(item) {
            return item && item.visible && item.width > 0 && item.height > 0
        }
        function isFirst(index) {
            for (let i = index - 1; i >= 0; --i)
                if (rowShown(bodyColumn.children[i]))
                    return false
            return true
        }
        function isLast(index) {
            for (let i = index + 1; i < bodyColumn.children.length; ++i)
                if (rowShown(bodyColumn.children[i]))
                    return false
            return true
        }

        Repeater {
            model: bodyColumn.children.length

            Rectangle {
                required property int index
                readonly property Item row: bodyColumn.children[index] || null
                readonly property bool first: body.isFirst(index)
                readonly property bool last: body.isLast(index)
                readonly property int outer: Metrics.cardRadius
                readonly property int inner: Metrics.segmentInnerRadius

                visible: body.rowShown(row)
                x: 0
                y: row ? row.y : 0
                width: body.width
                height: row ? row.height : 0
                color: Theme.groupSurface
                topLeftRadius: first ? outer : inner
                topRightRadius: first ? outer : inner
                bottomLeftRadius: last ? outer : inner
                bottomRightRadius: last ? outer : inner
            }
        }

        Column {
            id: bodyColumn
            // Rows read this to drop their divider lines inside segmented groups.
            readonly property bool segmented: true
            width: parent.width
            spacing: Metrics.segmentGap
        }
    }
}
