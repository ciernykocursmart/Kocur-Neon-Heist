"""Authoring script for all Kocur Dungeon levels.

Run from the kocur-dungeon folder:  python3 tools/build_maps.py
Writes scripts/data/maps/region1.gd ... region5.gd (ASCII maps, see
scripts/world/level_grid.gd for the legend). Level metadata (names, signs,
rescued cat, boss) lives in scripts/data/level_catalog.gd.

Movement budget used for the critical path (validated by tests/level_reach.gd):
climb <= 3 tiles per jump, gaps <= 4 tiles; pounce-only spots hold optional rewards.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from mapkit import Map  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'data', 'maps')
os.makedirs(OUT, exist_ok=True)


# ===========================================================================
# Region 1 - Mossroot Catacombs (teach: move, jump, claw, pounce, checkpoint)
# ===========================================================================

def l1_1():
    m = Map(150, 24)
    m.ground(0, 149, 19)
    m.ceil(0, 149, 2)
    # Start + movement lesson
    m.put(3, 18, 'P')
    m.put(6, 18, '?')
    m.text(9, 18, 'ooo')
    m.ground(13, 24, 18)
    m.text(15, 17, 'ooo')
    m.ground(19, 24, 17)
    m.put(20, 16, '?')
    m.put(22, 3, 'd'); m.put(10, 3, 'd'); m.put(30, 3, 'd')
    # First spike pit (3 wide)
    m.ground(25, 50, 17)
    m.pit(25, 27, 17)
    m.text(25, 13, 'ooo')
    # Claw lesson + first scout
    m.put(30, 16, '?')
    m.put(40, 16, 's')
    m.text(43, 16, 'oo')
    m.put(47, 16, 'K')
    m.put(36, 16, 'd')
    # 3-tile climb
    m.ground(51, 64, 14)
    m.put(49, 16, '?')
    # Pounce lesson: optional pounce-only ledge with a gem
    m.put(53, 13, '?')
    m.row(56, 59, 8, '=')
    m.put(57, 7, 'g')
    m.text(56, 12, 'ooo')
    m.put(60, 13, 't')
    # Drop to the lower hall
    m.ground(65, 80, 19)
    m.text(66, 18, 'oo')
    m.put(72, 18, 's')
    m.row(68, 70, 15, '=')
    m.text(68, 14, 'ooo')
    # Hidden room behind an illusory wall (entered from the hall floor)
    m.ground(81, 100, 15)
    m.row(77, 79, 16, '=')
    m.rect(81, 16, 84, 18, '%')
    m.clear(85, 16, 92, 18)
    m.rect(85, 16, 92, 18, ' ')
    m.put(87, 17, '$'); m.put(88, 17, '$')
    m.put(90, 18, 'T')
    m.text(86, 18, 'oo')
    m.put(83, 13, 'd')
    # Upper ledge with two scouts
    m.text(84, 14, 'ooo')
    m.put(94, 14, 's')
    m.put(98, 14, 'K')
    # Step down, one-way platforms across a long spike pit
    m.ground(101, 149, 19)
    m.pit(103, 116, 19)
    m.row(104, 106, 16, '=')
    m.row(110, 112, 15, '=')
    m.text(104, 15, 'ooo')
    m.text(110, 14, 'ooo')
    m.put(108, 11, 'f')
    m.row(107, 109, 12, '=')
    m.put(124, 18, 's')
    m.put(130, 18, 's')
    m.text(119, 18, 'ooo')
    m.put(136, 18, 'f')
    m.put(140, 18, '?')
    m.put(145, 18, 'X')
    m.put(143, 16, 't')
    m.put(120, 3, 'd'); m.put(134, 3, 'd')
    return m



def stairs(m, x, y, dx, dy, n, w=3, ch='='):
    """n one-way platforms of width w, starting at (x, y), stepping (dx, dy)."""
    for i in range(n):
        m.row(x + i * dx, x + i * dx + w - 1, y + i * dy, ch)


def arena(m, x0, x1, floor, top, boss='1', gate_h=3, exit_side='right'):
    """Guardian arena: walls x0/x1, floor row `floor` (top surface), ceiling `top`.
    Entrance gate column at x0 (rows floor-gate_h..floor-1), trigger 3 cells in."""
    m.clear(x0 + 1, top + 1, x1 - 1, floor - 1)
    m.ground(x0, x1, floor)
    m.rect(x0, 0, x1, top, '#')
    m.col(x0, top, floor - gate_h - 1, '#')
    m.col(x1, top, floor - 1, '#')
    m.col(x0, floor - gate_h, floor - 1, ']')
    m.put(x0 + 4, floor - 1, '!')
    m.put(x1 - 7, floor - 1, boss)
    m.put(x1 - 2, floor - 1, 'X')
    m.put(x0 + 2, top + 1, 'd')
    m.put(x1 - 2, top + 1, 'd')


# ---------------------------------------------------------------------------
# 1-2 Root Hollow: crumbling bridges, a guard, a hidden cage, secrets.
# ---------------------------------------------------------------------------
def l1_2():
    m = Map(176, 30)
    m.ceil(0, 175, 2)
    m.ground(0, 175, 26)
    m.put(3, 25, 'P')
    m.put(7, 25, '?')                     # meowing hint
    m.text(10, 25, 'ooo')
    m.put(18, 25, 's')
    m.ground(22, 29, 24)
    m.text(23, 23, 'oo')
    # crumble bridge over spikes
    m.put(28, 23, '?')                    # crumble hint
    m.pit(30, 37, 24)
    m.row(30, 37, 24, '~')
    m.ground(38, 52, 24)
    m.text(31, 21, 'oooooo')
    m.put(45, 23, 's')
    m.put(50, 23, 'K')
    # climb to the upper corridor (one-way stairs)
    m.ceil(53, 75, 2)
    m.ground(53, 75, 26)
    stairs(m, 55, 22, 4, -3, 4, 3)        # rows 22,19,16,13
    m.text(56, 21, 'oo'); m.text(64, 15, 'oo')
    m.ground(70, 110, 13, bottom=14)      # upper corridor floor (2 thick)
    m.rect(70, 15, 110, 25, ' ')
    m.ground(76, 110, 26)
    m.text(73, 12, 'ooo')
    m.put(80, 12, 'G')                    # guard on the walkway
    m.put(76, 12, '?')                    # guard hint
    m.put(88, 12, 's')
    m.text(92, 12, 'ooo')
    m.put(84, 3, 'd'); m.put(98, 3, 'd')
    # lower cave under the walkway (reached by dropping at x 111)
    m.text(80, 25, 'oooo')
    m.put(90, 25, 's')
    m.put(95, 25, 'f')
    # Hidden cage room: fake wall at the lower cave's east end
    m.rect(100, 22, 101, 25, '%')
    m.rect(102, 20, 110, 25, ' ')
    m.rect(102, 19, 110, 19, '#')
    m.put(106, 25, 'R')
    m.put(104, 23, '$'); m.put(105, 23, '$')
    m.text(108, 25, 'oo')
    # back up from the lower cave: one-way steps at x 76..
    stairs(m, 72, 23, 0, -3, 1, 3)
    m.row(72, 74, 23, '=')
    m.row(72, 74, 20, '=')
    m.row(72, 74, 17, '=')
    m.clear(70, 13, 71, 14)
    m.row(70, 71, 13, '=')
    # east: drop from walkway, crumble steps, second checkpoint
    m.clear(111, 13, 120, 25)
    m.ground(111, 175, 26)
    m.put(112, 12, 'K')
    m.ground(111, 114, 13, bottom=14)
    m.pit(118, 130, 26)
    m.row(118, 120, 23, '~')
    m.row(124, 126, 22, '~')
    m.row(128, 130, 23, '~')
    m.text(119, 21, 'ooo'); m.text(125, 20, 'ooo')
    m.ground(131, 175, 25)
    m.put(136, 24, 's')
    m.put(142, 24, 's')
    m.text(138, 24, 'ooo')
    # secret: high ledge only reachable with an upward pounce, gem + chest
    m.ground(150, 160, 20, bottom=21)
    m.rect(150, 22, 160, 24, ' ')
    m.put(148, 24, '?')
    m.put(155, 19, 'g')
    m.put(158, 19, 'T')
    m.put(152, 19, '$')
    m.text(162, 24, 'oo')
    m.put(166, 24, 'f')
    m.put(171, 24, 'X')
    m.put(169, 22, 't')
    return m


# ---------------------------------------------------------------------------
# 1-3 The Iron Gate: lever gates, Bramble's cell, then the Iron Mouser.
# ---------------------------------------------------------------------------
def l1_3():
    m = Map(210, 28)
    m.ceil(0, 209, 2)
    m.ground(0, 209, 24)
    m.put(3, 23, 'P')
    m.text(7, 23, 'ooo')
    m.put(14, 23, 's')
    m.put(20, 23, '?')                    # lever hint
    # gate 1 blocks the corridor; lever up on a ledge reached by stairs + crumble
    m.col(30, 3, 20, '#')
    m.col(30, 21, 23, 'D')
    m.row(22, 24, 20, '=')
    m.row(25, 27, 17, '~')
    m.ground(18, 29, 14, bottom=15)
    m.put(26, 13, 'l')
    m.text(19, 13, 'ooo')
    m.put(21, 13, 'g')
    # past gate 1
    m.text(33, 23, 'oooo')
    m.put(40, 23, 'G')
    m.put(46, 23, 's')
    m.ground(50, 60, 21)
    m.put(55, 20, 'K')
    # spike gauntlet with platforms
    m.pit(61, 76, 24)
    m.row(62, 64, 21, '=')
    m.row(68, 70, 19, '=')
    m.row(73, 75, 21, '=')
    m.text(68, 18, 'ooo')
    m.ground(77, 120, 21)
    m.put(84, 20, 's')
    m.put(90, 20, 'G')
    m.text(94, 20, 'ooo')
    # Bramble's cell above (gate 2 with its own lever further on)
    m.ground(98, 112, 13, bottom=14)
    m.rect(98, 9, 112, 12, ' ')
    m.rect(98, 8, 112, 8, '#')
    m.col(98, 9, 12, '#')
    m.col(112, 9, 10, '#')
    m.col(112, 11, 12, 'D')
    m.put(104, 12, 'R')
    m.put(101, 12, '$'); m.put(102, 12, '$')
    m.text(106, 12, 'oo')
    # reach the cell's roof route: stairs up from the floor, lever on the right
    stairs(m, 114, 18, 3, -3, 2, 3)       # rows 18, 15
    m.ground(118, 126, 12, bottom=13)
    m.put(122, 11, 'l')
    m.row(113, 117, 12, '=')
    m.text(119, 11, 'oo')
    # secret alcove behind a fake wall under the cell (chest)
    m.rect(121, 14, 126, 20, ' ')
    m.rect(121, 14, 126, 14, '#')
    m.rect(127, 15, 127, 20, '%')
    m.put(123, 20, 'T')
    m.put(124, 18, '$')
    m.ground(121, 126, 21)
    # approach to the arena
    m.ground(127, 165, 21)
    m.put(134, 20, 's')
    m.put(140, 20, 'f')
    m.put(146, 20, '?')                   # boss hint
    m.put(152, 20, 'K')
    m.text(156, 20, 'ooo')
    arena(m, 166, 208, 21, 6, '1')
    m.put(178, 20, 'f')
    return m

LEVELS = {
    1: [('L1', l1_1), ('L2', l1_2), ('L3', l1_3)],
}


REQUIRED = {1: ['L1', 'L2', 'L3'], 2: ['L1', 'L2', 'L3'], 3: ['L1', 'L2', 'L3'], 4: ['L1', 'L2', 'L3'],
            5: ['L1', 'L2', 'L3', 'FINAL']}


def main():
    for region, names in REQUIRED.items():
        items = list(LEVELS.get(region, []))
        have = {c for c, _ in items}
        for n in names:
            if n not in have:
                items.append((n, l1_1))  # placeholder until designed
        LEVELS[region] = items
    for region, items in LEVELS.items():
        out = ['extends RefCounted', '## Generated by tools/build_maps.py - edit the generator, not this file.', '']
        for const, fn in items:
            m = fn()
            out.append('const %s := """' % const)
            out.append(m.dump())
            out.append('"""')
            out.append('')
        with open(os.path.join(OUT, 'region%d.gd' % region), 'w') as f:
            f.write('\n'.join(out))
    print('maps written')


if __name__ == '__main__':
    main()
