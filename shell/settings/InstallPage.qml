import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Find apps and install them, without a terminal. Searches the system's
// packages and, when Flatpak is there, Flathub.
ColumnLayout {
    id: page
    spacing: 24

    // Removing needs a second click within three seconds.
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: page.armed = "" }

    Component.onCompleted: {
        Packages.countUpdates()
        if (Shell.installQuery.length > 0) { field.text = Shell.installQuery; Shell.installQuery = ""; Packages.search(field.text) }
        field.forceActiveFocus()
    }
    Connections {
        target: Shell
        function onInstallQueryChanged() {
            if (Shell.installQuery.length === 0) return
            field.text = Shell.installQuery
            Shell.installQuery = ""
            Packages.search(field.text)
        }
    }
    Timer { id: typed; interval: 450; onTriggered: Packages.search(field.text) }

    Label {
        Layout.fillWidth: true
        visible: !Packages.available
        wrapMode: Text.Wrap
        text: Lang.t("Installing apps from here needs pacman or Flatpak, and neither was found.")
        color: Theme.inkMuted
    }

    // Search
    Rectangle {
        Layout.fillWidth: true
        visible: Packages.available
        implicitHeight: 58
        radius: field.activeFocus ? Theme.cornerL : height / 2
        color: Theme.surfaceContainerHigh
        border.width: field.activeFocus ? 2 : 0
        border.color: Theme.primary
        Behavior on radius { Spring {} }

        MIcon { id: glass; x: 20; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 24; color: Theme.inkMuted }
        TextInput {
            id: field
            anchors.left: glass.right
            anchors.leftMargin: 12
            anchors.right: spin.left
            anchors.rightMargin: 12
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            maximumLength: 60
            color: Theme.ink
            selectionColor: Theme.primaryContainer
            font.family: Theme.font
            font.pixelSize: Theme.textTitle
            clip: true
            onTextEdited: typed.restart()
            Keys.onReturnPressed: { typed.stop(); Packages.search(text) }
            Keys.onEnterPressed: { typed.stop(); Packages.search(text) }
            Label {
                visible: field.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: Lang.t("Which app are you looking for?")
                font.pixelSize: Theme.textTitle
                color: Theme.inkMuted
            }
        }
        MIcon {
            id: spin
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            icon: "progress_activity"
            size: 22
            color: Theme.primary
            opacity: Packages.searching ? 1 : 0
            Behavior on opacity { Fade {} }
            RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: Packages.searching }
        }
    }

    // What is happening right now, or how the last job ended.
    Rectangle {
        Layout.fillWidth: true
        visible: Packages.busy.length > 0 || Packages.problem.length > 0
        implicitHeight: status.implicitHeight + 28
        radius: Theme.cornerXL
        color: Packages.busy.length > 0 ? Theme.secondaryContainer : Theme.errorContainer
        Behavior on color { Tint {} }
        RowLayout {
            id: status
            x: 18
            width: parent.width - 36
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            MIcon {
                icon: Packages.busy.length > 0 ? "progress_activity" : "error"
                size: 26
                color: Packages.busy.length > 0 ? Theme.inkOnSecondaryContainer : Theme.inkOnErrorContainer
                RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: Packages.busy.length > 0 }
                onIconChanged: rotation = 0
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: Packages.busy.length === 0 ? Packages.problem
                        : (Packages.busyKind === "remove" ? Lang.t("Removing %1…", Packages.busy)
                            : (Packages.busyKind === "update" ? Lang.t("Updating everything…") : Lang.t("Installing %1…", Packages.busy)))
                    font.weight: Font.DemiBold
                    color: Packages.busy.length > 0 ? Theme.inkOnSecondaryContainer : Theme.inkOnErrorContainer
                }
                Label {
                    Layout.fillWidth: true
                    visible: Packages.busy.length > 0 && text.length > 0
                    elide: Text.ElideRight
                    text: Packages.progress
                    font.pixelSize: Theme.textLabelS
                    color: Theme.inkOnSecondaryContainer
                    opacity: 0.8
                }
            }
        }
    }

    SegGroup {
        visible: Packages.available && field.text.trim().length < 2
        title: Lang.t("Up to date")
        SegItem {
            icon: "system_update_alt"
            hue: 2
            lobes: 8
            title: Lang.t("Update everything")
            description: Packages.updates > 0 ? Lang.t("%1 updates are waiting.", Packages.updates)
                : (Packages.updates === 0 ? Lang.t("Everything is up to date.") : Lang.t("Brings the system and all apps up to date."))
            Pressable {
                width: go.implicitWidth + 36
                height: 44
                enabledInput: Packages.busy.length === 0
                opacity: enabledInput ? 1 : 0.5
                color: Theme.primary
                restRadius: Theme.cornerFull
                onClicked: Packages.updateAll()
                Label { id: go; anchors.centerIn: parent; text: Lang.t("Update"); font.weight: Font.Bold; color: Theme.inkOnPrimary }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 20
        visible: Packages.available && field.text.trim().length >= 2 && !Packages.searching && Packages.results.length === 0 && Packages.query === field.text.trim()
        horizontalAlignment: Text.AlignHCenter
        text: Lang.t("Nothing found for \"%1\".", field.text.trim())
        color: Theme.inkMuted
    }

    SegGroup {
        visible: Packages.results.length > 0 && field.text.trim().length >= 2
        title: Lang.t("Found")
        Repeater {
            model: Packages.results
            SegItem {
                id: row
                required property var modelData
                required property int index
                readonly property string key: modelData.source + ":" + modelData.id
                readonly property bool working: Packages.busy === modelData.name
                readonly property bool hot: page.armed === key
                icon: modelData.installed ? "check_circle" : (modelData.source === "flatpak" ? "deployed_code" : "package_2")
                hue: index % 6
                lobes: [8, 0, 4, 5][index % 4]
                title: modelData.name
                description: (modelData.summary || modelData.id) + "\n" + (modelData.source === "flatpak" ? "Flathub" : modelData.repo) + "  ·  " + modelData.version
                    + (modelData.installed ? "  ·  " + Lang.t("Installed") : "")
                // Rows arrive one after the other.
                NumberAnimation on opacity { from: 0; to: 1; duration: Motion.effectsSlow }
                transform: Translate { id: rise }
                NumberAnimation { target: rise; property: "y"; from: 14 + Math.min(row.index, 8) * 6; to: 0; running: true; duration: Motion.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }

                Pressable {
                    visible: !row.modelData.installed || Packages.removable(row.modelData)
                    width: act.implicitWidth + 36
                    height: 44
                    enabledInput: Packages.busy.length === 0
                    opacity: enabledInput || row.working ? 1 : 0.5
                    color: row.modelData.installed ? (row.hot ? Theme.errorContainer : Theme.surfaceContainerHighest) : Theme.primary
                    restRadius: row.hot ? Theme.cornerM : Theme.cornerFull
                    Behavior on color { Tint {} }
                    Behavior on width { Spring {} }
                    onClicked: {
                        if (!row.modelData.installed) { Packages.install(row.modelData); return }
                        if (!row.hot) { page.armed = row.key; disarm.restart(); return }
                        page.armed = ""
                        Packages.remove(row.modelData)
                    }
                    Label {
                        id: act
                        anchors.centerIn: parent
                        text: row.working ? "…" : (!row.modelData.installed ? Lang.t("Install") : (row.hot ? Lang.t("Really remove?") : Lang.t("Remove")))
                        font.weight: Font.Bold
                        color: row.modelData.installed ? (row.hot ? Theme.inkOnErrorContainer : Theme.ink) : Theme.inkOnPrimary
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: Packages.available
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textLabel
        color: Theme.inkMuted
        text: Packages.hasFlatpak ? Lang.t("Searches the system's packages and Flathub. System packages ask for your password.")
            : Lang.t("Searches the system's packages; installing asks for your password. Install the package flatpak to search Flathub as well.")
    }
}
