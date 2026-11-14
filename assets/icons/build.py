#!/usr/bin/env python3
"""Builds the Voidline icon theme.

Voidline draws the icons you see most in a file manager itself: folders, the
special folders (Downloads, Music, ...), drives, the bin and the common file
types. Everything else (app icons and the long tail) comes from the themes it
inherits: Papirus-Dark, then Adwaita.

The icons are written as SVG text, so this needs nothing but Python:

    python3 build.py [output-dir]        default: ./Voidline

The result shares its folder with the Voidline mouse pointers, so "Voidline"
is one theme for both.
"""
import os
import sys

# Voidline palette: purple body, lilac front, pale ink for the symbols.
BACK = "#6A4FD8"
FRONT = "#9A80FF"
FRONT_TOP = "#B29DFF"
INK = "#F4EFFF"
SHEET = "#ECE6FA"
SHEET_FOLD = "#CFC4EC"
SHEET_INK = "#5B43C9"
DARK = "#1C1826"
CYAN = "#4FD1DC"
PINK = "#F08CC0"
AMBER = "#E0B45A"
RED = "#E5606B"


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n'
            '<defs><linearGradient id="f" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{FRONT_TOP}"/><stop offset="1" stop-color="{FRONT}"/></linearGradient></defs>\n'
            + body + '\n</svg>\n')


# ---- symbols, drawn around (0,0) in a box of about 20 x 20 ----------------------
def symbol(name, colour=INK):
    s = f'fill="{colour}"'
    line = f'fill="none" stroke="{colour}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"'
    return {
        "download": f'<path {line} d="M0 -8 V5 M-6 0 L0 6 L6 0 M-8 10 H8"/>',
        "documents": f'<path {line} d="M-8 -7 H8 M-8 0 H8 M-8 7 H3"/>',
        "music": f'<path {s} d="M-3 -9 L8 -11 V4 a4 4 0 1 1 -2.6 -3.7 V-6 L-0.4 -5 V7 a4 4 0 1 1 -2.6 -3.7 Z"/>',
        "pictures": f'<circle {s} cx="5" cy="-5" r="3"/><path {s} d="M-10 9 L-3 -2 L2 5 L5 1 L10 9 Z"/>',
        "videos": f'<path {s} d="M-5 -8 L9 0 L-5 8 Z" stroke="{colour}" stroke-width="2.4" stroke-linejoin="round"/>',
        "desktop": f'<rect {line} x="-10" y="-8" width="20" height="13" rx="2.5"/><path {line} d="M-5 10 H5 M0 5 V10"/>',
        "home": f'<path {s} d="M0 -10 L11 0 H8 V9 H2.5 V2.5 H-2.5 V9 H-8 V0 H-11 Z" stroke="{colour}" stroke-width="1.6" stroke-linejoin="round"/>',
        "templates": f'<rect {line} x="-9" y="-9" width="13" height="13" rx="2.5"/><path {line} d="M-3 9 H9 V-3"/>',
        "public": f'<circle {s} cx="-6" cy="0" r="3.4"/><circle {s} cx="6" cy="-7" r="3.4"/><circle {s} cx="6" cy="7" r="3.4"/><path {line} d="M-6 0 L6 -7 M-6 0 L6 7"/>',
        "network": f'<circle {line} cx="0" cy="0" r="9.5"/><path {line} d="M-9.5 0 H9.5 M0 -9.5 C-5 -4 -5 4 0 9.5 M0 -9.5 C5 -4 5 4 0 9.5"/>',
        "recent": f'<circle {line} cx="0" cy="0" r="9.5"/><path {line} d="M0 -5 V0 L4 3"/>',
        "star": f'<path {s} d="M0 -10 L3 -3.2 L10.2 -2.6 L4.7 2.2 L6.4 9.4 L0 5.6 L-6.4 9.4 L-4.7 2.2 L-10.2 -2.6 L-3 -3.2 Z"/>',
        "code": f'<path {line} d="M-4 -7 L-10 0 L-4 7 M4 -7 L10 0 L4 7"/>',
        "games": f'<path {line} d="M-9 -4 H9 a3 3 0 0 1 3 3 L11 6 a3 3 0 0 1 -5 1 L4 5 H-4 L-6 7 a3 3 0 0 1 -5 -1 L-12 -1 a3 3 0 0 1 3 -3 Z M-6 -1 V3 M-8 1 H-4"/><circle {s} cx="6" cy="1" r="1.5"/>',
        "": "",
    }[name]


def at(x, y, inner, scale=1.0):
    return f'<g transform="translate({x} {y}) scale({scale})">{inner}</g>'


# ---- the big shapes --------------------------------------------------------------
def folder(what="", colour_back=BACK, front="url(#f)"):
    return svg(
        f'<path fill="{colour_back}" d="M6 18 a7 7 0 0 1 7 -7 h11.5 a6 6 0 0 1 4.6 2.2 l2.6 3.1 a4 4 0 0 0 3 1.4 H51 a7 7 0 0 1 7 7 V46 a7 7 0 0 1 -7 7 H13 a7 7 0 0 1 -7 -7 Z"/>\n'
        f'<rect fill="{front}" x="6" y="24" width="52" height="30" rx="8"/>\n'
        + at(32, 39, symbol(what), 0.92))


def sheet(what, badge):
    """A file: a pale sheet with a folded corner and a coloured cookie badge."""
    return svg(
        f'<path fill="{SHEET}" stroke="{SHEET_FOLD}" stroke-width="1.4" d="M14 13 a7 7 0 0 1 7 -7 h17 l12 12 V51 a7 7 0 0 1 -7 7 H21 a7 7 0 0 1 -7 -7 Z"/>\n'
        f'<path fill="{SHEET_FOLD}" d="M38 6 l12 12 H43 a5 5 0 0 1 -5 -5 Z"/>\n'
        f'<circle fill="{badge}" cx="32" cy="38" r="13"/>\n'
        + at(32, 38, symbol(what), 0.78))


def bin_(full):
    lid = f'<rect fill="{BACK}" x="14" y="13" width="36" height="7" rx="3.5"/><rect fill="{BACK}" x="26" y="8" width="12" height="7" rx="3"/>'
    body = f'<path fill="url(#f)" d="M17 23 H47 L44.6 51 a6 6 0 0 1 -6 5.5 H25.4 a6 6 0 0 1 -6 -5.5 Z"/>'
    ribs = f'<path fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round" d="M26.5 31 L27.5 48 M32 31 V48 M37.5 31 L36.5 48"/>'
    paper = f'<path fill="{SHEET}" d="M22 23 L26 12 L33 16 L38 9 L43 23 Z"/>' if full else ""
    return svg((paper if full else "") + lid + body + ribs) if not full else svg(paper + body + ribs)


def drive(removable):
    if removable:
        return svg(f'<rect fill="{BACK}" x="24" y="6" width="16" height="14" rx="3"/>'
                   f'<rect fill="{INK}" x="27.5" y="10" width="3.4" height="4" rx="1"/><rect fill="{INK}" x="33" y="10" width="3.4" height="4" rx="1"/>'
                   f'<rect fill="url(#f)" x="17" y="18" width="30" height="40" rx="9"/>'
                   f'<circle fill="{INK}" cx="32" cy="45" r="3"/>')
    return svg(f'<rect fill="{BACK}" x="8" y="12" width="48" height="40" rx="10"/>'
               f'<rect fill="url(#f)" x="8" y="34" width="48" height="18" rx="9"/>'
               f'<circle fill="{CYAN}" cx="19" cy="43" r="3"/><rect fill="{INK}" x="30" y="41.5" width="18" height="3" rx="1.5"/>')


def computer():
    return svg(f'<rect fill="{BACK}" x="6" y="10" width="52" height="34" rx="8"/>'
               f'<rect fill="url(#f)" x="10" y="14" width="44" height="26" rx="5"/>'
               f'<rect fill="{BACK}" x="27" y="44" width="10" height="7"/><rect fill="{BACK}" x="19" y="50" width="26" height="6" rx="3"/>')


def settings():
    """The Voidline Settings app: a cookie shape with a dark void in the middle."""
    import math
    points = []
    for i in range(72):
        a = 2 * math.pi * i / 72
        r = 25 + 2.6 * math.cos(9 * a)
        points.append(f"{32 + r * math.cos(a):.2f} {32 + r * math.sin(a):.2f}")
    return svg(f'<path fill="url(#f)" d="M{" L".join(points)} Z"/>'
               f'<circle fill="{DARK}" cx="32" cy="32" r="10.5"/><circle fill="none" stroke="{CYAN}" stroke-width="1.6" cx="32" cy="32" r="10.5"/>')


# file name -> (picture, other names for the same icon)
PLACES = {
    "folder": (folder(), ["inode-directory", "folder-open", "folder-drag-accept", "folder-visiting", "gnome-fs-directory"]),
    "user-home": (folder("home"), ["folder-home", "go-home-folder", "gnome-fs-home"]),
    "user-desktop": (folder("desktop"), ["folder-desktop", "gnome-fs-desktop"]),
    "folder-documents": (folder("documents"), ["folder-document", "folder-text"]),
    "folder-download": (folder("download"), ["folder-downloads"]),
    "folder-music": (folder("music"), ["folder-sound", "folder-audio"]),
    "folder-pictures": (folder("pictures"), ["folder-image", "folder-images", "folder-photos"]),
    "folder-videos": (folder("videos"), ["folder-video", "folder-movies"]),
    "folder-templates": (folder("templates"), []),
    "folder-publicshare": (folder("public"), ["folder-public"]),
    "folder-remote": (folder("network"), ["network-workgroup", "folder-network", "network-server"]),
    "folder-recent": (folder("recent"), ["document-open-recent-folder"]),
    "folder-favorites": (folder("star"), ["user-bookmarks", "folder-bookmark", "starred"]),
    "folder-development": (folder("code"), ["folder-code", "folder-git", "folder-projects"]),
    "folder-games": (folder("games"), []),
    "user-trash": (bin_(False), ["trashcan_empty", "gnome-fs-trash-empty"]),
    "user-trash-full": (bin_(True), ["trashcan_full", "gnome-fs-trash-full"]),
}
DEVICES = {
    "drive-harddisk": (drive(False), ["drive-harddisk-system", "drive-harddisk-solidstate", "gnome-dev-harddisk"]),
    "drive-removable-media": (drive(True), ["drive-removable-media-usb", "media-removable", "media-flash", "drive-harddisk-usb", "media-flash-sd-mmc"]),
    "computer": (computer(), ["computer-laptop", "video-display"]),
}
MIMES = {
    "text-x-generic": (sheet("documents", SHEET_INK), ["text-plain", "text-x-plain", "application-text", "x-office-document", "text-markdown"]),
    "image-x-generic": (sheet("pictures", CYAN), ["image-png", "image-jpeg", "image-gif", "image-webp", "image-svg+xml", "image-bmp"]),
    "audio-x-generic": (sheet("music", PINK), ["audio-mpeg", "audio-flac", "audio-x-wav", "audio-ogg", "audio-mp4"]),
    "video-x-generic": (sheet("videos", RED), ["video-mp4", "video-x-matroska", "video-webm", "video-quicktime"]),
    "text-x-script": (sheet("code", AMBER), ["application-x-shellscript", "text-x-python", "text-x-csrc", "text-html", "application-json", "text-x-source", "application-x-executable"]),
    "package-x-generic": (sheet("download", BACK), ["application-zip", "application-x-tar", "application-x-compressed-tar", "application-x-7z-compressed", "application-gzip", "application-x-archive"]),
    "application-pdf": (sheet("documents", RED), ["application-x-pdf", "gnome-mime-application-pdf"]),
}
APPS = {
    "voidline-settings": (settings(), ["voidline"]),
}
GROUPS = (("places", "Places", PLACES), ("devices", "Devices", DEVICES), ("mimetypes", "MimeTypes", MIMES), ("apps", "Applications", APPS))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "Voidline")
    aliases = []
    for folder_name, _, icons in GROUPS:
        target = os.path.join(out, "scalable", folder_name)
        os.makedirs(target, exist_ok=True)
        for name, (picture, others) in icons.items():
            with open(os.path.join(target, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
                f.write(picture)
            if others:
                aliases.append(f"scalable/{folder_name} {name}.svg " + " ".join(o + ".svg" for o in others))

    directories = ",".join(f"scalable/{g[0]}" for g in GROUPS)
    index = ("[Icon Theme]\nName=Voidline\nComment=Icons and mouse pointers of the Voidline shell\n"
             "Inherits=Papirus-Dark,Papirus,Adwaita,hicolor\n"
             f"Directories={directories}\n\n")
    for folder_name, context, _ in GROUPS:
        index += f"[scalable/{folder_name}]\nSize=64\nMinSize=16\nMaxSize=512\nContext={context}\nType=Scalable\n\n"
    with open(os.path.join(out, "index.theme"), "w", encoding="utf-8", newline="\n") as f:
        f.write(index)
    # Same idea as the pointer aliases: "<folder> <real file> <alias> ..." become links at install.
    with open(os.path.join(out, "aliases.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(aliases) + "\n")
    print("built", sum(len(g[2]) for g in GROUPS), "icons in", out)


if __name__ == "__main__":
    main()
