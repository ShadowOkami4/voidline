# Files (Nautilus) extension for Voidline. Needs the package nautilus-python.
# Puts one "Voidline" entry into the right-click menu of a file, with what
# the shell can do with it inside. One entry, so the menu stays short; it
# replaces the entries Voidline otherwise adds under "Scripts".
import locale
import subprocess

from gi.repository import GObject, Nautilus

GERMAN = (locale.getlocale()[0] or "").lower().startswith("de")
TEXT = {
    "open": ("Open with…", "Öffnen mit…"),
    "wallpaper": ("Set as wallpaper", "Als Hintergrundbild"),
    "path": ("Copy path", "Pfad kopieren"),
}


def label(key):
    return TEXT[key][1 if GERMAN else 0]


def run(*command, text=None):
    try:
        p = subprocess.Popen(command, stdin=subprocess.PIPE if text is not None else subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if text is not None:
            p.stdin.write(text.encode())
            p.stdin.close()
    except OSError:
        pass


def shell(*args):
    run("qs", "-c", "voidline", "ipc", "call", "shell", *args)


class VoidlineMenu(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, *args):
        # Older versions pass (window, files), newer ones only (files).
        files = args[-1]
        paths = []
        for f in files:
            location = f.get_location()
            if location and location.get_path():
                paths.append(location.get_path())
        if not paths or len(paths) != len(files):
            return []

        entries = []
        if len(files) == 1 and not files[0].is_directory():
            entries.append(("open", lambda *_: shell("openWith", paths[0])))
            if (files[0].get_mime_type() or "").startswith("image/"):
                entries.append(("wallpaper", lambda *_: shell("set", "wallpaper", paths[0])))
        entries.append(("path", lambda *_: run("wl-copy", text="\n".join(paths))))

        top = Nautilus.MenuItem(name="Voidline::Menu", label="Voidline")
        menu = Nautilus.Menu()
        top.set_submenu(menu)
        for key, action in entries:
            item = Nautilus.MenuItem(name="Voidline::" + key, label=label(key))
            item.connect("activate", action)
            menu.append_item(item)
        return [top]
