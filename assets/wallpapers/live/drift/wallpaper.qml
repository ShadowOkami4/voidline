import QtQuick

// Voidline live wallpaper: Drift.
Item {
    id: root

    property var theme: ({})
    property var options: ({})

    readonly property real speed: options.speed ?? 1
    readonly property int count: Math.round(options.count ?? 26)
    readonly property bool themed: options.themed ?? true
    readonly property var colours: themed && theme.primary
        ? [theme.primary, theme.tertiary, theme.secondary, theme.primaryContainer]
        : ["#8E6BFF", "#F2A6C8", "#4FC3D0", "#C9A45C", "#B79BE0"]
    readonly property color base: themed && theme.surface ? theme.surface : "#08070D"

    property real t: 0
    // Called by the shell for every frame it wants drawn.
    function advance(dt) { t += dt * speed }

    // Repeatable pseudo-random number for shape i, channel k (no flicker on reload).
    function rnd(i, k) {
        const x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453
        return x - Math.floor(x)
    }

    Rectangle { anchors.fill: parent; color: root.base }

    Repeater {
        model: root.count
        Cookie {
            required property int index
            readonly property real size: (0.03 + root.rnd(index, 1) * 0.11) * Math.min(root.width, root.height)
            readonly property real rise: 0.006 + root.rnd(index, 2) * 0.016          // screens per second
            readonly property real phase: root.rnd(index, 3)
            // 0..1 position along the trip from below the screen to above it.
            readonly property real travel: (phase + root.t * rise) % 1
            width: size
            height: size
            lobes: [4, 5, 6, 8, 10, 12][Math.floor(root.rnd(index, 4) * 6)]
            depth: 0.07
            fill: root.colours[index % root.colours.length]
            opacity: (0.16 + root.rnd(index, 5) * 0.5) * Math.min(1, travel * 6, (1 - travel) * 6)
            x: root.rnd(index, 6) * root.width - size / 2 + Math.sin(root.t * 0.25 + index) * size * 0.6
            y: root.height + size - travel * (root.height + size * 2)
            rotation: root.t * (root.rnd(index, 7) - 0.5) * 30
        }
    }
}
