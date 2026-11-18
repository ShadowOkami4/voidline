pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Finding and installing apps. Uses what the system already has: pacman for
// the distribution's packages (asks for the password through the usual
// dialog) and Flatpak for Flathub, when it is installed. Nothing runs until
// you search or press a button.
Singleton {
    id: root

    property bool hasPacman: false
    property bool hasFlatpak: false
    // Steam and other 32-bit software live in pacman's "multilib" source,
    // which is switched off on a fresh Arch.
    property bool hasMultilib: false
    readonly property bool available: hasPacman || hasFlatpak

    // { source: "pacman" | "flatpak", id, name, summary, version, repo, installed }
    property var results: []
    property bool searching: false
    property string query: ""

    // What is being installed, removed or updated right now ("" = nothing),
    // the last line it printed, and how the last job ended.
    property string busy: ""
    property string busyKind: ""
    property string progress: ""
    property string lastDone: ""
    property bool lastOk: true
    property string problem: ""

    // Packages the computer cannot do without; never offered for removal.
    readonly property var vital: /^(base|base-devel|linux.*|systemd.*|pacman|glibc|bash|coreutils|filesystem|sudo|polkit|grub|mkinitcpio|networkmanager|mesa|quickshell.*|hyprland|niri|pipewire.*|wireplumber|sddm|dbus.*|util-linux|shadow|gcc-libs)$/
    function removable(p) { return p.installed && (p.source === "flatpak" || !vital.test(p.id)) }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v pacman >/dev/null && echo pacman; command -v flatpak >/dev/null && echo flatpak; pacman-conf --repo-list 2>/dev/null | grep -qx multilib && echo multilib; true"]
        stdout: StdioCollector {
            onStreamFinished: { root.hasPacman = text.includes("pacman"); root.hasFlatpak = text.includes("flatpak"); root.hasMultilib = text.includes("multilib") }
        }
    }

    // ---- search ------------------------------------------------------------------------
    function search(text) {
        const q = String(text).trim().slice(0, 60)
        query = q
        if (q.length < 2) { results = []; searching = false; return }
        if (find.running) { later.restart(); return }
        searching = true
        find.asked = q
        // The words go in as data, never as part of the command.
        find.command = ["sh", "-c", `
export LC_ALL=C
if command -v pacman >/dev/null; then echo "@@pacman"; pacman -Ss -- "$1" 2>/dev/null | head -n 600; fi
if command -v flatpak >/dev/null; then
    echo "@@installed"; flatpak list --app --columns=application 2>/dev/null
    echo "@@flatpak"; flatpak search --columns=application,name,description,version -- "$1" 2>/dev/null | head -n 40
fi
true`, "sh", q]
        find.running = true
    }
    Timer { id: later; interval: 300; onTriggered: root.search(root.query) }
    Process {
        id: find
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const q = find.asked.toLowerCase()
                const out = []
                const have = {}
                let part = ""
                let cur = null
                for (const line of text.split("\n")) {
                    if (line.startsWith("@@")) { part = line.slice(2); continue }
                    if (part === "pacman") {
                        const m = line.match(/^([\w.-]+)\/(\S+) (\S+)(.*)$/)
                        if (m) { cur = { source: "pacman", repo: m[1], id: m[2], name: m[2], version: m[3], installed: m[4].includes("[installed"), summary: "" }; out.push(cur) }
                        else if (cur && line.startsWith("    ")) cur.summary = line.trim()
                    } else if (part === "installed") {
                        if (line.trim().length > 0) have[line.trim()] = true
                    } else if (part === "flatpak") {
                        const p = line.split("\t")
                        if (p.length >= 3 && /^[A-Za-z0-9._-]+$/.test(p[0]) && p[0].includes("."))
                            out.push({ source: "flatpak", repo: "Flathub", id: p[0], name: p[1], summary: p[2], version: p[3] || "", installed: !!have[p[0]] })
                    }
                }
                // Best matches first: the name itself, then names that start
                // with the words, then the rest; helper packages go last.
                const rank = p => {
                    const n = p.name.toLowerCase()
                    let r = n === q ? 0 : (n.startsWith(q) ? 1 : (n.includes(q) ? 2 : 3))
                    if (p.source === "pacman" && /^(lib|python-|perl-|haskell-|ruby-|lib32-|php-|r-|ttf-|otf-)|-(docs?|debug|headers|i18n-.*|l10n-.*)$/.test(n)) r += 3
                    return r
                }
                // Steam is not in the lists while multilib is off; offer it anyway,
                // installing switches the source on.
                if (root.hasPacman && !root.hasMultilib && q.length >= 3 && ("steam".startsWith(q) || q.includes("steam") || q === "valve") && !out.some(p => p.id === "steam"))
                    out.push({ source: "pacman", repo: "multilib", id: "steam", name: "steam", version: "", installed: false, needsMultilib: true,
                        summary: Lang.t("Valve's game store. Installing switches on the 32-bit package source and updates the system first.") })
                out.sort((a, b) => rank(a) - rank(b) || a.name.length - b.name.length || a.name.localeCompare(b.name))
                root.results = out.slice(0, 40)
                root.searching = false
                if (find.asked !== root.query) later.restart()
            }
        }
    }

    // ---- install, remove, update ---------------------------------------------------------
    function start(kind, label, command) {
        if (busy.length > 0) return
        busy = label
        busyKind = kind
        progress = ""
        problem = ""
        job.command = command
        job.running = true
    }
    function install(p) {
        // Steam needs the multilib source and the 32-bit graphics driver
        // that matches the one in use. pacman.conf is backed up first; the
        // system is updated in the same go, as a new source requires.
        if (p.source === "pacman" && p.id === "steam")
            start("install", p.name, ["pkexec", "sh", "-c", `
set -e
if ! pacman-conf --repo-list | grep -qx multilib; then
    cp -p /etc/pacman.conf /etc/pacman.conf.voidline-backup
    if grep -q '^#\\[multilib\\]' /etc/pacman.conf; then
        sed -i '/^#\\[multilib\\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    else
        printf '\\n[multilib]\\nInclude = /etc/pacman.d/mirrorlist\\n' >> /etc/pacman.conf
    fi
fi
drivers=""
for d in vulkan-radeon vulkan-intel nvidia-utils vulkan-nouveau; do
    pacman -Qq "$d" >/dev/null 2>&1 && drivers="$drivers lib32-$d"
done
pacman -Syu --noconfirm --needed steam $drivers`])
        else if (p.source === "pacman" && /^[a-z0-9@._+-]+$/.test(p.id))
            start("install", p.name, ["pkexec", "pacman", "-S", "--noconfirm", "--needed", "--", p.id])
        else if (p.source === "flatpak" && /^[A-Za-z0-9._-]+$/.test(p.id))
            start("install", p.name, ["sh", "-c", `
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo &&
flatpak install --user -y --noninteractive flathub "$1"`, "sh", p.id])
    }
    function remove(p) {
        if (!removable(p)) return
        if (p.source === "pacman" && /^[a-z0-9@._+-]+$/.test(p.id))
            start("remove", p.name, ["pkexec", "pacman", "-R", "--noconfirm", "--", p.id])
        else if (p.source === "flatpak" && /^[A-Za-z0-9._-]+$/.test(p.id))
            start("remove", p.name, ["flatpak", "uninstall", "-y", "--noninteractive", p.id])
    }
    // Brings every package up to date; also the cure when installing fails
    // because the package lists are old.
    function updateAll() {
        start("update", Lang.t("System update"), ["sh", "-c", `
if command -v pacman >/dev/null; then pkexec pacman -Syu --noconfirm || exit 1; fi
if command -v flatpak >/dev/null; then flatpak update -y --noninteractive; fi
true`])
    }

    Process {
        id: job
        environment: ({ LC_ALL: "C" })
        stdout: SplitParser { onRead: line => root.note(line) }
        stderr: SplitParser { onRead: line => root.note(line) }
        onExited: code => {
            root.lastOk = code === 0
            root.lastDone = root.busy
            const kind = root.busyKind
            if (code === 126 || code === 127) root.problem = Lang.t("Cancelled: the password was not given.")
            else if (code !== 0) root.problem = /404|failed retrieving|not found in sync db|could not find/i.test(root.progress + root.seen)
                ? Lang.t("That did not work: the package lists are old. Press \"Update everything\" and try again.")
                : (root.progress.length > 0 ? Lang.t("That did not work: ") + root.progress : Lang.t("That did not work."))
            else root.problem = ""
            root.busy = ""
            root.busyKind = ""
            root.seen = ""
            if (code === 0 && kind !== "update")
                Quickshell.execDetached(["notify-send", "-a", "Voidline", "-i", kind === "remove" ? "voidline-delete" : "voidline-download_done", root.lastDone, kind === "remove" ? Lang.t("Removed") : Lang.t("Installed. You find it in the launcher.")])
            probe.running = true
            if (root.query.length > 1) root.search(root.query)
            root.countUpdates()
        }
    }
    property string seen: ""
    function note(line) {
        const clean = String(line).replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\r/g, "").trim()
        if (clean.length === 0) return
        progress = clean.slice(0, 140)
        seen = (seen + " " + clean).slice(-600)
    }

    // ---- how many updates wait ---------------------------------------------------------
    property int updates: -1        // -1 = not known
    // Looks a few minutes after starting and then twice a day; tells you once a day.
    Timer { interval: 5 * 60 * 1000; running: Config.updateNotify; onTriggered: root.countUpdates() }
    Timer { interval: 12 * 60 * 60 * 1000; running: Config.updateNotify; repeat: true; onTriggered: root.countUpdates() }
    onUpdatesChanged: {
        const today = new Date().toDateString()
        if (!Config.updateNotify || updates < 1 || Config.updateToldOn === today || busy.length > 0 || Shell.settingsOpen) return
        Config.updateToldOn = today
        Quickshell.execDetached(["sh", "-c", `
answer=$(timeout 3h notify-send -a Voidline -i voidline-system_update_alt --action=open="$3" "$1" "$2")
[ "$answer" = open ] && qs -c voidline ipc call shell settingsPage install
true`, "sh", Lang.t("Updates are waiting"), Lang.t("%1 updates for your system.", updates), Lang.t("Show")])
    }
    function countUpdates() { if (!count.running) count.running = true }
    Process {
        id: count
        command: ["sh", "-c", "command -v checkupdates >/dev/null || { echo none; exit 0; }; checkupdates 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.updates = text.includes("none") ? -1 : (Number(text.trim()) || 0)
        }
    }
}
