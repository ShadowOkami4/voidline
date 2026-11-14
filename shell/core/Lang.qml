pragma Singleton
import Quickshell
import QtQuick
import "lang/de.js" as De

// Translations. The shell is written in English; Lang.t("English text") looks
// the text up in the table of the language in use and falls back to English.
// A new language is one more file in core/lang plus a line in `tables`.
Singleton {
    id: root

    // Languages that have a table, with the name shown in Settings.
    readonly property var languages: [
        { value: "en", label: "English" },
        { value: "de", label: "Deutsch" }
    ]
    readonly property var tables: ({ de: De.words })

    // The language of the system, as "de" or "en".
    readonly property string system: Qt.locale().name.slice(0, 2).toLowerCase()
    // Config.language is "" (follow the system) or one of the codes above.
    readonly property string code: Config.language.length > 0 ? Config.language : (tables[system] ? system : "en")
    readonly property var table: tables[code] ?? null
    // Used for the names of days and months.
    readonly property var locale: code === system ? Qt.locale() : Qt.locale(code === "en" ? "en_GB" : code)

    // Lang.t("Hello")            plain text
    // Lang.t("%1 of %2", a, b)   with values put in
    // Lang.t("Windows##wm")      the part after ## tells two meanings of one
    //                            English word apart and is never shown
    function t(text, a, b) {
        let s = table ? table[text] : undefined
        if (s === undefined) {
            const cut = text.indexOf("##")
            s = cut < 0 ? text : text.slice(0, cut)
        }
        if (a !== undefined) s = s.replace("%1", a)
        if (b !== undefined) s = s.replace("%2", b)
        return s
    }

    // A date written out in the language in use.
    function date(when, format) { return locale.toString(when, format) }
}
