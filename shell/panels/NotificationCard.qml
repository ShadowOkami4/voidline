import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

Rectangle {
    id: root

    required property var notification
    property color base: Theme.surfaceContainerHigh
    signal dismissed()

    // Messengers let you answer right here (Reply on the card).
    readonly property bool canReply: !!notification && notification.hasInlineReply === true
    property bool replying: false
    // While you type, the popup stays.
    onReplyingChanged: Notifs.hold(notification ? notification.id : -1, replying)
    Component.onDestruction: if (replying && notification) Notifs.hold(notification.id, false)
    function send() {
        const t = answer.text.trim()
        if (t.length === 0) return
        notification.sendInlineReply(t)
        replying = false
        root.dismissed()
    }

    implicitHeight: layout.implicitHeight + 24
    radius: Theme.cornerLInc
    color: base

    RowLayout {
        id: layout
        x: 14
        y: 12
        width: parent.width - 28
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            radius: Theme.cornerM
            color: Theme.primaryContainer

            // Voidline's own notifications name one of the shell's symbols
            // ("voidline-alarm"), so they never depend on the icon theme.
            // The icon's name arrives as appIcon or, wrapped, as the image.
            readonly property string iconName: {
                const img = String(root.notification.image || "")
                return root.notification.appIcon || (img.startsWith("image://icon/") ? decodeURIComponent(img.slice(13)) : "")
            }
            readonly property string own: iconName.startsWith("voidline-") ? iconName.slice(9) : ""
            IconImage {
                id: appIcon
                anchors.centerIn: parent
                implicitSize: 22
                // A picture that cannot be loaded makes way for the symbol
                // instead of showing as a broken square.
                visible: source.toString().length > 0 && status !== Image.Error && status !== Image.Null
                // A real picture (a contact's photo, a cover) comes first. An
                // "image://icon/..." address is only the icon name again, and
                // shows a chequered square when the theme has no such icon.
                readonly property string picture: {
                    const img = String(root.notification.image || "")
                    return img.length > 0 && !img.startsWith("image://icon/") ? img : ""
                }
                readonly property string named: {
                    const n = parent.iconName
                    return n.startsWith("/") ? "file://" + n : (n.startsWith("file://") ? n : (n.length > 0 ? Quickshell.iconPath(n, true) : ""))
                }
                source: parent.own.length > 0 ? "" : (picture || named)
            }
            MIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                icon: parent.own.length > 0 ? parent.own : "notifications"
                filled: true
                size: 20
                color: Theme.inkOnPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: root.notification.summary || root.notification.appName
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.notification.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                font.pixelSize: Theme.textLabel
                color: Theme.inkMuted
            }
            // What the app offers to do (Reply, Open, Mark as read, ...).
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: (root.notification.actions.length > 0 || root.canReply) && !root.replying
                spacing: 6
                Pressable {
                    visible: root.canReply
                    width: replyLabel.implicitWidth + 50
                    height: 34
                    color: Theme.primary
                    tint: Theme.inkOnPrimary
                    onClicked: { root.replying = true; answer.forceActiveFocus() }
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "reply"; size: 18; color: Theme.inkOnPrimary }
                        Label {
                            id: replyLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lang.t("Reply")
                            font.pixelSize: Theme.textLabel + 1
                            font.weight: Font.DemiBold
                            color: Theme.inkOnPrimary
                        }
                    }
                }
                Repeater {
                    model: root.notification.actions
                    Pressable {
                        id: act
                        required property var modelData
                        width: actLabel.implicitWidth + 28
                        height: 34
                        color: Theme.secondaryContainer
                        tint: Theme.inkOnSecondaryContainer
                        onClicked: { act.modelData.invoke(); root.dismissed() }
                        Label {
                            id: actLabel
                            anchors.centerIn: parent
                            text: act.modelData.text
                            font.pixelSize: Theme.textLabel + 1
                            font.weight: Font.DemiBold
                            color: Theme.inkOnSecondaryContainer
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.replying
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Theme.cornerM
                    color: Theme.surfaceContainerHighest
                    border.width: 2
                    border.color: Theme.primary
                    TextInput {
                        id: answer
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.ink
                        selectionColor: Theme.primaryContainer
                        font.family: Theme.font
                        font.pixelSize: Theme.textLabel + 1
                        clip: true
                        Keys.onReturnPressed: root.send()
                        Keys.onEnterPressed: root.send()
                        Keys.onEscapePressed: { text = ""; root.replying = false }
                        Label {
                            visible: answer.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.notification && root.notification.inlineReplyPlaceholder ? root.notification.inlineReplyPlaceholder : Lang.t("Your answer")
                            font.pixelSize: Theme.textLabel + 1
                            color: Theme.inkMuted
                        }
                    }
                }
                IconBtn { icon: "close"; size: 36; onClicked: { answer.text = ""; root.replying = false } }
                IconBtn { icon: "send"; size: 36; selected: true; onClicked: root.send() }
            }
        }

        IconBtn {
            Layout.alignment: Qt.AlignTop
            visible: !root.replying
            icon: "close"
            size: 28
            onClicked: root.dismissed()
        }
    }
}
