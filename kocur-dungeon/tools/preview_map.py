"""Renders level maps from scripts/data/maps/*.gd to PNG previews (dev aid).
Usage: python3 tools/preview_map.py <region_file.gd> <CONST_NAME> <out.png>"""
import re
import sys
from PIL import Image, ImageDraw

COL = {'#': (90, 95, 90), 'I': (140, 200, 240), '%': (120, 90, 90), '=': (160, 120, 70), '~': (170, 150, 120),
       '^': (230, 230, 240), 'v': (230, 230, 240), 'L': (255, 120, 40), 'D': (120, 120, 160), ']': (160, 120, 160),
       ':': (60, 60, 80)}
ENT = {'P': (80, 255, 80), 'X': (255, 255, 0), 'K': (100, 255, 160), 'o': (255, 210, 60), 'f': (255, 140, 110),
       'g': (190, 90, 255), 'T': (200, 140, 60), 'R': (255, 120, 200), '$': (40, 120, 60), 's': (240, 240, 255),
       'G': (180, 190, 220), 'A': (120, 220, 130), 'W': (200, 140, 255), 'B': (255, 255, 255), 'H': (200, 200, 220),
       'V': (200, 200, 220), 'l': (255, 80, 80), 'F': (255, 80, 0), 'O': (210, 210, 210), 'Y': (180, 230, 255),
       'J': (255, 60, 60), 't': (255, 170, 60), '?': (200, 160, 100), 'd': (70, 80, 70), '!': (255, 0, 0)}


def load(path, name):
    src = open(path).read()
    m = re.search(r'const ' + name + r' := """\n(.*?)"""', src, re.S)
    return m.group(1).split('\n')


def main():
    lines = load(sys.argv[1], sys.argv[2])
    lines = [l for l in lines]
    while lines and not lines[-1].strip():
        lines.pop()
    w = max(len(l) for l in lines)
    h = len(lines)
    S = 6
    img = Image.new('RGB', (w * S, h * S), (25, 22, 35))
    d = ImageDraw.Draw(img)
    for y, l in enumerate(lines):
        for x, c in enumerate(l):
            if c in COL:
                d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=COL[c])
            elif c in ENT or c.isdigit():
                d.rectangle([x * S + 1, y * S + 1, x * S + S - 2, y * S + S - 2], fill=ENT.get(c, (255, 0, 0)))
    for x in range(0, w, 10):
        d.line([x * S, 0, x * S, 2], fill=(255, 255, 255))
    img.save(sys.argv[3])
    print(w, h)


main()
