import QtQuick
import qs.core
import qs.widgets

// A panel body placed inside the full-screen PanelHost. In attached styles
// (Voidline) it grows out of the bar with concave joins; in floating styles
// it is a rounded card that springs in from its anchor.
Item {
    id: root

    property bool open: false
    property string anchor: "top-right"
    property int panelWidth: 400
    property int panelHeight: 400
    default property alias content: body.data
    readonly property bool showing: progress > 0.001
    readonly property bool attached: Style.attachedPanels && anchor.startsWith("top")
    readonly property bool isRight: anchor.endsWith("right")
    readonly property bool isTop: anchor.startsWith("top")
    readonly property color fill: attached ? Style.barColor : Theme.surfaceContainerLow
    readonly property int r: Style.frameRadius

    property real progress: open ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: root.open ? Motion.spatial : Motion.effectsSlow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Motion.spatialCurve : Motion.effectsSlowCurve
        }
    }

    anchors.fill: parent
    visible: showing

    // The host covers the work area, so (0, 0) is the corner just inside the
    // bar and frame.
    readonly property real px: anchor.endsWith("center") ? (width - panelWidth) / 2
        : width - panelWidth - (attached ? 0 : Style.panelGap)
    readonly property real py: anchor === "center" ? height * 0.16
        : (isTop ? (attached ? 0 : Style.panelGap) : height - Style.panelGap - panelHeight)

    Rectangle {
        id: card
        x: root.px
        y: root.py + (root.attached ? 0 : (root.isTop || root.anchor === "center" ? -1 : 1) * 24 * (1 - root.progress))
        width: root.panelWidth
        height: root.attached ? root.panelHeight * Math.min(1.04, root.progress) : root.panelHeight
        color: root.fill
        clip: true
        opacity: root.attached ? 1 : Math.min(1, root.progress * 1.6)
        scale: root.attached ? 1 : 0.94 + 0.06 * root.progress
        transformOrigin: root.anchor === "center" ? Item.Center
            : (root.isTop ? (root.isRight ? Item.TopRight : Item.Top) : (root.isRight ? Item.BottomRight : Item.Bottom))

        radius: root.attached ? 0 : Theme.cornerXL
        bottomLeftRadius: Theme.cornerXL
        bottomRightRadius: root.attached && root.isRight ? 0 : Theme.cornerXL
        border.width: root.attached ? 0 : 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.5)

        // Swallow clicks so they do not close the panel.
        MouseArea { anchors.fill: parent }

        Item {
            id: body
            width: root.panelWidth
            height: root.panelHeight
            opacity: Math.max(0, root.progress * 1.5 - 0.5)
        }
    }

    // Joins (attached only): bar -> panel on the left, and either bar -> panel
    // on the right (centred) or panel -> frame underneath (right aligned).
    ConcaveJoin {
        visible: root.attached
        x: card.x - width
        y: card.y
        height: Math.min(root.r, card.height)
        corner: "tr"
        fill: root.fill
    }
    ConcaveJoin {
        visible: root.attached && !root.isRight
        x: card.x + card.width
        y: card.y
        height: Math.min(root.r, card.height)
        corner: "tl"
        fill: root.fill
    }
    ConcaveJoin {
        visible: root.attached && root.isRight
        x: card.x + card.width - width
        y: card.y + card.height
        height: Math.min(root.r, card.height)
        corner: "tr"
        fill: root.fill
    }
}
