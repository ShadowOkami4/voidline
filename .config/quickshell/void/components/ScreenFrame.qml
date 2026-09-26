import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../core"

PanelWindow {
    id: root

    readonly property int lineWidth: Theme.screenFrameWidth
    readonly property int cornerRadius: Theme.concaveRadius
    readonly property int cornerExtent: cornerRadius + lineWidth
    readonly property string barPosition: Appearance.barPosition

    anchors { top: true; bottom: true; left: true; right: true }
    // The frame belongs to the "frame" bar style only.
    visible: Appearance.barStyle === "frame"
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-screen-frame"

    HyprlandWindow.visibleMask: Region {
        Region {
            x: 0
            y: 0
            width: root.barPosition === "top" ? 0 : root.width
            height: root.cornerExtent
        }
        Region {
            x: 0
            y: root.height - root.cornerExtent
            width: root.barPosition === "bottom" ? 0 : root.width
            height: root.cornerExtent
        }
        Region {
            x: 0
            y: 0
            width: root.barPosition === "left" ? 0 : root.cornerExtent
            height: root.height
        }
        Region {
            x: root.width - root.cornerExtent
            y: 0
            width: root.barPosition === "right" ? 0 : root.cornerExtent
            height: root.height
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: root.cornerExtent
        anchors.rightMargin: root.cornerExtent
        height: root.lineWidth
        visible: root.barPosition !== "top"
        color: Theme.panel
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: root.cornerExtent
        anchors.rightMargin: root.cornerExtent
        height: root.lineWidth
        visible: root.barPosition !== "bottom"
        color: Theme.panel
    }
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        anchors.topMargin: root.cornerExtent
        anchors.bottomMargin: root.cornerExtent
        width: root.lineWidth
        visible: root.barPosition !== "left"
        color: Theme.panel
    }
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        anchors.topMargin: root.cornerExtent
        anchors.bottomMargin: root.cornerExtent
        width: root.lineWidth
        visible: root.barPosition !== "right"
        color: Theme.panel
    }

    Canvas {
        width: root.cornerExtent
        height: root.cornerExtent
        anchors { left: parent.left; top: parent.top }
        visible: root.barPosition !== "top" && root.barPosition !== "left"
        antialiasing: true
        property color frameColor: Theme.panel
        onFrameColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = frameColor
            c.fillRect(0, 0, width, height)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(width, height, root.cornerRadius, 0, Math.PI * 2)
            c.fill()
        }
    }

    Canvas {
        width: root.cornerExtent
        height: root.cornerExtent
        anchors { right: parent.right; top: parent.top }
        visible: root.barPosition !== "top" && root.barPosition !== "right"
        antialiasing: true
        property color frameColor: Theme.panel
        onFrameColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = frameColor
            c.fillRect(0, 0, width, height)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(0, height, root.cornerRadius, 0, Math.PI * 2)
            c.fill()
        }
    }

    Canvas {
        width: root.cornerExtent
        height: root.cornerExtent
        anchors { left: parent.left; bottom: parent.bottom }
        visible: root.barPosition !== "bottom" && root.barPosition !== "left"
        antialiasing: true
        property color frameColor: Theme.panel
        onFrameColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = frameColor
            c.fillRect(0, 0, width, height)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(width, 0, root.cornerRadius, 0, Math.PI * 2)
            c.fill()
        }
    }

    Canvas {
        width: root.cornerExtent
        height: root.cornerExtent
        anchors { right: parent.right; bottom: parent.bottom }
        visible: root.barPosition !== "bottom" && root.barPosition !== "right"
        antialiasing: true
        property color frameColor: Theme.panel
        onFrameColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = frameColor
            c.fillRect(0, 0, width, height)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(0, 0, root.cornerRadius, 0, Math.PI * 2)
            c.fill()
        }
    }
}
