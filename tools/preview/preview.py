#!/usr/bin/env python3
"""Voidline design preview.

Renders the real Voidline QML (bar, panels, Settings, lock screen, SDDM login)
with PySide6, so the design can be worked on without Quickshell, Hyprland, or
Linux. Quickshell types are replaced by small stubs (tools/preview/stubs) and
every service is replaced by a fake filled with sample data (demo.json).

    pip install PySide6
    python tools/preview/preview.py --fetch-fonts      # once
    python tools/preview/preview.py settings --page appearance

The window reloads whenever a .qml/.js/.json file in the shell changes.
Keys in the window: F5 reload, F6 light/dark, F12 screenshot.
"""

import argparse
import json
import os
import re
import shutil
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SHELL_SRC = REPO / ".config" / "quickshell" / "void"
SDDM_SRC = REPO / "sddm" / "voidline"
CACHE = HERE / ".cache"
MIRROR = CACHE / "shell"
FONTS = HERE / "fonts"
SHOTS = HERE / "shots"
SCENE_NAME = "__preview_scene.qml"
WATCHED_SUFFIXES = {".qml", ".js", ".json", ".conf", ".svg"}

FONT_URLS = {
    "RobotoFlex.ttf": "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/robotoflex/"
    "RobotoFlex%5BGRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght%5D.ttf",
    "MaterialSymbolsRounded.ttf": "https://cdn.jsdelivr.net/gh/google/material-design-icons@master/"
    "variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf",
}

TARGETS = {
    "desktop": "Wallpaper, screen frame, and bar",
    "bar": "Same as desktop (use --style / --position)",
    "action-center": "Bar with the Action Center / Quick Settings open",
    "launcher": "Bar with the App Center open",
    "clock": "Bar with the clock and calendar panel open",
    "music": "Bar with the music panel open",
    "power": "Bar with the power menu open",
    "notification": "Bar with a notification popup",
    "settings": "The Settings app (use --page)",
    "lock": "The lock screen",
    "sddm": "The SDDM login theme",
}

SETTINGS_PAGES = [
    "connections", "devices", "display", "audio", "input", "appearance",
    "desktop", "windows", "lock", "notifications", "security", "accessibility",
    "language", "updates", "system",
]


def qml_path(path):
    """A path that stays valid after the shell prepends "file://" to it.

    On Windows C:\\x becomes /C:/x, so "file://" + path gives file:///C:/x.
    """
    posix = Path(path).resolve().as_posix()
    return posix if posix.startswith("/") else "/" + posix


def qml_url(path):
    return "file://" + qml_path(path)


# ---------------------------------------------------------------- mirror ---

LIST_RE = re.compile(r"(s|History|List|Laps|Streams|Cards|Ports|Sessions|Applications|Devices|Networks"
                     r"|identities|games|timers|monitors|packages|players|messages)$")
BOOL_RE = re.compile(
    r"^(is|has|can)|(Enabled|Active|Available|Visible|Open|Muted|Connected|Ready|Busy|Running|Scanning"
    r"|Changing|Connecting|Allowed|Saved|Loaded|Pending|Required|Supported|Configured|Monitoring|Hidden"
    r"|Starting|Stopping|Generating|Installed|Acknowledged|Refreshing|Selecting|Searching|Applying|Blocked"
    r"|Known|Recommended|Mode)$|^(available|busy|loading|charging|recording|playing|locked|registered|failed"
    r"|active|shuffled|configured|ready|checking|installing|unlocking|authenticating|monitoring|lyrics"
    r"|verboseLogging|tapToClick|naturalScroll)$")
NUM_RE = re.compile(r"(percentage|Percent|Volume|Usage|Count|count|Bytes|GiB|KiB|MiB|Temperature|position"
                    r"|length|progress|watts|Seconds|Minutes|Limit|Tokens|Ms|Size|Rate|Delay|Speed|Gaps"
                    r"|Rounding|Opacity|Strength|Range|Angle|Passes|Ghz|Health|Timeout|Second|Month|Date"
                    r"|Index|State|Revision|Code|Interval)$")
NULL_OBJECTS = {"popupNotification", "activePlayer", "pendingConfirmation", "artworkChoiceGame"}
MAP_OBJECTS = {"weather", "networkDetails", "sink", "source", "states", "flow", "selectedDate",
               "displayMonth", "primaryMonitor"}
WINDOW_ROOT = re.compile(r"^(PanelWindow|FloatingWindow|PopupWindow) \{", re.M)


def fake_service(name, members, overrides):
    """Build a QML singleton that answers every member the shell uses."""
    body = []
    for member, is_call in sorted(members.items()):
        if member in overrides:
            continue
        if is_call:
            if re.search(r"(resultsFor|filteredGames|list)$", member):
                result = "[]"
            elif re.search(r"(Label|Name|Icon|Detail|Time|explanation|formatBytes|iconForCode|format\w*"
                           r"|remaining\w*|stopwatch\w*)", member, re.I):
                result = '""'
            elif member == "streamVolume":
                result = "0.5"
            else:
                result = "null"
            body.append(f"    function {member}() {{ return {result} }}")
        elif member in NULL_OBJECTS:
            body.append(f"    property var {member}: null")
        elif member in MAP_OBJECTS:
            body.append(f"    property var {member}: ({{}})")
        elif BOOL_RE.search(member):
            body.append(f"    property bool {member}: false")
        elif NUM_RE.search(member):
            body.append(f"    property real {member}: 0")
        elif LIST_RE.search(member):
            body.append(f"    property var {member}: []")
        else:
            body.append(f'    property string {member}: ""')
    for member, value in overrides.items():
        if isinstance(value, str) and value.startswith("fn:"):
            body.append(f"    function {member}() {{ return {value[3:]} }}")
        else:
            body.append(f"    property var {member}: {json.dumps(value)}")
    if name == "LockService":
        body.append("    signal authenticationFailed()")
    return "pragma Singleton\nimport QtQuick\nQtObject {\n" + "\n".join(body) + "\n}\n"


def build_mirror():
    """Copy the shell into the cache and swap services/windows for fakes."""
    shutil.rmtree(MIRROR, ignore_errors=True)
    shutil.copytree(SHELL_SRC, MIRROR, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    home = CACHE / "home"
    home.mkdir(parents=True, exist_ok=True)

    stubs = CACHE / "stubs"
    shutil.rmtree(stubs, ignore_errors=True)
    shutil.copytree(HERE / "stubs", stubs)
    singleton = stubs / "Quickshell" / "QuickshellSingleton.qml"
    singleton.write_text(singleton.read_text(encoding="utf-8")
                         .replace("@SHELL_DIR@", qml_path(MIRROR))
                         .replace("@HOME@", qml_path(home)), encoding="utf-8")

    uses = {}
    for path in SHELL_SRC.rglob("*.qml"):
        text = path.read_text(encoding="utf-8", errors="replace")
        for service, member, call in re.findall(r"\b([A-Z][A-Za-z]+Service)\.([a-zA-Z_]+)(\()?", text):
            known = uses.setdefault(service, {})
            known[member] = bool(call) or known.get(member, False)

    demo = (HERE / "demo.json").read_text(encoding="utf-8").replace("@REPO@", qml_path(REPO))
    overrides = json.loads(demo)
    wallpapers = overrides.setdefault("WallpaperService", {})
    if not wallpapers.get("wallpapers"):
        wallpapers["wallpapers"] = [
            {"path": qml_path(path), "title": path.stem}
            for path in sorted((REPO / "assets" / "wallpapers").glob("*"))
            if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}]

    services = MIRROR / "services"
    for path in services.glob("*.qml"):
        path.unlink()
    qmldir = ["module Services"]
    for service in sorted(set(uses) | set(overrides)):
        (services / f"{service}.qml").write_text(
            fake_service(service, uses.get(service, {}), overrides.get(service, {})), encoding="utf-8")
        qmldir.append(f"singleton {service} 1.0 {service}.qml")
    (services / "qmldir").write_text("\n".join(qmldir) + "\n", encoding="utf-8")

    # Layer-shell windows become plain Items that can sit inside one scene.
    for path in MIRROR.rglob("*.qml"):
        text = path.read_text(encoding="utf-8", errors="replace")
        original = text
        if WINDOW_ROOT.search(text):
            text = re.sub(r"^    anchors \{", "    windowAnchors {", text, flags=re.M)
            text = re.sub(r"^\s*WlrLayershell\.[^\n]*\n", "", text, flags=re.M)
            text = re.sub(r"^    HyprlandWindow\.visibleMask: Region \{[\s\S]*?^    \}\n", "", text, flags=re.M)
            text = re.sub(r"^\s*HyprlandFocusGrab[\s\S]*?^    \}\n", "", text, flags=re.M)
        for mode in ("Ignore", "Normal", "Auto"):
            text = text.replace(f"ExclusionMode.{mode}", "0")
        if text != original:
            path.write_text(text, encoding="utf-8")
    return stubs


# ----------------------------------------------------------------- scene ---

def scene_qml(args):
    """The QML file that places the requested piece on a wallpaper."""
    wallpaper = qml_url(args.wallpaper)
    setup = [
        f'Appearance.colorMode = "{"light" if args.light else "dark"}"',
        f"Appearance.uiScale = {args.scale}",
        f'Appearance.wallpaperPath = "{qml_path(args.wallpaper)}"',
    ]
    if args.accent:
        setup += ["Appearance.magicColors = false", f'Appearance.accentColor = "{args.accent}"']
    style = args.style
    if style:
        setup.append(f'Appearance.barStyle = "{style}"')
        setup.append(f'Appearance.pendingBarStyle = "{style}"')
    position = "bottom" if style == "taskbar" else args.position
    if position:
        setup.append(f'Appearance.barPosition = "{position}"')
        setup.append(f'Appearance.pendingBarPosition = "{position}"')
    setup.append(f"Appearance.taskbarAutoHide = {'true' if args.autohide else 'false'}")

    target = args.target
    imports = 'import QtQuick\nimport "core"\nimport "bar"\nimport "panels"\nimport "components"\n'
    screen = '({ name: "DP-1", width: root.width, height: root.height })'

    if target == "settings":
        setup.append(f'ShellState.settingsSection = "{args.page}"')
        body = """
    Rectangle { anchors.fill: parent; color: Theme.panel }
    SettingsPage { anchors.fill: parent; active: true }"""
    elif target == "lock":
        body = """
    LockSurface { anchors.fill: parent }"""
    else:
        opener = {
            "action-center": "ShellState.toggleControlCenter(bar.screen)",
            "launcher": "ShellState.toggleLauncher(bar.screen)",
            "clock": "ShellState.toggleClock(bar.screen)",
            "music": "ShellState.toggleMusic(bar.screen)",
            "power": "ShellState.openPowerMenu(bar.screen)",
        }.get(target)
        if opener:
            setup.append(f"Qt.callLater(() => {opener})")
        body = f"""
    Image {{ anchors.fill: parent; source: "{wallpaper}"; fillMode: Image.PreserveAspectCrop }}
    ScreenFrame {{ anchors.fill: parent }}
    Bar {{ id: bar; screen: {screen}
        x: Appearance.barPosition === "right" ? parent.width - width : 0
        y: Appearance.barPosition === "bottom" ? parent.height - height : 0 }}"""
        if target == "power":
            body += f"""
    PowerDrawer {{ x: parent.width - width; height: parent.height; screen: {screen} }}"""
        if target == "notification":
            body += """
    NotificationPopup { x: parent.width - width - 12; y: Theme.barThickness + 10 }"""

    return f"""{imports}
// Generated by tools/preview/preview.py. Edit the shell, not this file.
Item {{
    id: root
    width: {args.width}; height: {args.height}
    Component.onCompleted: {{
        {chr(10).join("        " + line for line in setup).strip()}
    }}
{body}
}}
"""


# ------------------------------------------------------------------ fonts ---

def fetch_fonts():
    FONTS.mkdir(exist_ok=True)
    for name, url in FONT_URLS.items():
        target = FONTS / name
        if target.exists():
            print(f"  {name} already present")
            continue
        print(f"  downloading {name} …")
        with urllib.request.urlopen(url, timeout=120) as response:
            target.write_bytes(response.read())
    print(f"Fonts are in {FONTS}")


def load_fonts():
    from PySide6.QtGui import QFontDatabase
    families = set()
    for path in sorted(FONTS.glob("*.[ot]tf")) if FONTS.exists() else []:
        font_id = QFontDatabase.addApplicationFont(str(path))
        families.update(QFontDatabase.applicationFontFamilies(font_id))
    installed = set(QFontDatabase.families()) | families
    for needed in ("Material Symbols Rounded", "Roboto Flex"):
        if needed not in installed:
            print(f"warning: font '{needed}' is missing; run with --fetch-fonts", file=sys.stderr)


# ----------------------------------------------------------------- viewer ---

def source_state():
    """Modification times of everything that should trigger a reload."""
    state = {}
    roots = [SHELL_SRC, HERE / "stubs", HERE / "demo.json", SDDM_SRC]
    for root in roots:
        paths = [root] if root.is_file() else root.rglob("*")
        for path in paths:
            if path.suffix in WATCHED_SUFFIXES and path.is_file():
                try:
                    state[str(path)] = path.stat().st_mtime_ns
                except OSError:
                    pass
    return state


def sddm_context(view):
    """Context objects SDDM gives its themes, with sample users and sessions."""
    from PySide6.QtCore import Property, QByteArray, QObject, Qt, QTimer, Signal, Slot
    from PySide6.QtGui import QStandardItem, QStandardItemModel

    class Sddm(QObject):
        loginFailed = Signal()
        loginSucceeded = Signal()
        informationMessage = Signal(str)

        @Property(str, constant=True)
        def hostName(self):
            return "voidbox"

        @Property(bool, constant=True)
        def canSuspend(self):
            return True

        @Property(bool, constant=True)
        def canHibernate(self):
            return False

        @Slot(str, str, int)
        def login(self, user, password, session):
            print(f"sddm.login({user!r}, <password>, {session}) → failing on purpose")
            QTimer.singleShot(400, self.loginFailed.emit)

        @Slot()
        def suspend(self):
            print("sddm.suspend()")

        @Slot()
        def reboot(self):
            print("sddm.reboot()")

        @Slot()
        def powerOff(self):
            print("sddm.powerOff()")

    class Model(QStandardItemModel):
        def __init__(self, rows, roles):
            super().__init__()
            self._roles = {Qt.UserRole + i + 1: QByteArray(role.encode()) for i, role in enumerate(roles)}
            for row in rows:
                item = QStandardItem()
                for i, role in enumerate(roles):
                    item.setData(row.get(role, ""), Qt.UserRole + i + 1)
                self.appendRow(item)

        def roleNames(self):
            return self._roles

        @Property(int, constant=True)
        def lastIndex(self):
            return 0

        @Property(str, constant=True)
        def lastUser(self):
            return "demo"

    class Keyboard(QObject):
        @Property(bool, constant=True)
        def capsLock(self):
            return False

    config = {}
    for line in (SDDM_SRC / "theme.conf").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith(("#", "[")):
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()
    keep = [Sddm(), Keyboard(),
            Model([{"name": "demo", "realName": "Demo User", "icon": ""},
                   {"name": "guest", "realName": "Guest", "icon": ""}], ["name", "realName", "icon"]),
            Model([{"name": "Hyprland"}, {"name": "Hyprland (uwsm)"}], ["name"])]
    context = view.rootContext()
    for key, value in {"sddm": keep[0], "keyboard": keep[1], "userModel": keep[2],
                       "sessionModel": keep[3], "config": config}.items():
        context.setContextProperty(key, value)
    return keep


def main():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(line_buffering=True)
    parser = argparse.ArgumentParser(
        description="Preview Voidline QML without Quickshell.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="targets:\n" + "\n".join(f"  {k:<14} {v}" for k, v in TARGETS.items())
        + "\n\nsettings pages:\n  " + ", ".join(SETTINGS_PAGES))
    parser.add_argument("target", nargs="?", default="desktop", choices=list(TARGETS))
    parser.add_argument("--page", default="connections", choices=SETTINGS_PAGES, help="Settings page")
    parser.add_argument("--style", choices=["frame", "islands", "floating", "minimal", "taskbar"],
                        help="bar style (default: frame)")
    parser.add_argument("--position", choices=["top", "bottom", "left", "right"], help="bar edge")
    parser.add_argument("--autohide", action="store_true", help="let the taskbar auto-hide")
    parser.add_argument("--light", action="store_true", help="light theme")
    parser.add_argument("--accent", help="fixed accent colour such as #2FA38A (disables wallpaper colours)")
    parser.add_argument("--wallpaper", default=str(REPO / "assets" / "wallpapers" / "EmeraldRift.png"))
    parser.add_argument("--size", default="1536x864", help="window size, e.g. 1920x1080")
    parser.add_argument("--scale", type=float, default=1.0, help="Voidline UI scale")
    parser.add_argument("--shot", metavar="PNG", help="save a screenshot and exit")
    parser.add_argument("--delay", type=int, default=1500, help="ms to wait before --shot")
    parser.add_argument("--fetch-fonts", action="store_true", help="download Roboto Flex and Material Symbols")
    parser.add_argument("--no-watch", action="store_true", help="do not reload on file changes")
    parser.add_argument("--verbose", action="store_true",
                        help="print every QML warning (sample data causes some harmless ones)")
    args = parser.parse_args()

    if args.fetch_fonts:
        fetch_fonts()
        if len(sys.argv) == 2:
            return 0
    try:
        args.width, args.height = (int(v) for v in args.size.lower().split("x"))
    except ValueError:
        parser.error("--size must look like 1536x864")
    if args.target == "sddm":
        args.width, args.height = (args.width, args.height) if "--size" in sys.argv else (1280, 800)

    if args.shot:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    os.environ.setdefault("QML_XHR_ALLOW_FILE_READ", "1")
    if not args.verbose:
        os.environ.setdefault("QT_LOGGING_RULES", "qt.qml.propertyCache.append=false")
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

    try:
        from PySide6.QtCore import QTimer, QUrl, Qt
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQuick import QQuickView
    except ImportError:
        print("PySide6 is not installed. Run:  pip install PySide6", file=sys.stderr)
        return 1

    class Log:
        """Prints each distinct QML message once; sample-data noise is hidden."""
        noise = re.compile(r"TypeError: Cannot read property|is not a function|propertyCache"
                           r"|Cannot open: file:///var/tmp|of null$|of undefined$")

        def __init__(self):
            self.seen = set()
            self.hidden = 0

        def show(self, text):
            text = text.replace(qml_url(MIRROR), qml_url(SHELL_SRC))
            if text in self.seen:
                return
            self.seen.add(text)
            if not args.verbose and self.noise.search(text):
                self.hidden += 1
                return
            print("qml:", text, file=sys.stderr)

        def reset(self):
            if self.hidden:
                print(f"({self.hidden} sample-data warnings hidden; --verbose shows them)", file=sys.stderr)
            self.seen.clear()
            self.hidden = 0

    log = Log()

    app = QGuiApplication(sys.argv[:1])
    app.setApplicationName("Voidline preview")
    load_fonts()

    state = {"view": None, "keep": None, "sources": source_state(), "light": args.light}

    class PreviewView(QQuickView):
        def keyPressEvent(self, event):
            key = event.key()
            if key == Qt.Key_F5:
                QTimer.singleShot(0, reload)
            elif key == Qt.Key_F6:
                args.light = not args.light
                QTimer.singleShot(0, reload)
            elif key == Qt.Key_F12:
                SHOTS.mkdir(exist_ok=True)
                out = SHOTS / f"{args.target}-{time.strftime('%Y%m%d-%H%M%S')}.png"
                self.grabWindow().save(str(out))
                print(f"saved {out}")
            else:
                super().keyPressEvent(event)

    def reload():
        old = state["view"]
        geometry = old.geometry() if old else None
        if old:
            old.close()
            old.deleteLater()
        started = time.monotonic()
        if args.target == "sddm":
            stubs = HERE / "stubs"
            source = SDDM_SRC / "Main.qml"
        else:
            stubs = build_mirror()
            source = MIRROR / SCENE_NAME
            source.write_text(scene_qml(args), encoding="utf-8")

        view = PreviewView()
        view.setTitle(f"Voidline preview · {args.target}"
                      + (f" · {args.page}" if args.target == "settings" else ""))
        view.setResizeMode(QQuickView.SizeRootObjectToView)
        view.engine().addImportPath(str(stubs))
        view.engine().setOutputWarningsToStandardError(False)
        view.engine().warnings.connect(lambda warnings: [log.show(w.toString()) for w in warnings])
        state["keep"] = sddm_context(view) if args.target == "sddm" else None
        view.setSource(QUrl.fromLocalFile(str(source)))
        for error in view.errors():
            print("error:", error.toString().replace(qml_url(MIRROR), qml_url(SHELL_SRC)), file=sys.stderr)
        if args.target == "sddm" and view.rootObject() is not None:
            # SDDM reads the wallpaper from a cache in /var/tmp that only the
            # real session writes; show the chosen wallpaper instead.
            view.rootObject().setProperty("cachedWallpaper", qml_url(args.wallpaper))
            view.rootObject().setProperty("cachedAvatar", "")
        if geometry:
            view.setGeometry(geometry)
        else:
            view.resize(args.width, args.height)
        view.show()
        state["view"] = view
        QTimer.singleShot(2500, log.reset)
        print(f"loaded {args.target} in {time.monotonic() - started:.1f}s"
              + ("" if view.status() == QQuickView.Ready else "  (with errors, see above)"))
        return view

    view = reload()
    # Tear the scene down before Python frees the SDDM context objects.
    app.aboutToQuit.connect(lambda: state["view"].setSource(QUrl()))

    if args.shot:
        def shoot():
            state["view"].grabWindow().save(args.shot)
            print(f"saved {args.shot}")
            app.quit()
        QTimer.singleShot(args.delay, shoot)
        return app.exec()

    if not args.no_watch:
        def check():
            current = source_state()
            if current != state["sources"]:
                state["sources"] = current
                print("change detected, reloading …")
                reload()
        watcher = QTimer()
        watcher.timeout.connect(check)
        watcher.start(800)
        print("Watching for changes. F5 reload · F6 light/dark · F12 screenshot · close the window to quit")
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
