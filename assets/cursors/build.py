#!/usr/bin/env python3
"""Builds the Voidline mouse pointer theme.

Draws every pointer as vector shapes (dark body, white outline, rounded like
the rest of the shell) and writes them straight into the Xcursor format, so no
other tool is needed.  Needs python-cairo.

    python3 build.py [output-dir]        default: ./Voidline
    python3 build.py --windows [dir]     default: ./Voidline-Windows

The first form writes the Linux theme (Xcursor files), the second the same
pointers for Windows (.cur and .ani files plus an install.inf).

Only the real pointers are written.  The many other names apps ask for
(left_ptr, hand2, xterm, ...) are listed in aliases.txt and become links when
the theme is installed.
"""
import math
import os
import struct
import sys

import cairo

BODY = (0x14 / 255, 0x11 / 255, 0x1C / 255)
EDGE = (1, 1, 1)
ACCENT = (0xB7 / 255, 0x9C / 255, 0xFF / 255)
OUT = 0.045          # outline thickness, as a share of the pointer size
ROUND = 0.035        # how round the corners are
SIZES = [24, 32, 48, 64, 96]
SPIN_SIZES = [24, 32, 48, 64]
FRAMES = 12


# ---- shapes: each returns a list of (kind, draw-function, line-width) ----------
def poly(points):
    def draw(c):
        c.move_to(*points[0])
        for p in points[1:]:
            c.line_to(*p)
        c.close_path()
    return ("fill", draw, 0)


def rrect(x, y, w, h, r=None):
    r = min(w, h) / 2 if r is None else r
    def draw(c):
        c.new_sub_path()
        c.arc(x + w - r, y + r, r, -math.pi / 2, 0)
        c.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
        c.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
        c.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
        c.close_path()
    return ("fill", draw, 0)


def line(x0, y0, x1, y1, width):
    def draw(c):
        c.move_to(x0, y0)
        c.line_to(x1, y1)
    return ("stroke", draw, width)


def ring(cx, cy, r, width, start=0.0, end=2 * math.pi):
    def draw(c):
        c.new_sub_path()
        c.arc(cx, cy, r, start, end)
    return ("stroke", draw, width)


def turned(shapes, angle):
    """The same shapes rotated around the middle."""
    out = []
    for kind, draw, width in shapes:
        def wrapped(c, draw=draw):
            c.translate(0.5, 0.5)
            c.rotate(angle)
            c.translate(-0.5, -0.5)
            draw(c)
        out.append((kind, wrapped, width))
    return out


ARROW = [poly([(0.17, 0.11), (0.17, 0.76), (0.35, 0.61), (0.63, 0.61)])]
HAND = [
    rrect(0.37, 0.09, 0.16, 0.52),               # index finger
    rrect(0.53, 0.33, 0.13, 0.30),
    rrect(0.66, 0.37, 0.13, 0.30),
    rrect(0.19, 0.47, 0.15, 0.30),               # thumb
    rrect(0.27, 0.45, 0.52, 0.44, 0.14),         # palm
]
FIST = [
    rrect(0.25, 0.30, 0.14, 0.26), rrect(0.39, 0.27, 0.14, 0.26),
    rrect(0.53, 0.29, 0.14, 0.26), rrect(0.66, 0.33, 0.13, 0.26),
    rrect(0.17, 0.44, 0.15, 0.24),
    rrect(0.25, 0.40, 0.54, 0.46, 0.14),
]
IBEAM = [rrect(0.465, 0.14, 0.07, 0.72), rrect(0.36, 0.11, 0.28, 0.07), rrect(0.36, 0.82, 0.28, 0.07)]
CROSS = [rrect(0.465, 0.10, 0.07, 0.80), rrect(0.10, 0.465, 0.80, 0.07)]
DOUBLE = [
    rrect(0.22, 0.455, 0.56, 0.09),
    poly([(0.09, 0.50), (0.27, 0.33), (0.27, 0.67)]),
    poly([(0.91, 0.50), (0.73, 0.33), (0.73, 0.67)]),
]
NO = [ring(0.5, 0.5, 0.31, 0.10), line(0.29, 0.29, 0.71, 0.71, 0.10)]


def spinner(cx, cy, r, width, frame):
    turn = 2 * math.pi * frame / FRAMES
    return [ring(cx, cy, r, width)], [(ring(cx, cy, r, width * 0.62, turn, turn + 1.9), ACCENT)]


def render(size, shapes, extra=()):
    """One picture: outline first for every shape, then the bodies, so shapes
    that touch melt into one."""
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    c = cairo.Context(surface)
    c.scale(size, size)
    c.set_line_join(cairo.LINE_JOIN_ROUND)
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    for colour, grow in ((EDGE, OUT + ROUND), (BODY, ROUND)):
        c.set_source_rgb(*colour)
        for kind, draw, width in shapes:
            c.save()
            draw(c)
            c.restore()
            if kind == "fill":
                if colour is BODY:
                    c.fill_preserve()
                c.set_line_width(2 * grow)
            else:
                c.set_line_width(width + (2 * OUT if colour is EDGE else 0))
            c.stroke()
    for (kind, draw, width), colour in extra:
        c.set_source_rgb(*colour)
        c.save()
        draw(c)
        c.restore()
        c.set_line_width(width)
        c.stroke()
    surface.flush()
    return surface


def xcursor(path, pictures):
    """pictures: [(nominal size, surface, hot x, hot y, delay ms)]"""
    toc, chunks = b"", b""
    position = 16 + 12 * len(pictures)
    for size, surface, hx, hy, delay in pictures:
        w, h = surface.get_width(), surface.get_height()
        data = bytes(surface.get_data())            # premultiplied BGRA, what Xcursor wants
        if surface.get_stride() != w * 4:
            data = b"".join(data[r * surface.get_stride():r * surface.get_stride() + w * 4] for r in range(h))
        chunk = struct.pack("<9I", 36, 0xFFFD0002, size, 1, w, h, hx, hy, delay) + data
        toc += struct.pack("<3I", 0xFFFD0002, size, position)
        chunks += chunk
        position += len(chunk)
    with open(path, "wb") as f:
        f.write(b"Xcur" + struct.pack("<3I", 16, 0x10000, len(pictures)) + toc + chunks)


# ---- Windows: .cur (still) and .ani (animated) ---------------------------------
WIN_SIZES = [32, 48, 64, 96]


def dib(surface):
    """A picture as Windows wants it inside a cursor: a 32-bit bitmap stored
    bottom-up, colours not multiplied by alpha, followed by an empty mask."""
    w, h, stride = surface.get_width(), surface.get_height(), surface.get_stride()
    src = bytes(surface.get_data())
    rows = []
    for y in range(h - 1, -1, -1):
        row = bytearray(src[y * stride:y * stride + w * 4])
        for x in range(0, w * 4, 4):
            a = row[x + 3]
            if 0 < a < 255:
                row[x] = min(255, row[x] * 255 // a)
                row[x + 1] = min(255, row[x + 1] * 255 // a)
                row[x + 2] = min(255, row[x + 2] * 255 // a)
        rows.append(bytes(row))
    mask = bytes(((w + 31) // 32) * 4) * h
    header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, w * h * 4 + len(mask), 0, 0, 0, 0)
    return header + b"".join(rows) + mask


def cur(pictures):
    """pictures: [(surface, hot x, hot y)] -> the bytes of a .cur file."""
    images = [dib(surface) for surface, _, _ in pictures]
    offset = 6 + 16 * len(pictures)
    entries = b""
    for (surface, hx, hy), image in zip(pictures, images):
        w, h = surface.get_width(), surface.get_height()
        entries += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, hx, hy, len(image), offset)
        offset += len(image)
    return struct.pack("<HHH", 0, 2, len(pictures)) + entries + b"".join(images)


def ani(frames, jiffies):
    """frames: a list of .cur files as bytes; jiffies: 1/60 s per frame."""
    def chunk(tag, data):
        return tag + struct.pack("<I", len(data)) + data + (b"\0" if len(data) % 2 else b"")
    anih = struct.pack("<9I", 36, len(frames), len(frames), 0, 0, 0, 0, jiffies, 1)
    icons = b"fram" + b"".join(chunk(b"icon", f) for f in frames)
    body = b"ACON" + chunk(b"anih", anih) + chunk(b"LIST", icons)
    return b"RIFF" + struct.pack("<I", len(body)) + body


# Windows pointer slots, in the order a scheme lists them -> our pointer.
WIN_SCHEME = [
    ("Arrow", "default"), ("Help", "default"), ("AppStarting", "progress"), ("Wait", "wait"),
    ("Crosshair", "crosshair"), ("IBeam", "text"), ("NWPen", "default"), ("No", "not-allowed"),
    ("SizeNS", "ns-resize"), ("SizeWE", "ew-resize"), ("SizeNWSE", "nwse-resize"), ("SizeNESW", "nesw-resize"),
    ("SizeAll", "move"), ("UpArrow", "default"), ("Hand", "pointer"), ("Pin", "pointer"), ("Person", "pointer"),
]
SPINS = (("wait", [], (0.5, 0.5, 0.30, 0.13), (0.5, 0.5)),
         ("progress", "arrow", (0.74, 0.74, 0.16, 0.09), (0.12, 0.07)))


def build_windows(out):
    os.makedirs(out, exist_ok=True)
    files = {}
    for name, (shapes, hot) in STILL.items():
        files[name] = name + ".cur"
        with open(os.path.join(out, files[name]), "wb") as f:
            f.write(cur([(render(s, shapes), round(hot[0] * s), round(hot[1] * s)) for s in WIN_SIZES]))
    for name, base, where, hot in SPINS:
        base = ARROW if base == "arrow" else []
        frames = []
        for frame in range(FRAMES):
            track, arc = spinner(*where, frame)
            frames.append(cur([(render(s, base + track, arc), round(hot[0] * s), round(hot[1] * s)) for s in (32, 48, 64)]))
        files[name] = name + ".ani"
        with open(os.path.join(out, files[name]), "wb") as f:
            f.write(ani(frames, 4))

    used = sorted(set(files[ours] for _, ours in WIN_SCHEME))
    scheme = ",".join("%10%\\%CUR_DIR%\\" + files[ours] for _, ours in WIN_SCHEME)
    slots = "\n".join('HKCU,"Control Panel\\Cursors",%s,0x00020000,"%%10%%\\%%CUR_DIR%%\\%s"' % (slot, files[ours]) for slot, ours in WIN_SCHEME)
    inf = (
        "; Voidline mouse pointers for Windows.\r\n"
        "; Right-click this file and choose Install, then pick \"Voidline\" under\r\n"
        "; Settings > Bluetooth & devices > Mouse > Additional mouse settings > Pointers.\r\n"
        "[Version]\r\nsignature=\"$CHICAGO$\"\r\n\r\n"
        "[DefaultInstall]\r\nCopyFiles = Scheme.Cur\r\nAddReg = Scheme.Reg\r\n\r\n"
        "[DestinationDirs]\r\nScheme.Cur = 10,\"%CUR_DIR%\"\r\n\r\n"
        "[Scheme.Reg]\r\n"
        'HKCU,"Control Panel\\Cursors\\Schemes","%SCHEME_NAME%",,"' + scheme + '"\r\n'
        'HKCU,"Control Panel\\Cursors",,0x00020000,"%SCHEME_NAME%"\r\n'
        + slots.replace("\n", "\r\n") + "\r\n\r\n"
        "[Scheme.Cur]\r\n" + "\r\n".join(used) + "\r\n\r\n"
        "[Strings]\r\nCUR_DIR = \"Cursors\\Voidline\"\r\nSCHEME_NAME = \"Voidline\"\r\n"
    )
    with open(os.path.join(out, "install.inf"), "w", newline="") as f:
        f.write(inf)
    print("built", len(files), "Windows pointers in", out)


# name: (shapes, hot spot as a share of the size)
STILL = {
    "default": (ARROW, (0.12, 0.07)),
    "pointer": (HAND, (0.45, 0.07)),
    "grabbing": (FIST, (0.50, 0.40)),
    "text": (IBEAM, (0.50, 0.50)),
    "crosshair": (CROSS, (0.50, 0.50)),
    "ew-resize": (DOUBLE, (0.50, 0.50)),
    "ns-resize": (turned(DOUBLE, math.pi / 2), (0.50, 0.50)),
    "nwse-resize": (turned(DOUBLE, math.pi / 4), (0.50, 0.50)),
    "nesw-resize": (turned(DOUBLE, -math.pi / 4), (0.50, 0.50)),
    "move": (DOUBLE + turned(DOUBLE, math.pi / 2), (0.50, 0.50)),
    "not-allowed": (NO, (0.50, 0.50)),
}


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--windows":
        here = os.path.dirname(os.path.abspath(__file__))
        build_windows(sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "Voidline-Windows"))
        return
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "Voidline")
    cursors = os.path.join(out, "cursors")
    os.makedirs(cursors, exist_ok=True)

    for name, (shapes, hot) in STILL.items():
        xcursor(os.path.join(cursors, name),
                [(s, render(s, shapes), round(hot[0] * s), round(hot[1] * s), 0) for s in SIZES])

    # Busy: a ring with a travelling accent arc; "progress" keeps the arrow.
    for name, base, where, hot in (("wait", [], (0.5, 0.5, 0.30, 0.13), (0.5, 0.5)),
                                   ("progress", ARROW, (0.74, 0.74, 0.16, 0.09), (0.12, 0.07))):
        pictures = []
        for s in SPIN_SIZES:
            for frame in range(FRAMES):
                track, arc = spinner(*where, frame)
                pictures.append((s, render(s, base + track, arc), round(hot[0] * s), round(hot[1] * s), 60))
        xcursor(os.path.join(cursors, name), pictures)

    for file in ("index.theme", "cursor.theme"):
        with open(os.path.join(out, file), "w") as f:
            f.write("[Icon Theme]\nName=Voidline\nComment=Mouse pointer of the Voidline shell\nInherits=Adwaita\n")

    # Contact sheet for a quick look: every pointer at 96 px on dark and light.
    names = list(STILL) + ["wait", "progress"]
    cell = 120
    sheet = cairo.ImageSurface(cairo.FORMAT_ARGB32, cell * len(names), cell * 2)
    c = cairo.Context(sheet)
    for row, background in enumerate(((0.07, 0.06, 0.10), (0.93, 0.92, 0.96))):
        c.set_source_rgb(*background)
        c.rectangle(0, row * cell, cell * len(names), cell)
        c.fill()
        for i, name in enumerate(names):
            if name in STILL:
                picture = render(96, STILL[name][0])
            else:
                where = (0.5, 0.5, 0.30, 0.13) if name == "wait" else (0.74, 0.74, 0.16, 0.09)
                track, arc = spinner(*where, 2)
                picture = render(96, ([] if name == "wait" else ARROW) + track, arc)
            c.set_source_surface(picture, i * cell + 12, row * cell + 12)
            c.paint()
    sheet.write_to_png(os.path.join(out, "preview.png"))
    print("built", len(names), "pointers in", out)


if __name__ == "__main__":
    main()
