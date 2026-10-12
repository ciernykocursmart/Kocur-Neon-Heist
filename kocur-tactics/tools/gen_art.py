"""Generates every sprite, tile and icon for Kocur Tactics (original pixel art).

Usage (from the kocur-tactics folder):  python3 tools/gen_art.py
Output: assets/sprites/*.png  (16x16 pixel art, drawn 3x in game)
Needs Pillow + NumPy.
"""
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
os.makedirs(OUT, exist_ok=True)


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3],)


def save(img, name):
    img.save(os.path.join(OUT, name + '.png'))


def from_ascii(rows, pal, size=16):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal and pal[ch] is not None:
                img.putpixel((x, y), pal[ch])
    return img


def overlay(base, rows, pal):
    img = base.copy()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal and pal[ch] is not None and x < img.width and y < img.height:
                img.putpixel((x, y), pal[ch])
    return img


# ---------------------------------------------------------------------------
# Cats
# ---------------------------------------------------------------------------

CAT = [
    "................",
    "...o......o.....",
    "..oBo....oBo....",
    "..oBPo..oPBo....",
    "..oBBBooBBBo....",
    "..oBBBBBBBBo....",
    ".oBBEBBBBEBBo...",
    ".oBBEBBBBEBBo...",
    ".oBBBBNNBBBBo...",
    "..oBBBBBBBBo....",
    "..oBBBBBBBBo..o.",
    ".oBBBBBBBBBBooBo",
    ".oBBBBBBBBBBoBo.",
    ".oBBLBBBBBBBBo..",
    ".oBBoBBBBoBBo...",
    "..oo.oooo.oo....",
]


def cat_base(fur, eye, outline='#0c0a12', inner='#e58fa8', light=None, nose='#e58fa8'):
    pal = {'o': hexc(outline), 'B': hexc(fur), 'P': hexc(inner), 'E': hexc(eye), 'N': hexc(nose),
           'L': hexc(light) if light else hexc(fur)}
    img = from_ascii(CAT, pal)
    # soft highlight on the head (top-left) for readability on dark fur
    if light:
        for (x, y) in [(4, 5), (5, 5), (4, 9), (3, 11), (3, 12)]:
            if img.getpixel((x, y))[3] > 0 and img.getpixel((x, y))[:3] == hexc(fur)[:3]:
                img.putpixel((x, y), hexc(light))
    return img


def frame2(img):
    """Idle frame: body squashes down one pixel (breathing)."""
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    top = img.crop((0, 0, 16, 14))
    out.paste(top, (0, 1))
    out.paste(img.crop((0, 14, 16, 16)), (0, 14))
    return out


def sheet(frames):
    img = Image.new('RGBA', (16 * len(frames), 16), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f, (16 * i, 0), f)
    return img


HERO_FUR = '#2a2436'
HERO_LIGHT = '#4b4262'
HERO_EYE = '#ffd54a'
ENEMY_FUR = '#f2f0ea'
ENEMY_LIGHT = '#ffffff'
ENEMY_EYE = '#d8304a'


def make_cat(name, fur, light, eye, acc_rows=None, acc_pal=None, outline='#0c0a12'):
    base = cat_base(fur, eye, outline=outline, light=light)
    if acc_rows:
        base = overlay(base, acc_rows, acc_pal)
    f2 = frame2(base)
    save(sheet([base, f2]), 'unit_' + name)
    return base


def accessories():
    o = hexc('#0c0a12')
    # ---- heroes ----
    make_cat('shadowblade', HERO_FUR, HERO_LIGHT, HERO_EYE, [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "..mmmmmmmmmm....",
        "................",
        "................",
        "SSoSSSSSSSSo....",
        "SS.oSSSSSSo.....",
        "S...............",
        "..............wo",
        "..............w.",
        ".............w..",
        "................",
    ], {'S': hexc('#8a3cc9'), 'm': hexc('#5a2a86'), 'w': hexc('#cfd6e6'), 'o': o})
    make_cat('guardian', HERO_FUR, HERO_LIGHT, HERO_EYE, [
        "................",
        "...o......o.....",
        "..oHo....oHo....",
        "..oHHooooHHo....",
        "..oHHHHHHHHo....",
        "..ohhhhhhhho....",
        "................",
        "................",
        "................",
        "oooo............",
        "oWGWo...........",
        "oWGWWo..........",
        "oGGGGo..........",
        "oWGWWo..........",
        "oWGWo...........",
        ".oo.............",
    ], {'H': hexc('#8d97a8'), 'h': hexc('#5d6577'), 'W': hexc('#8a5a32'), 'G': hexc('#e6b84a'), 'o': o})
    make_cat('ranger', HERO_FUR, HERO_LIGHT, HERO_EYE, [
        "..........o.....",
        "...o.....oGo....",
        "..oGo...oGGo..b.",
        "..oGGo.oGGGo..sb",
        "..oGGGGGGGGo..s.",
        "..oggggggggo..s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............sb",
        "..............b.",
        "................",
        "................",
        "................",
        "................",
    ], {'G': hexc('#3f9a4a'), 'g': hexc('#2c6e36'), 'b': hexc('#9a6234'), 's': hexc('#e8e2c8'), 'o': o})
    make_cat('mender', HERO_FUR, HERO_LIGHT, HERO_EYE, [
        ".L..............",
        "LlL.o......o....",
        ".L.oL.L..L.Lo...",
        ".t.....LlL......",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
        ".t..............",
    ], {'L': hexc('#6fd16a'), 'l': hexc('#ff8fb4'), 't': hexc('#9a6234'), 'o': o})
    make_cat('elder', '#3b3546', '#5e5670', '#ffd54a', [
        "................",
        "................",
        "................",
        "................",
        "................",
        "...www..www.....",
        "................",
        "................",
        "....wwwwww......",
        "...wwwwwwww.....",
        "....wwwwww......",
        ".....wwww.....c.",
        "..............c.",
        "..............c.",
        "..............c.",
        ".............cc.",
    ], {'w': hexc('#e8e8f0'), 'c': hexc('#8a5a32')})
    # ---- enemies (White Crown Legion) ----
    make_cat('recruit', ENEMY_FUR, ENEMY_LIGHT, ENEMY_EYE, [
        "..............t.",
        "...o......o..ttt",
        "..oHo....oHo..s.",
        "..oHHooooHHo..s.",
        "..ohhhhhhhho..s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..rrrrrrrr....s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "................",
        "................",
    ], {'H': hexc('#b9c2d0'), 'h': hexc('#7d8798'), 't': hexc('#dfe6f0'), 's': hexc('#8a5a32'),
        'r': hexc('#c8323e'), 'o': o})
    make_cat('guard', ENEMY_FUR, ENEMY_LIGHT, ENEMY_EYE, [
        "................",
        "...o......o.....",
        "..oHo....oHo....",
        "..oHHooooHHo....",
        "..oHHHHHHHHo....",
        "..ohhhhhhhho....",
        "................",
        "................",
        "oooooo..........",
        "oSSSSSo.........",
        "oSYYYSo.........",
        "oSYCYSo.........",
        "oSYYYSo.........",
        "oSSSSSo.........",
        ".oSSSo..........",
        "..ooo...........",
    ], {'H': hexc('#b9c2d0'), 'h': hexc('#7d8798'), 'S': hexc('#3a5fb0'), 'Y': hexc('#e6b84a'),
        'C': hexc('#f2f0ea'), 'o': o})
    make_cat('archer', ENEMY_FUR, ENEMY_LIGHT, ENEMY_EYE, [
        "..........o.....",
        "...o.....oRo....",
        "..oRo...oRRo..b.",
        "..oRRo.oRRRo..sb",
        "..oRRRRRRRRo..s.",
        "..orrrrrrrro..s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............sb",
        "..............b.",
        "................",
        "................",
        "................",
        "................",
    ], {'R': hexc('#c8323e'), 'r': hexc('#8e2030'), 'b': hexc('#7a4a24'), 's': hexc('#dcdcdc'), 'o': o})
    make_cat('mage', ENEMY_FUR, ENEMY_LIGHT, '#5ab8ff', [
        "......o.......c.",
        ".....oMo.....ccc",
        "....oMMMo.....s.",
        "...oMMSMMo....s.",
        "..oMMMMMMMo...s.",
        ".ommmmmmmmmo..s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "..............s.",
        "................",
        "................",
    ], {'M': hexc('#7b5cc8'), 'm': hexc('#4f3a8a'), 'S': hexc('#ffe36a'), 'c': hexc('#7fd8ff'),
        's': hexc('#8a5a32'), 'o': o})
    make_cat('stalker', ENEMY_FUR, ENEMY_LIGHT, ENEMY_EYE, [
        "................",
        "...o......o.....",
        "..oKo....oKo....",
        "..oKKoooKKKo....",
        "..oKKKKKKKKo....",
        "..oKKKKKKKKo....",
        "..kkkkkkkkkk....",
        "................",
        "................",
        "................",
        "..............w.",
        "w.............wo",
        "w...............",
        "wo..............",
        "................",
        "................",
    ], {'K': hexc('#6a6a7a'), 'k': hexc('#3a3a48'), 'w': hexc('#e8eef8'), 'o': o})
    # ---- bosses ----
    make_cat('ironpaw', '#d8d8e0', '#ffffff', '#ff3a2a', [
        ".o............o.",
        "oho.o......o.oho",
        ".ohoIo....oIoho.",
        "..oIIIooooIIIo..",
        "..oIIIIIIIIIIo..",
        "..oiiiiiiiiiio..",
        "................",
        "................",
        "...IIIIIIIII....",
        "..IiIIIIIIIiI...",
        "..IIIIIIIIIII...",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], {'I': hexc('#5e6472'), 'i': hexc('#3a3e4a'), 'h': hexc('#c8c8c8'), 'o': o}, outline='#0c0a12')
    make_cat('king', '#f8f6ff', '#ffffff', '#b45aff', [
        "..o.o.oo.o.o....",
        "..oYoYooYoYo....",
        "..oYYYYYYYYo....",
        "..oYRYYBYYRo....",
        "................",
        "................",
        "................",
        "................",
        "................",
        "CCoCCCCCCCCoCC..",
        "CC.CCCCCCCC.CC..",
        "CC..........CC..",
        "CC..........CC..",
        "CC..........CC..",
        "CC..........CC..",
        ".C..........C...",
    ], {'Y': hexc('#f2c230'), 'R': hexc('#e0304a'), 'B': hexc('#3a8ae0'), 'C': hexc('#6a2aa0'), 'o': o})


def objects():
    o = hexc('#0c0a12')
    pylon = from_ascii([
        "................",
        ".......o........",
        "......oCo.......",
        ".....oCcCo......",
        ".....oCcCo......",
        "....oCCcCCo.....",
        "....oCcCcCo.....",
        "....oCCcCCo.....",
        ".....oCcCo......",
        ".....oCCCo......",
        "......oCo.......",
        "....ooSSSoo.....",
        "...oSSSSSSSo....",
        "...osssssssо....".replace('о', 'o'),
        "....ooooooo.....",
        "................",
    ], {'C': hexc('#c79bff'), 'c': hexc('#f4e6ff'), 'S': hexc('#9aa0b4'), 's': hexc('#646a80'), 'o': o})
    save(sheet([pylon, frame2(pylon)]), 'unit_pylon')
    well = from_ascii([
        "................",
        "................",
        "....oooooooo....",
        "...oSSSSSSSSo...",
        "..oSwwwwwwwwSo..",
        "..oSwWWwwWWwSo..",
        "..oSwwwWWwwwSo..",
        "..oSwwwwwwwwSo..",
        "...oSSSSSSSSo...",
        "...osSsSsSsSo...",
        "...oSsSsSsSso...",
        "...osSsSsSsSo...",
        "....oooooooo....",
        "................",
        "................",
        "................",
    ], {'S': hexc('#a8b0c4'), 's': hexc('#6c7488'), 'w': hexc('#4aa8ff'), 'W': hexc('#d8f4ff'), 'o': o})
    save(sheet([well, frame2(well)]), 'unit_moonwell')


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

REGIONS = {
    'wood': {'grass': '#4f8f3a', 'grass2': '#5ea444', 'grass_dark': '#3f7530', 'road': '#a57c4f',
             'road_dark': '#8a6440', 'tree': '#2d6a2c', 'tree_light': '#4a9640', 'trunk': '#6a4426',
             'rock': '#7a7a86', 'rock_light': '#a0a0ac', 'rock_dark': '#55555f', 'water': '#3a78c8',
             'water_light': '#6aa8f0', 'mud': '#6e5236', 'mud_light': '#86663f', 'hazard': '#8a2a6a',
             'hazard_light': '#d65aa8', 'flower': '#ffd6e8', 'hill': '#6fae4a', 'hill_dark': '#4a7a32'},
    'border': {'grass': '#8a9a46', 'grass2': '#9aaa52', 'grass_dark': '#6e7c38', 'road': '#b08a5a',
               'road_dark': '#8e6c44', 'tree': '#a0602a', 'tree_light': '#d08a3a', 'trunk': '#5a3a22',
               'rock': '#8a6e5a', 'rock_light': '#b09078', 'rock_dark': '#5e4a3c', 'water': '#3a6aa8',
               'water_light': '#6a9ad8', 'mud': '#5e4630', 'mud_light': '#7a5a3a', 'hazard': '#7a7a80',
               'hazard_light': '#d0d0d8', 'flower': '#f0e08a', 'hill': '#a8b05a', 'hill_dark': '#76803e'},
    'crown': {'grass': '#b8b4c8', 'grass2': '#c4c0d4', 'grass_dark': '#9a96ac', 'road': '#d8d0b8',
              'road_dark': '#b4ac94', 'tree': '#6a8aa0', 'tree_light': '#a8c8dc', 'trunk': '#5a5060',
              'rock': '#e6e4ee', 'rock_light': '#ffffff', 'rock_dark': '#a6a2b8', 'water': '#8ac8e8',
              'water_light': '#d8f0ff', 'mud': '#e8eef6', 'mud_light': '#ffffff', 'hazard': '#c84a1a',
              'hazard_light': '#ffb030', 'flower': '#c8a0ff', 'hill': '#ccc8dc', 'hill_dark': '#9a96ac'},
}


def noise_tile(base, alt, dark, seed, density=0.18):
    rnd = random.Random(seed)
    img = Image.new('RGBA', (16, 16), hexc(base))
    for y in range(16):
        for x in range(16):
            r = rnd.random()
            if r < density * 0.5:
                img.putpixel((x, y), hexc(dark))
            elif r < density:
                img.putpixel((x, y), hexc(alt))
    return img


def grass(p, seed, flowers=False):
    img = noise_tile(p['grass'], p['grass2'], p['grass_dark'], seed)
    rnd = random.Random(seed + 99)
    for _ in range(3):
        x, y = rnd.randrange(1, 15), rnd.randrange(2, 15)
        img.putpixel((x, y), hexc(p['grass_dark']))
        img.putpixel((x, y - 1), hexc(p['grass2']))
    if flowers:
        for _ in range(2):
            x, y = rnd.randrange(2, 14), rnd.randrange(2, 14)
            img.putpixel((x, y), hexc(p['flower']))
    return img


def crown_floor(p, seed):
    img = noise_tile(p['grass'], p['grass2'], p['grass_dark'], seed, 0.08)
    for i in range(16):
        img.putpixel((i, 15), hexc(p['grass_dark']))
        img.putpixel((15, i), hexc(p['grass_dark']))
        img.putpixel((i, 7), hexc(p['grass_dark']))
    for y in range(8, 15):
        img.putpixel((7, y), hexc(p['grass_dark']))
    for y in range(0, 7):
        img.putpixel((11, y), hexc(p['grass_dark']))
    return img


def base_floor(region, p, seed, flowers=False):
    if region == 'crown':
        return crown_floor(p, seed)
    return grass(p, seed, flowers)


def tree(img, p):
    o = hexc('#0c0a12')
    canopy = [
        "................",
        ".....oooooo.....",
        "...ooLLLLLLoo...",
        "..oLLLTTTTLLLo..",
        "..oLTTTTTTTTLo..",
        ".oLTTTTTTTTTTLo.",
        ".oTTTTTTTTTTTTo.",
        ".oTTTTTTTTTTTTo.",
        "..oTTTTTTTTTTo..",
        "...ooTTTTTToo...",
        ".....oowwoo.....",
        "......owwo......",
        "......owwo......",
        ".....ooooo......",
        "................",
        "................",
    ]
    return overlay(img, canopy, {'o': o, 'L': hexc(p['tree_light']), 'T': hexc(p['tree']), 'w': hexc(p['trunk'])})


def rock(p, region, seed):
    o = hexc('#0c0a12')
    if region == 'border':
        img = Image.new('RGBA', (16, 16), hexc(p['rock']))
        for y in range(16):
            for x in range(16):
                if y % 4 == 3 or (x + (8 if (y // 4) % 2 else 0)) % 8 == 7:
                    img.putpixel((x, y), hexc(p['rock_dark']))
                elif y % 4 == 0:
                    img.putpixel((x, y), hexc(p['rock_light']))
        return img
    if region == 'crown':
        img = Image.new('RGBA', (16, 16), hexc(p['rock']))
        for y in range(16):
            for x in range(16):
                if y in (7, 15) or (x == 7 and y < 7) or (x == 15 and y >= 8):
                    img.putpixel((x, y), hexc(p['rock_dark']))
                elif y in (0, 8):
                    img.putpixel((x, y), hexc(p['rock_light']))
        return img
    img = base_floor(region, p, seed)
    shape = [
        "................",
        "....oooooo......",
        "...oLLLLRRoo....",
        "..oLLRRRRRRRo...",
        "..oLRRRRRRRRRo..",
        ".oLRRRRRRRRRRo..",
        ".oRRRRRRRRRRRDo.",
        ".oRRRRRRRRRRDDo.",
        "oLRRRRRRRRRRRDo.",
        "oRRRRRRRRRRDDDo.",
        "oRRRRRRRRRRRDDDo",
        "oRRRRRRRRRDDDDDo",
        ".oRRRRRRRDDDDDo.",
        "..ooDDDDDDDDoo..",
        "....oooooooo....",
        "................",
    ]
    return overlay(img, shape, {'o': o, 'L': hexc(p['rock_light']), 'R': hexc(p['rock']), 'D': hexc(p['rock_dark'])})


def pillar(p, region, seed):
    o = hexc('#0c0a12')
    img = base_floor(region, p, seed)
    shape = [
        "...oooooooooo...",
        "...oLLLLLLLLo...",
        "...oDDDDDDDDo...",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "....oLRRRRDo....",
        "...oLLLLLLLLo...",
        "...oDDDDDDDDo...",
        "...oooooooooo...",
        "................",
    ]
    if region == 'wood':
        p2 = {'rock_light': '#b48a5a', 'rock': '#8a6440', 'rock_dark': '#5e4228'}
    else:
        p2 = p
    return overlay(img, shape, {'o': o, 'L': hexc(p2['rock_light']), 'R': hexc(p2['rock']), 'D': hexc(p2['rock_dark'])})


def water(p, region, phase):
    img = Image.new('RGBA', (16, 16), hexc(p['water']))
    if region == 'crown':
        rnd = random.Random(5)
        for _ in range(3):
            x, y = rnd.randrange(16), rnd.randrange(16)
            for k in range(4):
                if 0 <= x + k < 16 and 0 <= y + (k % 2) < 16:
                    img.putpixel((x + k, y + (k % 2)), hexc(p['water_light']))
        return img
    for y in (3, 9, 14):
        for x in range(16):
            if (x + phase * 3 + y) % 8 < 3:
                img.putpixel((x, y), hexc(p['water_light']))
    return img


def bridge(p, region):
    img = water(p, region, 0)
    plank = hexc('#9a6a3a')
    dark = hexc('#6a4424')
    for y in range(16):
        for x in range(1, 15):
            img.putpixel((x, y), dark if (y % 4 == 3 or x in (1, 14)) else plank)
    return img


def hill(p, region, seed):
    img = base_floor(region, p, seed)
    o = hexc(p['hill_dark'])
    L = hexc(p['hill'])
    shape = [
        "................",
        "................",
        "................",
        "......oooo......",
        "....ooLLLLoo....",
        "...oLLLLLLLLo...",
        "..oLLLLLLLLLLo..",
        "..oLLLLLLLLLLo..",
        ".oLLLLLLLLLLLLo.",
        ".oLLLLLLLLLLLLo.",
        "oLLLLLLLLLLLLLLo",
        "oLLLLLLLLLLLLLLo",
        "oooooooooooooooo",
        "................",
        "................",
        "................",
    ]
    img = overlay(img, shape, {'o': o, 'L': L})
    # contour marks so the hill reads without colour
    for (x, y) in [(6, 6), (7, 5), (8, 5), (9, 6), (4, 9), (5, 8), (10, 8), (11, 9)]:
        img.putpixel((x, y), hexc(p['hill_dark']))
    return img


def mud(p, region, seed):
    img = base_floor(region, p, seed)
    rnd = random.Random(seed)
    for _ in range(5):
        cx, cy = rnd.randrange(2, 14), rnd.randrange(2, 14)
        for y in range(cy - 2, cy + 2):
            for x in range(cx - 3, cx + 3):
                if 0 <= x < 16 and 0 <= y < 16 and rnd.random() < 0.8:
                    img.putpixel((x, y), hexc(p['mud'] if rnd.random() < 0.75 else p['mud_light']))
    return img


def hazard(p, region, seed):
    img = base_floor(region, p, seed)
    o = hexc('#0c0a12')
    H = hexc(p['hazard'])
    L = hexc(p['hazard_light'])
    spike = ["..L..", ".LHL.", ".HHH.", "oHHHo"]
    for (bx, by) in [(1, 1), (9, 2), (4, 8), (11, 10), (0, 11)]:
        for y, row in enumerate(spike):
            for x, ch in enumerate(row):
                px, py = bx + x, by + y
                if ch != '.' and 0 <= px < 16 and 0 <= py < 16:
                    img.putpixel((px, py), {'L': L, 'H': H, 'o': o}[ch])
    return img


def cage(p, region, seed):
    img = base_floor(region, p, seed)
    kitten = cat_base(HERO_FUR, HERO_EYE, light=HERO_LIGHT).resize((10, 10), Image.NEAREST)
    img.paste(kitten, (3, 4), kitten)
    bar = hexc('#4a4a56')
    hi = hexc('#9a9aa8')
    for x in (1, 4, 7, 10, 13):
        for y in range(2, 15):
            img.putpixel((x, y), bar)
            if x + 1 < 16 and y % 3 == 0:
                img.putpixel((x + 1, y), hi)
    for x in range(1, 15):
        img.putpixel((x, 1), bar)
        img.putpixel((x, 2), hi)
        img.putpixel((x, 14), bar)
    return img


def tiles():
    for region, p in REGIONS.items():
        save(base_floor(region, p, 1), f'tile_{region}_grass')
        save(base_floor(region, p, 2, flowers=True), f'tile_{region}_grass2')
        road = noise_tile(p['road'], p['road_dark'], p['road_dark'], 3, 0.12)
        save(road, f'tile_{region}_road')
        save(tree(base_floor(region, p, 4), p), f'tile_{region}_forest')
        save(rock(p, region, 5), f'tile_{region}_wall')
        save(pillar(p, region, 6), f'tile_{region}_pillar')
        save(water(p, region, 0), f'tile_{region}_water')
        save(bridge(p, region), f'tile_{region}_bridge')
        save(hill(p, region, 7), f'tile_{region}_hill')
        save(mud(p, region, 8), f'tile_{region}_mud')
        save(hazard(p, region, 9), f'tile_{region}_hazard')
        save(cage(p, region, 10), f'tile_{region}_cage')


# ---------------------------------------------------------------------------
# Markers and icons
# ---------------------------------------------------------------------------

def markers():
    o = hexc('#0c0a12')
    save(from_ascii([
        "................",
        "...oooooooooo...",
        "..oGGGGGGGGGGo..",
        "..oGgggggggGGo..",
        "..oGg......gGo..",
        "..oGg..oo..gGo..",
        "..oGg.oWWo.gGo..",
        "..oGgoWWWWogGo..",
        "..oGg..WW..gGo..",
        "..oGg..WW..gGo..",
        "..oGg..WW..gGo..",
        "..oGg......gGo..",
        "..oGggggggggGo..",
        "..oGGGGGGGGGGo..",
        "...oooooooooo...",
        "................",
    ], {'o': o, 'G': hexc('#3ad07a'), 'g': hexc('#1f8a4a'), 'W': hexc('#e8fff0')}), 'mark_exit')
    save(from_ascii([
        "................",
        ".......oo.......",
        "......oYYo......",
        ".....oYyyYo.....",
        "....oYy..yYo....",
        "...oYy....yYo...",
        "..oYy..oo..yYo..",
        ".oYy..oWWo..yYo.",
        ".oYy..oWWo..yYo.",
        "..oYy..oo..yYo..",
        "...oYy....yYo...",
        "....oYy..yYo....",
        ".....oYyyYo.....",
        "......oYYo......",
        ".......oo.......",
        "................",
    ], {'o': o, 'Y': hexc('#f2c230'), 'y': hexc('#a8801a'), 'W': hexc('#fff6c8')}), 'mark_defend')
    altar = [
        "................",
        "......oooo......",
        ".....oGggGo.....",
        "....oGgWWgGo....",
        "....oGgWWgGo....",
        ".....oGggGo.....",
        "......oooo......",
        "................",
        "...oooooooooo...",
        "...oSSSSSSSSo...",
        "....osssssso....",
        "....oSSSSSSo....",
        "....osssssso....",
        "...oSSSSSSSSo...",
        "...oooooooooo...",
        "................",
    ]
    pal = {'o': o, 'G': hexc('#ff5ad8'), 'g': hexc('#b02a98'), 'W': hexc('#ffe0f8'), 'S': hexc('#c8c4d8'), 's': hexc('#8a86a0')}
    save(from_ascii(altar, pal), 'mark_relic')
    empty = altar[:]
    for i in range(1, 7):
        empty[i] = "................"
    save(from_ascii(empty, pal), 'mark_relic_taken')
    save(from_ascii([
        "................",
        "................",
        "................",
        "................",
        "..oooooooooooo..",
        "..oWWWWWWWWWWo..",
        "..oWwwwwwwwwWo..",
        "..oWw.FFF..wWo..",
        "..oWwFFFFF.wWo..",
        "..oWw.FFF..wWo..",
        "..oWwwwwwwwwWo..",
        "..oWWWWWWWWWWo..",
        "..oooooooooooo..",
        "................",
        "................",
        "................",
    ], {'o': o, 'W': hexc('#a8703a'), 'w': hexc('#7a4a22'), 'F': hexc('#7ad0ff')}), 'mark_treasure')
    save(from_ascii([
        "................",
        "...o.......o....",
        "..oRo.....oRo...",
        "..oRRo...oRRo...",
        "...oRRo.oRRo....",
        "....oRRoRRo.....",
        ".....oRRRo......",
        "......oRo.......",
        ".....oRRRo......",
        "....oRRoRRo.....",
        "...oRRo.oRRo....",
        "..oRRo...oRRo...",
        "..oRo.....oRo...",
        "...o.......o....",
        "................",
        "................",
    ], {'o': o, 'R': hexc('#ff6a3a')}), 'mark_incoming')


ICONS = {
    'claw': ["................", "..o...o...o.....", ".oWo.oWo.oWo....", ".oWo.oWo.oWo....", "..oWo.oWo.oWo...",
             "..oWo.oWo.oWo...", "...oWo.oWo.oWo..", "...oWo.oWo.oWo..", "....oWo.oWo.oWo.", "....oWo.oWo.oWo.",
             ".....o...o...o..", "................", "................", "................", "................", "................"],
    'pounce': ["................", "..........oo....", ".........oPPo...", "........oPPo....", ".......oPPo.....",
               "......oPPo......", ".....oPPo.......", "..oooPPo........", "..oPPPPo........", "..oPPPPPo.......",
               "..oooooo........", "................", "..o.o.o.........", "................", "................", "................"],
    'strike': ["................", "............oo..", "...........oWo..", "..........oWo...", ".........oWo....",
               "........oWo.....", ".......oWo......", "......oWo.......", "...o.oWo........", "....oBo.........",
               "...oBoBo........", "..oBo.oo........", "..oo............", "................", "................", "................"],
    'heavy': ["................", "....oooooo......", "...oGGGGGGo.....", "...oGGGGGGo.....", "...oGGGGGGo.....",
              "....oooBoo......", "......oBo.......", "......oBo.......", "......oBo.......", "......oBo.......",
              "......oBo.......", "......oBo.......", "......ooo.......", "................", "................", "................"],
    'stance': ["................", "...oooooooo.....", "..oYSSSSSSYo....", "..oSSSYYSSSo....", "..oSSSYYSSSo....",
               "..oSYYYYYYSo....", "..oSSSYYSSSo....", "...oSSYYSSo.....", "....oSSSSo......", ".....oSSo.......",
               "......oo........", "................", "................", "................", "................", "................"],
    'shot': ["................", "................", "...........oo...", "..........oWWo..", ".........oWWo...",
             "........oBo.....", ".......oBo......", "......oBo.......", ".....oBo........", "...ooBo.........",
             "..oFFo..........", "..oFo...........", "...o............", "................", "................", "................"],
    'volley': ["................", "..o....o....o...", ".oWo..oWo..oWo..", "..B....B....B...", "..B....B....B...",
               "..B....B....B...", "..B....B....B...", ".oFo..oFo..oFo..", "................", ".oooooooooooo...",
               ".oRRRRRRRRRRo...", ".oooooooooooo...", "................", "................", "................", "................"],
    'swipe': ["................", "................", "....ooooo.......", "...oWWWWWo......", "..oW.....Wo.....",
              "..o.......o.....", "........oWo.....", ".......oWo......", "......oWo.......", "................",
              "................", "................", "................", "................", "................", "................"],
    'mend': ["................", "...oo...oo......", "..oHHo.oHHo.....", ".oHHHHoHHHHo....", ".oHHHHHHHHHo....",
             ".oHHHWWWHHHo....", "..oHHWWWHHo.....", "...oHWWWHo......", "....oHHHo.......", ".....oHo........",
             "......o.........", "................", "................", "................", "................", "................"],
    'wait': ["................", "...oooooooo.....", "...oSSSSSSo.....", "....oSSSSo......", ".....oSSo.......",
             "......oo........", ".....oSSo.......", "....oSSSSo......", "...oSSSSSSo.....", "...oooooooo.....",
             "................", "................", "................", "................", "................", "................"],
    'free': ["................", "....oooo........", "...oYYYYo.......", "...oYooYo.......", "...oYYYYo.......",
             "....oYYo........", ".....oYo........", ".....oYoo.......", ".....oYYo.......", ".....oYo........",
             ".....oYYo.......", "......oo........", "................", "................", "................", "................"],
    'claim': ["................", "......oo........", ".....oGGo.......", "....oGWGGo......", "...oGWGGGGo.....",
              "...oGGGGGGo.....", "....oGGGGo......", ".....oGGo.......", "......oo........", "................",
              "................", "................", "................", "................", "................", "................"],
    'escape': ["................", "..oooooooo......", "..oDDDDDDo......", "..oDDDDDDo......", "..oDDDDYDo......",
               "..oDDDDDDo......", "..oDDDDDDo......", "..oDDDDDDo......", "..oDDDDDDo......", "..oooooooo......",
               "................", "................", "................", "................", "................", "................"],
    'end': ["................", "......oo........", ".....oYYo.......", "....oYYYYo......", "...oYYYYYYo.....",
            "......YY........", "......YY........", "......YY........", "......YY........", "................",
            "................", "................", "................", "................", "................", "................"],
    'chilled': ["................", "......o.........", "...o..C..o......", "....o.C.o.......", ".....oCo........",
                ".CCCCCCCCC......", ".....oCo........", "....o.C.o.......", "...o..C..o......", "......o.........",
                "................", "................", "................", "................", "................", "................"],
    'exhausted': ["................", "....ooooo.......", "...oSSSSSo......", "..oSo...oSo.....", "..oSo.o..So.....",
                  "..oSo.oSoSo.....", "...oSoooSo......", "....oSSSo.......", "................", "................",
                  "................", "................", "................", "................", "................", "................"],
    'sleep': ["................", "..ZZZZ..........", "....Z...........", "...Z............", "..ZZZZ..ZZZ.....",
              ".........Z......", "........Z.......", ".......ZZZ......", "................", "................",
              "................", "................", "................", "................", "................", "................"],
    'warn': ["................", ".......oo.......", "......oYYo......", "......oYYo......", ".....oYooYo.....",
             ".....oYooYo.....", "....oYYooYYo....", "....oYYooYYo....", "...oYYYYYYYYo...", "...oYYYooYYYo...",
             "..oYYYYYYYYYYo..", "..oooooooooooo..", "................", "................", "................", "................"],
}


def icons():
    pal = {'o': hexc('#0c0a12'), 'W': hexc('#f0f0f8'), 'P': hexc('#b06aff'), 'B': hexc('#9a6234'),
           'G': hexc('#a8b0c0'), 'Y': hexc('#f2c230'), 'S': hexc('#8ab0e8'), 'F': hexc('#e8e8e8'),
           'R': hexc('#c8323e'), 'H': hexc('#ff6a8a'), 'D': hexc('#7a4a22'), 'C': hexc('#9ae0ff'),
           'Z': hexc('#d8d8ff')}
    for name, rows in ICONS.items():
        save(from_ascii(rows, pal), 'icon_' + name)


def fx():
    # arrow projectile (pointing right) and a frost bolt
    o = hexc('#0c0a12')
    save(from_ascii(["................"] * 7 + ["..FF.BBBBBBBWW.."] + ["................"] * 8,
                    {'F': hexc('#e8e8e8'), 'B': hexc('#9a6234'), 'W': hexc('#f0f0f8')}), 'fx_arrow')
    bolt = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if d < 3:
                bolt.putpixel((x, y), hexc('#e8faff'))
            elif d < 5:
                bolt.putpixel((x, y), hexc('#6ac8ff'))
            elif d < 6:
                bolt.putpixel((x, y), hexc('#3a78c8', 160))
    save(bolt, 'fx_bolt')
    spark = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for i in range(16):
        for (x, y) in [(i, 7), (7, i), (i, i), (i, 15 - i)]:
            d = abs(i - 7.5)
            if d < 7:
                spark.putpixel((x, y), hexc('#fff6c8', int(255 * (1 - d / 7.5))))
    save(spark, 'fx_spark')


if __name__ == '__main__':
    accessories()
    objects()
    tiles()
    markers()
    icons()
    fx()
    print('art generated in', os.path.normpath(OUT))
