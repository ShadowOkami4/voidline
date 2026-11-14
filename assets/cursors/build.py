#!/usr/bin/env python3
"""Builds the Voidline mouse pointer theme.

Draws every pointer as vector shapes (dark body, white outline, rounded like
the rest of the shell) and writes them straight into the Xcursor format, so no
other tool is needed.  Needs python-cairo.

    python3 build.py [output-dir]        default: ./Voidline

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
