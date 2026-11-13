import QtQuick

// Voidline live wallpaper: Bloom.
// Each cloud is a radial gradient painted once; only its position changes.
Item {
    id: root

    property var theme: ({})
    property var options: ({})

    readonly property real speed: options.speed ?? 1
    readonly property real strength: options.strength ?? 0.6
    readonly property string tint: options.tint ?? "theme"
    readonly property var colours: tint === "ember" ? ["#FF7A45", "#E5484D", "#F2B63A", "#C4406E"]
        : (tint === "void" || !theme.primary ? ["#8E6BFF", "#E255A1", "#4FC3D0", "#5B4BD6"]
            : [theme.primary, theme.tertiary, theme.secondary, theme.primary])
    readonly property color base: theme.dark === false ? "#F4F1F8" : "#07060B"

    property real t: 0
    // Called by the shell for every frame it wants drawn.
    function advance(dt) { t += dt * speed }

    Rectangle { anchors.fill: parent; color: root.base }

    Repeater {
        model: [
            { size: 0.95, ax: 0.30, ay: 0.22, fx: 0.031, fy: 0.023, px: 0.0, py: 1.3, cx: 0.30, cy: 0.35 },
            { size: 0.80, ax: 0.26, ay: 0.26, fx: 0.019, fy: 0.037, px: 2.1, py: 0.4, cx: 0.70, cy: 0.40 },
            { size: 0.70, ax: 0.34, ay: 0.20, fx: 0.027, fy: 0.017, px: 4.0, py: 2.6, cx: 0.50, cy: 0.72 },
            { size: 0.60, ax: 0.22, ay: 0.30, fx: 0.041, fy: 0.029, px: 1.2, py: 5.0, cx: 0.62, cy: 0.20 }
        ]

        Canvas {
            id: cloud
            required property var modelData
            required property int index
            property color tone: root.colours[index % root.colours.length]
            width: Math.max(root.width, root.height) * modelData.size
            height: width
            opacity: root.strength
            x: root.width * (modelData.cx + modelData.ax * Math.sin(root.t * modelData.fx * 6.283 + modelData.px)) - width / 2
            y: root.height * (modelData.cy + modelData.ay * Math.cos(root.t * modelData.fy * 6.283 + modelData.py)) - height / 2
            onToneChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
                g.addColorStop(0, Qt.rgba(tone.r, tone.g, tone.b, 0.85))
                g.addColorStop(0.45, Qt.rgba(tone.r, tone.g, tone.b, 0.32))
                g.addColorStop(1, Qt.rgba(tone.r, tone.g, tone.b, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
        }
    }
}
