import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property var monitors: []
    property string selectedName: ""
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property real panStartX: 0
    property real panStartY: 0
    property real pointerStartX: 0
    property real pointerStartY: 0
    signal selected(string name)
    signal monitorMoved(string name, real x, real y)

    implicitHeight: Math.round(360 * Metrics.scale)
    radius: Metrics.cardRadius
    color: Theme.groupSurface
    border.width: Metrics.border
    border.color: Theme.outlineSoft
    clip: true

    readonly property real toolbarHeight: Math.round(54 * Metrics.scale)
    readonly property real originX: width / 2 + panX
    readonly property real originY: toolbarHeight
        + (height - toolbarHeight) / 2 + panY

    function transformedWidth(monitor) {
        const transform = Number(monitor.transform) || 0
        const rotated = transform === 1 || transform === 3
            || transform === 5 || transform === 7
        const extent = rotated ? Number(monitor.height) : Number(monitor.width)
        return Math.max(1, extent / Math.max(0.25, Number(monitor.scale) || 1))
    }

    function transformedHeight(monitor) {
        const transform = Number(monitor.transform) || 0
        const rotated = transform === 1 || transform === 3
            || transform === 5 || transform === 7
        const extent = rotated ? Number(monitor.width) : Number(monitor.height)
        return Math.max(1, extent / Math.max(0.25, Number(monitor.scale) || 1))
    }

    function extreme(axis, maximum) {
        let result = 0
        for (let index = 0; index < monitors.length; ++index) {
            const monitor = monitors[index]
            const position = Number(monitor[axis]) || 0
            const extent = axis === "x"
                ? transformedWidth(monitor) : transformedHeight(monitor)
            result = maximum ? Math.max(result, position + extent)
                : Math.min(result, position)
        }
        return result
    }

    readonly property real worldHalfWidth: Math.max(960,
        Math.abs(extreme("x", false)), Math.abs(extreme("x", true)))
    readonly property real worldHalfHeight: Math.max(540,
        Math.abs(extreme("y", false)), Math.abs(extreme("y", true)))
    readonly property real fitScale: Math.max(0.025, Math.min(
        Math.max(1, width - Metrics.spaceXXL * 2) / (worldHalfWidth * 2),
        Math.max(1, height - toolbarHeight - Metrics.spaceXL * 2)
            / (worldHalfHeight * 2)))
    readonly property real previewScale: fitScale * zoom

    function resetView() {
        zoom = 1
        panX = 0
        panY = 0
    }

    function snappedPosition(movingMonitor, proposedX, proposedY) {
        const threshold = Math.max(18, 22 / Math.max(0.025, previewScale))
        const width = transformedWidth(movingMonitor)
        const height = transformedHeight(movingMonitor)
        let resultX = proposedX
        let resultY = proposedY
        let bestX = threshold + 1
        let bestY = threshold + 1

        const xCandidates = [0]
        const yCandidates = [0]
        for (let index = 0; index < monitors.length; ++index) {
            const other = monitors[index]
            if (other.name === movingMonitor.name)
                continue
            const ox = Number(other.x) || 0
            const oy = Number(other.y) || 0
            const ow = transformedWidth(other)
            const oh = transformedHeight(other)
            xCandidates.push(ox, ox + ow, ox - width, ox + ow - width)
            yCandidates.push(oy, oy + oh, oy - height, oy + oh - height)
        }

        for (let xIndex = 0; xIndex < xCandidates.length; ++xIndex) {
            const distance = Math.abs(proposedX - xCandidates[xIndex])
            if (distance < bestX && distance <= threshold) {
                bestX = distance
                resultX = xCandidates[xIndex]
            }
        }
        for (let yIndex = 0; yIndex < yCandidates.length; ++yIndex) {
            const distance = Math.abs(proposedY - yCandidates[yIndex])
            if (distance < bestY && distance <= threshold) {
                bestY = distance
                resultY = yCandidates[yIndex]
            }
        }
        return { x: Math.round(resultX), y: Math.round(resultY) }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: mouse => {
            root.pointerStartX = mouse.x
            root.pointerStartY = mouse.y
            root.panStartX = root.panX
            root.panStartY = root.panY
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return
            root.panX = root.panStartX + mouse.x - root.pointerStartX
            root.panY = root.panStartY + mouse.y - root.pointerStartY
        }
        onWheel: wheel => {
            const factor = wheel.angleDelta.y > 0 ? 1.12 : 0.89
            root.zoom = Math.max(0.55, Math.min(2.8, root.zoom * factor))
            wheel.accepted = true
        }
    }

    Rectangle {
        x: root.originX
        y: root.toolbarHeight
        width: Metrics.border
        height: parent.height - root.toolbarHeight
        color: Theme.withAlpha(Theme.outline, 0.28)
    }
    Rectangle {
        x: 0
        y: root.originY
        width: parent.width
        height: Metrics.border
        color: Theme.withAlpha(Theme.outline, 0.28)
    }
    Rectangle {
        x: root.originX - 3
        y: root.originY - 3
        width: 7
        height: 7
        radius: 4
        color: Theme.accent
    }
    Text {
        x: root.originX + Metrics.spaceXS
        y: root.originY + Metrics.spaceXS
        text: "0, 0"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.textCaption
    }

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: Metrics.cardPadding
            rightMargin: Metrics.spaceS
        }
        height: root.toolbarHeight
        spacing: Metrics.spaceS

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: I18n.tr("display.arrangement")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.textBody
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: I18n.tr("display.arrangeHint")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.textCaption
                elide: Text.ElideRight
            }
        }
        IconButton {
            icon: "remove"
            accessibleName: I18n.tr("display.zoomOut")
            onClicked: root.zoom = Math.max(0.55, root.zoom / 1.15)
        }
        IconButton {
            icon: "add"
            accessibleName: I18n.tr("display.zoomIn")
            onClicked: root.zoom = Math.min(2.8, root.zoom * 1.15)
        }
        IconButton {
            icon: "fit_screen"
            accessibleName: I18n.tr("display.fitArrangement")
            onClicked: root.resetView()
        }
    }

    Repeater {
        model: root.monitors

        Item {
            id: displayItem
            required property var modelData

            x: root.originX + (Number(modelData.x) || 0) * root.previewScale
            y: root.originY + (Number(modelData.y) || 0) * root.previewScale
            width: Math.max(2, root.transformedWidth(modelData) * root.previewScale)
            height: Math.max(2, root.transformedHeight(modelData) * root.previewScale)
            z: dragArea.drag.active ? 5 : (root.selectedName === modelData.name ? 3 : 2)

            Rectangle {
                id: displayCard
                x: 0
                y: 0
                width: displayItem.width
                height: displayItem.height
                radius: Math.min(Metrics.tileRadius, height / 4)
                color: Theme.surfaceHigh
                border.width: root.selectedName === displayItem.modelData.name
                    ? Metrics.focusBorder : Metrics.border
                border.color: root.selectedName === displayItem.modelData.name
                    ? Theme.accent : Theme.outlineSoft
                clip: true

                Image {
                    anchors.fill: parent
                    source: Appearance.wallpaperPath.length > 0
                        ? "file://" + Appearance.wallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: status === Image.Ready ? 0.5 : 0
                }
                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha(Theme.background, 0.44)
                }

                Rectangle {
                    readonly property bool side: Appearance.barPosition === "left"
                        || Appearance.barPosition === "right"
                    x: Appearance.barPosition === "right" ? parent.width - width : 0
                    y: Appearance.barPosition === "bottom" ? parent.height - height : 0
                    width: side ? Math.max(3, Math.round(7 * Metrics.scale)) : parent.width
                    height: side ? parent.height : Math.max(3, Math.round(6 * Metrics.scale))
                    color: Theme.panel
                }

                Column {
                    anchors.centerIn: parent
                    width: Math.max(1, parent.width - Metrics.spaceM * 2)
                    spacing: 1
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: displayItem.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.min(Metrics.textBody,
                            Math.max(Metrics.textCaption, displayCard.height / 5))
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: displayCard.height >= 42
                        horizontalAlignment: Text.AlignHCenter
                        text: displayItem.modelData.width + " × "
                            + displayItem.modelData.height + "  ·  "
                            + Math.round((Number(displayItem.modelData.scale) || 1) * 100) + "%"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textCaption
                        elide: Text.ElideRight
                    }
                }

                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            MouseArea {
                id: dragArea
                anchors.fill: displayCard
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: displayCard
                drag.threshold: 4
                onPressed: root.selected(displayItem.modelData.name)
                onPositionChanged: mouse => {
                    if (!drag.active)
                        return
                    const point = mapToItem(root, mouse.x, mouse.y)
                    const edge = Math.round(30 * Metrics.scale)
                    const step = Math.round(7 * Metrics.scale)
                    if (point.x < edge)
                        root.panX += step
                    else if (point.x > root.width - edge)
                        root.panX -= step
                    if (point.y < root.toolbarHeight + edge)
                        root.panY += step
                    else if (point.y > root.height - edge)
                        root.panY -= step
                }
                onReleased: {
                    const proposedX = (displayItem.x + displayCard.x - root.originX)
                        / root.previewScale
                    const proposedY = (displayItem.y + displayCard.y - root.originY)
                        / root.previewScale
                    const result = root.snappedPosition(displayItem.modelData,
                        proposedX, proposedY)
                    displayCard.x = 0
                    displayCard.y = 0
                    root.monitorMoved(displayItem.modelData.name, result.x, result.y)
                }
            }
        }
    }
}
