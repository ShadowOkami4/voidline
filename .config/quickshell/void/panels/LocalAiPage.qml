import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    property bool showComposer: false
    property bool showHeader: true
    property bool showRuntimeStrip: true
    property bool spacious: false
    property alias composerText: chatInput.text
    readonly property int requestedBodyWidth: 640
    readonly property int requestedBodyHeight: 574
    signal back
    signal useSuggestion(string value)

    function focusComposer() {
        if (showComposer)
            chatInput.forceActiveFocus()
    }

    function submitComposer() {
        const value = chatInput.text.trim()
        if (value.length === 0 || AssistantService.busy)
            return
        if (AssistantService.ask(value)) {
            chatInput.clear()
            Qt.callLater(() => chatInput.forceActiveFocus())
        }
    }

    onActiveChanged: {
        if (active) {
            AssistantService.refreshCapabilities()
            AssistantService.ensureWarm()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.round(66 * Metrics.scale) : 0
            visible: root.showHeader
            radius: Theme.radiusLarge
            color: Theme.surfaceHigh

            IconButton {
                id: aiBack
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: "arrow_back"
                accessibleName: I18n.tr("assistant.backToCommands")
                onClicked: root.back()
            }
            Rectangle {
                id: aiHeaderIcon
                anchors {
                    left: aiBack.right
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 48
                height: 48
                radius: Theme.radiusMedium
                color: Theme.accentContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "neurology"
                    size: 25
                    color: Theme.accent
                }
            }
            IconButton {
                id: aiHeaderAction
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: AssistantService.busy ? "stop_circle"
                    : (AssistantService.messages.length > 0
                        ? "delete_sweep" : "refresh")
                accessibleName: AssistantService.busy ? I18n.tr("assistant.stopGeneration")
                    : (AssistantService.messages.length > 0
                        ? I18n.tr("assistant.clearChat") : I18n.tr("assistant.refresh"))
                onClicked: {
                    if (AssistantService.busy)
                        AssistantService.cancel()
                    else if (AssistantService.messages.length > 0)
                        AssistantService.clearConversation()
                    else
                        AssistantService.refreshCapabilities()
                }
            }
            Rectangle {
                id: modelStatus
                anchors {
                    right: aiHeaderAction.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: Math.min(176, modelStatusContent.implicitWidth + 22)
                height: 36
                radius: Theme.radiusMedium
                color: modelHover.hovered && AssistantService.models.length > 1
                    ? Theme.accentContainer : Theme.surfaceLow
                visible: AssistantService.providerInstalled

                RowLayout {
                    id: modelStatusContent
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon {
                        text: AssistantService.models.length > 0
                            ? "memory" : "download"
                        size: 16
                        color: AssistantService.models.length > 0
                            ? Theme.accent : Theme.textMuted
                    }
                    Text {
                        id: modelLabel
                        text: AssistantService.selectedModel.length > 0
                            ? AssistantService.selectedModel
                            : (AssistantService.configuredModel.length > 0
                                ? AssistantService.configuredModel : I18n.tr("assistant.noModel"))
                        color: AssistantService.models.length > 0
                            ? Theme.text : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                    MaterialIcon {
                        text: "unfold_more"
                        size: 14
                        color: Theme.textMuted
                        visible: AssistantService.models.length > 1
                    }
                }
                HoverHandler { id: modelHover }
                TapHandler {
                    enabled: AssistantService.models.length > 1
                    onTapped: AssistantService.selectNextModel()
                }
            }
            ColumnLayout {
                anchors {
                    left: aiHeaderIcon.right
                    leftMargin: 10
                    right: modelStatus.visible
                        ? modelStatus.left : aiHeaderAction.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: -1
                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("assistant.name")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    text: I18n.tr("assistant.extremeBeta")
                    color: Theme.tertiary
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textCaption
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: AssistantService.statusText
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Metrics.controlS : 0
            radius: Metrics.stateRadius
            color: Theme.groupSurfaceRaised
            visible: root.showRuntimeStrip && AssistantService.providerReady

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Metrics.spaceM
                    rightMargin: Metrics.spaceM
                }
                spacing: Metrics.spaceM
                MaterialIcon {
                    // `memory_off` is not present in every Material Symbols
                    // release and renders as a missing-glyph box on those
                    // systems. State is already conveyed by color and text.
                    text: "memory"
                    size: Metrics.iconS
                    color: AssistantService.modelLoaded ? Theme.secondary : Theme.textMuted
                }
                Text {
                    Layout.fillWidth: true
                    text: AssistantService.modelLoaded
                        ? I18n.tr("assistant.performanceCompact", {
                            speed: AssistantService.tokensPerSecond.toFixed(1),
                            memory: AssistantService.formatBytes(AssistantService.serviceRamBytes),
                            compute: AssistantService.loadedVramBytes > 0
                                && AssistantService.loadedVramBytes < AssistantService.loadedSizeBytes
                                ? I18n.tr("assistant.hybrid") : AssistantService.accelerator.toUpperCase()
                        })
                        : I18n.tr("assistant.modelUnloaded")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textSupporting
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: I18n.tr("assistant.tokenTotal", {
                        count: AssistantService.conversationTokens
                    })
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textSupporting
                    visible: AssistantService.conversationTokens > 0
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Theme.surfaceLow
            clip: true

            ListView {
                id: conversation
                anchors {
                    fill: parent
                    margins: 12
                    bottomMargin: AssistantService.pendingConfirmation !== null ? 128 : 12
                }
                spacing: 6
                clip: true
                model: AssistantService.messages
                boundsBehavior: Flickable.StopAtBounds
                visible: model.length > 0

                onCountChanged: Qt.callLater(() => positionViewAtEnd())

                delegate: Item {
                    id: messageDelegate
                    required property var modelData
                    width: ListView.view.width
                    height: messageBubble.height + 4
                    readonly property bool fromUser: modelData.role === "user"
                    readonly property string messageKind: String(modelData.kind || "text")
                    readonly property var messagePayload: modelData.payload || ({})
                    readonly property var richResults: Array.isArray(messagePayload.results)
                        ? messagePayload.results : []
                    readonly property var richSources: Array.isArray(messagePayload.sources)
                        ? messagePayload.sources : []
                    readonly property var richWeather: messagePayload.weather || ({})

                    Rectangle {
                        id: messageBubble
                        x: messageDelegate.fromUser
                            ? parent.width - width : 0
                        width: Math.min(parent.width, Math.max(Math.min(240, parent.width),
                            parent.width * (messageDelegate.messageKind === "text" ? 0.78 : 0.94)))
                        height: messageContent.implicitHeight + 28
                        radius: Theme.radiusLarge
                        color: messageDelegate.fromUser
                            ? Theme.accentContainer : Theme.groupSurfaceRaised
                        border.width: messageDelegate.fromUser ? 0 : 1
                        border.color: Theme.outlineSoft

                        Column {
                            id: messageContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            spacing: Metrics.spaceS

                            Text {
                                id: messageText
                                width: parent.width
                                text: messageDelegate.modelData.text || ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: root.spacious
                                    ? Metrics.appTextBody : Metrics.textBody
                                lineHeight: 1.18
                                wrapMode: Text.Wrap
                                textFormat: messageDelegate.fromUser
                                    ? Text.PlainText : Text.MarkdownText
                                rightPadding: messageDelegate.fromUser ? 0 : 34
                            }

                            Rectangle {
                                width: parent.width
                                height: visible ? Math.round(102 * Metrics.scale) : 0
                                visible: messageDelegate.messageKind === "weather"
                                    && Object.keys(messageDelegate.richWeather).length > 0
                                radius: Metrics.tileRadius
                                color: Theme.accentContainer
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Metrics.cardPadding
                                    spacing: Metrics.spaceM
                                    Rectangle {
                                        Layout.preferredWidth: Metrics.controlL
                                        Layout.preferredHeight: Metrics.controlL
                                        radius: Metrics.iconContainerRadius
                                        color: Theme.groupSurfaceRaised
                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "partly_cloudy_day"
                                            size: Metrics.iconL
                                            color: Theme.accent
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: String(messageDelegate.richWeather.location || "")
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.spacious
                                                ? Metrics.appTextTitle : Metrics.textTitle
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: String(messageDelegate.richWeather.condition || "")
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.spacious
                                                ? Metrics.appTextSupporting : Metrics.textSupporting
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: I18n.tr("clock.weather.feels", {
                                                value: Math.round(Number(messageDelegate.richWeather.feels_like_c))
                                            }) + " · " + I18n.tr("clock.weather.humidity", {
                                                value: Math.round(Number(messageDelegate.richWeather.humidity_percent))
                                            })
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.spacious
                                                ? Metrics.appTextCaption : Metrics.textCaption
                                        }
                                    }
                                    Text {
                                        text: Math.round(Number(messageDelegate.richWeather.temperature_c)) + "°"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.round(30 * Metrics.scale)
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            Repeater {
                                model: messageDelegate.richResults
                                Rectangle {
                                    id: resultRow
                                    required property var modelData
                                    width: messageContent.width
                                    height: Math.round(54 * Metrics.scale)
                                    radius: Metrics.stateRadius
                                    color: resultHover.hovered
                                        ? Theme.surfaceHigh : Theme.surfaceLow
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Metrics.spaceM
                                        anchors.rightMargin: Metrics.spaceM
                                        spacing: Metrics.spaceM
                                        Rectangle {
                                            Layout.preferredWidth: Metrics.controlS
                                            Layout.preferredHeight: Metrics.controlS
                                            radius: Metrics.iconContainerRadius
                                            color: Theme.accentContainer
                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: resultRow.modelData.kind === "file"
                                                    ? (resultRow.modelData.icon || "draft")
                                                    : (messageDelegate.messageKind === "games"
                                                        ? "sports_esports" : "apps")
                                                size: Metrics.iconM
                                                color: Theme.accent
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text {
                                                Layout.fillWidth: true
                                                text: String(resultRow.modelData.title
                                                    || resultRow.modelData.name || "")
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: root.spacious
                                                    ? Metrics.appTextBody : Metrics.textBody
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: String(resultRow.modelData.description || "")
                                                color: Theme.textMuted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: root.spacious
                                                    ? Metrics.appTextCaption : Metrics.textCaption
                                                elide: Text.ElideMiddle
                                            }
                                        }
                                        MaterialIcon {
                                            text: "open_in_new"
                                            size: Metrics.iconS
                                            color: Theme.textMuted
                                        }
                                    }
                                    HoverHandler { id: resultHover }
                                    TapHandler {
                                        onTapped: AssistantService.activateResult(resultRow.modelData)
                                    }
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                }
                            }

                            Flow {
                                width: parent.width
                                spacing: Metrics.spaceS
                                visible: messageDelegate.richSources.length > 0
                                Repeater {
                                    model: messageDelegate.richSources
                                    Rectangle {
                                        id: sourceChip
                                        required property var modelData
                                        width: sourceText.implicitWidth + Metrics.spaceXL
                                        height: Metrics.controlS
                                        radius: Metrics.pillRadius
                                        color: sourceHover.hovered
                                            ? Theme.surfaceHigh : Theme.surfaceLow
                                        Text {
                                            id: sourceText
                                            anchors.centerIn: parent
                                            text: String(sourceChip.modelData.title || sourceChip.modelData.url || "")
                                            color: Theme.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.spacious
                                                ? Metrics.appTextCaption : Metrics.textCaption
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        HoverHandler { id: sourceHover }
                                        TapHandler {
                                            onTapped: AssistantService.activateResult(sourceChip.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        IconButton {
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: 6
                            }
                            size: 30
                            icon: "content_copy"
                            visible: !messageDelegate.fromUser
                            accessibleName: I18n.tr("assistant.copyResponse")
                            onClicked: AssistantService.copyText(
                                String(messageDelegate.modelData.text || ""))
                        }
                    }
                }

                footer: Item {
                    width: conversation.width
                    height: AssistantService.busy
                        ? Math.max(58, streamingAnswer.implicitHeight + 34) : 0
                    visible: height > 0

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                        }
                        width: AssistantService.streamingText.length > 0
                            ? Math.max(240, parent.width * 0.78) : 128
                        height: AssistantService.streamingText.length > 0
                            ? streamingAnswer.implicitHeight + 28 : 48
                        radius: Theme.radiusLarge
                        color: Theme.groupSurfaceRaised

                        MaterialIcon {
                            anchors {
                                left: parent.left
                                leftMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            visible: AssistantService.streamingText.length === 0
                            text: "progress_activity"
                            size: 18
                            color: Theme.accent
                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: Motion.spinner
                                loops: Animation.Infinite
                                running: AssistantService.busy
                            }
                        }
                        Text {
                            id: streamingAnswer
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: AssistantService.streamingText.length > 0 ? 14 : 42
                                rightMargin: 14
                            }
                            text: AssistantService.streamingText.length > 0
                                ? AssistantService.streamingText : I18n.tr("assistant.thinking")
                            color: AssistantService.streamingText.length > 0
                                ? Theme.text : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.spacious ? Metrics.appTextBody
                                : (AssistantService.streamingText.length > 0 ? 12 : 11)
                            font.weight: AssistantService.streamingText.length > 0
                                ? Font.Normal : Font.Bold
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                        Behavior on width {
                            NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors {
                    centerIn: parent
                    verticalCenterOffset: -10
                }
                width: Math.min(parent.width - 48, 430)
                spacing: 10
                visible: AssistantService.messages.length === 0

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 78
                    Layout.preferredHeight: 78
                    radius: Theme.radiusLarge
                    color: Theme.accentContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: AssistantService.providerInstalled ? "neurology" : "memory"
                        size: 38
                        color: Theme.accent
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: AssistantService.canAsk
                        ? I18n.tr("assistant.promptTitle")
                        : I18n.tr("assistant.privateTitle")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: AssistantService.canAsk
                        ? I18n.tr("assistant.promptHint")
                        : AssistantService.statusText
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 7
                    visible: AssistantService.canAsk

                    Repeater {
                        model: [
                            I18n.tr("assistant.suggestionApp"),
                            I18n.tr("assistant.suggestionFiles"),
                            I18n.tr("assistant.suggestionSystem")
                        ]
                        delegate: Rectangle {
                            id: suggestion
                            required property string modelData
                            height: 36
                            width: suggestionText.implicitWidth + 20
                            radius: Theme.radiusMedium
                            color: suggestionHover.hovered
                                ? Theme.accentContainer : Theme.surfaceHigh
                            Text {
                                id: suggestionText
                                anchors.centerIn: parent
                                text: suggestion.modelData
                                color: suggestionHover.hovered
                                    ? Theme.accent : Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }
                            HoverHandler { id: suggestionHover }
                            TapHandler {
                                onTapped: root.useSuggestion(suggestion.modelData)
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: refreshContent.implicitWidth + 24
                    Layout.preferredHeight: 38
                    radius: Theme.radiusMedium
                    color: refreshHover.hovered
                        ? Theme.accentContainer : Theme.surfaceHigh
                    visible: !AssistantService.canAsk

                    RowLayout {
                        id: refreshContent
                        anchors.centerIn: parent
                        spacing: 7
                        MaterialIcon {
                            text: "refresh"
                            size: 17
                            color: Theme.accent
                        }
                        Text {
                            text: I18n.tr("assistant.checkAgain")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                    HoverHandler { id: refreshHover }
                    TapHandler { onTapped: AssistantService.refreshCapabilities() }
                }
            }

            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 8
                }
                width: Math.min(parent.width - 32, errorText.implicitWidth + 28)
                height: errorText.implicitHeight + 18
                radius: Theme.radiusMedium
                color: Theme.tertiaryContainer
                visible: AssistantService.lastError.length > 0

                Text {
                    id: errorText
                    anchors {
                        fill: parent
                        margins: 9
                    }
                    text: AssistantService.lastError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 12
                }
                width: Math.min(parent.width - 32, 390)
                height: 104
                radius: Theme.radiusLarge
                color: Theme.surfaceHigh
                border.width: 1
                border.color: Theme.outlineSoft
                visible: AssistantService.pendingConfirmation !== null

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            text: "shield_lock"
                            size: 20
                            color: Theme.accent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -1
                            Text {
                                Layout.fillWidth: true
                                text: AssistantService.pendingConfirmation
                                    ? AssistantService.pendingConfirmation.label : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.tr("assistant.protectedActions")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 86
                            Layout.preferredHeight: 34
                            radius: Theme.radiusMedium
                            color: cancelHover.hovered
                                ? Theme.surfaceHover : Theme.surfaceLow
                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("common.cancel")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                            HoverHandler { id: cancelHover }
                            TapHandler { onTapped: AssistantService.cancelPending() }
                        }

                        Rectangle {
                            Layout.preferredWidth: 94
                            Layout.preferredHeight: 34
                            radius: Theme.radiusMedium
                            color: confirmTap.pressed
                                ? Qt.darker(Theme.accent, 1.12) : Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("common.confirm")
                                color: Theme.accentInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                            TapHandler {
                                id: confirmTap
                                onTapped: AssistantService.confirmPending()
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: showComposer
                ? Math.round(104 * Metrics.scale) : 0
            visible: showComposer
            radius: Metrics.cardRadius
            color: Theme.surfaceHigh
            border.width: 1
            border.color: chatInput.activeFocus
                ? Theme.accent : Theme.outlineSoft
            clip: true

            RowLayout {
                anchors {
                    fill: parent
                    margins: Metrics.spaceS
                }
                spacing: Metrics.spaceS

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: chatInput.implicitHeight
                    clip: true

                    TextEdit {
                        id: chatInput
                        width: parent.width
                        height: Math.max(parent.height, implicitHeight)
                        color: Theme.text
                        selectionColor: Theme.accentContainer
                        selectedTextColor: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.spacious
                            ? Metrics.appTextBody : Metrics.textBody
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        enabled: AssistantService.canAsk || AssistantService.busy

                        Keys.onPressed: event => {
                            if ((event.key === Qt.Key_Return
                                    || event.key === Qt.Key_Enter)
                                    && !(event.modifiers & Qt.ShiftModifier)) {
                                root.submitComposer()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                if (AssistantService.busy)
                                    AssistantService.cancel()
                                else
                                    root.back()
                                event.accepted = true
                            }
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            top: parent.top
                            topMargin: 2
                        }
                        visible: chatInput.text.length === 0
                        text: AssistantService.canAsk
                            ? I18n.tr("launcher.askAssistant")
                            : AssistantService.statusText
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: root.spacious
                            ? Metrics.appTextBody : Metrics.textBody
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignBottom
                    size: Metrics.controlM
                    icon: AssistantService.busy ? "stop_circle" : "send"
                    accessibleName: AssistantService.busy
                        ? I18n.tr("assistant.stopGeneration")
                        : I18n.tr("assistant.send")
                    enabled: AssistantService.busy
                        || (AssistantService.canAsk && chatInput.text.trim().length > 0)
                    onClicked: {
                        if (AssistantService.busy)
                            AssistantService.cancel()
                        else
                            root.submitComposer()
                    }
                }
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active
            && AssistantService.providerReady
            && AssistantService.models.length === 0
        onTriggered: AssistantService.refreshCapabilities()
    }

    Timer {
        interval: AssistantService.busy ? 1500 : 4000
        repeat: true
        running: root.active && AssistantService.providerReady
        triggeredOnStart: true
        onTriggered: AssistantService.refreshRuntimeMetrics()
    }
}
