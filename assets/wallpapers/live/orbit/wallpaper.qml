import QtQuick

// Voidline live wallpaper: Orbit.
// The shell fills in `theme` and `options` and calls advance() (see docs/live-wallpapers.md).
Item {
    id: root

    property var theme: ({})
    property var options: ({})

    readonly property real speed: options.speed ?? 1
    readonly property bool themed: options.themed ?? false
    readonly property color core: themed && theme.primary ? theme.primary : "#8A5FC0"
    readonly property var colours: themed && theme.primary
        ? [theme.primary, theme.tertiary, theme.secondary, theme.primaryContainer, theme.tertiary, theme.primary]
        : ["#F2A6C8", "#B79BE0", "#4FC3D0", "#C9A45C", "#8A5FD0", "#FFAAD4"]
    readonly property real unit: Math.min(width, height)

    property real t: 0
    // Called by the shell for every frame it wants drawn.
    function advance(dt) { t += dt * speed }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#07060B" }
            GradientStop { position: 1; color: "#0B0A12" }
        }
    }

    // Soft glow behind the core, painted once.
    Canvas {
        anchors.centerIn: parent
        width: root.unit * 1.5
        height: width
        property color tint: root.core
        onTintChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
            g.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, 0.34))
            g.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
    }

    // Orbits: a ring plus the shapes riding on it.
    Repeater {
        model: [
            { r: 0.20, period: 46, shapes: [{ a: 0.3, size: 0.050, lobes: 4, c: 5 }, { a: 2.6, size: 0.036, lobes: 5, c: 1 }] },
            { r: 0.31, period: 70, shapes: [{ a: 1.2, size: 0.058, lobes: 9, c: 1 }, { a: 4.1, size: 0.040, lobes: 6, c: 2 }] },
            { r: 0.42, period: 104, shapes: [{ a: 5.2, size: 0.052, lobes: 4, c: 0 }, { a: 2.2, size: 0.044, lobes: 4, c: 3 }, { a: 3.4, size: 0.040, lobes: 7, c: 2 }] },
            { r: 0.53, period: 150, shapes: [{ a: 0.9, size: 0.090, lobes: 12, c: 4 }, { a: 4.6, size: 0.062, lobes: 5, c: 1 }] }
        ]

        Item {
            id: orbit
            required property var modelData
            required property int index
            readonly property real radius: root.unit * modelData.r
            anchors.centerIn: parent

            Rectangle {
                visible: root.options.rings ?? true
                anchors.centerIn: parent
                width: orbit.radius * 2
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.11)
            }

            Repeater {
                model: orbit.modelData.shapes
                Cookie {
                    required property var modelData
                    // Alternate direction per orbit.
                    readonly property real angle: modelData.a + (orbit.index % 2 ? -1 : 1) * root.t * Math.PI * 2 / orbit.modelData.period
                    width: root.unit * modelData.size
                    height: width
                    lobes: modelData.lobes
                    fill: root.colours[modelData.c % root.colours.length]
                    x: Math.cos(angle) * orbit.radius - width / 2
                    y: Math.sin(angle) * orbit.radius - height / 2
                    rotation: root.t * 6 * (modelData.c % 2 ? 1 : -1)
                }
            }
        }
    }

    // Core: two slow counter-rotating cookies and the void in the middle.
    Cookie {
        anchors.centerIn: parent
        width: root.unit * 0.33
        height: width
        lobes: 10
        depth: 0.05
        fill: Qt.rgba(root.core.r, root.core.g, root.core.b, 0.28)
        rotation: -root.t * 1.6
    }
    Cookie {
        anchors.centerIn: parent
        width: root.unit * 0.28
        height: width
        lobes: 10
        depth: 0.05
        fill: root.core
        rotation: root.t * 2.4
    }
    Rectangle {
        anchors.centerIn: parent
        width: root.unit * 0.105
        height: width
        radius: width / 2
        color: "#050507"
        border.width: Math.max(2, root.unit * 0.002)
        border.color: "#56D6E0"
    }
}
