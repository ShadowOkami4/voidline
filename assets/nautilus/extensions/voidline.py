# Files (Nautilus) extension for Voidline. Needs the package nautilus-python.
# Adds "Open with Voidline…" to the right-click menu of a file; it shows the
# shell's own "Open with" dialog. Nautilus's built-in entry stays as it is.
import locale
import subprocess

from gi.repository import GObject, Nautilus

GERMAN = (locale.getlocale()[0] or "").lower().startswith("de")
LABEL = "Mit Voidline öffnen…" if GERMAN else "Open with Voidline…"


class VoidlineOpenWith(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, *args):
        # Older versions pass (window, files), newer ones only (files).
        files = args[-1]
        if len(files) != 1 or files[0].is_directory():
            return []
        location = files[0].get_location()
        path = location.get_path() if location else None
        if not path:
            return []
        item = Nautilus.MenuItem(name="Voidline::OpenWith", label=LABEL)
        item.connect("activate", self.open, path)
        return [item]

    def open(self, item, path):
        subprocess.Popen(["qs", "-c", "voidline", "ipc", "call", "shell", "openWith", path],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
