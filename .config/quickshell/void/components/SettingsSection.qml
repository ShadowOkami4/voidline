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
    // Plain sections skip the segmented row backgrounds, for content that
    // brings its own cards (for example the About tile grid).
    property bool plain: false
    default property alias contentData: bodyColumn.data

    width: parent && parent.isSettingsMasonry
        ? parent.itemWidth(fullWidth) : (parent ? parent.width : 0)
    spacing: Metrics.sectionHeaderGap

    // Android 16 section label: accent-coloured title with an optional
    // one-line explanation. Icons are kept only for callers that pass one.
    Column {
        width: parent.width
        visible: root.title.length > 0
        leftPadding: Metrics.spaceL
        rightPadding: Metrics.spaceL
        topPadding: Metrics.spaceS
        bottomPadding: 2
        spacing: 2

        Text {
            width: parent.width - parent.leftPadding - parent.rightPadding
            text: root.title
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextBody
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width - parent.leftPadding - parent.rightPadding
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextSupporting
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
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

                visible: !root.plain && body.rowShown(row)
                x: 0
                y: row ? row.y : 0
                width: body.width
                height: row ? row.height : 0
                color: Theme.surfaceContainerHigh
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
