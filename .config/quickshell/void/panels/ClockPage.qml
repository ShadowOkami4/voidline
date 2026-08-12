import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    property string page: "calendar"
    property string timerName: ""
    property int timerHours: 0
    property int timerMinutes: 5
    property int timerSeconds: 0

    function monthLabel(date) {
        return I18n.locale.monthName(date.getMonth() + 1, Locale.LongFormat)
            + " " + date.getFullYear()
    }

    function sameDay(first, second) {
        return first.getFullYear() === second.getFullYear()
            && first.getMonth() === second.getMonth()
            && first.getDate() === second.getDate()
    }

    function calendarDays() {
        const month = ClockService.displayMonth
        const first = new Date(month.getFullYear(), month.getMonth(), 1)
        const jsDay = first.getDay() === 0 ? 7 : first.getDay()
        const localeFirst = Number(I18n.locale.firstDayOfWeek) || 1
        const offset = (jsDay - localeFirst + 7) % 7
        const start = new Date(first.getFullYear(), first.getMonth(), 1 - offset)
        const result = []
        for (let index = 0; index < 42; ++index) {
            const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index)
            result.push({
                date: date,
                day: date.getDate(),
                currentMonth: date.getMonth() === month.getMonth(),
                today: sameDay(date, new Date()),
                selected: sameDay(date, ClockService.selectedDate)
            })
        }
        return result
    }

    function weekDays() {
        const result = []
        const first = Number(I18n.locale.firstDayOfWeek) || 1
        for (let index = 0; index < 7; ++index) {
            const day = ((first - 1 + index) % 7) + 1
            result.push(I18n.locale.dayName(day, Locale.ShortFormat))
        }
        return result
    }

    function startTimer() {
        const total = timerHours * 3600 + timerMinutes * 60 + timerSeconds
        if (total > 0)
            ClockService.startTimer(total, timerName)
    }

    function forecastDays() {
        if (!WeatherService.available || !WeatherService.weather.daily)
            return []
        const daily = WeatherService.weather.daily
        const dates = Array.isArray(daily.time) ? daily.time : []
        const highs = Array.isArray(daily.temperature_2m_max)
            ? daily.temperature_2m_max : []
        const lows = Array.isArray(daily.temperature_2m_min)
            ? daily.temperature_2m_min : []
        const rain = Array.isArray(daily.precipitation_probability_max)
            ? daily.precipitation_probability_max : []
        const codes = Array.isArray(daily.weather_code) ? daily.weather_code : []
        return dates.slice(0, 5).map((date, index) => ({
            date: new Date(date + "T12:00:00"),
            high: Number(highs[index]) || 0,
            low: Number(lows[index]) || 0,
            rain: Number(rain[index]) || 0,
            code: Number(codes[index]) || 0
        }))
    }

    onActiveChanged: {
        WeatherService.setPanelActive(active)
        ClockService.setUiActive(active)
    }
    Component.onDestruction: {
        WeatherService.setPanelActive(false)
        ClockService.setUiActive(false)
    }

    component DurationInput: Rectangle {
        id: durationRoot
        property string label: ""
        property int number: 0
        property int maximum: 59
        signal changed(int value)

        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(72 * Metrics.scale)
        radius: Metrics.tileRadius
        color: Theme.groupSurfaceRaised

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spaceS
            spacing: 0
            TextInput {
                id: durationField
                Layout.fillWidth: true
                text: String(durationRoot.number).padStart(2, "0")
                color: Theme.text
                selectionColor: Theme.accentContainer
                selectedTextColor: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(24 * Metrics.scale)
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                validator: IntValidator { bottom: 0; top: durationRoot.maximum }
                inputMethodHints: Qt.ImhDigitsOnly
                onEditingFinished: durationRoot.changed(Math.max(0,
                    Math.min(durationRoot.maximum, Number(text) || 0)))
            }
            Text {
                Layout.fillWidth: true
                text: durationRoot.label
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.textCaption
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spaceM

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.panelHeaderHeight
            spacing: Metrics.spaceM

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                Text {
                    Layout.fillWidth: true
                    text: I18n.formatDate(new Date(), Locale.LongFormat)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textHeader
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: WeatherService.available
                        ? Math.round(Number(WeatherService.weather.temperature_c)) + "° · "
                            + String(WeatherService.weather.condition || "")
                        : I18n.tr("clock.subtitle")
                    color: WeatherService.available ? Theme.accent : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textSupporting
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "close"
                accessibleName: I18n.tr("common.close")
                onClicked: ShellState.closePanels()
            }
        }

        SlidingChoice {
            Layout.fillWidth: true
            options: ["calendar", "timer", "stopwatch", "weather"]
            optionLabels: [
                I18n.tr("clock.calendar.title"),
                I18n.tr("clock.timer.title"),
                I18n.tr("clock.stopwatch.title"),
                I18n.tr("clock.weather.title")
            ]
            value: root.page
            maxColumns: 4
            onSelected: value => root.page = value
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Metrics.spaceS
                visible: root.page === "calendar"

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Metrics.controlM
                    IconButton {
                        icon: "chevron_left"
                        accessibleName: I18n.tr("clock.calendar.previous")
                        onClicked: ClockService.previousMonth()
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.monthLabel(ClockService.displayMonth)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textTitle
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                    IconButton {
                        icon: "chevron_right"
                        accessibleName: I18n.tr("clock.calendar.next")
                        onClicked: ClockService.nextMonth()
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: Metrics.spaceXS
                    rowSpacing: Metrics.spaceXS

                    Repeater {
                        model: root.weekDays()
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Metrics.controlS
                            text: modelData
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Metrics.textCaption
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Repeater {
                        model: root.calendarDays()
                        Rectangle {
                            id: dayCell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(48 * Metrics.scale)
                            radius: Metrics.tileRadius
                            color: modelData.selected ? Theme.accentContainer
                                : (dayHover.hovered ? Theme.groupSurfaceRaised : "transparent")
                            border.width: modelData.today ? Metrics.focusBorder : 0
                            border.color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.day
                                color: dayCell.modelData.currentMonth
                                    ? Theme.text : Theme.textMuted
                                opacity: dayCell.modelData.currentMonth ? 1 : 0.55
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textBody
                                font.weight: dayCell.modelData.today
                                    || dayCell.modelData.selected ? Font.Bold : Font.Medium
                            }
                            HoverHandler { id: dayHover }
                            TapHandler {
                                onTapped: ClockService.selectedDate = dayCell.modelData.date
                            }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
                ActionChip {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "today"
                    label: I18n.tr("clock.calendar.today")
                    onClicked: ClockService.showToday()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Metrics.spaceM
                visible: root.page === "timer"

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("clock.timer.new")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textTitle
                    font.weight: Font.DemiBold
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spaceS
                    DurationInput {
                        label: I18n.tr("clock.timer.hours")
                        number: root.timerHours
                        maximum: 99
                        onChanged: value => root.timerHours = value
                    }
                    DurationInput {
                        label: I18n.tr("clock.timer.minutes")
                        number: root.timerMinutes
                        onChanged: value => root.timerMinutes = value
                    }
                    DurationInput {
                        label: I18n.tr("clock.timer.seconds")
                        number: root.timerSeconds
                        onChanged: value => root.timerSeconds = value
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Metrics.inputHeight
                    radius: Metrics.tileRadius
                    color: Theme.groupSurfaceRaised
                    TextInput {
                        anchors.fill: parent
                        anchors.leftMargin: Metrics.inputPaddingX
                        anchors.rightMargin: Metrics.inputPaddingX
                        verticalAlignment: Text.AlignVCenter
                        text: root.timerName
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textBody
                        onTextChanged: root.timerName = text
                        Text {
                            anchors.fill: parent
                            visible: parent.text.length === 0 && !parent.activeFocus
                            text: I18n.tr("clock.timer.name")
                            color: Theme.textMuted
                            font: parent.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                ActionChip {
                    Layout.alignment: Qt.AlignRight
                    icon: "play_arrow"
                    label: I18n.tr("clock.timer.start")
                    active: true
                    onClicked: root.startTimer()
                }

                Text {
                    Layout.fillWidth: true
                    visible: ClockService.timers.length > 0
                    text: I18n.tr("clock.timer.running")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textTitle
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: ClockService.timers
                    Rectangle {
                        id: timerCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(74 * Metrics.scale)
                        radius: Metrics.tileRadius
                        color: Theme.groupSurfaceRaised
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Metrics.cardPadding
                            spacing: Metrics.spaceS
                            MaterialIcon {
                                text: timerCard.modelData.running ? "timer" : "pause"
                                size: Metrics.iconL
                                color: Theme.accent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: timerCard.modelData.name.length > 0
                                        ? timerCard.modelData.name : I18n.tr("clock.timer.defaultName")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.textBody
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: ClockService.remainingLabel(timerCard.modelData)
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.textTitle
                                    font.weight: Font.Bold
                                }
                            }
                            IconButton {
                                icon: timerCard.modelData.running ? "pause" : "play_arrow"
                                accessibleName: timerCard.modelData.running
                                    ? I18n.tr("clock.timer.pause") : I18n.tr("clock.timer.resume")
                                onClicked: timerCard.modelData.running
                                    ? ClockService.pauseTimer(timerCard.modelData.id)
                                    : ClockService.resumeTimer(timerCard.modelData.id)
                            }
                            IconButton {
                                icon: "close"
                                accessibleName: I18n.tr("clock.timer.cancel")
                                onClicked: ClockService.cancelTimer(timerCard.modelData.id)
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Metrics.spaceL
                visible: root.page === "stopwatch"

                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: ClockService.stopwatchLabel()
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(52 * Metrics.scale)
                    font.weight: Font.DemiBold
                    font.letterSpacing: -1
                    horizontalAlignment: Text.AlignHCenter
                    font.features: { "tnum": 1 }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Metrics.spaceM
                    ActionChip {
                        icon: ClockService.stopwatchRunning ? "pause" : "play_arrow"
                        label: ClockService.stopwatchRunning
                            ? I18n.tr("clock.timer.pause") : I18n.tr("clock.timer.start")
                        active: true
                        onClicked: ClockService.stopwatchRunning
                            ? ClockService.pauseStopwatch() : ClockService.startStopwatch()
                    }
                    ActionChip {
                        visible: ClockService.stopwatchRunning
                            || ClockService.stopwatchElapsedMs > 0
                        icon: "flag"
                        label: I18n.tr("clock.stopwatch.lap")
                        available: ClockService.stopwatchRunning
                        onClicked: ClockService.addStopwatchLap()
                    }
                    ActionChip {
                        icon: "restart_alt"
                        label: I18n.tr("clock.stopwatch.reset")
                        onClicked: ClockService.resetStopwatch()
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(330 * Metrics.scale)
                    Layout.alignment: Qt.AlignHCenter
                    visible: ClockService.stopwatchLaps.length > 0
                    spacing: Metrics.spaceXS

                    Repeater {
                        model: ClockService.stopwatchLaps.slice(0, 5)
                        Rectangle {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Metrics.controlS
                            radius: Metrics.tileRadius
                            color: Theme.groupSurface
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Metrics.spaceM
                                anchors.rightMargin: Metrics.spaceM
                                Text {
                                    text: I18n.tr("clock.stopwatch.lapNumber", {
                                        number: ClockService.stopwatchLaps.length - index
                                    })
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.textSupporting
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: ClockService.formatStopwatch(modelData.elapsedMs)
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.textBody
                                    font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Metrics.spaceM
                visible: root.page === "weather"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: WeatherService.available
                        ? Math.round(218 * Metrics.scale) : Math.round(110 * Metrics.scale)
                    radius: Metrics.cardRadius
                    color: Theme.accentContainer
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.cardPaddingWide
                        spacing: Metrics.spaceS
                        RowLayout {
                            Layout.fillWidth: true
                            MaterialIcon {
                                text: WeatherService.available
                                    ? WeatherService.iconForCode(
                                        WeatherService.weather.weather_code)
                                    : "location_on"
                                size: Metrics.iconXL
                                color: Theme.accent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: WeatherService.available
                                        ? String(WeatherService.weather.location || Appearance.weatherLocation)
                                        : I18n.tr("clock.weather.location")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.textTitle
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: WeatherService.available
                                        ? String(WeatherService.weather.condition || "")
                                        : I18n.tr("clock.weather.locationHint")
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.textSupporting
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Text {
                                visible: WeatherService.available
                                text: Math.round(Number(WeatherService.weather.temperature_c)) + "°"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.round(38 * Metrics.scale)
                                font.weight: Font.Bold
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: WeatherService.available
                            spacing: Metrics.spaceL
                            Text {
                                text: I18n.tr("clock.weather.feels", { value: Math.round(Number(WeatherService.weather.feels_like_c)) })
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                            }
                            Text {
                                text: I18n.tr("clock.weather.humidity", { value: Math.round(Number(WeatherService.weather.humidity_percent)) })
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                            }
                            Text {
                                text: I18n.tr("clock.weather.wind", { value: Number(WeatherService.weather.wind_kmh).toFixed(1) })
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: WeatherService.available
                            spacing: Metrics.spaceL
                            Text {
                                text: root.forecastDays().length > 0
                                    ? I18n.tr("clock.weather.highLow", {
                                        high: Math.round(root.forecastDays()[0].high),
                                        low: Math.round(root.forecastDays()[0].low)
                                    }) : ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                            }
                            Text {
                                text: root.forecastDays().length > 0
                                    ? I18n.tr("clock.weather.precipitation", {
                                        value: root.forecastDays()[0].rain
                                    }) : ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: I18n.tr("clock.weather.updated", {
                                    time: Qt.formatTime(new Date(WeatherService.lastUpdated), "HH:mm")
                                })
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textCaption
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible
                        ? Math.round(100 * Metrics.scale) : 0
                    visible: root.forecastDays().length > 0
                    radius: Metrics.cardRadius
                    color: Theme.groupSurface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.spaceS
                        spacing: Metrics.spaceXS

                        Repeater {
                            model: root.forecastDays()
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Metrics.tileRadius
                                color: Theme.surfaceLow

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Metrics.spaceXS
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.locale.dayName(
                                            modelData.date.getDay() === 0
                                                ? 7 : modelData.date.getDay(),
                                            Locale.ShortFormat)
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Metrics.textCaption
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: WeatherService.iconForCode(modelData.code)
                                        size: Metrics.iconM
                                        color: Theme.accent
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: Math.round(modelData.high) + "° / "
                                            + Math.round(modelData.low) + "°"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Metrics.textSupporting
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.rain + "%"
                                        color: Theme.secondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Metrics.textCaption
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsField {
                    Layout.fillWidth: true
                    title: I18n.tr("clock.weather.manualLocation")
                    subtitle: I18n.tr("clock.weather.privacy")
                    icon: "location_on"
                    value: Appearance.weatherLocation
                    placeholder: I18n.tr("clock.weather.example")
                    onAccepted: value => WeatherService.setLocation(value)
                }
                Text {
                    Layout.fillWidth: true
                    visible: WeatherService.loading || WeatherService.error.length > 0
                    text: WeatherService.loading
                        ? I18n.tr("clock.weather.loading") : WeatherService.error
                    color: WeatherService.error.length > 0 ? Theme.danger : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textSupporting
                    wrapMode: Text.WordWrap
                }
                ActionChip {
                    Layout.alignment: Qt.AlignRight
                    icon: "refresh"
                    label: I18n.tr("common.refresh")
                    available: WeatherService.configured && !WeatherService.loading
                    onClicked: WeatherService.refresh(true)
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    visible: WeatherService.available
                    text: I18n.tr("clock.weather.source")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textCaption
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
