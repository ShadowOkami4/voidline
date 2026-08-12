import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    property date date: new Date()
    property string style: Appearance.lockClockStyle
    property string clockFont: Appearance.lockClockFont
    property int clockWeight: Appearance.lockClockWeight
    property real clockScale: Appearance.lockClockSize
    property real characterSpacing: Appearance.lockClockSpacing
    property bool showDate: Appearance.lockShowDate
    property string datePlacement: Appearance.lockDatePlacement
    property bool showWeather: Appearance.lockShowWeather
    property bool showWeatherTemperature: Appearance.lockShowWeatherTemperature
    property bool showWeatherCondition: Appearance.lockShowWeatherCondition
    property bool showWeatherIcon: Appearance.lockShowWeatherIcon
    property bool showWeatherForecast: Appearance.lockShowWeatherForecast
    property string colorMode: Appearance.lockClockColorMode
    property color customColor1: Appearance.lockClockColor1
    property color customColor2: Appearance.lockClockColor2
    property bool preview: false
    readonly property real renderScale: preview
        ? Math.max(0.2, Math.min(width / 660, height / 280))
        : Math.max(0.55, Math.min(1, width / 660, height / 280))

    readonly property color primaryColor: colorMode === "wallpaper"
        ? (Theme.darkMode ? "#FFFFFF" : Theme.text)
        : customColor1
    readonly property color secondaryColor: colorMode === "gradient"
        ? customColor2 : (colorMode === "wallpaper" ? Theme.secondary : customColor1)
    readonly property string timeText: Qt.formatDateTime(date, "hh:mm")
    readonly property string dateText: I18n.formatDate(date, Locale.LongFormat)
    readonly property string weatherText: {
        if (!WeatherService.available)
            return I18n.tr("lock.weatherUnavailable")
        const values = []
        if (showWeatherTemperature)
            values.push(Math.round(Number(WeatherService.weather.temperature_c)) + "°")
        if (showWeatherCondition)
            values.push(String(WeatherService.weather.condition || ""))
        if (showWeatherForecast && WeatherService.weather.daily) {
            const daily = WeatherService.weather.daily
            const highs = Array.isArray(daily.temperature_2m_max)
                ? daily.temperature_2m_max : []
            const lows = Array.isArray(daily.temperature_2m_min)
                ? daily.temperature_2m_min : []
            if (highs.length > 0 && lows.length > 0)
                values.push("↑" + Math.round(Number(highs[0])) + "° · ↓"
                    + Math.round(Number(lows[0])) + "°")
        }
        return values.join(" · ")
    }

    implicitWidth: 520
    implicitHeight: 230

    Canvas {
        id: analogClock
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.82
        height: width
        visible: root.style === "analog"
        antialiasing: true

        onPaint: {
            const context = getContext("2d")
            context.reset()
            const center = width / 2
            const radius = width * 0.43
            context.translate(center, center)
            context.lineCap = "round"

            context.strokeStyle = root.primaryColor
            context.lineWidth = Math.max(2, width * 0.018)
            context.beginPath()
            context.arc(0, 0, radius, 0, Math.PI * 2)
            context.stroke()

            for (let index = 0; index < 12; ++index) {
                const angle = index * Math.PI / 6
                const inner = radius * (index % 3 === 0 ? 0.78 : 0.86)
                context.strokeStyle = index % 3 === 0
                    ? root.primaryColor : root.secondaryColor
                context.lineWidth = index % 3 === 0 ? 3 : 1.5
                context.beginPath()
                context.moveTo(Math.sin(angle) * inner, -Math.cos(angle) * inner)
                context.lineTo(Math.sin(angle) * radius, -Math.cos(angle) * radius)
                context.stroke()
            }

            const hours = root.date.getHours() % 12
            const minutes = root.date.getMinutes()
            const hourAngle = (hours + minutes / 60) * Math.PI / 6
            const minuteAngle = minutes * Math.PI / 30
            context.strokeStyle = root.primaryColor
            context.lineWidth = 6
            context.beginPath()
            context.moveTo(0, 0)
            context.lineTo(Math.sin(hourAngle) * radius * 0.52,
                -Math.cos(hourAngle) * radius * 0.52)
            context.stroke()
            context.strokeStyle = root.secondaryColor
            context.lineWidth = 4
            context.beginPath()
            context.moveTo(0, 0)
            context.lineTo(Math.sin(minuteAngle) * radius * 0.75,
                -Math.cos(minuteAngle) * radius * 0.75)
            context.stroke()
            context.fillStyle = root.primaryColor
            context.beginPath()
            context.arc(0, 0, 6, 0, Math.PI * 2)
            context.fill()
        }

        Connections {
            target: root
            function onDateChanged() { analogClock.requestPaint() }
            function onPrimaryColorChanged() { analogClock.requestPaint() }
            function onSecondaryColorChanged() { analogClock.requestPaint() }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 620)
        spacing: root.style === "minimal" ? 7 : 2
        visible: root.style !== "analog"

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showDate && root.datePlacement === "above"
            text: root.dateText
            color: root.secondaryColor
            font.family: root.clockFont
            font.pixelSize: Math.round(18 * root.renderScale * root.clockScale)
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(18 * root.renderScale)

            Text {
                text: root.style === "stacked"
                    ? Qt.formatDateTime(root.date, "hh") + "\n"
                        + Qt.formatDateTime(root.date, "mm")
                    : root.timeText
                color: root.primaryColor
                font.family: root.style === "playful" ? "URW Chancery L" : root.clockFont
                font.pixelSize: Math.round((root.style === "minimal" ? 62
                    : (root.style === "digital-compact" ? 76 : 104))
                    * root.renderScale * root.clockScale)
                font.weight: root.style === "minimal" ? Font.Medium : root.clockWeight
                font.letterSpacing: root.characterSpacing
                font.variableAxes: {
                    "wght": root.clockWeight,
                    "wdth": root.style === "playful" ? 110 : 88,
                    "opsz": 96,
                    "GRAD": root.style === "playful" ? 110 : 60
                }
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.78
                rotation: root.style === "playful" ? -2 : 0
            }

            ColumnLayout {
                visible: (root.showDate && root.datePlacement === "side")
                    || root.showWeather
                spacing: 2
                Text {
                    visible: root.showDate && root.datePlacement === "side"
                    text: root.dateText
                    color: root.secondaryColor
                    font.family: root.clockFont
                    font.pixelSize: Math.round(16 * root.renderScale)
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    Layout.maximumWidth: Math.round(190 * root.renderScale)
                }
                RowLayout {
                    visible: root.showWeather
                    spacing: Math.round(4 * root.renderScale)
                    MaterialIcon {
                        visible: root.showWeatherIcon && WeatherService.available
                        text: WeatherService.iconForCode(
                            WeatherService.weather.weather_code)
                        size: Math.round(15 * root.renderScale)
                        color: root.secondaryColor
                    }
                    Text {
                        text: root.weatherText
                        color: root.secondaryColor
                        font.family: root.clockFont
                        font.pixelSize: Math.round(13 * root.renderScale)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showDate && root.datePlacement === "below"
            text: root.dateText
            color: root.secondaryColor
            font.family: root.clockFont
            font.pixelSize: Math.round(18 * root.renderScale * root.clockScale)
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showWeather && root.datePlacement !== "side"
            spacing: Math.round(4 * root.renderScale)
            MaterialIcon {
                visible: root.showWeatherIcon && WeatherService.available
                text: WeatherService.iconForCode(
                    WeatherService.weather.weather_code)
                size: Math.round(15 * root.renderScale)
                color: root.secondaryColor
            }
            Text {
                text: root.weatherText
                color: root.secondaryColor
                font.family: root.clockFont
                font.pixelSize: Math.round(13 * root.renderScale)
            }
        }
    }
}
