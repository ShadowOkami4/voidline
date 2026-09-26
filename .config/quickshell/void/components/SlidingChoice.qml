import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property var options: []
    property var optionLabels: []
    property var disabledOptions: []
    property string value: ""
    property int maxColumns: 4
    property bool enabled: true
    signal selected(string value)

    readonly property int columns: Math.max(1,
        Math.min(maxColumns, options.length))
    readonly property int rows: Math.max(1,
        Math.ceil(options.length / columns))
    readonly property int selectedIndex:
        options.map(option => String(option)).indexOf(value)
    // Material 3 Expressive connected button group: segments touch through a
    // narrow gap, the outer ends are fully round, and the selected segment
    // morphs into a filled pill.
    readonly property real inset: 0
    readonly property real gap: Metrics.segmentGap
    readonly property real segmentWidth: (width - inset * 2
        - gap * (columns - 1)) / columns
    readonly property real segmentHeight: Metrics.minimumHitSize

    readonly property int pressedIndex: wholeControlTap.pressed
        ? indexAt(wholeControlTap.point.position.x, wholeControlTap.point.position.y)
        : -1

    implicitHeight: inset * 2 + rows * segmentHeight + gap * (rows - 1)
    radius: segmentHeight / 2
    color: "transparent"
    opacity: enabled ? 1 : 0.46
    clip: true
    activeFocusOnTab: enabled

    function optionIsEnabled(index) {
        if (!enabled || index < 0 || index >= options.length)
            return false
        return disabledOptions.indexOf(String(options[index])) < 0
            && disabledOptions.indexOf(index) < 0
    }

    function selectIndex(index) {
        if (!optionIsEnabled(index))
            return
        forceActiveFocus(Qt.TabFocusReason)
        selected(String(options[index]))
    }

    function indexAt(positionX, positionY) {
        const localX = positionX - inset
        const localY = positionY - inset
        if (localX < 0 || localY < 0)
            return -1
        const column = Math.floor(localX / (segmentWidth + gap))
        const row = Math.floor(localY / (segmentHeight + gap))
        if (column < 0 || column >= columns || row < 0 || row >= rows)
            return -1
        const withinColumn = localX - column * (segmentWidth + gap)
        const withinRow = localY - row * (segmentHeight + gap)
        if (withinColumn > segmentWidth || withinRow > segmentHeight)
            return -1
        const index = row * columns + column
        return index < options.length ? index : -1
    }

    function moveSelection(delta) {
        if (options.length === 0)
            return
        let index = selectedIndex >= 0 ? selectedIndex : 0
        for (let attempt = 0; attempt < options.length; ++attempt) {
            index = (index + delta + options.length) % options.length
            if (optionIsEnabled(index)) {
                selectIndex(index)
                return
            }
        }
    }

    Keys.onLeftPressed: event => {
        moveSelection(-1)
        event.accepted = true
    }
    Keys.onRightPressed: event => {
        moveSelection(1)
        event.accepted = true
    }
    Keys.onUpPressed: event => {
        moveSelection(-columns)
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        moveSelection(columns)
        event.accepted = true
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            for (let index = 0; index < options.length; ++index) {
                if (optionIsEnabled(index)) {
                    selectIndex(index)
                    break
                }
            }
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            for (let index = options.length - 1; index >= 0; --index) {
                if (optionIsEnabled(index)) {
                    selectIndex(index)
                    break
                }
            }
            event.accepted = true
        }
    }

    GridLayout {
        anchors {
            fill: parent
            margins: root.inset
        }
        columns: root.columns
        columnSpacing: root.gap
        rowSpacing: root.gap

        Repeater {
            model: root.options

            Item {
                id: optionItem
                required property int index
                required property var modelData
                readonly property bool isSelected:
                    String(modelData) === root.value
                readonly property bool optionEnabled:
                    root.optionIsEnabled(index)
                readonly property int column: index % root.columns
                readonly property bool rowStart: column === 0
                readonly property bool rowEnd: column === root.columns - 1
                    || index === root.options.length - 1
                readonly property bool isPressed: root.pressedIndex === index
                readonly property real full: height / 2
                readonly property real innerRadius: isPressed
                    ? Metrics.radiusXS : Metrics.pressedRadius

                Layout.fillWidth: true
                Layout.preferredHeight: root.segmentHeight
                opacity: optionEnabled ? 1 : 0.38

                Rectangle {
                    id: segment
                    anchors.fill: parent
                    color: optionItem.isSelected ? Theme.accent
                        : (optionHover.hovered && optionItem.optionEnabled
                            ? Theme.surfaceHover : Theme.groupSurfaceRaised)
                    topLeftRadius: optionItem.isSelected || optionItem.rowStart
                        ? optionItem.full : optionItem.innerRadius
                    bottomLeftRadius: topLeftRadius
                    topRightRadius: optionItem.isSelected || optionItem.rowEnd
                        ? optionItem.full : optionItem.innerRadius
                    bottomRightRadius: topRightRadius

                    Behavior on topLeftRadius {
                        NumberAnimation {
                            duration: Motion.springFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.spatialFast
                        }
                    }
                    Behavior on topRightRadius {
                        NumberAnimation {
                            duration: Motion.springFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.spatialFast
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
                }

                Text {
                    anchors {
                        fill: parent
                        leftMargin: Metrics.spaceS
                        rightMargin: Metrics.spaceS
                    }
                    text: root.optionLabels.length > optionItem.index
                        ? root.optionLabels[optionItem.index]
                        : String(optionItem.modelData)
                    color: optionItem.isSelected
                        ? Theme.accentInk : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextSupporting
                    font.weight: optionItem.isSelected
                        ? Font.Bold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight

                    Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
                }

                HoverHandler {
                    id: optionHover
                    cursorShape: optionItem.optionEnabled
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }

    // This handler sits at the shared control level so the gaps between
    // segments never become dead areas.
    TapHandler {
        id: wholeControlTap
        enabled: root.enabled
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint, button) => {
            root.selectIndex(root.indexAt(eventPoint.position.x,
                eventPoint.position.y))
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.activeFocus
            ? (Appearance.focusIndicators ? Metrics.focusBorder : Metrics.border)
            : 0
        border.color: Theme.accent
    }
}
