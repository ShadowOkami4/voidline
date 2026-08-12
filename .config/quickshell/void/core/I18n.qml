pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property var fallbackCatalog: ({})
    property var activeCatalog: ({})
    readonly property string localeName: {
        const selected = Appearance.language
        if (selected === "en-US" || selected === "de-DE" || selected === "pl-PL")
            return selected
        const environment = String(Quickshell.env("LC_ALL")
            || Quickshell.env("LC_MESSAGES")
            || Quickshell.env("LANG") || "en-US").toLowerCase()
        if (environment.startsWith("de"))
            return "de-DE"
        if (environment.startsWith("pl"))
            return "pl-PL"
        return "en-US"
    }
    readonly property var locale: Qt.locale(localeName)

    function parseCatalog(contents) {
        try {
            return JSON.parse(String(contents || "{}"))
        } catch (error) {
            console.warn("Voidline: invalid locale catalog", error)
            return ({})
        }
    }

    function lookup(catalog, key) {
        const parts = String(key || "").split(".")
        let value = catalog
        for (let index = 0; index < parts.length; ++index) {
            if (!value || value[parts[index]] === undefined)
                return undefined
            value = value[parts[index]]
        }
        return value
    }

    function interpolate(template, values) {
        let result = String(template === undefined ? "" : template)
        const data = values || ({})
        const keys = Object.keys(data)
        for (let index = 0; index < keys.length; ++index)
            result = result.replace(new RegExp("\\{" + keys[index] + "\\}", "g"),
                String(data[keys[index]]))
        return result
    }

    function tr(key, values) {
        let value = lookup(activeCatalog, key)
        if (value === undefined)
            value = lookup(fallbackCatalog, key)
        if (value === undefined)
            return String(key)
        return interpolate(value, values)
    }

    function plural(key, count, values) {
        let forms = lookup(activeCatalog, key)
        if (!forms || typeof forms !== "object")
            forms = lookup(fallbackCatalog, key)
        if (!forms || typeof forms !== "object")
            return tr(key, Object.assign({ count: count }, values || ({})))
        let form = "other"
        if (localeName === "pl-PL") {
            if (count === 1)
                form = "one"
            else if (count % 10 >= 2 && count % 10 <= 4
                    && !(count % 100 >= 12 && count % 100 <= 14))
                form = "few"
            else
                form = "many"
        } else {
            form = count === 1 ? "one" : "other"
        }
        return interpolate(forms[form] || forms.other || "",
            Object.assign({ count: count }, values || ({})))
    }

    function formatDate(date, format) {
        return date.toLocaleDateString(locale, format || Locale.LongFormat)
    }

    function formatTime(date, format) {
        return date.toLocaleTimeString(locale, format || Locale.ShortFormat)
    }

    property var englishFile: FileView {
        path: Paths.shellRoot + "/i18n/en-US.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.fallbackCatalog = root.parseCatalog(text())
    }

    property var localeFile: FileView {
        path: Paths.shellRoot + "/i18n/" + root.localeName + ".json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.activeCatalog = root.parseCatalog(text())
    }

    onLocaleNameChanged: localeFile.reload()
}
