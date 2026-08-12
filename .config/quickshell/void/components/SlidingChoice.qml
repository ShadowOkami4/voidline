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
    readonly property real inset: Metrics.spaceXS
    readonly property real gap: Metrics.space2XS
    readonly property real segmentWidth: (width - inset * 2
        - gap * (columns - 1)) / columns
    readonly property real segmentHeight: Metrics.minimumHitSize

    implicitHeight: inset * 2 + rows * segmentHeight + gap * (rows - 1)
    radius: Theme.radiusLarge
    color: Theme.groupSurfaceRaised
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

    Rectangle {
        id: selectionBlob
        readonly property int selectedColumn: root.selectedIndex % root.columns
        readonly property int selectedRow: Math.floor(root.selectedIndex / root.columns)

        x: root.inset + selectedColumn * (root.segmentWidth + root.gap)
        y: root.inset + selectedRow * (root.segmentHeight + root.gap)
        width: root.segmentWidth
        height: root.segmentHeight
        radius: Metrics.stateRadius
        color: Theme.accentContainer
        visible: root.selectedIndex >= 0

        Behavior on x {
            NumberAnimation {
                duration: Motion.selectionSlide
                easing.type: Motion.expressiveCurve
                easing.overshoot: 0.24
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Motion.selectionSlide
                easing.type: Motion.expressiveCurve
                easing.overshoot: 0.18
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.standardCurve
            }
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

                Layout.fillWidth: true
                Layout.preferredHeight: root.segmentHeight
                scale: 1
                opacity: optionEnabled ? 1 : 0.38

                Text {
                    anchors {
                        fill: parent
                        leftMargin: 5
                        rightMargin: 5
                    }
                    text: root.optionLabels.length > optionItem.index
                        ? root.optionLabels[optionItem.index]
                        : String(optionItem.modelData)
                    color: optionItem.isSelected
                        ? Theme.accent : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: optionItem.isSelected
                        ? Font.Bold : Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                HoverHandler { id: optionHover }
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.instant
                        easing.type: Motion.standardCurve
                    }
                }
            }
        }
    }

    // This handler sits at the shared control level, including above the
    // animated selection blob. It fixes the dead area that previously appeared
    // when the indicator itself was clicked or touched.
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
