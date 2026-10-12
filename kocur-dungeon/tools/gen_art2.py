"""Tiles, backgrounds, objects, effects, bosses, UI icons and the pixel font."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, mix, shade, sheet, grid_sheet, noise_rng  # noqa: E402
from PIL import Image  # noqa: E402
import gen_art as G  # noqa: E402

OUT = G.OUT


def save(img, name):
    img.save(os.path.join(OUT, name))


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

REGIONS = {
    1: dict(stone='4f574c', mortar='2c3229', lip='6aa040', lip2='3f7a2a', bg='252b25', bg2='1c211c', accent='8ccf5a',
            hazard='lava', name='mossroot'),
    2: dict(stone='5e3d31', mortar='2e1a14', lip='d0683a', lip2='8a3420', bg='2c1c18', bg2='211411', accent='ff9a3a',
            hazard='lava', name='emberpaw'),
    3: dict(stone='52627a', mortar='2a3242', lip='e6f2ff', lip2='a8c4e0', bg='1e2636', bg2='161c2a', accent='9ad8ff',
            hazard='lava', name='frostfang'),
    4: dict(stone='3e3456', mortar='1e1830', lip='4ad6b4', lip2='2a8a76', bg='16121f', bg2='0f0c17', accent='5affd0',
            hazard='lava', name='shadowclaw'),
    5: dict(stone='b4accb', mortar='726a8a', lip='e8c860', lip2='a88a30', bg='2e2840', bg2='231e33', accent='ffe080',
            hazard='lava', name='citadel'),
}


def brick_tile(rng, st, mo, variant):
    c = Canvas(16, 16)
    c.rect(0, 0, 16, 16, st)
    off = 0 if variant % 2 == 0 else 4
    for row in range(4):
        y = row * 4
        c.rect(0, y + 3, 16, 1, mo)
        o = (off + (row % 2) * 4) % 8
        for x in range(o, 16, 8):
            c.rect(x, y, 1, 3, mo)
    for _ in range(10):
        x, y = rng.randrange(16), rng.randrange(16)
        if c.get(x, y) == st:
            c.set(x, y, shade(st, rng.choice([0.85, 1.12, 0.92])))
    # top-left light on each brick
    for x in range(16):
        for y in range(16):
            if c.get(x, y) == st and c.get(x, y - 1) == mo:
                c.set(x, y, shade(st, 1.15))
    return c


def autotile(base, mask, pal, rng, ice=False):
    """mask bits: 1 top exposed, 2 right, 4 bottom, 8 left."""
    c = Canvas(16, 16)
    c.paste(base, 0, 0)
    dark = hexc('0c0a10')
    lip, lip2 = hexc(pal['lip']), hexc(pal['lip2'])
    if ice:
        lip, lip2 = hexc('f2fbff'), hexc('9fd6f5')
    if mask & 2:
        c.rect(15, 0, 1, 16, dark)
        c.rect(14, 0, 1, 16, shade(base.get(14, 8), 0.8))
    if mask & 8:
        c.rect(0, 0, 1, 16, dark)
        c.rect(1, 0, 1, 16, shade(base.get(1, 8), 0.85))
    if mask & 4:
        c.rect(0, 15, 16, 1, dark)
        c.rect(0, 14, 16, 1, shade(base.get(8, 14), 0.75))
    if mask & 1:
        c.rect(0, 0, 16, 2, lip)
        c.rect(0, 2, 16, 1, lip2)
        for x in range(16):
            if rng.random() < 0.45:
                c.set(x, 3, lip2)
            if rng.random() < 0.2:
                c.set(x, 4, lip2)
        if not ice and pal['name'] in ('mossroot', 'shadowclaw'):
            for x in range(0, 16, rng.choice([5, 6, 7])):
                c.set(x, 0, shade(lip, 1.25))
        if mask & 8:
            c.set(0, 0, T0)
        if mask & 2:
            c.set(15, 0, T0)
    return c


T0 = (0, 0, 0, 0)


def bg_tile(rng, pal, variant):
    c = Canvas(16, 16)
    b, b2 = hexc(pal['bg']), hexc(pal['bg2'])
    c.rect(0, 0, 16, 16, b)
    off = (variant % 2) * 8
    for row in range(2):
        y = row * 8
        c.rect(0, y + 7, 16, 1, b2)
        o = (off + row * 8) % 16
        c.rect(o, y, 1, 7, b2)
    for _ in range(8):
        x, y = rng.randrange(16), rng.randrange(16)
        c.set(x, y, shade(b, rng.choice([0.8, 1.15])))
    if variant == 2:
        c.ellipse(8, 9, 3, 2, shade(b, 0.7))  # crack / hole
    if variant == 3:
        c.line(3, 2, 6, 7, b2); c.line(6, 7, 5, 12, b2)
    return c


def tiles_for_region(n):
    pal = REGIONS[n]
    rng = noise_rng(100 + n)
    st, mo = hexc(pal['stone']), hexc(pal['mortar'])
    atlas = Image.new('RGBA', (16 * 16, 16 * 5), (0, 0, 0, 0))
    bases = [brick_tile(rng, st, mo, v) for v in range(2)]
    for row in range(2):
        for mask in range(16):
            t = autotile(bases[row], mask, pal, rng)
            atlas.paste(t.img, (mask * 16, row * 16))
    # row 2: background + misc
    for v in range(4):
        atlas.paste(bg_tile(rng, pal, v).img, (v * 16, 32))
    # dark bg (deep)
    d = Canvas(16, 16); d.rect(0, 0, 16, 16, shade(hexc(pal['bg2']), 0.7))
    atlas.paste(d.img, (4 * 16, 32))
    # one-way platform l/m/r  (wooden / stone plank)
    wood = hexc('7a5634') if n != 5 else hexc('cfc6de')
    woodd = shade(wood, 0.6)
    for i in range(3):
        c = Canvas(16, 16)
        c.rect(0, 0, 16, 5, wood)
        c.rect(0, 0, 16, 1, shade(wood, 1.3))
        c.rect(0, 4, 16, 1, woodd)
        for x in (3, 11):
            c.set(x, 2, woodd)
        if i == 0:
            c.rect(0, 0, 1, 5, woodd)
            c.line(2, 5, 6, 9, woodd)
        if i == 2:
            c.rect(15, 0, 1, 5, woodd)
            c.line(13, 5, 9, 9, woodd)
        atlas.paste(c.img, ((6 + i) * 16, 32))
    # crumble platform + cracked
    for k in range(2):
        c = Canvas(16, 16)
        cr = hexc('8a7a68') if n != 3 else hexc('9ab8d8')
        c.rect(0, 0, 16, 8, cr)
        c.rect(0, 0, 16, 1, shade(cr, 1.3))
        c.rect(0, 7, 16, 1, shade(cr, 0.55))
        c.line(5, 0, 7, 7, shade(cr, 0.55))
        c.line(11, 1, 10, 7, shade(cr, 0.55))
        if k:
            c.line(2, 3, 14, 4, shade(cr, 0.45))
            c.line(8, 0, 9, 7, shade(cr, 0.45))
        atlas.paste(c.img, ((9 + k) * 16, 32))
    # spikes up / down
    for k in range(2):
        c = Canvas(16, 16)
        metal, metald = hexc('c8ccd8'), hexc('6a6e80')
        for i in range(4):
            x = i * 4
            pts = [(x, 16), (x + 2, 8), (x + 4, 16)]
            c.poly(pts, metal)
            c.line(x + 2, 9, x + 2, 15, metald)
        c.rect(0, 15, 16, 1, metald)
        if k:
            c.img = c.img.transpose(Image.FLIP_TOP_BOTTOM); c.px = c.img.load()
        atlas.paste(c.img, ((11 + k) * 16, 32))
    # lava/acid top + body (region-coloured pool)
    pool = {1: ('6ad04a', '3a8a2a'), 2: ('ff8a2a', 'c0401a'), 3: ('7ad0ff', '2a70c0'), 4: ('b05aff', '5a2aa0'),
            5: ('ffd060', 'd07a20')}[n]
    top, body = hexc(pool[0]), hexc(pool[1])
    c = Canvas(16, 16)
    c.rect(0, 4, 16, 12, body)
    for x in range(16):
        h = 4 + int(1.5 + 1.5 * math.sin(x / 16 * math.tau * 2))
        c.rect(x, h, 1, 2, top)
    c.set(4, 9, shade(top, 1.2)); c.set(11, 12, shade(top, 1.2))
    atlas.paste(c.img, (13 * 16, 32))
    c = Canvas(16, 16)
    c.rect(0, 0, 16, 16, body)
    for _ in range(6):
        c.set(rng.randrange(16), rng.randrange(16), shade(body, 1.25))
    atlas.paste(c.img, (14 * 16, 32))
    # fake wall marker look = same as base brick (col 15 row 2) slightly different
    atlas.paste(autotile(bases[0], 0, pal, rng).img, (15 * 16, 32))
    # row 3: ice autotile
    ice_base = brick_tile(rng, hexc('8ec4e8'), hexc('4a7ab0'), 0)
    for mask in range(16):
        t = autotile(ice_base, mask, pal, rng, ice=True)
        atlas.paste(t.img, (mask * 16, 48))
    # row 4: decorations (moss hang, chain, skull, banner, crystal, mushroom, bones, grate)
    decos = []
    acc = hexc(pal['accent'])
    c = Canvas(16, 16)  # hanging vines/icicles/etc
    for x in (2, 6, 9, 13):
        ln = rng.randrange(4, 12)
        c.line(x, 0, x, ln, hexc(pal['lip2']))
        c.set(x, ln, acc)
    decos.append(c)
    c = Canvas(16, 16)  # chain
    for y in range(0, 16, 3):
        c.rect(7, y, 2, 2, hexc('6a6a78'))
        c.set(7, y + 2, hexc('3a3a48'))
    decos.append(c)
    c = Canvas(16, 16)  # skull
    c.ellipse(8, 10, 4, 3.5, hexc('d8d2c0'))
    c.rect(6, 12, 5, 2, hexc('d8d2c0'))
    c.set(6, 10, hexc('201818')); c.set(10, 10, hexc('201818'))
    c.poly([(4, 8), (5, 4), (7, 7)], hexc('d8d2c0')); c.poly([(9, 7), (11, 4), (12, 8)], hexc('d8d2c0'))
    decos.append(c)
    c = Canvas(16, 16)  # banner (white clan)
    c.rect(3, 0, 10, 13, hexc('e8e4f0'))
    c.poly([(3, 13), (8, 16), (13, 13)], hexc('e8e4f0'))
    c.rect(3, 0, 10, 1, hexc('c8a040'))
    c.ellipse(8, 7, 2.5, 2.5, hexc('c03040'))
    c.poly([(6, 6), (6.5, 3.5), (8, 5)], hexc('c03040')); c.poly([(8, 5), (9.5, 3.5), (10, 6)], hexc('c03040'))
    decos.append(c)
    c = Canvas(16, 16)  # crystal
    c.poly([(5, 16), (7, 5), (9, 16)], acc)
    c.poly([(9, 16), (11, 9), (13, 16)], shade(acc, 0.8))
    c.poly([(2, 16), (3, 11), (5, 16)], shade(acc, 0.7))
    c.line(7, 7, 7, 14, shade(acc, 1.3))
    decos.append(c)
    c = Canvas(16, 16)  # mushroom / plant
    c.rect(7, 10, 2, 6, hexc('d8d0b8'))
    c.ellipse(8, 9, 5, 2.5, acc)
    c.set(6, 8, shade(acc, 1.4)); c.set(10, 9, shade(acc, 1.4))
    c.rect(3, 14, 1, 2, acc); c.rect(12, 13, 1, 3, acc)
    decos.append(c)
    c = Canvas(16, 16)  # bones/rubble
    c.ellipse(5, 14, 4, 2, shade(hexc(pal['stone']), 0.9))
    c.ellipse(11, 14, 3, 2, shade(hexc(pal['stone']), 1.1))
    c.line(4, 12, 11, 15, hexc('d8d2c0')); c.set(4, 11, hexc('d8d2c0')); c.set(11, 16, hexc('d8d2c0'))
    decos.append(c)
    c = Canvas(16, 16)  # window grate with light
    c.rect(3, 3, 10, 10, shade(acc, 0.5))
    for x in (5, 8, 11):
        c.rect(x, 3, 1, 10, hexc('1a1820'))
    c.rect(3, 3, 10, 1, hexc('1a1820')); c.rect(3, 12, 10, 1, hexc('1a1820'))
    decos.append(c)
    for i, d in enumerate(decos):
        atlas.paste(d.img, (i * 16, 64))
    save(atlas, 'tiles_r%d.png' % n)


# ---------------------------------------------------------------------------
# Parallax backgrounds (320x180, tile horizontally)
# ---------------------------------------------------------------------------

def backgrounds():
    for n, pal in REGIONS.items():
        rng = noise_rng(300 + n)
        W, H = 320, 180
        far = Canvas(W, H)
        top = shade(hexc(pal['bg2']), 0.55)
        bot = shade(hexc(pal['bg']), 0.9)
        for y in range(H):
            far.rect(0, y, W, 1, mix(top, bot, y / H))
        sil = shade(hexc(pal['bg']), 1.25)
        sil2 = shade(hexc(pal['bg']), 1.05)
        # distant arches / pillars
        for i in range(5):
            x = i * 64 + 10
            far.rect(x, 40, 14, H - 40, sil2)
            far.rect(x - 2, 38, 18, 4, sil)
            for k in range(3):
                far.rect(x + 2, 60 + k * 30, 10, 1, shade(sil2, 0.8))
        for i in range(5):
            cx = i * 64 + 49
            for a in range(0, 181, 4):
                r = math.radians(a)
                far.rect(cx + math.cos(r) * 25, 70 - math.sin(r) * 22, 3, 3, sil2)
        accent = hexc(pal['accent'], 120)
        for _ in range(40):
            far.set(rng.randrange(W), rng.randrange(H), accent)
        if n == 5:  # citadel windows with moon light
            for i in range(5):
                x = i * 64 + 44
                far.rect(x, 90, 10, 22, hexc('5a5480'))
                far.ellipse(x + 5, 90, 5, 4, hexc('5a5480'))
                far.rect(x + 4, 86, 2, 26, shade(hexc('5a5480'), 0.6))
        save(far.img, 'bg_r%d_far.png' % n)
        mid = Canvas(W, H)
        rock = shade(hexc(pal['stone']), 0.45)
        rock2 = shade(hexc(pal['stone']), 0.6)
        for i in range(8):  # stalactites
            x = rng.randrange(W)
            w = rng.randrange(8, 20)
            h = rng.randrange(18, 50)
            mid.poly([(x - w / 2, 0), (x + w / 2, 0), (x, h)], rock)
            mid.poly([(x - w / 4, 0), (x + w / 6, 0), (x - 1, h * 0.7)], rock2)
            if x < w:
                mid.poly([(x + W - w / 2, 0), (x + W + w / 2, 0), (x + W, h)], rock)
            if x > W - w:
                mid.poly([(x - W - w / 2, 0), (x - W + w / 2, 0), (x - W, h)], rock)
        for i in range(6):  # floor rocks / mounds
            x = rng.randrange(W)
            w = rng.randrange(20, 50)
            mid.ellipse(x, H, w, rng.randrange(14, 30), rock)
            if x < w:
                mid.ellipse(x + W, H, w, 20, rock)
            if x > W - w:
                mid.ellipse(x - W, H, w, 20, rock)
        if n == 1:
            for i in range(10):
                x = rng.randrange(W)
                ln = rng.randrange(20, 70)
                mid.line(x, 0, x + rng.randrange(-4, 5), ln, hexc('2f5a24'))
        if n == 2:
            for i in range(3):  # mine scaffolding
                x = i * 107 + 30
                mid.rect(x, 60, 3, 120, hexc('3a2618'))
                mid.rect(x + 30, 60, 3, 120, hexc('3a2618'))
                mid.rect(x - 2, 60, 37, 3, hexc('3a2618'))
                mid.line(x, 63, x + 32, 110, hexc('2e1e12'))
        if n == 3:
            for i in range(14):
                x = rng.randrange(W)
                mid.poly([(x - 2, 0), (x + 2, 0), (x, rng.randrange(10, 30))], hexc('6a8ab0'))
        if n == 4:
            for i in range(12):
                x, y = rng.randrange(W), rng.randrange(40, H)
                mid.circle(x, y, 1, hexc('5affd0', 140))
        if n == 5:
            for i in range(4):
                x = i * 80 + 20
                mid.rect(x, 0, 18, H, hexc('8a82a6', 140))
                mid.rect(x - 3, 0, 24, 8, hexc('a49cc0', 160))
                mid.rect(x + 4, 30, 10, 40, hexc('c0303a', 140))
                mid.poly([(x + 4, 70), (x + 9, 76), (x + 14, 70)], hexc('c0303a', 140))
        save(mid.img, 'bg_r%d_mid.png' % n)


# ---------------------------------------------------------------------------
# Objects / pickups / FX
# ---------------------------------------------------------------------------

def strip(frames, name):
    save(sheet(frames, frames[0].w, frames[0].h), name)


def objects():
    gold, goldd, goldl = hexc('f0c040'), hexc('a87818'), hexc('fff0a0')
    # coin 4 frames 16x16
    fr = []
    for i, w in enumerate([4, 3, 1, 3]):
        c = Canvas(16, 16)
        c.ellipse(8, 8, w + 0.5, 4.5, goldd)
        c.ellipse(8, 8, max(w - 0.5, 0.6), 3.5, gold)
        if w > 2:
            c.rect(7, 6, 1, 4, goldd)  # paw print-ish mark
            c.set(9, 6, goldd)
        c.set(7 - (w > 2), 5, goldl)
        fr.append(c)
    strip(fr, 'coin.png')
    # shadow gem 4 frames
    fr = []
    for i in range(4):
        c = Canvas(16, 16)
        pur, purd, purl = hexc('9a4aff'), hexc('4a1a90'), hexc('e0b0ff')
        c.poly([(8, 2), (13, 7), (8, 14), (3, 7)], purd)
        c.poly([(8, 3), (12, 7), (8, 12), (4, 7)], pur)
        c.line(5, 7, 11, 7, purd)
        sp = [(6, 5), (9, 4), (10, 9), (6, 9)][i]
        c.set(sp[0], sp[1], purl)
        c.set(8, 3, purl)
        fr.append(c)
    strip(fr, 'gem.png')
    # fish (heal) 2 frames
    fr = []
    for i in range(2):
        c = Canvas(16, 16)
        fish, fishd = hexc('ff9a6a'), hexc('c05a3a')
        c.ellipse(7, 8 + (i * 0.5), 4.5, 2.6, fish)
        c.poly([(11, 8), (15, 5 + i), (15, 11 - i)], fishd)
        c.set(4, 7, hexc('201010'))
        c.line(6, 6, 6, 10, fishd)
        c.set(3, 9, hexc('ffd0c0'))
        fr.append(c)
    strip(fr, 'fish.png')
    # chest closed/open 16x16
    fr = []
    for k in range(2):
        c = Canvas(16, 16)
        wd, wdd, band = hexc('8a5a2a'), hexc('4a2a12'), hexc('d8b040')
        c.rect(2, 7, 12, 8, wd)
        c.rect(2, 14, 12, 1, wdd)
        if k == 0:
            c.rect(2, 3, 12, 5, shade(wd, 1.15))
            c.rect(2, 3, 12, 1, shade(wd, 1.3))
        else:
            c.rect(2, 1, 12, 3, shade(wd, 1.15))
            c.rect(3, 6, 10, 2, hexc('ffe070'))
            c.set(5, 5, hexc('fff6c0')); c.set(10, 4, hexc('fff6c0'))
        c.rect(2, 7, 12, 1, band)
        c.rect(7, 6, 2, 3, band)
        c.outline(hexc('1a1008'))
        fr.append(c)
    strip(fr, 'chest.png')
    # checkpoint: catnip lantern 16x32, unlit + 3 lit frames
    fr = []
    for k in range(4):
        c = Canvas(16, 32)
        post = hexc('5a4a3a')
        c.rect(7, 12, 2, 20, post)
        c.rect(4, 29, 8, 3, post)
        c.rect(4, 3, 8, 9, hexc('2a2a34'))
        c.rect(5, 4, 6, 7, hexc('3a3a4a') if k == 0 else hexc('80ff9a'))
        c.rect(3, 2, 10, 2, hexc('6a6a78'))
        c.rect(7, 0, 2, 2, hexc('6a6a78'))
        if k:
            fl = [(8, 6), (7, 7), (8, 5)][k - 1]
            c.rect(fl[0] - 1, fl[1], 2, 3, hexc('ffffff'))
            c.rect(6, 9, 4, 1, hexc('c0ffd0'))
        c.outline(hexc('101018'))
        fr.append(c)
    strip(fr, 'checkpoint.png')
    # exit door 32x32 closed/open
    fr = []
    for k in range(2):
        c = Canvas(32, 32)
        st = hexc('6a6478')
        c.rect(4, 4, 24, 28, st)
        c.ellipse(16, 8, 12, 8, st)
        c.rect(7, 9, 18, 23, hexc('3a2414') if k == 0 else hexc('0a0810'))
        c.ellipse(16, 10, 9, 6, hexc('3a2414') if k == 0 else hexc('0a0810'))
        if k == 0:
            for x in (11, 16, 21):
                c.rect(x, 6, 1, 26, hexc('2a180c'))
            c.set(21, 20, hexc('d8b040'))
        else:
            for y in range(10, 32, 2):
                c.set(16 + int(math.sin(y) * 3), y, hexc('c6ff4a', 150))
        # paw emblem
        c.ellipse(16, 3, 2, 1.5, hexc('d8b040'))
        c.outline(hexc('101018'))
        fr.append(c)
    strip(fr, 'door.png')
    # lever off/on 16x16
    fr = []
    for k in range(2):
        c = Canvas(16, 16)
        c.rect(3, 12, 10, 4, hexc('5a5a68'))
        c.rect(3, 12, 10, 1, hexc('8a8a98'))
        if k == 0:
            c.line(8, 12, 4, 5, hexc('7a5a3a'), 2)
            c.circle(4, 5, 1.5, hexc('d04040'))
        else:
            c.line(8, 12, 12, 5, hexc('7a5a3a'), 2)
            c.circle(12, 5, 1.5, hexc('40d060'))
        c.outline(hexc('101018'))
        fr.append(c)
    strip(fr, 'lever.png')
    # gate 16x16 segment (iron bars)
    c = Canvas(16, 16)
    for x in (2, 7, 12):
        c.rect(x, 0, 2, 16, hexc('6a6e80'))
        c.rect(x, 0, 1, 16, hexc('9a9eb0'))
    c.rect(0, 6, 16, 2, hexc('4a4e60'))
    strip([c], 'gate.png')
    # sign 16x16
    c = Canvas(16, 16)
    c.rect(7, 9, 2, 7, hexc('5a3a1a'))
    c.rect(1, 2, 14, 8, hexc('9a7040'))
    c.rect(1, 2, 14, 1, hexc('c09060'))
    for y in (4, 6):
        c.rect(3, y, 10, 1, hexc('5a3a1a'))
    c.outline(hexc('101018'))
    strip([c], 'sign.png')
    # torch 3 frames 16x16
    fr = []
    for k in range(3):
        c = Canvas(16, 16)
        c.rect(7, 8, 2, 8, hexc('5a3a1a'))
        c.rect(6, 7, 4, 2, hexc('6a6a78'))
        fl = [3, 2, 4][k]
        c.ellipse(8, 5, 2.5, fl, hexc('ff8a2a'))
        c.ellipse(8, 5.5, 1.3, fl * 0.6, hexc('ffe070'))
        fr.append(c)
    strip(fr, 'torch.png')
    # cage 32x32 (closed) + broken
    fr = []
    for k in range(2):
        c = Canvas(32, 32)
        iron, irond = hexc('8a8e9e'), hexc('4a4e5e')
        c.rect(4, 28, 24, 4, irond)
        c.rect(4, 28, 24, 1, iron)
        if k == 0:
            c.rect(4, 6, 24, 3, irond)
            c.rect(4, 6, 24, 1, iron)
            for x in range(5, 28, 4):
                c.rect(x, 8, 1, 20, iron)
            c.rect(15, 2, 2, 4, irond)
            c.rect(13, 13, 6, 5, hexc('c8a040'))  # padlock
            c.rect(14, 11, 4, 2, irond)
            c.set(16, 15, hexc('201010'))
        else:
            for x in (5, 9, 26):
                c.rect(x, 20, 1, 8, iron)
            c.line(12, 27, 16, 22, iron); c.line(20, 27, 24, 20, iron)
        c.outline(hexc('101018'))
        fr.append(c)
    strip(fr, 'cage.png')
    # moving platform 48x10
    c = Canvas(48, 10)
    m = hexc('7a7088')
    c.rect(0, 0, 48, 8, m)
    c.rect(0, 0, 48, 2, shade(m, 1.35))
    c.rect(0, 7, 48, 1, shade(m, 0.5))
    for x in (4, 22, 40):
        c.circle(x + 2, 4.5, 1.2, hexc('d8b040'))
    c.rect(20, 8, 8, 2, shade(m, 0.6))
    strip([c], 'platform.png')
    # saw blade 16x16 2 frames
    fr = []
    for k in range(2):
        c = Canvas(16, 16)
        for i in range(8):
            a = i / 8 * math.tau + k * math.pi / 8
            c.poly([(8 + math.cos(a) * 3, 8 + math.sin(a) * 3), (8 + math.cos(a + 0.25) * 7.5, 8 + math.sin(a + 0.25) * 7.5),
                    (8 + math.cos(a + 0.5) * 3, 8 + math.sin(a + 0.5) * 3)], hexc('d0d4e0'))
        c.circle(8, 8, 4.5, hexc('9aa0b0'))
        c.circle(8, 8, 1.5, hexc('3a3e4e'))
        fr.append(c)
    strip(fr, 'saw.png')
    # flame jet nozzle 16x16 + flame column 16x48 3 frames
    c = Canvas(16, 16)
    c.rect(2, 10, 12, 6, hexc('4a4450'))
    c.rect(4, 8, 8, 3, hexc('6a6470'))
    c.rect(6, 7, 4, 1, hexc('2a2430'))
    c.outline(hexc('101018'))
    strip([c], 'flame_base.png')
    fr = []
    rng = noise_rng(5)
    for k in range(3):
        c = Canvas(16, 48)
        for y in range(48):
            w = 3 + 3 * (y / 48) + rng.random() * 1.5
            col = mix(hexc('fff2a0'), hexc('ff5a1a'), 1 - y / 48)
            c.rect(8 - w, y, w * 2, 1, col)
            c.rect(8 - w * 0.4, y, w * 0.8, 1, mix(hexc('ffffff'), col, 0.5))
        fr.append(c)
    strip(fr, 'flame.png')
    # icicle 16x16
    c = Canvas(16, 16)
    c.poly([(4, 0), (12, 0), (8, 15)], hexc('a8dcff'))
    c.line(7, 1, 8, 12, hexc('f0faff'))
    c.outline(hexc('3a5a8a'))
    strip([c], 'icicle.png')
    # spring pad 16x16 2 frames
    fr = []
    for k in range(2):
        c = Canvas(16, 16)
        c.rect(2, 13, 12, 3, hexc('5a5a68'))
        h = 4 if k == 0 else 8
        for y in range(13 - h, 13, 2):
            c.rect(5, y, 6, 1, hexc('b0b0c0'))
        c.rect(2, 12 - h, 12, 2, hexc('d04040'))
        c.outline(hexc('101018'))
        fr.append(c)
    strip(fr, 'spring.png')
    # relic (region relic, 5 colours) 16x16 per frame
    fr = []
    for col in ['8ccf5a', 'ff8a3a', '9ad8ff', '5affd0', 'ffe080']:
        c = Canvas(16, 16)
        cc = hexc(col)
        c.circle(8, 8, 6, shade(cc, 0.4))
        c.circle(8, 8, 5, cc)
        c.ellipse(8, 9, 2.4, 1.8, shade(cc, 0.35))  # paw pad
        for (x, y) in [(5, 5), (7, 4), (9, 4), (11, 5)]:
            c.set(x, y, shade(cc, 0.35))
        c.set(6, 5, hexc('ffffff'))
        c.outline(hexc('101018'))
        fr.append(c)
    strip(fr, 'relic.png')


def fx():
    # slash arc 32x32 3 frames
    fr = []
    for k in range(3):
        c = Canvas(32, 32)
        a0, a1 = -1.4 + k * 0.5, 0.2 + k * 0.6
        for i in range(30):
            a = a0 + (a1 - a0) * i / 29
            r = 11
            alpha = int(255 * (1 - k * 0.3))
            col = mix(hexc('ffffff'), hexc('c6ff4a'), i / 29)
            col = (col[0], col[1], col[2], alpha)
            c.set(12 + math.cos(a) * r, 16 + math.sin(a) * r, col)
            c.set(12 + math.cos(a) * (r - 1), 16 + math.sin(a) * (r - 1), col)
            if i % 2 == 0:
                c.set(12 + math.cos(a) * (r - 3), 16 + math.sin(a) * (r - 3), (col[0], col[1], col[2], alpha // 2))
        fr.append(c)
    strip(fr, 'slash.png')
    # hit spark 16x16 3 frames
    fr = []
    for k in range(3):
        c = Canvas(16, 16)
        r = 2 + k * 2.5
        for i in range(8):
            a = i / 8 * math.tau
            c.line(8 + math.cos(a) * (r - 2), 8 + math.sin(a) * (r - 2), 8 + math.cos(a) * r, 8 + math.sin(a) * r,
                   hexc('fff6c0') if k < 2 else hexc('ffb040'))
        if k == 0:
            c.circle(8, 8, 2, hexc('ffffff'))
        fr.append(c)
    strip(fr, 'spark.png')
    # dust 16x16 4 frames
    fr = []
    for k in range(4):
        c = Canvas(16, 16)
        a = int(200 * (1 - k / 4))
        c.circle(5 - k * 0.5, 11 - k, 2 + k * 0.6, (200, 196, 210, a))
        c.circle(11 + k * 0.5, 11 - k, 1.6 + k * 0.5, (200, 196, 210, a))
        fr.append(c)
    strip(fr, 'dust.png')
    # explosion / poof 32x32 5 frames
    fr = []
    for k in range(5):
        c = Canvas(32, 32)
        r = 4 + k * 3
        a = int(255 * (1 - k / 5))
        c.circle(16, 16, r, (255, 240, 220, a))
        c.circle(16, 16, max(r - 3, 0.5), (255, 255, 255, int(a * 0.8)) if k < 2 else (0, 0, 0, 0))
        for i in range(6):
            ang = i / 6 * math.tau + k
            c.circle(16 + math.cos(ang) * (r + 2), 16 + math.sin(ang) * (r + 2), 1.5, (230, 230, 255, a))
        fr.append(c)
    strip(fr, 'poof.png')
    # projectiles
    c = Canvas(16, 8)
    c.line(1, 4, 12, 4, hexc('c8a070'))
    c.poly([(11, 2), (15, 4), (11, 6)], hexc('e0e4f0'))
    c.line(0, 3, 2, 4, hexc('f0f0f0')); c.line(0, 5, 2, 4, hexc('f0f0f0'))
    strip([c], 'arrow.png')
    for name, cols in [('orb', ('c080ff', 'f4e0ff')), ('fireball', ('ff6a1a', 'ffe070')), ('pale_orb', ('e8e0ff', 'ffffff')),
                       ('shadow_orb', ('6a3aa0', 'c8a0ff'))]:
        fr = []
        for k in range(2):
            c = Canvas(12, 12)
            c.circle(6, 6, 5 - k * 0.5, hexc(cols[0], 160))
            c.circle(6, 6, 3.5, hexc(cols[0]))
            c.circle(5.5, 5.5, 1.8, hexc(cols[1]))
            fr.append(c)
        strip(fr, name + '.png')
    c = Canvas(12, 12)
    c.poly([(1, 6), (6, 2), (11, 6), (6, 10)], hexc('a8dcff'))
    c.line(2, 6, 10, 6, hexc('f0faff'))
    strip([c], 'ice_shard.png')
    # shockwave 32x16 2 frames
    fr = []
    for k in range(2):
        c = Canvas(32, 16)
        for x in range(32):
            h = int(6 + 6 * math.sin(x / 31 * math.pi) + k)
            c.rect(x, 16 - h, 1, h, (255, 200 - k * 60, 120, 200))
            c.set(x, 16 - h, hexc('ffffff'))
        fr.append(c)
    strip(fr, 'shockwave.png')
    # warning marker (red !) 16x16
    c = Canvas(16, 16)
    c.poly([(8, 1), (15, 14), (1, 14)], hexc('ff3a3a'))
    c.poly([(8, 3), (13, 13), (3, 13)], hexc('ffd040'))
    c.rect(7, 6, 2, 4, hexc('201010'))
    c.rect(7, 11, 2, 1, hexc('201010'))
    strip([c], 'warning.png')
    # soft light texture 64x64 (radial)
    c = Canvas(64, 64)
    for x in range(64):
        for y in range(64):
            d = math.hypot(x - 31.5, y - 31.5) / 32
            if d < 1:
                a = (1 - d) ** 1.6
                c.px[x, y] = (255, 255, 255, int(255 * a))
    save(c.img, 'light.png')


# ---------------------------------------------------------------------------
# Bosses
# ---------------------------------------------------------------------------

def boss_sheet(name, draw, fw=64, fh=64):
    rows = []
    rows.append([draw({'by': b, 'tail': t}) for b, t in [(0, 0), (0.5, 0.6)]])  # idle
    walk = []
    for i in range(4):
        ph = i / 4 * math.tau
        walk.append(draw({'by': -abs(math.sin(ph)) * 0.7, 'legs': [(math.sin(ph) * 2.5, max(0, math.cos(ph)) * 1.5),
                                                                  (-math.sin(ph) * 2.5, max(0, -math.cos(ph)) * 1.5)]}))
    rows.append(walk)
    rows.append([draw({'bx': -1.5, 'lean': -1.5, 'arm_f': (17, 9), 'by': -0.5, 'windup': 1}),
                 draw({'bx': -2, 'lean': -2, 'arm_f': (16, 8), 'by': -1, 'windup': 2})])  # windup
    rows.append([draw({'bx': 2, 'lean': 2, 'arm_f': (26, 24), 'legs': [(-3, 0), (2, 0)], 'attack': 1}),
                 draw({'bx': 1.5, 'lean': 1, 'arm_f': (25, 26), 'attack': 2})])  # attack
    rows.append([draw({'arm_f': (22, 8), 'arm_b': (12, 8), 'by': -1, 'cast': 1}),
                 draw({'arm_f': (23, 7), 'arm_b': (11, 7), 'by': -1.5, 'cast': 2})])  # cast
    rows.append([draw({'eye': 'x', 'hy': 1.5, 'lean': -1, 'by': 1, 'arm_f': (20, 26), 'arm_b': (13, 26)}),
                 draw({'eye': 'x', 'hy': 2, 'lean': -1, 'by': 1.3, 'arm_f': (20, 27), 'arm_b': (13, 27)})])  # stunned
    rows.append([draw({'eye': 'closed', 'bx': -1, 'lean': -1.5})])  # hurt
    death = [draw({'eye': 'x', 'by': 1, 'lean': -2})]
    for i in range(2):
        img = draw({'eye': 'x', 'by': 1}).img.rotate(90 if i else 40, center=(fw // 2, fh - 4))
        cc = Canvas(fw, fh)
        cc.img.paste(img, (0, 3 if i else 2))
        cc.px = cc.img.load()
        death.append(cc)
    rows.append(death)
    save(grid_sheet(rows, fw, fh), name + '.png')


def big_biped(outfit, item=None, s=1.9, fw=64, fh=64, eye=None, fur=None):
    def draw(p):
        c = Canvas(fw, fh)
        p = dict(p)
        if item and 'item' not in p:
            p['item'] = item
        old_eye = G.WHITE['eye']
        old_fur = G.WHITE['fur']
        old_sh = G.WHITE['sh']
        if eye:
            G.WHITE['eye'] = hexc(eye)
        if fur:
            G.WHITE['fur'], G.WHITE['sh'] = hexc(fur[0]), hexc(fur[1])
        G.draw_biped(c, p, outfit, ox=(fw - 32) // 2, oy=fh - 32, s=s)
        G.WHITE['eye'], G.WHITE['fur'], G.WHITE['sh'] = old_eye, old_fur, old_sh
        return c
    return draw


def outfit_iron(c, p, X, Y, bx, by, hx, hy, s):
    iron, ironl, irond = hexc('7a7e8e'), hexc('b0b6c6'), hexc('4a4e5e')
    c.ellipse(X(16 + bx + p.get('lean', 0) * 0.5), Y(19.5 + by), 4.8 * s, 5.2 * s, iron)
    c.rect(X(12 + bx), Y(16 + by), 9 * s, 1 * s, ironl)
    c.rect(X(12 + bx), Y(21 + by), 9 * s, 1 * s, irond)
    c.ellipse(X(13 + bx), Y(15 + by), 2.4 * s, 1.8 * s, ironl)  # pauldron
    c.rect(X(hx - 4.4), Y(hy - 4.4), 9 * s, 3.4 * s, iron)
    c.rect(X(hx - 4.4), Y(hy - 4.4), 9 * s, 1 * s, ironl)
    c.rect(X(hx + 0.5), Y(hy - 1.4), 4 * s, 1 * s, irond)  # visor
    for k in range(3):
        c.set(X(13 + bx + k * 3), Y(18.5 + by), hexc('d8b040'))


def item_gauntlet(c, X, Y, x, y, s):
    c.ellipse(X(x), Y(y), 2.6 * s, 2.4 * s, hexc('7a7e8e'))
    for k in range(3):
        c.line(X(x + 1.5), Y(y - 1.5 + k * 1.5), X(x + 4.5), Y(y - 2.5 + k * 2), hexc('e8ecf4'), w=2)


def outfit_ember(c, p, X, Y, bx, by, hx, hy, s):
    rock, rockd, glow = hexc('4a3a36'), hexc('2a201e'), hexc('ff7a2a')
    c.ellipse(X(16 + bx + p.get('lean', 0) * 0.5), Y(19.5 + by), 5.0 * s, 5.6 * s, rock)
    for (a, b, d, e) in [(13, 16, 15, 20), (18, 15, 17, 22), (14, 22, 18, 24)]:
        c.line(X(a + bx), Y(b + by), X(d + bx), Y(e + by), glow, w=2)
    c.rect(X(hx - 4.6), Y(hy - 4.6), 9.4 * s, 3 * s, rockd)
    for k in range(4):
        c.poly([(X(hx - 4 + k * 2.4), Y(hy - 4.4)), (X(hx - 3 + k * 2.4), Y(hy - 7.5 - (k % 2))), (X(hx - 2 + k * 2.4), Y(hy - 4.4))],
               glow)


def item_hammer(c, X, Y, x, y, s):
    c.line(X(x - 2), Y(y + 6), X(x + 3), Y(y - 6), hexc('5a3a2a'), w=2)
    c.rect(X(x + 0.5), Y(y - 10), 6 * s, 5 * s, hexc('3a2a26'))
    c.rect(X(x + 1), Y(y - 9), 5 * s, 1 * s, hexc('ff7a2a'))


def outfit_frost(c, p, X, Y, bx, by, hx, hy, s):
    robe, robel = hexc('3a6aa8'), hexc('a8dcff')
    c.poly([(X(11.5 + bx), Y(15 + by)), (X(20.5 + bx), Y(15 + by)), (X(23 + bx), Y(29)), (X(9 + bx), Y(29))], robe)
    c.rect(X(9.5 + bx), Y(27), 13 * s, 1 * s, robel)
    c.line(X(16 + bx), Y(15 + by), X(16 + bx), Y(29), robel)
    for k in range(5):
        x0 = hx - 4 + k * 2
        c.poly([(X(x0), Y(hy - 3)), (X(x0 + 1), Y(hy - 7.5 - (k % 2) * 2)), (X(x0 + 2), Y(hy - 3))], robel)


def item_ice_staff(c, X, Y, x, y, s):
    c.line(X(x), Y(y + 7), X(x + 1), Y(y - 9), hexc('c8e8ff'), w=2)
    c.poly([(X(x - 2), Y(y - 9)), (X(x + 1), Y(y - 15)), (X(x + 4), Y(y - 9)), (X(x + 1), Y(y - 7))], hexc('a8dcff'))


def outfit_king(c, p, X, Y, bx, by, hx, hy, s):
    robe, robed, ermine, gold = hexc('6a2a8a'), hexc('3a1050'), hexc('f8f6ff'), hexc('f0c040')
    c.poly([(X(11 + bx), Y(15 + by)), (X(21 + bx), Y(15 + by)), (X(24 + bx), Y(29)), (X(8 + bx), Y(29))], robe)
    c.poly([(X(8 + bx), Y(29)), (X(11 + bx), Y(15 + by)), (X(12.5 + bx), Y(29))], robed)
    c.rect(X(11 + bx), Y(14.5 + by), 10 * s, 2 * s, ermine)
    for k in range(3):
        c.set(X(13 + bx + k * 2.5), Y(15.5 + by), hexc('201828'))
    c.rect(X(8.5 + bx), Y(27.5), 15.5 * s, 1.5 * s, ermine)
    c.line(X(16 + bx), Y(16 + by), X(16 + bx), Y(27), gold)
    # crown
    c.rect(X(hx - 4), Y(hy - 5), 8 * s, 2 * s, gold)
    for k in range(4):
        c.poly([(X(hx - 4 + k * 2.4), Y(hy - 4.5)), (X(hx - 3 + k * 2.4), Y(hy - 8.5)), (X(hx - 2 + k * 2.4), Y(hy - 4.5))],
               gold)
    c.set(X(hx - 1), Y(hy - 4), hexc('e8344c'))
    # cape behind
    if p.get('cast'):
        c.poly([(X(10 + bx), Y(15 + by)), (X(4 + bx), Y(27)), (X(9 + bx), Y(27))], robed)


def item_scepter(c, X, Y, x, y, s):
    c.line(X(x), Y(y + 6), X(x + 1), Y(y - 10), hexc('f0c040'), w=2)
    c.circle(X(x + 1), Y(y - 12), 2.4 * s / 1.9 * 1.6, hexc('e8e0ff'))
    c.circle(X(x + 1), Y(y - 12), 1.0 * s / 1.9 * 1.6, hexc('ffffff'))


SHADOW = {'fur': hexc('2a1e3a'), 'hi': hexc('5a4a7a'), 'eye': hexc('ffffff'), 'pupil': hexc('c03ae0'),
          'nose': hexc('8a6aa8'), 'inner_ear': hexc('6a4a8a')}


def stalker_draw(p):
    c = Canvas(64, 64)
    q = {'sx': 1.2}
    if p.get('windup'):
        q.update({'bx': -2, 'by': -1, 'hy': -1, 'legs': [(-1, 0), (0, 0), (2, 3), (3, 4)], 'mouth': True})
    elif p.get('attack'):
        q.update({'bx': 2, 'sx': 1.4, 'sy': 0.85, 'legs': [(-5, 2), (-4, 2), (6, 4), (7, 4)], 'ears_back': 1.5,
                  'mouth': True})
    elif p.get('cast'):
        q.update({'by': -1.5, 'hy': -1.5, 'tail': -0.8})
    else:
        q.update({k: v for k, v in p.items() if k in ('by', 'bx', 'eye', 'hy')})
        if 'legs' in p:
            l = p['legs']
            q['legs'] = [l[0], l[1], l[1], l[0]]
    if p.get('eye'):
        q['eye'] = p['eye']
    G.draw_cat(c, q, SHADOW, ox=16, oy=32 - 8, s=1.8, scarf=False)
    # white mask across face
    for x in range(64):
        for y in range(64):
            if c.get(x, y) == SHADOW['fur'] and 40 < x < 60 and 10 < y < 40 and (x + y) % 7 == 0:
                c.set(x, y, hexc('d8d0ec'))
    c.outline(hexc('c8a0ff'))
    return c


def bosses():
    boss_sheet('boss_mouser', big_biped(outfit_iron, item_gauntlet, s=1.9, eye='ffb030'))
    boss_sheet('boss_ember', big_biped(outfit_ember, item_hammer, s=1.95, eye='ffd040', fur=('5a4642', '3a2a28')))
    boss_sheet('boss_frost', big_biped(outfit_frost, item_ice_staff, s=1.85, eye='60e0ff', fur=('f4f8ff', 'b8cce0')))
    boss_sheet('boss_stalker', stalker_draw)
    boss_sheet('boss_king', big_biped(outfit_king, item_scepter, s=2.2, fw=64, fh=80, eye='e8344c'), fw=64, fh=80)


# ---------------------------------------------------------------------------
# UI icons + font
# ---------------------------------------------------------------------------

def icons():
    fr = []
    red, redd, redl = hexc('e8344c'), hexc('8a1a2a'), hexc('ffb0b8')
    for k in range(3):  # heart full / half / empty
        c = Canvas(16, 16)
        pts = [(8, 14), (1, 7), (1, 4), (3, 2), (6, 2), (8, 4), (10, 2), (13, 2), (15, 4), (15, 7)]
        c.poly(pts, hexc('2a1a24'))
        if k == 0:
            c.poly(pts, red)
            c.set(4, 4, redl); c.set(5, 4, redl); c.set(4, 5, redl)
        elif k == 1:
            c.poly([(8, 14), (1, 7), (1, 4), (3, 2), (6, 2), (8, 4)], red)
            c.set(4, 4, redl)
        c.outline(hexc('0a0610'))
        fr.append(c)
    # coin, gem, cat face, chest, skull, shield, clock, star, lock, check, relic, paw, heart+, sword
    c = Canvas(16, 16); c.ellipse(8, 8, 5.5, 5.5, hexc('a87818')); c.ellipse(8, 8, 4.5, 4.5, hexc('f0c040'))
    c.rect(7, 5, 2, 6, hexc('a87818')); c.set(6, 5, hexc('fff0a0')); fr.append(c)
    c = Canvas(16, 16); c.poly([(8, 1), (14, 7), (8, 15), (2, 7)], hexc('4a1a90')); c.poly([(8, 3), (12, 7), (8, 13), (4, 7)], hexc('9a4aff'))
    c.set(7, 5, hexc('e0b0ff')); fr.append(c)
    c = Canvas(16, 16); c.ellipse(8, 9, 6, 5, hexc('1d1929')); c.poly([(2, 7), (3, 1), (7, 5)], hexc('1d1929'))
    c.poly([(9, 5), (13, 1), (14, 7)], hexc('1d1929')); c.rect(5, 8, 2, 2, hexc('c6ff4a')); c.rect(10, 8, 2, 2, hexc('c6ff4a'))
    c.set(8, 11, hexc('e07a9a')); c.outline(hexc('8c80c4')); fr.append(c)
    c = Canvas(16, 16); c.rect(2, 5, 12, 9, hexc('8a5a2a')); c.rect(2, 5, 12, 2, hexc('a87040')); c.rect(2, 8, 12, 1, hexc('d8b040'))
    c.rect(7, 7, 2, 3, hexc('d8b040')); c.outline(hexc('1a1008')); fr.append(c)
    c = Canvas(16, 16); c.ellipse(8, 7, 5, 5, hexc('e8e4d8')); c.rect(5, 10, 6, 4, hexc('e8e4d8'))
    c.rect(5, 6, 2, 2, hexc('201818')); c.rect(9, 6, 2, 2, hexc('201818')); c.outline(hexc('3a3030')); fr.append(c)
    c = Canvas(16, 16); c.poly([(2, 2), (14, 2), (14, 8), (8, 15), (2, 8)], hexc('5a8ad8')); c.poly([(4, 4), (12, 4), (12, 8), (8, 12), (4, 8)], hexc('9ac4ff'))
    c.outline(hexc('1a2a4a')); fr.append(c)
    c = Canvas(16, 16); c.circle(8, 8, 6, hexc('e8e4f0')); c.circle(8, 8, 5, hexc('3a3450')); c.line(8, 8, 8, 4, hexc('ffffff'))
    c.line(8, 8, 11, 9, hexc('ffffff')); fr.append(c)
    c = Canvas(16, 16)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 7 if i % 2 == 0 else 3
        pts.append((8 + math.cos(a) * r, 8.5 + math.sin(a) * r))
    c.poly(pts, hexc('ffd040')); c.outline(hexc('8a5a10')); fr.append(c)
    c = Canvas(16, 16); c.rect(3, 7, 10, 8, hexc('c8a040')); c.rect(5, 2, 6, 6, hexc('6a6e80')); c.rect(7, 4, 2, 4, (0, 0, 0, 0))
    c.rect(7, 10, 2, 3, hexc('3a2a10')); fr.append(c)
    c = Canvas(16, 16); c.line(2, 8, 6, 12, hexc('5aff7a'), 2); c.line(6, 12, 14, 3, hexc('5aff7a'), 2); fr.append(c)
    c = Canvas(16, 16); c.circle(8, 8, 6, hexc('6a3a10')); c.circle(8, 8, 5, hexc('ffe080')); c.ellipse(8, 10, 2.5, 2, hexc('6a3a10'))
    for (x, y) in [(5, 6), (7, 5), (9, 5), (11, 6)]:
        c.set(x, y, hexc('6a3a10'))
    fr.append(c)
    c = Canvas(16, 16); c.ellipse(8, 10, 4, 3.5, hexc('c6ff4a'))
    for (x, y) in [(3, 6), (6, 3), (10, 3), (13, 6)]:
        c.ellipse(x, y, 1.6, 1.8, hexc('c6ff4a'))
    fr.append(c)
    c = Canvas(16, 16); c.line(3, 13, 12, 4, hexc('e8ecf4'), 2); c.line(2, 10, 6, 14, hexc('c8a040'), 2); fr.append(c)
    c = Canvas(16, 16); c.line(2, 12, 13, 12, hexc('8ad8ff'), 2); c.poly([(10, 8), (15, 12), (10, 16)], hexc('8ad8ff'))
    c.line(3, 6, 9, 6, hexc('8ad8ff')); fr.append(c)  # speed
    strip(fr, 'icons.png')


# 5x7 pixel font, cells 6x10 (glyph rows 0-6 cap height, 7-8 descender)
FONT = {
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
    'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
    'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
    'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01111'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'I': ['01110', '00100', '00100', '00100', '00100', '00100', '01110'],
    'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
    'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
    'N': ['10001', '10001', '11001', '10101', '10011', '10001', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
    'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
    'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
    'W': ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
    'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
    'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
    'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
    'a': ['00000', '00000', '01110', '00001', '01111', '10001', '01111'],
    'b': ['10000', '10000', '10110', '11001', '10001', '10001', '11110'],
    'c': ['00000', '00000', '01110', '10000', '10000', '10001', '01110'],
    'd': ['00001', '00001', '01101', '10011', '10001', '10001', '01111'],
    'e': ['00000', '00000', '01110', '10001', '11111', '10000', '01110'],
    'f': ['00110', '01001', '01000', '11100', '01000', '01000', '01000'],
    'g': ['00000', '00000', '01111', '10001', '10001', '01111', '00001', '01110'],
    'h': ['10000', '10000', '10110', '11001', '10001', '10001', '10001'],
    'i': ['00100', '00000', '01100', '00100', '00100', '00100', '01110'],
    'j': ['00010', '00000', '00110', '00010', '00010', '00010', '10010', '01100'],
    'k': ['10000', '10000', '10010', '10100', '11000', '10100', '10010'],
    'l': ['01100', '00100', '00100', '00100', '00100', '00100', '01110'],
    'm': ['00000', '00000', '11010', '10101', '10101', '10101', '10001'],
    'n': ['00000', '00000', '10110', '11001', '10001', '10001', '10001'],
    'o': ['00000', '00000', '01110', '10001', '10001', '10001', '01110'],
    'p': ['00000', '00000', '11110', '10001', '10001', '11110', '10000', '10000'],
    'q': ['00000', '00000', '01111', '10001', '10001', '01111', '00001', '00001'],
    'r': ['00000', '00000', '10110', '11001', '10000', '10000', '10000'],
    's': ['00000', '00000', '01111', '10000', '01110', '00001', '11110'],
    't': ['01000', '01000', '11100', '01000', '01000', '01001', '00110'],
    'u': ['00000', '00000', '10001', '10001', '10001', '10011', '01101'],
    'v': ['00000', '00000', '10001', '10001', '10001', '01010', '00100'],
    'w': ['00000', '00000', '10001', '10001', '10101', '10101', '01010'],
    'x': ['00000', '00000', '10001', '01010', '00100', '01010', '10001'],
    'y': ['00000', '00000', '10001', '10001', '10001', '01111', '00001', '01110'],
    'z': ['00000', '00000', '11111', '00010', '00100', '01000', '11111'],
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    '.': ['00000', '00000', '00000', '00000', '00000', '01100', '01100'],
    ',': ['00000', '00000', '00000', '00000', '01100', '00100', '01000'],
    ':': ['00000', '01100', '01100', '00000', '01100', '01100', '00000'],
    ';': ['00000', '01100', '01100', '00000', '01100', '00100', '01000'],
    '!': ['00100', '00100', '00100', '00100', '00100', '00000', '00100'],
    '?': ['01110', '10001', '00001', '00010', '00100', '00000', '00100'],
    '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
    '+': ['00000', '00100', '00100', '11111', '00100', '00100', '00000'],
    '=': ['00000', '00000', '11111', '00000', '11111', '00000', '00000'],
    '/': ['00001', '00001', '00010', '00100', '01000', '10000', '10000'],
    '\\': ['10000', '10000', '01000', '00100', '00010', '00001', '00001'],
    '(': ['00010', '00100', '01000', '01000', '01000', '00100', '00010'],
    ')': ['01000', '00100', '00010', '00010', '00010', '00100', '01000'],
    '[': ['01110', '01000', '01000', '01000', '01000', '01000', '01110'],
    ']': ['01110', '00010', '00010', '00010', '00010', '00010', '01110'],
    "'": ['00100', '00100', '01000', '00000', '00000', '00000', '00000'],
    '"': ['01010', '01010', '01010', '00000', '00000', '00000', '00000'],
    '%': ['11000', '11001', '00010', '00100', '01000', '10011', '00011'],
    '#': ['01010', '01010', '11111', '01010', '11111', '01010', '01010'],
    '*': ['00000', '00100', '10101', '01110', '10101', '00100', '00000'],
    '<': ['00010', '00100', '01000', '10000', '01000', '00100', '00010'],
    '>': ['01000', '00100', '00010', '00001', '00010', '00100', '01000'],
    '_': ['00000', '00000', '00000', '00000', '00000', '00000', '11111'],
    '&': ['01100', '10010', '10100', '01000', '10101', '10010', '01101'],
    '@': ['01110', '10001', '10111', '10101', '10111', '10000', '01110'],
    '$': ['00100', '01111', '10100', '01110', '00101', '11110', '00100'],
    '|': ['00100', '00100', '00100', '00100', '00100', '00100', '00100'],
    '~': ['00000', '00000', '01000', '10101', '00010', '00000', '00000'],
    '^': ['00100', '01010', '10001', '00000', '00000', '00000', '00000'],
    '`': ['01000', '00100', '00000', '00000', '00000', '00000', '00000'],
    '{': ['00110', '00100', '00100', '01000', '00100', '00100', '00110'],
    '}': ['01100', '00100', '00100', '00010', '00100', '00100', '01100'],
}


def font():
    chars = [chr(i) for i in range(32, 127)]
    cw, ch = 6, 10
    img = Image.new('RGBA', (cw * len(chars), ch), (0, 0, 0, 0))
    px = img.load()
    for i, chh in enumerate(chars):
        g = FONT.get(chh)
        if g is None:
            continue
        for y, row in enumerate(g):
            for x, b in enumerate(row):
                if b == '1':
                    px[i * cw + x, y + 1] = (255, 255, 255, 255)
    img.save(os.path.join(OUT, '..', 'fonts', 'kocur_font.png'))
    with open(os.path.join(OUT, '..', 'fonts', 'kocur_font.txt'), 'w') as f:
        f.write(''.join(chars))


def logo():
    # Title art: big cat silhouette + moon, 160x64 (text drawn by the game font)
    c = Canvas(96, 64)
    c.circle(62, 26, 20, hexc('e8e4f8'))
    c.circle(68, 22, 17, (0, 0, 0, 0))
    p = {'by': 0, 'tail': 0.4}
    G.draw_cat(c, p, G.HERO, ox=24, oy=2, s=1.8)
    c.outline(G.HERO['rim'])
    save(c.img, 'title_cat.png')


def main():
    for n in REGIONS:
        tiles_for_region(n)
    backgrounds()
    objects()
    fx()
    bosses()
    icons()
    font()
    logo()
