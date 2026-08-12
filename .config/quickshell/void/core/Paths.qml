pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Canonical paths shared by the shell and optional standalone applications.
// A standalone window has its own Quickshell shell directory, but must still use the
// main Voidline scripts, locale catalogues, and persistent state.
QtObject {
    id: root

    readonly property string home: String(Quickshell.env("HOME") || "")
    readonly property string configHome: String(Quickshell.env("XDG_CONFIG_HOME")
        || (home + "/.config"))
    readonly property string stateHome: String(Quickshell.env("XDG_STATE_HOME")
        || (home + "/.local/state"))
    readonly property string dataHome: String(Quickshell.env("XDG_DATA_HOME")
        || (home + "/.local/share"))
    readonly property string runtimeHome: String(Quickshell.env("XDG_RUNTIME_DIR") || "")
    readonly property string configRoot: configHome + "/voidline"
    readonly property string stateRoot: stateHome + "/voidline"
    readonly property string dataRoot: dataHome + "/voidline"
    readonly property string runtimeRoot: runtimeHome + "/voidline"
    readonly property string providerConfig: configRoot + "/ai-provider.json"
    property bool writableRootsReady: false

    readonly property string shellRoot: {
        const configured = String(Quickshell.env("VOIDLINE_SHELL_ROOT") || "")
        if (configured.length > 0)
            return configured
        const current = String(Quickshell.shellDir || "")
        if (current.endsWith("/void-lyra"))
            return current.substring(0, current.length - "/void-lyra".length) + "/void"
        return current
    }

    readonly property string scripts: shellRoot + "/scripts"
    readonly property string localeRoot: shellRoot + "/i18n"
    readonly property string networkBackend: {
        const configured = String(Quickshell.env("VOIDLINE_NETWORK_BACKEND") || "")
        if (configured.length > 0)
            return configured
        return shellRoot.startsWith("/usr/share/")
            ? "/usr/lib/voidline/voidline-network"
            : home + "/.local/lib/voidline/voidline-network"
    }

    // Installed QML is read-only. Persistent data belongs in the XDG roots,
    // regardless of whether Voidline runs from /usr/share or a development tree.
    property Process createWritableRoots: Process {
        running: root.home.length > 0
        command: ["/usr/bin/install", "-d", "-m", "700",
            root.configRoot, root.stateRoot, root.dataRoot]
        onExited: (code, status) => {
            if (code === 0)
                migrateLegacyState.running = true
        }
    }

    property Process migrateLegacyState: Process {
        command: ["/usr/bin/sh", root.scripts + "/migrate-xdg-state.sh",
            root.shellRoot, root.configRoot, root.stateRoot]
        onExited: (code, status) => root.writableRootsReady = code === 0
    }
}
