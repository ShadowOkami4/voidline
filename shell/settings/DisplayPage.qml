import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Resolution, refresh rate and scale per display. A change is applied first
// and only saved once it is confirmed; without confirmation it reverts, so a
// mode the screen cannot show never locks you out.
ColumnLayout {
    id: page
    spacing: 24

    // Pending confirmation: { name, mode, scale, oldMode, oldScale }
    property var pending: null
    property int secondsLeft: 0

    Component.onCompleted: Compositor.refreshOutputs()

    function resolutionOf(mode) { return mode.split("@")[0] }
    function rateOf(mode) { return parseFloat(mode.split("@")[1]) }

    function apply(output, mode, scale) {
        pending = { name: output.name, mode: mode, scale: scale, oldMode: output.mode, oldScale: output.scale }
        secondsLeft = 15
        Compositor.applyOutput(output.name, mode, scale)
        countdown.restart()
    }
    function keep() {
        countdown.stop()
        const rest = Config.displays.filter(e => e.split("|")[0] !== pending.name)
        Config.displays = rest.concat([pending.name + "|" + pending.mode + "|" + pending.scale])
        pending = null
    }
    function revert() {
        countdown.stop()
        if (pending) Compositor.applyOutput(pending.name, pending.oldMode, pending.oldScale)
        pending = null
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: { page.secondsLeft -= 1; if (page.secondsLeft <= 0) page.revert() }
    }

    // ---- keep / revert banner ------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: !!page.pending
        implicitHeight: 96
        radius: Theme.cornerXXL
        color: Theme.tertiaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 18
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: "Keep these display settings?"
                    font.pixelSize: Theme.textTitle + 4
                    font.weight: Font.Black
                    color: Theme.inkOnTertiaryContainer
                }
                Label {
                    Layout.fillWidth: true
                    text: "Reverting in " + page.secondsLeft + " seconds."
                    color: Theme.inkOnTertiaryContainer
                    opacity: 0.85
                }
            }
            Pressable {
                implicitWidth: 104
                implicitHeight: 52
                color: Theme.surfaceContainerHigh
                onClicked: page.revert()
                Label { anchors.centerIn: parent; text: "Revert"; font.weight: Font.Bold }
            }
            Pressable {
                implicitWidth: 104
                implicitHeight: 52
                color: Theme.tertiary
                tint: Theme.surface
                onClicked: page.keep()
                Label { anchors.centerIn: parent; text: "Keep"; font.weight: Font.Bold; color: Theme.surface }
            }
        }
    }

    // ---- brightness -----------------------------------------------------------------
    SegGroup {
        visible: Brightness.available
        title: "Brightness"
        SliderItem {
            icon: "brightness_medium"
            hue: 3
            lobes: 8
            title: "Screen brightness"
            from: 2; to: 100; step: 1; suffix: "%"
            value: Math.round(Brightness.value * 100)
            onChanged: v => Brightness.set(v / 100)
        }
    }

    Label {
        visible: Compositor.outputs.length === 0
        text: Compositor.supported ? "Looking for displays..." : "No supported window manager is running."
        color: Theme.inkMuted
    }

    // ---- arrangement (more than one screen) -----------------------------------------
    function placeOf(name) {
        const e = Config.displayPlaces.find(p => p.startsWith(name + "="))
        return e ? e.split("=")[1] : "auto"
    }
    function setPlace(name, place) {
        const rest = Config.displayPlaces.filter(p => !p.startsWith(name + "="))
        Config.displayPlaces = place === "auto" ? rest : rest.concat([name + "=" + place])
        later.restart()
    }
    Timer { id: later; interval: 1200; onTriggered: Compositor.refreshOutputs() }

    SegGroup {
        visible: Compositor.outputs.length > 1 && Compositor.name === "hyprland"
        title: "Arrangement"
        Repeater {
            model: Compositor.outputs.filter(o => o.name !== WmConfig.primary)
            SegItem {
                id: seat
                required property var modelData
                required property int index
                icon: "desktop_windows"
                hue: index + 1
                lobes: [4, 8, 0, 5][index % 4]
                title: modelData.name + (modelData.description ? "  ·  " + modelData.description : "")
                description: "Where this screen sits next to " + WmConfig.primary + "."
                extra: Choice {
                    Layout.fillWidth: true
                    value: page.placeOf(seat.modelData.name)
                    options: [
                        { value: "auto", label: "Automatic" },
                        { value: "left", label: "Left" },
                        { value: "right", label: "Right" },
                        { value: "up", label: "Above" },
                        { value: "down", label: "Below" },
                        { value: "mirror", label: "Same picture" }
                    ]
                    onPicked: v => page.setPlace(seat.modelData.name, v)
                }
            }
        }
    }

    // ---- one group per display ---------------------------------------------------------
    Repeater {
        model: Compositor.outputs

        SegGroup {
            id: group
            required property var modelData
            readonly property var output: modelData
            title: output.name + (output.description ? "  ·  " + output.description : "")

            // What is selected in the controls (starts at the current mode).
            property string resolution: page.resolutionOf(output.mode)
            property real rate: page.rateOf(output.mode)
            property real zoom: output.scale

            readonly property var resolutions: {
                const seen = []
                for (const m of output.modes) {
                    const r = page.resolutionOf(m)
                    if (!seen.includes(r)) seen.push(r)
                }
                return seen.sort((a, b) => parseInt(b) - parseInt(a) || parseInt(b.split("x")[1]) - parseInt(a.split("x")[1])).slice(0, 8)
            }
            readonly property var rates: output.modes.filter(m => page.resolutionOf(m) === resolution)
                .sort((a, b) => page.rateOf(b) - page.rateOf(a))
            readonly property string mode: {
                const exact = rates.find(m => Math.abs(page.rateOf(m) - rate) < 0.6)
                return exact ?? rates[0] ?? output.mode
            }
            // Scales that give a whole number of pixels at this resolution.
            readonly property var scales: {
                const w = parseInt(resolution), h = parseInt(resolution.split("x")[1])
                const ok = [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.5, 3].filter(s =>
                    Math.abs(w / s - Math.round(w / s)) < 0.01 && Math.abs(h / s - Math.round(h / s)) < 0.01 && w / s >= 960)
                if (!ok.some(s => Math.abs(s - output.scale) < 0.01)) ok.push(output.scale)
                return ok.sort((a, b) => a - b)
            }
            readonly property bool dirty: mode !== output.mode || Math.abs(zoom - output.scale) > 0.01

            SegItem {
                icon: "aspect_ratio"
                hue: 0
                lobes: 4
                title: "Resolution"
                description: group.resolution.replace("x", " × ")
                extra: Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: group.resolutions
                        Pressable {
                            id: res
                            required property string modelData
                            readonly property bool current: group.resolution === modelData
                            width: resLabel.implicitWidth + 32
                            height: 40
                            color: current ? Theme.primary : Theme.surfaceContainerHighest
                            tint: current ? Theme.inkOnPrimary : Theme.ink
                            restRadius: current ? Theme.cornerFull : Theme.cornerM
                            Behavior on color { Tint {} }
                            onClicked: group.resolution = modelData
                            Label {
                                id: resLabel
                                anchors.centerIn: parent
                                text: res.modelData.replace("x", " × ")
                                font.pixelSize: Theme.textLabel + 1
                                font.weight: Font.DemiBold
                                color: res.current ? Theme.inkOnPrimary : Theme.ink
                            }
                        }
                    }
                }
            }

            SegItem {
                icon: "speed"
                hue: 1
                lobes: 8
                title: "Refresh rate"
                description: Math.round(page.rateOf(group.mode)) + " Hz"
                extra: Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: group.rates
                        Pressable {
                            id: hz
                            required property string modelData
                            readonly property bool current: group.mode === modelData
                            width: 84
                            height: 40
                            color: current ? Theme.primary : Theme.surfaceContainerHighest
                            tint: current ? Theme.inkOnPrimary : Theme.ink
                            restRadius: current ? Theme.cornerFull : Theme.cornerM
                            Behavior on color { Tint {} }
                            onClicked: group.rate = page.rateOf(modelData)
                            Label {
                                anchors.centerIn: parent
                                text: Math.round(page.rateOf(hz.modelData)) + " Hz"
                                font.pixelSize: Theme.textLabel + 1
                                font.weight: Font.DemiBold
                                color: hz.current ? Theme.inkOnPrimary : Theme.ink
                            }
                        }
                    }
                }
            }

            SegItem {
                icon: "zoom_in"
                hue: 2
                lobes: 0
                title: "Scale"
                description: "How large apps and text appear. Voidline's own size is under Interface."
                extra: Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: group.scales
                        Pressable {
                            id: sc
                            required property real modelData
                            readonly property bool current: Math.abs(group.zoom - modelData) < 0.01
                            width: 84
                            height: 40
                            color: current ? Theme.primary : Theme.surfaceContainerHighest
                            tint: current ? Theme.inkOnPrimary : Theme.ink
                            restRadius: current ? Theme.cornerFull : Theme.cornerM
                            Behavior on color { Tint {} }
                            onClicked: group.zoom = modelData
                            Label {
                                anchors.centerIn: parent
                                text: Math.round(sc.modelData * 100) + "%"
                                font.pixelSize: Theme.textLabel + 1
                                font.weight: Font.DemiBold
                                color: sc.current ? Theme.inkOnPrimary : Theme.ink
                            }
                        }
                    }
                }
            }

            SegItem {
                icon: "done_all"
                hue: 4
                lobes: 5
                title: group.dirty ? "Apply changes" : "No changes"
                description: group.dirty ? "You will be asked to confirm; otherwise it reverts after 15 seconds." : "Pick a different resolution, refresh rate or scale above."
                opacity: group.dirty && !page.pending ? 1 : 0.5
                Pressable {
                    implicitWidth: 110
                    implicitHeight: 48
                    enabledInput: group.dirty && !page.pending
                    color: Theme.primary
                    tint: Theme.inkOnPrimary
                    onClicked: page.apply(group.output, group.mode, Math.round(group.zoom * 1000000) / 1000000)
                    Label { anchors.centerIn: parent; text: "Apply"; font.weight: Font.Bold; color: Theme.inkOnPrimary }
                }
            }
        }
    }
}
