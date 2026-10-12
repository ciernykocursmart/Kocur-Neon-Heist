"""Tiny pixel-art drawing helpers used by gen_art.py.

Everything in Kocur Dungeon's art is drawn by these scripts, so the game
ships no third-party graphics. Run `python3 tools/gen_art.py` from the
kocur-dungeon folder to regenerate assets/sprites/*.png.
"""
import math
import random
from PIL import Image


def hexc(s, a=255):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3])


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if c[3] == 255 or c[3] == 0:
                self.px[x, y] = c
            else:
                base = self.px[x, y]
                if base[3] == 0:
                    self.px[x, y] = c
                else:
                    a = c[3] / 255.0
                    self.px[x, y] = (int(base[0] * (1 - a) + c[0] * a), int(base[1] * (1 - a) + c[1] * a),
                                     int(base[2] * (1 - a) + c[2] * a), max(base[3], c[3]))

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.set(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
            for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx = (xx + 0.5 - cx) / max(rx, 0.01)
                dy = (yy + 0.5 - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.0:
                    self.set(xx, yy, c)

    def circle(self, cx, cy, r, c):
        self.ellipse(cx, cy, r, r, c)

    def line(self, x0, y0, x1, y1, c, w=1):
        dist = max(abs(x1 - x0), abs(y1 - y0), 1)
        steps = int(dist * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            if w <= 1:
                self.set(math.floor(x), math.floor(y), c)
            else:
                self.rect(math.floor(x - (w - 1) / 2), math.floor(y - (w - 1) / 2), w, w, c)

    def poly(self, pts, c):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for yy in range(int(min(ys)), int(max(ys)) + 1):
            for xx in range(int(min(xs)), int(max(xs)) + 1):
                if point_in_poly(xx + 0.5, yy + 0.5, pts):
                    self.set(xx, yy, c)

    def curve(self, pts, c, w=1):
        for i in range(len(pts) - 1):
            self.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], c, w)

    def outline(self, c, diag=False):
        src = [[self.px[x, y][3] > 0 for y in range(self.h)] for x in range(self.w)]
        for x in range(self.w):
            for y in range(self.h):
                if src[x][y]:
                    continue
                n = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                if diag:
                    n += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
                for dx, dy in n:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[xx][yy]:
                        self.px[x, y] = c
                        break

    def recolor(self, frm, to):
        for x in range(self.w):
            for y in range(self.h):
                if self.px[x, y] == frm:
                    self.px[x, y] = to

    def paste(self, other, ox, oy, flip=False):
        for x in range(other.w):
            for y in range(other.h):
                c = other.px[x, y]
                if c[3] > 0:
                    tx = ox + (other.w - 1 - x if flip else x)
                    self.set(tx, oy + y, c)

    def tint_alpha(self, f):
        for x in range(self.w):
            for y in range(self.h):
                c = self.px[x, y]
                if c[3] > 0:
                    self.px[x, y] = (c[0], c[1], c[2], int(c[3] * f))


def point_in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


def sheet(frames, fw, fh):
    """Pack Canvas frames horizontally into one image."""
    img = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f.img, (i * fw, 0))
    return img


def grid_sheet(rows, fw, fh):
    """rows: list of lists of Canvas. Packs into a grid (one row per animation)."""
    cols = max(len(r) for r in rows)
    img = Image.new('RGBA', (fw * cols, fh * len(rows)), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for i, f in enumerate(frames):
            img.paste(f.img, (i * fw, r * fh))
    return img


def noise_rng(seed):
    return random.Random(seed)
