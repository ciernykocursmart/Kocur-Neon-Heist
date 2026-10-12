"""Generates every sprite sheet used by Kocur Dungeon.

Usage (from the kocur-dungeon folder):  python3 tools/gen_art.py
Output: assets/sprites/*.png  (committed, so the game never needs Python).
All art is original and drawn procedurally by this script.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, mix, shade, sheet, grid_sheet, noise_rng  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
os.makedirs(OUT, exist_ok=True)

T = (0, 0, 0, 0)


def save(img, name):
    img.save(os.path.join(OUT, name))


# ---------------------------------------------------------------------------
# Quadruped cat (hero, captive cats, White Beast)
# ---------------------------------------------------------------------------

HERO = {
    'fur': hexc('1d1929'), 'hi': hexc('3a3454'), 'rim': hexc('8c80c4'),
    'eye': hexc('c6ff4a'), 'pupil': hexc('14301a'), 'nose': hexc('e07a9a'),
    'scarf': hexc('d8344a'), 'scarf_d': hexc('8e1c30'), 'inner_ear': hexc('6a3a58'),
}


def draw_cat(c, p, pal, ox=0, oy=0, s=1.0, scarf=True):
    """Side-view cat facing right. p = pose dict. Ground at y=29 (scaled about (16,29))."""
    def X(x):
        return ox + 16 + (x - 16) * s

    def Y(y):
        return oy + 29 + (y - 29) * s

    fur, hi = pal['fur'], pal['hi']
    bx, by = p.get('bx', 0), p.get('by', 0)
    sx, sy = p.get('sx', 1.0), p.get('sy', 1.0)
    # tail
    ta = p.get('tail', 0.0)
    tx0, ty0 = 8 + bx, 21 + by
    pts = [(tx0, ty0)]
    for i in range(1, 6):
        ang = -2.2 + ta * 0.5 + i * (0.25 + ta * 0.12)
        px_ = pts[-1][0] + math.cos(ang) * 2.0
        py_ = pts[-1][1] + math.sin(ang) * 2.0 - 0.3
        pts.append((px_, py_))
    c.curve([(X(a), Y(b)) for a, b in pts], fur, w=max(1, round(2 * s)))
    # legs: back (x 10,12), front (x 18,20)
    legs = p.get('legs', [(0, 0)] * 4)
    lx = [10, 12, 18, 20]
    for i, (dx, lift) in enumerate(legs):
        top_x = lx[i] + bx
        top_y = 23 + by
        foot_x = top_x + dx
        foot_y = 29 - lift
        col = shade(fur, 0.8) if i % 2 == 0 else fur
        c.line(X(top_x), Y(top_y), X(foot_x), Y(foot_y), col, w=max(1, round(2 * s)))
    # body
    c.ellipse(X(15 + bx), Y(21.5 + by), 6.6 * sx * s, 3.9 * sy * s, fur)
    # head
    hx, hy = 21.5 + bx + p.get('hx', 0), 16.5 + by + p.get('hy', 0)
    c.ellipse(X(hx), Y(hy), 4.3 * s, 4.0 * s, fur)
    c.ellipse(X(hx + 3.2), Y(hy + 1.6), 1.8 * s, 1.4 * s, fur)  # muzzle
    ear_back = p.get('ears_back', 0)
    # ears
    e1 = [(hx - 3.4, hy - 1.8), (hx - 2.6 - ear_back, hy - 6.6 + ear_back * 1.5), (hx - 0.4, hy - 3.6)]
    e2 = [(hx + 0.2, hy - 3.8), (hx + 1.6 - ear_back, hy - 7.2 + ear_back * 1.5), (hx + 3.6, hy - 2.6)]
    c.poly([(X(a), Y(b)) for a, b in e1], fur)
    c.poly([(X(a), Y(b)) for a, b in e2], fur)
    if s >= 1.0 and ear_back == 0:
        c.set(X(hx + 1.6), Y(hy - 4.5), pal['inner_ear'])
    # top highlight on body / head
    for xx in range(int(X(10 + bx)), int(X(20 + bx))):
        for yy in range(int(Y(16 + by)), int(Y(25 + by))):
            if c.get(xx, yy) == fur and c.get(xx, yy - 1)[3] == 0:
                c.set(xx, yy, hi)
    # scarf
    if scarf and 'scarf' in pal:
        sc, scd = pal['scarf'], pal['scarf_d']
        nx, ny = hx - 1.5, hy + 3.4
        c.line(X(nx - 1), Y(ny - 1.5), X(nx + 1.5), Y(ny + 0.5), sc, w=max(1, round(2 * s)))
        c.set(X(nx + 1), Y(ny + 1), scd)
        fl = p.get('flutter', 0)
        c.line(X(nx - 1.5), Y(ny - 1.5), X(nx - 4.5), Y(ny - 3.5 + fl * 0.7), sc, w=max(1, round(1 * s)))
        c.line(X(nx - 1.5), Y(ny - 0.5), X(nx - 5.5), Y(ny - 1.5 + fl * 0.7), scd, w=max(1, round(1 * s)))
    # eye
    if p.get('eye', 'open') == 'open':
        ex, ey = X(hx + 1.6), Y(hy - 0.4)
        c.rect(ex, ey, max(1, round(2 * s)), max(2, round(2 * s)), pal['eye'])
        c.set(ex + max(1, round(2 * s)) - 1, ey + max(2, round(2 * s)) - 1, pal['pupil'])
    elif p.get('eye') == 'closed':
        c.line(X(hx + 1), Y(hy + 0.5), X(hx + 3), Y(hy + 0.5), pal['eye'])
    elif p.get('eye') == 'x':
        ex, ey = X(hx + 1.5), Y(hy - 0.5)
        c.set(ex, ey, pal['eye']); c.set(ex + 2, ey, pal['eye']); c.set(ex + 1, ey + 1, pal['eye'])
        c.set(ex, ey + 2, pal['eye']); c.set(ex + 2, ey + 2, pal['eye'])
    c.set(X(hx + 4.8), Y(hy + 1.0), pal['nose'])
    if p.get('mouth'):
        c.set(X(hx + 4), Y(hy + 2.6), hexc('f4b4c4'))
    # swiping paw
    if p.get('paw'):
        pxx, pyy = p['paw']
        c.line(X(19 + bx), Y(21 + by), X(pxx), Y(pyy), fur, w=max(1, round(2 * s)))
        c.set(X(pxx + 1), Y(pyy - 1), hexc('f0eef8'))
        c.set(X(pxx + 1), Y(pyy + 1), hexc('f0eef8'))


def finish_hero(c):
    c.outline(HERO['rim'])


def hero_frames():
    rows = []
    # idle 4
    idle = []
    for i in range(4):
        c = Canvas(32, 32)
        b = [0, 0, 1, 0][i] * 0.0
        draw_cat(c, {'by': [0, 0, 0.5, 0.5][i], 'sy': [1.0, 1.04, 1.0, 0.98][i], 'tail': math.sin(i / 4 * 6.28) * 0.5,
                     'flutter': [0, 1, 0, -1][i], 'eye': 'closed' if i == 3 else 'open'}, HERO)
        finish_hero(c)
        idle.append(c)
    rows.append(idle)
    # run 6
    run = []
    for i in range(6):
        ph = i / 6 * math.tau
        legs = []
        for j, off in enumerate([0, 0.9, math.pi, math.pi + 0.9]):
            legs.append((math.sin(ph + off) * 4.0 * (1 if j < 2 else 1.1), max(0, math.cos(ph + off)) * 2.2))
        c = Canvas(32, 32)
        draw_cat(c, {'by': -abs(math.sin(ph)) * 1.2, 'legs': legs, 'tail': 0.6 + math.sin(ph) * 0.3,
                     'flutter': 1 + (i % 2), 'sx': 1.06}, HERO)
        finish_hero(c)
        run.append(c)
    rows.append(run)
    # jump 2 (rise), fall 2
    jump = []
    for i in range(2):
        c = Canvas(32, 32)
        draw_cat(c, {'by': -1, 'legs': [(-3, 1), (-2, 0), (3, 3), (4, 3)], 'tail': -0.4 - i * 0.2,
                     'flutter': 2, 'ears_back': 0, 'sy': 1.05}, HERO)
        finish_hero(c)
        jump.append(c)
    for i in range(2):
        c = Canvas(32, 32)
        draw_cat(c, {'by': -1, 'legs': [(-1, 0), (0, 0), (2, 0), (3, 1)], 'tail': 1.2 + i * 0.2,
                     'flutter': -1, 'ears_back': 1}, HERO)
        finish_hero(c)
        jump.append(c)
    rows.append(jump)
    # attack 3
    atk = []
    poses = [
        {'bx': -1, 'paw': (19, 13), 'hy': -0.5, 'tail': 0.8, 'mouth': True},
        {'bx': 1, 'paw': (27, 19), 'sx': 1.1, 'tail': 0.4, 'mouth': True, 'flutter': 2},
        {'bx': 0.5, 'paw': (24, 24), 'tail': 0.2},
    ]
    for pz in poses:
        c = Canvas(32, 32)
        draw_cat(c, pz, HERO)
        finish_hero(c)
        atk.append(c)
    rows.append(atk)
    # pounce 2
    pou = []
    for i in range(2):
        c = Canvas(32, 32)
        draw_cat(c, {'bx': 1, 'by': -1, 'sx': 1.35, 'sy': 0.8, 'legs': [(-5, 2), (-4, 2), (6, 4), (7, 4)],
                     'tail': -0.9, 'ears_back': 1.5, 'flutter': 3 + i, 'mouth': True, 'hx': 1.5}, HERO)
        finish_hero(c)
        pou.append(c)
    rows.append(pou)
    # hurt 1 + death 3
    hd = []
    c = Canvas(32, 32)
    draw_cat(c, {'bx': -1, 'sy': 0.9, 'ears_back': 1.5, 'eye': 'closed', 'tail': 1.6, 'mouth': True,
                 'legs': [(-1, 1), (0, 0), (1, 1), (2, 0)]}, HERO)
    finish_hero(c)
    hd.append(c)
    for i in range(3):
        c = Canvas(32, 32)
        if i == 0:
            draw_cat(c, {'by': 1, 'sy': 0.85, 'ears_back': 1.5, 'eye': 'closed', 'tail': 2.0,
                         'legs': [(-2, 0), (-1, 0), (2, 0), (3, 0)]}, HERO)
        else:
            draw_cat(c, {'by': 3, 'sy': 0.7, 'sx': 1.1, 'ears_back': 2, 'eye': 'x', 'tail': 2.4, 'hy': 2,
                         'legs': [(-4, 4), (-3, 4), (4, 4), (5, 4)]}, HERO)
        finish_hero(c)
        if i == 2:
            # little ghost wisp above
            c.ellipse(21, 8, 2.5, 3, (220, 220, 255, 150))
            c.set(20, 7, (30, 30, 50, 200)); c.set(22, 7, (30, 30, 50, 200))
        hd.append(c)
    rows.append(hd)
    save(grid_sheet(rows, 32, 32), 'hero.png')


CAPTIVE_COLORS = ['3a9ad8', 'e0b030', '58c060', 'c060d0', 'f08040', '60d0d0', 'e05080', 'a0a0ff', 'ffffff', '9070ff',
                  '70ff90', 'ff7070']


def captive_frames():
    """Rescued black cats. Row per cat colour (scarf + eye), 4 idle frames each."""
    rows = []
    for k, col in enumerate(CAPTIVE_COLORS):
        pal = dict(HERO)
        pal['scarf'] = hexc(col)
        pal['scarf_d'] = shade(hexc(col), 0.6)
        pal['eye'] = hexc(['ffd040', '80e0ff', 'c6ff4a', 'ff9a40'][k % 4])
        pal['fur'] = hexc(['1d1929', '231d24', '1a1d29', '28202a'][k % 4])
        frames = []
        for i in range(4):
            c = Canvas(32, 32)
            draw_cat(c, {'by': [0, 0.5, 0, 0.5][i] + 1, 'tail': math.sin(i / 4 * 6.28) * 0.6, 'sx': 0.92,
                         'eye': 'closed' if (i == 2 and k % 2 == 0) else 'open', 'flutter': [0, 1, 0, -1][i]},
                     pal, s=0.8)
            c.outline(hexc('6a5f99'))
            frames.append(c)
        rows.append(frames)
    save(grid_sheet(rows, 32, 32), 'captives.png')


# ---------------------------------------------------------------------------
# Bipedal white cats (enemies)
# ---------------------------------------------------------------------------

WHITE = {'fur': hexc('ecebf4'), 'sh': hexc('b6b2cc'), 'ol': hexc('2a2236'), 'eye': hexc('e8344c'),
         'nose': hexc('f0909a')}


def draw_biped(c, p, outfit, ox=0, oy=0, s=1.0):
    def X(x):
        return ox + 16 + (x - 16) * s

    def Y(y):
        return oy + 29 + (y - 29) * s

    fur, sh = WHITE['fur'], WHITE['sh']
    bx, by = p.get('bx', 0), p.get('by', 0)
    lean = p.get('lean', 0)
    W = max(1, round(2 * s))
    # tail
    ta = p.get('tail', 0)
    pts = [(11 + bx, 23 + by)]
    for i in range(1, 5):
        ang = math.pi - 0.5 - i * 0.35 + ta * 0.3
        pts.append((pts[-1][0] + math.cos(ang) * 2.0, pts[-1][1] - abs(math.sin(ang)) * 2.0 + 0.4))
    c.curve([(X(a), Y(b)) for a, b in pts], sh, w=W)
    # legs
    legs = p.get('legs', [(0, 0), (0, 0)])
    for i, (dx, lift) in enumerate(legs):
        hx_ = 14.5 + i * 3 + bx
        col = sh if i == 0 else fur
        c.line(X(hx_), Y(24 + by), X(hx_ + dx), Y(28.5 - lift), col, w=W)
        c.rect(X(hx_ + dx - 0.5), Y(28 - lift), W + 1, 1 * W, col)
    # back arm
    arm_b = p.get('arm_b', (12, 22))
    c.line(X(15 + bx + lean), Y(17 + by), X(arm_b[0] + bx), Y(arm_b[1] + by), sh, w=W)
    # torso
    c.ellipse(X(16 + bx + lean * 0.5), Y(20 + by), 4.2 * s, 5.4 * s, fur)
    # head
    hx, hy = 17 + bx + lean, 11.5 + by + p.get('hy', 0)
    c.ellipse(X(hx), Y(hy), 4.2 * s, 3.8 * s, fur)
    c.ellipse(X(hx + 3.0), Y(hy + 1.4), 1.6 * s, 1.3 * s, fur)
    c.poly([(X(a), Y(b)) for a, b in [(hx - 3.6, hy - 1.5), (hx - 2.6, hy - 6.4), (hx - 0.6, hy - 3.4)]], fur)
    c.poly([(X(a), Y(b)) for a, b in [(hx + 0.4, hy - 3.6), (hx + 2.0, hy - 6.8), (hx + 3.6, hy - 2.2)]], fur)
    c.set(X(hx + 2.0), Y(hy - 4.4), hexc('f0a0b8'))
    # outfit (drawn over body)
    outfit(c, p, X, Y, bx, by, hx, hy, s)
    # eye
    if p.get('eye', 'open') == 'open':
        c.rect(X(hx + 1.4), Y(hy - 0.6), W, W, WHITE['eye'])
    elif p.get('eye') == 'x':
        c.set(X(hx + 1), Y(hy - 1), WHITE['ol']); c.set(X(hx + 3), Y(hy - 1), WHITE['ol'])
        c.set(X(hx + 2), Y(hy), WHITE['ol']); c.set(X(hx + 1), Y(hy + 1), WHITE['ol']); c.set(X(hx + 3), Y(hy + 1), WHITE['ol'])
    else:
        c.line(X(hx + 1), Y(hy), X(hx + 3), Y(hy), WHITE['ol'])
    c.set(X(hx + 4.4), Y(hy + 0.8), WHITE['nose'])
    # front arm + held item
    arm_f = p.get('arm_f', (21, 21))
    c.line(X(17 + bx + lean), Y(17 + by), X(arm_f[0] + bx), Y(arm_f[1] + by), fur, w=W)
    if p.get('item'):
        p['item'](c, X, Y, arm_f[0] + bx, arm_f[1] + by, s)
    c.outline(WHITE['ol'])


def item_dagger(c, X, Y, x, y, s):
    c.line(X(x), Y(y), X(x + 4), Y(y - 3), hexc('d8dce8'))
    c.set(X(x), Y(y), hexc('6a4a2a'))


def item_spear(c, X, Y, x, y, s):
    c.line(X(x - 3), Y(y + 6), X(x + 5), Y(y - 9), hexc('7a5a34'))
    c.poly([(X(x + 4), Y(y - 8)), (X(x + 7), Y(y - 12)), (X(x + 6), Y(y - 7))], hexc('dfe6f0'))


def item_bow(c, X, Y, x, y, s):
    c.curve([(X(x - 1), Y(y - 7)), (X(x + 2), Y(y - 4)), (X(x + 3), Y(y)), (X(x + 2), Y(y + 4)), (X(x - 1), Y(y + 7))],
            hexc('8a5a2c'))
    c.line(X(x - 1), Y(y - 7), X(x - 1), Y(y + 7), hexc('e8e0c8'))


def item_bow_drawn(c, X, Y, x, y, s):
    c.curve([(X(x + 1), Y(y - 7)), (X(x + 3), Y(y - 4)), (X(x + 4), Y(y)), (X(x + 3), Y(y + 4)), (X(x + 1), Y(y + 7))],
            hexc('8a5a2c'))
    c.line(X(x + 1), Y(y - 7), X(x - 4), Y(y), hexc('e8e0c8'))
    c.line(X(x - 4), Y(y), X(x + 1), Y(y + 7), hexc('e8e0c8'))
    c.line(X(x - 4), Y(y), X(x + 6), Y(y), hexc('c8c8d0'))


def item_staff(glow):
    def f(c, X, Y, x, y, s):
        c.line(X(x), Y(y + 7), X(x + 1), Y(y - 9), hexc('5a3a6a'))
        c.circle(X(x + 1), Y(y - 10), 1.8 + glow, hexc('c080ff') if glow < 1 else hexc('f0c0ff'))
        if glow:
            c.circle(X(x + 1), Y(y - 10), 3.2 + glow, (200, 140, 255, 90))
    return f


def outfit_scout(c, p, X, Y, bx, by, hx, hy, s):
    c.rect(X(12.5 + bx), Y(18 + by), 7 * s, 4 * s, hexc('7a5232'))
    c.rect(X(12.5 + bx), Y(21 + by), 7 * s, 1 * s, hexc('4a3020'))
    c.rect(X(hx - 4), Y(hy - 3), 8 * s, 1 * s, hexc('a83a3a'))  # headband


def outfit_guard(c, p, X, Y, bx, by, hx, hy, s):
    c.ellipse(X(16 + bx + p.get('lean', 0) * 0.5), Y(19.5 + by), 4.4 * s, 4.6 * s, hexc('8e98ac'))
    c.rect(X(12 + bx), Y(18 + by), 9 * s, 1 * s, hexc('c6cfdc'))
    c.rect(X(hx - 4.2), Y(hy - 4.0), 8.4 * s, 3 * s, hexc('8e98ac'))
    c.rect(X(hx - 4.2), Y(hy - 4.0), 8.4 * s, 1 * s, hexc('c6cfdc'))
    c.rect(X(hx - 0.5), Y(hy - 6), 1 * s, 2 * s, hexc('c03a3a'))
    # shield in front
    if p.get('shield', True):
        sxp = 20.5 + bx + p.get('lean', 0)
        c.rect(X(sxp), Y(16 + by), 3 * s, 9 * s, hexc('6a7a98'))
        c.rect(X(sxp + 1), Y(17 + by), 1 * s, 7 * s, hexc('c03a3a'))


def outfit_archer(c, p, X, Y, bx, by, hx, hy, s):
    c.ellipse(X(16 + bx), Y(20 + by), 4.4 * s, 5.0 * s, hexc('3e7a46'))
    c.ellipse(X(hx - 0.6), Y(hy - 0.8), 4.4 * s, 3.6 * s, hexc('3e7a46'))
    c.ellipse(X(hx + 1.2), Y(hy + 0.6), 2.8 * s, 2.4 * s, WHITE['fur'])
    c.line(X(13 + bx), Y(15 + by), X(18 + bx), Y(24 + by), hexc('6a4a2a'))


def outfit_mage(c, p, X, Y, bx, by, hx, hy, s):
    c.poly([(X(12 + bx), Y(15 + by)), (X(20 + bx), Y(15 + by)), (X(22 + bx), Y(29)), (X(10 + bx), Y(29))],
           hexc('5a3a8a'))
    c.rect(X(10.5 + bx), Y(27), 11 * s, 1 * s, hexc('c8a040'))
    c.poly([(X(hx - 5), Y(hy - 2)), (X(hx + 4), Y(hy - 2)), (X(hx - 2), Y(hy - 11))], hexc('5a3a8a'))
    c.rect(X(hx - 5), Y(hy - 3), 10 * s, 1 * s, hexc('c8a040'))
    c.set(X(hx - 1), Y(hy - 6), hexc('f0d060'))


def enemy_sheet(name, outfit, idle_item, atk_rows):
    """atk_rows: dict anim -> list of pose dicts (merged over a default)."""
    rows = []

    def mk(pz):
        c = Canvas(32, 32)
        draw_biped(c, pz, outfit)
        return c

    base_item = idle_item
    rows.append([mk({'by': b, 'item': base_item, 'tail': t}) for b, t in [(0, 0), (0.5, 0.5), (0.5, 1), (0, 0.5)]])
    walk = []
    for i in range(4):
        ph = i / 4 * math.tau
        walk.append(mk({'by': -abs(math.sin(ph)) * 0.8, 'legs': [(math.sin(ph) * 2.5, max(0, math.cos(ph)) * 1.5),
                                                               (-math.sin(ph) * 2.5, max(0, -math.cos(ph)) * 1.5)],
                        'item': base_item, 'tail': math.sin(ph)}))
    rows.append(walk)
    for anim in ['windup', 'attack']:
        rows.append([mk(dict({'item': base_item}, **pz)) for pz in atk_rows[anim]])
    rows.append([mk({'bx': -1, 'eye': 'closed', 'lean': -1, 'item': base_item, 'tail': 2})])
    death = [mk({'bx': -1, 'eye': 'x', 'lean': -2, 'by': 1, 'tail': 2})]
    for i in range(2):
        c = Canvas(32, 32)
        draw_biped(c, {'eye': 'x', 'by': 1}, outfit)
        img = c.img.rotate(90 if i else 45, expand=False, center=(16, 28))
        cc = Canvas(32, 32)
        cc.img.paste(img, (0, 2 if i else 1))
        cc.px = cc.img.load()
        death.append(cc)
    rows.append(death)
    save(grid_sheet(rows, 32, 32), name + '.png')


def enemies():
    enemy_sheet('scout', outfit_scout, item_dagger, {
        'windup': [{'bx': -1, 'arm_f': (18, 14), 'lean': -1}],
        'attack': [{'bx': 2, 'arm_f': (24, 19), 'lean': 2, 'legs': [(-2, 0), (2, 0)]},
                   {'bx': 1, 'arm_f': (23, 21), 'lean': 1}]})
    enemy_sheet('guard', outfit_guard, item_spear, {
        'windup': [{'bx': -2, 'arm_f': (16, 15), 'lean': -2, 'shield': True},
                   {'bx': -2, 'arm_f': (15, 14), 'lean': -2, 'by': -0.5}],
        'attack': [{'bx': 3, 'arm_f': (26, 19), 'lean': 2, 'legs': [(-3, 0), (2, 0)]},
                   {'bx': 2, 'arm_f': (24, 20), 'lean': 1}]})
    enemy_sheet('archer', outfit_archer, item_bow, {
        'windup': [{'arm_f': (22, 18), 'item': item_bow_drawn, 'arm_b': (17, 18)},
                   {'arm_f': (22, 18), 'item': item_bow_drawn, 'arm_b': (16, 18), 'by': -0.5}],
        'attack': [{'arm_f': (22, 18), 'item': item_bow, 'arm_b': (14, 20)}]})
    enemy_sheet('mage', outfit_mage, item_staff(0), {
        'windup': [{'arm_f': (21, 13), 'item': item_staff(1)}, {'arm_f': (21, 12), 'item': item_staff(2), 'by': -1}],
        'attack': [{'arm_f': (23, 17), 'item': item_staff(1), 'lean': 1}]})


BEAST = {'fur': hexc('e6e2ee'), 'hi': hexc('ffffff'), 'eye': hexc('ff3a3a'), 'pupil': hexc('701010'),
         'nose': hexc('d07080'), 'inner_ear': hexc('d090a0')}


def beast_frame(p):
    c = Canvas(64, 48)
    pal = BEAST
    p = dict({'sx': 1.15}, **p)
    draw_cat(c, p, pal, ox=14, oy=17, s=1.85, scarf=False)
    # horns + mane spikes
    hx = 14 + 16 + (21.5 + p.get('bx', 0) + p.get('hx', 0) - 16) * 1.85
    hy = 17 + 29 + (16.5 + p.get('by', 0) + p.get('hy', 0) - 29) * 1.85
    c.poly([(hx - 3, hy - 4), (hx - 8, hy - 11), (hx - 2, hy - 7)], hexc('8a7a6a'))
    c.poly([(hx + 1, hy - 5), (hx - 1, hy - 13), (hx + 3, hy - 7)], hexc('a89888'))
    c.ellipse(hx - 5, hy + 3, 4, 6, hexc('cfc8dc'))
    for i in range(4):
        x0 = hx - 9 - i * 4
        c.poly([(x0, hy + 3), (x0 - 2, hy - 3 + (i % 2) * 2), (x0 - 4, hy + 3)], hexc('9a90b0'))
    # armour plate
    bx = 14 + 16 + (15 + p.get('bx', 0) - 16) * 1.85
    by = 17 + 29 + (19 + p.get('by', 0) - 29) * 1.85
    c.rect(bx - 8, by - 2, 16, 4, hexc('6a5a7a'))
    c.rect(bx - 8, by - 2, 16, 1, hexc('a898b8'))
    for k in range(3):
        c.set(bx - 5 + k * 5, by, hexc('d8c070'))
    c.outline(hexc('2a2236'))
    return c


def beast():
    rows = []
    rows.append([beast_frame({'by': b, 'tail': t}) for b, t in [(0, 0.2), (0.4, 0.5), (0.6, 0.8), (0.3, 0.5)]])
    walk = []
    for i in range(4):
        ph = i / 4 * math.tau
        legs = [(math.sin(ph + o) * 2.5, max(0, math.cos(ph + o)) * 1.6) for o in [0, 0.5, math.pi, math.pi + 0.5]]
        walk.append(beast_frame({'by': -abs(math.sin(ph)) * 0.6, 'legs': legs, 'tail': 0.5}))
    rows.append(walk)
    rows.append([beast_frame({'bx': -2, 'by': -1, 'hy': -1.5, 'legs': [(-1, 0), (0, 0), (1, 2), (2, 3)], 'mouth': True,
                              'tail': 1.2}),
                 beast_frame({'bx': -2.5, 'by': -2, 'hy': -2.5, 'legs': [(-1, 0), (0, 0), (2, 3), (3, 4)],
                              'mouth': True, 'tail': 1.5})])
    rows.append([beast_frame({'bx': 2, 'by': 0.5, 'hy': 1.5, 'sx': 1.15, 'legs': [(-3, 0), (-2, 0), (4, 0), (5, 0)],
                              'mouth': True, 'tail': 0}),
                 beast_frame({'bx': 1.5, 'by': 0.5, 'hy': 1, 'legs': [(-2, 0), (-1, 0), (3, 0), (4, 0)], 'tail': 0.3})])
    rows.append([beast_frame({'bx': -1, 'eye': 'closed', 'ears_back': 1.5, 'tail': 2})])
    rows.append([beast_frame({'eye': 'x', 'by': 1, 'sy': 0.85, 'tail': 2}),
                 beast_frame({'eye': 'x', 'by': 2.5, 'sy': 0.7, 'legs': [(-3, 3), (-2, 3), (3, 3), (4, 3)]}),
                 beast_frame({'eye': 'x', 'by': 3.5, 'sy': 0.6, 'legs': [(-4, 4), (-3, 4), (4, 4), (5, 4)]})])
    save(grid_sheet(rows, 64, 48), 'beast.png')


if __name__ == '__main__':
    hero_frames()
    captive_frames()
    enemies()
    beast()
    import gen_art2  # noqa: F401  (tiles, objects, bosses, ui)
    gen_art2.main()
    print('art generated')
