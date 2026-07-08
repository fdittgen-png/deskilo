#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Generates the DesKilo launcher icon (#103): flat red field with a white
# top-down desk + seat glyph — the app's floor-plan motif. Pure stdlib
# (no Pillow): analytic signed-distance coverage, zlib-compressed PNG.
import struct, zlib, math

SIZE = 1024
RED = (211, 47, 47)        # #D32F2F — DesKilo red
WHITE = (255, 255, 255)

def rounded_rect_alpha(px, py, x0, y0, x1, y1, r):
    """Anti-aliased coverage of a rounded rect at pixel center."""
    cx = min(max(px, x0 + r), x1 - r)
    cy = min(max(py, y0 + r), y1 - r)
    d = math.hypot(px - cx, py - cy) - r
    return max(0.0, min(1.0, 0.5 - d))

def glyph_alpha(px, py, scale=1.0, ox=0.0, oy=0.0):
    """White glyph: wide desk on top, square seat below."""
    def t(v):  # transform into glyph space
        return v
    px = (px - 512 - ox) / scale + 512
    py = (py - 512 - oy) / scale + 512
    a = rounded_rect_alpha(px, py, 252, 350, 772, 530, 46)   # desk
    b = rounded_rect_alpha(px, py, 412, 588, 612, 788, 54)   # seat/chair
    return max(a, b)

def write_png(path, get_rgba):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # filter none
        for x in range(SIZE):
            raw += bytes(get_rgba(x + 0.5, y + 0.5))
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)
    print('wrote', path)

def full(x, y):
    a = glyph_alpha(x, y)
    r = int(RED[0] + (WHITE[0] - RED[0]) * a)
    g = int(RED[1] + (WHITE[1] - RED[1]) * a)
    b = int(RED[2] + (WHITE[2] - RED[2]) * a)
    return (r, g, b, 255)

def foreground(x, y):
    # Adaptive foreground: glyph shrunk into the safe zone, transparent bg.
    a = glyph_alpha(x, y, scale=0.62)
    return (255, 255, 255, int(255 * a))

write_png('assets/icon/icon_full.png', full)
write_png('assets/icon/icon_foreground.png', foreground)
