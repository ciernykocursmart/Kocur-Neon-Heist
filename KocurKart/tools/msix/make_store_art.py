#!/usr/bin/env python3
"""Composes Microsoft Store art from the rendered key art (build/keyart.png):
  store/art/hero_3840x2160.png    16:9 super hero art (no text, per Store guidance)
  store/art/boxart_2160x2160.png  1:1 box art with title
  store/art/poster_1440x2160.png  2:3 poster art with title
  store/art/logo_1080x1080.png    1:1 transparent logo
and copies the screenshots into store/screenshots with their final names."""
import os
import shutil
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "store", "art")
SHOTS = os.path.join(ROOT, "store", "screenshots")
FONT = os.path.join(ROOT, "assets", "fonts", "Fredoka-Bold.ttf")
os.makedirs(ART, exist_ok=True)
os.makedirs(SHOTS, exist_ok=True)
key = Image.open(os.path.join(ROOT, "build", "keyart.png")).convert("RGBA")
icon = Image.open(os.path.join(ROOT, "build", "icon", "icon_512.png")).convert("RGBA")


def crop_to(img, w, h, cx=0.5, cy=0.5):
    """Scale to cover w x h, then crop around the (cx, cy) focus."""
    s = max(w / img.width, h / img.height)
    im = img.resize((int(img.width * s + 0.5), int(img.height * s + 0.5)), Image.LANCZOS)
    x = int(min(max(im.width * cx - w / 2, 0), im.width - w))
    y = int(min(max(im.height * cy - h / 2, 0), im.height - h))
    return im.crop((x, y, x + w, y + h))


def title(img, cx, cy, size, sub=True):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, size)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    lines = [("KOCUR", (255, 245, 230)), ("KART", (255, 133, 51))]
    line_h = size * 0.92
    top = cy - line_h
    for i, (t, _c) in enumerate(lines):
        w = d.textlength(t, font=f)
        sd.text((cx - w / 2 + size * 0.04, top + i * line_h + size * 0.05), t, font=f, fill=(20, 8, 40, 200))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.04)))
    for i, (t, c) in enumerate(lines):
        w = d.textlength(t, font=f)
        d.text((cx - w / 2, top + i * line_h), t, font=f, fill=c, stroke_width=max(2, size // 22), stroke_fill=(30, 14, 50))
    if sub:
        fs = ImageFont.truetype(FONT, int(size * 0.2))
        t = "A KOCUR STUDIOS GAME"
        w = d.textlength(t, font=fs)
        d.text((cx - w / 2, top + 2 * line_h + size * 0.1), t, font=fs, fill=(255, 245, 230), stroke_width=max(1, size // 60), stroke_fill=(30, 14, 50))


def gradient_top(img, frac, alpha):
    g = Image.new("L", (1, img.height))
    for y in range(img.height):
        g.putpixel((0, y), int(alpha * max(0.0, 1.0 - y / (img.height * frac))))
    shade = Image.new("RGBA", img.size, (24, 12, 48, 0))
    shade.putalpha(g.resize(img.size))
    img.alpha_composite(shade)


hero = crop_to(key, 3840, 2160)
hero.convert("RGB").save(os.path.join(ART, "hero_3840x2160.png"))

box = crop_to(key, 2160, 2160, cx=0.55, cy=0.5)
gradient_top(box, 0.5, 170)
title(box, 1080, 470, 330)
box.convert("RGB").save(os.path.join(ART, "boxart_2160x2160.png"))

poster = crop_to(key, 1440, 2160, cx=0.56, cy=0.5)
gradient_top(poster, 0.45, 180)
title(poster, 720, 440, 250)
poster.convert("RGB").save(os.path.join(ART, "poster_1440x2160.png"))

logo = Image.new("RGBA", (1080, 1080), (0, 0, 0, 0))
logo.alpha_composite(icon.resize((1000, 1000), Image.LANCZOS), (40, 40))
logo.save(os.path.join(ART, "logo_1080x1080.png"))

order = [("countdown", "01_race_start"), ("neon_start", "02_neon_catway"), ("garage", "03_garage"), ("menu", "04_main_menu")]
for src, dst in order:
    p = os.path.join(ROOT, "build", "shot_%s.png" % src)
    if os.path.exists(p):
        im = Image.open(p).convert("RGB")
        assert im.size == (1920, 1080), (src, im.size)
        im.save(os.path.join(SHOTS, dst + ".png"))
print(sorted(os.listdir(ART)), sorted(os.listdir(SHOTS)))
