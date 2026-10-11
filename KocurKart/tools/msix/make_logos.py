#!/usr/bin/env python3
"""Generates the MSIX tile/logo assets from the rendered game icon."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "store", "msix", "Assets")
ICON = os.path.join(ROOT, "build", "icon", "icon_512.png")
FONT = os.path.join(ROOT, "assets", "fonts", "Fredoka-Bold.ttf")
BG = (20, 13, 36, 255)
ORANGE = (255, 133, 51)
CREAM = (255, 245, 230)
os.makedirs(OUT, exist_ok=True)
icon = Image.open(ICON).convert("RGBA")


def square(name, size, pad=0.0, transparent=True):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0) if transparent else BG)
    s = int(size * (1 - 2 * pad))
    ic = icon.resize((s, s), Image.LANCZOS)
    img.alpha_composite(ic, ((size - s) // 2, (size - s) // 2))
    img.save(os.path.join(OUT, name))


def banner(name, w, h, icon_frac, text_size):
    img = Image.new("RGBA", (w, h), BG)
    s = int(h * icon_frac)
    ic = icon.resize((s, s), Image.LANCZOS)
    font = ImageFont.truetype(FONT, text_size)
    d = ImageDraw.Draw(img)
    t1, t2 = "KOCUR", "KART"
    tw = max(d.textlength(t1, font=font), d.textlength(t2, font=font))
    gap = int(h * 0.06)
    total = s + gap + tw
    x = int((w - total) / 2)
    img.alpha_composite(ic, (x, (h - s) // 2))
    tx = x + s + gap
    line = text_size * 0.95
    ty = h / 2 - line
    d.text((tx, ty), t1, font=font, fill=CREAM)
    d.text((tx, ty + line), t2, font=font, fill=ORANGE)
    img.save(os.path.join(OUT, name))


square("StoreLogo.png", 50)
square("Square44x44Logo.png", 44)
square("Square44x44Logo.targetsize-256.png", 256)
square("Square71x71Logo.png", 71, 0.05)
square("Square150x150Logo.png", 150, 0.12)
square("Square310x310Logo.png", 310, 0.12)
banner("Wide310x150Logo.png", 310, 150, 0.62, 34)
banner("SplashScreen.png", 620, 300, 0.62, 68)
print(sorted(os.listdir(OUT)))
