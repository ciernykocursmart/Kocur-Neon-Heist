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
    m.row(19, 21, 21, '=')
    m.row(14, 16, 18, '~')
    m.ground(18, 29, 15, bottom=16)
    m.put(26, 14, 'l')
    m.text(19, 14, 'ooo')
    m.put(22, 14, 'g')
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


def secret_pocket(m, x0, x1, roof, ch_room='$', chest=True):
    """A 2-row pocket under the floor whose roof (row `roof`, x0..x1) is a fake wall.
    Floor of the pocket is roof+3 so the player can jump back out (3-row rise)."""
    m.rect(x0 - 2, roof + 1, x1 + 2, roof + 2, ' ')
    m.row(x0, x1, roof, '%')
    m.row(x0 - 2, x1 + 2, roof + 3, '#')
    m.put(x0, roof + 2, ch_room)
    m.put(x0 + 1, roof + 2, ch_room)
    if chest:
        m.put(x1 + 1, roof + 2, 'T')


# ---------------------------------------------------------------------------
# Region 2 - Emberpaw Mines
# ---------------------------------------------------------------------------
def l2_1():
    m = Map(184, 32)
    m.ceil(0, 183, 2)
    m.ground(0, 183, 27)
    m.put(3, 26, 'P')
    m.put(7, 26, '?')                     # flame jets
    m.text(10, 26, 'ooo')
    m.put(16, 26, 'F')
    m.text(18, 25, 'o')
    m.put(21, 26, 'F')
    m.row(24, 27, 27, 'L')
    m.text(24, 23, 'oooo')
    m.put(32, 26, 's')
    m.put(36, 26, '?')                    # guards
    m.put(42, 26, 'G')
    m.text(44, 26, 'oo')
    m.put(47, 26, 'K')
    m.put(40, 3, 'd'); m.put(20, 3, 'd')
    # raised stretch with flame jets and a pounce-only gem
    m.ground(50, 70, 24)
    m.put(55, 23, 'F')
    m.put(60, 23, 'F')
    m.text(57, 23, 'oo')
    m.row(59, 61, 17, '=')
    m.put(60, 16, 'g')
    m.put(66, 23, 's')
    # lava basin with stepping platforms
    m.row(71, 80, 27, 'L')
    m.row(73, 75, 22, '=')
    m.row(78, 80, 22, '=')
    m.text(73, 21, 'ooo'); m.text(78, 21, 'ooo')
    m.ground(81, 102, 24)
    m.put(85, 23, 's')
    m.put(90, 23, 'f')
    # shaft up to the upper gallery
    m.row(99, 101, 21, '=')
    m.row(95, 97, 18, '=')
    m.row(99, 101, 15, '=')
    m.text(95, 17, 'oo'); m.text(99, 14, 'oo')
    m.ground(103, 183, 12)
    # Soot's cell under the gallery
    m.clear(103, 19, 112, 23)
    m.row(103, 112, 24, '#')
    m.put(109, 23, 'R')
    m.text(105, 23, 'oo')
    m.put(111, 23, 't')
    # upper gallery
    m.put(112, 11, 'G')
    m.put(118, 11, 'F')
    m.put(122, 11, 'F')
    m.text(119, 10, 'ooo')
    m.put(126, 11, 'K')
    m.row(130, 133, 12, 'L')
    m.text(130, 9, 'oooo')
    m.put(140, 11, 's')
    m.put(146, 11, 'F')
    m.put(150, 11, 'G')
    # secret loft behind an illusory wall
    m.row(155, 157, 9, '=')
    m.text(155, 8, 'oo')
    m.rect(159, 3, 169, 8, ' ')
    m.row(159, 169, 9, '#')
    m.col(158, 5, 8, '%')
    m.col(158, 3, 4, '#')
    m.col(170, 3, 9, '#')
    m.put(161, 8, '$'); m.put(162, 8, '$')
    m.put(166, 8, 'T')
    m.put(164, 8, 'g')
    m.put(164, 3, 'd')
    m.text(160, 11, 'oooo')
    m.put(172, 11, 's')
    m.put(176, 11, 'f')
    m.put(180, 11, 'X')
    m.put(178, 9, 't')
    return m


def l2_2():
    m = Map(200, 30)
    m.ceil(0, 199, 2)
    m.ground(0, 199, 25)
    m.put(3, 24, 'P')
    m.put(6, 24, '?')                     # lifts
    m.text(9, 24, 'ooo')
    m.put(14, 24, 's')
    # lava lake crossed on mine lifts
    m.row(20, 45, 25, 'L')
    m.put(21, 23, 'H'); m.put(29, 23, ':')
    m.ground(33, 36, 23, bottom=24)
    m.text(33, 22, 'oooo')
    m.put(38, 23, 'H'); m.put(44, 23, ':')
    m.row(30, 32, 17, '=')
    m.put(31, 16, 'g')
    m.text(22, 19, 'ooo'); m.text(39, 19, 'ooo')
    # archers
    m.put(50, 24, '?')                    # archers
    m.put(54, 24, 's')
    m.ground(58, 66, 22)
    m.put(62, 21, 'A')
    m.text(59, 21, 'oo')
    m.put(70, 24, 'K')
    # vertical lift over a lava shaft
    m.row(75, 80, 25, 'L')
    m.put(78, 24, 'V'); m.put(78, 14, ':')
    m.ground(81, 120, 14, bottom=15)
    m.rect(81, 16, 120, 24, ' ')
    m.text(83, 24, 'oooo')
    m.put(90, 24, 'f')
    m.put(96, 24, 's')
    m.row(84, 86, 22, '=')            # way back up from the lower cellar
    m.row(84, 86, 19, '=')
    m.row(81, 83, 16, '=')
    m.text(85, 13, 'oo')
    m.put(95, 13, 'A')
    m.put(100, 13, 'F')
    m.put(105, 13, 'G')
    m.text(108, 13, 'ooo')
    # Cinder's cage on a high perch
    m.row(110, 112, 11, '=')
    m.put(111, 10, 'R')
    m.put(115, 4, 'd')
    m.text(116, 13, 'oo')
    # drop back to the main floor
    m.put(123, 24, 'K')
    m.row(127, 130, 25, 'L')
    m.put(134, 24, 's')
    m.ground(136, 139, 22)
    m.put(137, 21, 'A')
    m.row(140, 152, 25, 'L')
    m.put(141, 23, 'H'); m.put(148, 23, ':')
    m.text(142, 20, 'oooooo')
    m.put(160, 24, 'G')
    m.text(164, 24, 'ooo')
    secret_pocket(m, 172, 174, 25)
    m.put(176, 24, '?')                   # hidden floor hint (sign 3)
    m.put(173, 26, 'g')
    m.put(183, 24, 'A')
    m.put(190, 24, 'f')
    m.put(196, 24, 'X')
    m.put(194, 22, 't')
    return m


def l2_3():
    m = Map(124, 26)
    m.ceil(0, 123, 2)
    m.ground(0, 123, 22)
    m.put(3, 21, 'P')
    m.text(6, 21, 'oo')
    secret_pocket(m, 10, 12, 22)
    m.put(11, 24, 'g')
    m.put(16, 21, 'F')
    m.put(20, 21, 'G')
    m.ground(26, 32, 19)
    m.put(29, 18, 'A')
    m.text(27, 18, 'oo')
    m.row(35, 38, 22, 'L')
    m.text(35, 18, 'oooo')
    m.put(44, 21, 'K')
    m.put(48, 21, 'f')
    m.put(52, 21, '?')
    m.put(56, 21, 's')
    m.put(60, 21, 'F')
    m.row(61, 63, 16, '=')
    m.put(62, 15, 'g')
    m.text(64, 21, 'ooo')
    arena(m, 70, 123, 22, 6, '2')
    return m


# ---------------------------------------------------------------------------
# Region 3 - Frostfang Crypt
# ---------------------------------------------------------------------------
def l3_1():
    m = Map(196, 30)
    m.ceil(0, 195, 2)
    m.ground(0, 195, 25)
    m.put(3, 24, 'P')
    m.put(7, 24, '?')                     # ice
    m.row(10, 40, 25, 'I')
    m.text(12, 24, 'oooo')
    m.put(20, 24, 's')
    m.ground(26, 34, 22, 'I')
    m.text(27, 21, 'ooo')
    m.put(38, 24, '?')                    # icicles
    for x in (42, 46, 50):
        m.put(x, 3, 'Y')
    m.text(43, 24, 'ooooooo')
    m.put(54, 24, 'K')
    # icy pit crossing
    m.pit(58, 70, 25)
    m.row(59, 61, 22, 'I')
    m.row(64, 66, 21, 'I')
    m.row(69, 70, 22, 'I')
    m.text(64, 19, 'ooo')
    m.ground(71, 100, 25, 'I')
    m.put(78, 24, 'G')
    m.put(86, 24, 'A')
    m.put(90, 3, 'Y'); m.put(93, 3, 'Y')
    m.ground(94, 100, 22)
    m.put(97, 21, 's')
    # Nibbles in an ice cave below (way back with one-way ledges)
    m.ground(101, 195, 22)
    m.clear(101, 23, 118, 27)
    m.row(101, 118, 28, '#')
    m.clear(101, 22, 104, 22)
    m.row(103, 105, 25, '=')
    m.put(110, 27, 'R')
    m.text(106, 27, 'ooo')
    m.put(114, 27, 'f')
    m.row(116, 118, 25, '=')
    m.put(112, 23, 't')
    m.put(120, 21, 'K')
    # upper ice shelves
    m.ground(126, 150, 19, 'I')
    m.rect(126, 22, 150, 22, '#')
    m.put(132, 18, 'G')
    m.put(138, 3, 'Y'); m.put(142, 3, 'Y')
    m.text(136, 18, 'ooo')
    m.row(140, 142, 13, '=')
    m.put(141, 12, 'g')
    # secret ice niche behind a fake wall
    m.rect(151, 17, 151, 18, '%')
    m.clear(152, 17, 157, 18)
    m.row(151, 158, 16, '#')
    m.col(158, 16, 18, '#')
    m.ground(151, 158, 19)
    m.put(152, 18, '$'); m.put(153, 18, '$')
    m.put(156, 18, 'T')
    m.put(155, 18, 'g')
    m.ground(159, 195, 22)
    m.put(164, 21, 's')
    m.put(170, 21, 'A')
    m.text(174, 21, 'ooo')
    m.put(180, 21, 'f')
    m.put(186, 21, '?')
    m.put(191, 21, 'X')
    m.put(189, 19, 't')
    return m


def l3_2():
    m = Map(150, 40)
    m.ceil(0, 149, 2)
    m.ground(0, 149, 36)
    m.put(3, 35, 'P')
    m.put(7, 35, '?')                     # mages
    m.text(10, 35, 'ooo')
    m.put(18, 35, 'W')
    m.put(24, 35, 's')
    m.put(28, 35, '?')                    # springs
    m.put(31, 35, 'J')
    m.ground(34, 60, 28)
    m.text(31, 28, 'o'); m.text(31, 24, 'o')
    m.put(38, 27, 'K')
    m.put(44, 27, 'W')
    m.put(48, 3, 'Y'); m.put(52, 3, 'Y')
    m.text(46, 27, 'oooo')
    # spring tower up to the vaults
    m.pit(61, 72, 28)
    m.ground(61, 63, 33, bottom=38)
    m.put(62, 32, 'J')
    m.row(61, 72, 38, '^')
    m.row(66, 68, 25, '=')
    m.row(70, 72, 22, '=')
    m.put(67, 24, 'f')
    m.ground(73, 100, 20)
    m.put(79, 19, 'G')
    m.put(86, 19, 'W')
    m.put(90, 3, 'Y'); m.put(94, 3, 'Y')
    m.text(82, 19, 'ooo')
    m.put(96, 19, 'K')
    # Flurry's cage on a spring-launched shelf
    m.put(99, 19, 'J')
    m.row(97, 101, 12, '=')
    m.put(99, 11, 'R')
    m.text(97, 11, 'o'); m.text(101, 11, 'o')
    # lower vault (optional, gem + secret)
    m.ground(101, 149, 28)
    m.rect(101, 21, 112, 27, ' ')
    m.rect(101, 20, 112, 20, '=')
    m.put(104, 27, 'W')
    m.put(108, 27, 'g')
    m.put(111, 27, 'J')
    m.rect(113, 21, 113, 27, '%')
    m.rect(114, 21, 120, 27, ' ')
    m.row(114, 120, 20, '#')
    m.col(121, 20, 27, '#')
    m.put(116, 27, '$'); m.put(117, 27, '$')
    m.put(119, 27, 'T')
    m.ground(122, 149, 20)
    m.put(128, 19, 'A')
    m.put(134, 19, 's')
    m.text(136, 19, 'ooo')
    m.put(141, 19, 'f')
    m.put(145, 19, 'X')
    m.put(143, 17, 't')
    return m


def l3_3():
    m = Map(124, 26)
    m.ceil(0, 123, 2)
    m.ground(0, 123, 22)
    m.put(3, 21, 'P')
    m.row(8, 30, 22, 'I')
    m.text(8, 21, 'ooo')
    m.put(14, 21, 'W')
    m.put(18, 3, 'Y'); m.put(22, 3, 'Y')
    m.put(26, 21, 'G')
    m.ground(32, 38, 19, 'I')
    m.put(35, 18, 'J')
    m.row(34, 36, 10, '=')
    m.put(35, 9, 'g')
    m.text(32, 18, 'oo')
    m.put(44, 21, 'K')
    m.put(48, 21, 'f')
    secret_pocket(m, 51, 53, 22)
    m.put(52, 24, 'g')
    m.put(56, 21, '?')
    m.put(60, 21, 'A')
    m.text(63, 21, 'ooo')
    arena(m, 70, 123, 22, 6, '3')
    m.row(71, 122, 22, 'I')
    return m


# ---------------------------------------------------------------------------
# Region 4 - Shadowclaw Depths (dark)
# ---------------------------------------------------------------------------
def l4_1():
    m = Map(200, 30)
    m.ceil(0, 199, 2)
    m.ground(0, 199, 25)
    m.put(3, 24, 'P')
    m.put(5, 22, 't')
    m.put(8, 24, '?')                     # darkness
    m.text(11, 24, 'ooo')
    m.put(18, 24, 's')
    m.put(22, 22, 't')
    m.pit(26, 30, 25)
    m.text(26, 21, 'ooooo')
    m.put(36, 24, 'A')
    m.put(42, 22, 't')
    m.put(46, 24, 'K')
    m.put(52, 24, '?')                    # beast
    m.put(64, 24, 'B')
    m.put(72, 22, 't')
    m.ground(74, 110, 22)
    m.text(80, 20, 'ooo')
    m.put(86, 21, 'W')
    m.put(92, 19, 't')
    m.put(98, 21, 'G')
    # Whisper's cage in a side cave behind a fake wall... with a clear hint path of coins
    m.text(102, 21, 'oo')
    m.put(106, 21, 'K')
    m.pit(111, 124, 22)
    m.row(112, 114, 19, '=')
    m.row(117, 119, 18, '=')
    m.row(121, 123, 19, '=')
    m.text(117, 17, 'ooo')
    m.put(118, 15, 't')
    m.ground(125, 199, 22)
    m.put(128, 21, 's')
    m.put(134, 21, 'B')
    m.put(140, 19, 't')
    m.col(146, 3, 18, '#')
    m.rect(146, 19, 146, 21, '%')
    m.rect(147, 14, 158, 21, ' ')
    m.row(147, 158, 13, '#')
    m.rect(147, 3, 158, 12, '#')
    m.col(159, 3, 18, '#')
    m.rect(159, 19, 159, 21, '%')
    m.put(152, 21, 'R')
    m.put(149, 21, '$'); m.put(150, 21, '$')
    m.put(155, 19, 't')
    m.put(156, 21, 'g')
    m.text(162, 21, 'ooo')
    m.put(168, 21, 'A')
    m.put(174, 21, 'W')
    m.row(178, 180, 16, '=')
    m.put(179, 15, 'g')
    m.put(184, 21, 'f')
    m.put(195, 21, 'X')
    m.put(193, 19, 't')
    m.put(186, 19, 't')
    return m


def l4_2():
    m = Map(190, 34)
    m.ceil(0, 189, 2)
    m.ground(0, 189, 29)
    m.put(3, 28, 'P')
    m.put(5, 26, 't')
    m.put(9, 28, '?')                     # hidden passages
    m.text(12, 28, 'ooo')
    m.put(20, 28, 'W')
    m.put(24, 26, 't')
    # Two routes: upper ledges or lower tunnel through a fake wall
    m.ground(28, 70, 26)
    m.row(30, 33, 23, '=')
    m.row(36, 39, 20, '=')
    m.ground(42, 70, 17, bottom=18)
    m.rect(42, 19, 70, 25, ' ')
    m.rect(28, 26, 41, 26, '#')
    m.text(44, 25, 'oooo')
    m.put(52, 25, 'B')
    m.put(60, 23, 't')
    m.rect(68, 21, 69, 25, '%')
    m.clear(70, 21, 77, 25)
    m.put(71, 25, '$'); m.put(72, 25, '$')
    m.put(75, 25, 'T')
    m.put(73, 25, 'g')
    m.put(44, 16, 'A')
    m.put(50, 14, 't')
    m.put(56, 16, 's')
    m.text(60, 16, 'ooo')
    m.put(66, 16, 'K')
    m.ground(71, 120, 17, bottom=20)
    m.ground(78, 120, 21)
    m.put(72, 16, 'f')
    m.put(78, 16, 'G')
    m.put(84, 14, 't')
    m.put(90, 16, 'W')
    m.pit(96, 108, 17)
    m.row(97, 99, 15, '=')
    m.row(102, 104, 14, '=')
    m.row(106, 108, 15, '=')
    m.text(102, 13, 'ooo')
    m.put(103, 10, 't')
    m.ground(109, 120, 17)
    # Inkblot behind a hidden wall in the ceiling
    m.row(112, 114, 13, '=')
    m.row(110, 124, 10, '#')
    m.row(111, 115, 10, '%')
    m.put(118, 9, 'R')
    m.put(114, 7, 't')
    m.text(120, 9, 'oo')
    m.put(122, 9, 'g')
    m.put(124, 16, 'K')
    m.ground(121, 189, 17)
    m.put(130, 16, 'B')
    m.put(138, 14, 't')
    m.put(144, 16, 'A')
    secret_pocket(m, 150, 152, 17)
    m.put(151, 19, 'g')
    m.put(156, 16, 's')
    m.put(162, 16, 'W')
    m.put(168, 14, 't')
    m.text(170, 16, 'ooo')
    m.put(176, 16, 'f')
    m.put(185, 16, 'X')
    m.put(183, 14, 't')
    return m


def l4_3():
    m = Map(128, 26)
    m.ceil(0, 127, 2)
    m.ground(0, 127, 22)
    m.put(3, 21, 'P')
    m.put(5, 19, 't')
    m.text(8, 21, 'ooo')
    m.put(15, 21, 'B')
    m.put(20, 19, 't')
    m.row(24, 26, 18, '=')
    m.put(25, 17, 'g')
    m.put(30, 21, 'W')
    m.put(34, 19, 't')
    m.pit(37, 41, 22)
    m.text(37, 18, 'ooooo')
    m.put(46, 21, 'K')
    m.put(48, 19, 't')
    secret_pocket(m, 52, 54, 22)
    m.put(53, 24, 'g')
    m.put(58, 21, '?')
    m.put(62, 21, 'A')
    m.put(66, 19, 't')
    arena(m, 72, 127, 22, 6, '4')
    m.put(80, 19, 't'); m.put(100, 19, 't'); m.put(118, 19, 't')
    return m


# ---------------------------------------------------------------------------
# Region 5 - The Pale King's Citadel
# ---------------------------------------------------------------------------
def l5_1():
    m = Map(210, 32)
    m.ceil(0, 209, 2)
    m.ground(0, 209, 27)
    m.put(3, 26, 'P')
    m.put(7, 26, '?')
    m.text(10, 26, 'oooo')
    m.put(18, 26, 'G')
    m.ground(24, 40, 24)
    m.put(30, 23, 'A')
    m.put(36, 23, 's')
    m.pit(41, 52, 27)
    m.put(42, 25, 'H'); m.put(48, 25, ':')
    m.text(43, 22, 'ooooo')
    m.ground(53, 80, 24)
    m.put(56, 23, 'K')
    m.put(62, 23, 'W')
    m.put(66, 23, 'O')
    m.put(72, 23, 'G')
    m.row(70, 72, 18, '=')
    m.put(71, 17, 'g')
    # saw corridor and archers on battlements
    m.ground(81, 130, 27)
    m.put(86, 26, 'O')
    m.put(92, 26, 'B')
    m.ground(98, 104, 24)
    m.put(101, 23, 'A')
    m.put(110, 26, 'O')
    m.text(106, 26, 'ooo')
    m.put(116, 26, 'K')
    # Moonpaw on the high battlement (spring)
    m.put(120, 26, 'J')
    m.row(118, 124, 18, '=')
    m.put(121, 17, 'R')
    m.text(118, 17, 'o'); m.text(124, 17, 'o')
    m.ground(131, 209, 24)
    m.put(136, 23, 'W')
    m.put(142, 23, 'G')
    m.put(148, 23, 'O')
    m.pit(152, 164, 24)
    m.put(153, 22, 'H'); m.put(160, 22, ':')
    m.text(154, 19, 'ooooo')
    m.put(168, 23, 'B')
    m.put(174, 23, 'A')
    m.rect(180, 18, 180, 23, '%')
    m.col(180, 3, 17, '#')
    m.rect(181, 18, 186, 23, ' ')
    m.row(181, 186, 17, '#')
    m.col(187, 3, 17, '#')
    m.rect(187, 18, 187, 23, '%')
    m.put(183, 23, '$'); m.put(184, 23, '$')
    m.put(185, 23, 'T')
    m.put(182, 23, 'g')
    m.put(192, 23, 's')
    m.put(196, 23, 'f')
    m.put(205, 23, 'X')
    m.put(203, 21, 't')
    return m


def l5_2():
    m = Map(200, 34)
    m.ceil(0, 199, 2)
    m.ground(0, 199, 29)
    m.put(3, 28, 'P')
    m.put(7, 28, '?')
    m.text(10, 28, 'ooo')
    m.put(16, 28, 'A')
    m.put(22, 28, 'G')
    for x in (26, 32, 38):
        m.put(x, 3, 'd')
    m.put(28, 28, 'F'); m.put(34, 28, 'F')
    m.text(29, 27, 'ooooo')
    m.put(42, 28, 'K')
    # banner hall: tiers
    m.ground(46, 90, 26)
    m.put(50, 25, 'W')
    m.ground(56, 90, 23)
    m.put(60, 22, 'B')
    m.ground(68, 90, 20)
    m.put(72, 19, 'A')
    m.put(80, 19, 'G')
    m.text(84, 19, 'ooo')
    m.row(76, 78, 14, '=')
    m.put(77, 13, 'g')
    m.put(88, 19, 'K')
    # lever gate to the prison wing (Old Tom)
    m.ground(91, 140, 20)
    m.put(96, 19, 's')
    m.put(100, 19, 'O')
    m.col(110, 3, 16, '#')
    m.col(110, 17, 19, 'D')
    m.row(102, 104, 17, '=')
    m.ground(104, 109, 14, bottom=14)
    m.put(107, 13, 'l')
    m.text(105, 13, 'o')
    m.put(115, 19, 'W')
    m.put(122, 19, 'G')
    m.rect(126, 13, 138, 19, ' ')
    m.row(126, 138, 12, '#')
    m.rect(126, 3, 138, 11, '#')
    m.col(139, 3, 16, '#')
    m.col(139, 17, 19, 'D')
    m.put(132, 19, 'R')
    m.put(128, 19, 'f')
    m.text(134, 19, 'oo')
    m.row(124, 126, 17, '=')
    # second lever is inside the wing: opens the way on
    m.put(136, 19, 'l')
    m.ground(140, 199, 20)
    m.put(146, 19, 'K')
    m.put(152, 19, 'B')
    m.pit(158, 170, 20)
    m.put(159, 18, 'H'); m.put(166, 18, ':')
    m.text(160, 15, 'ooooo')
    m.put(174, 19, 'A')
    secret_pocket(m, 178, 180, 20)
    m.put(179, 22, 'g')
    m.put(186, 19, 'W')
    m.put(190, 19, 'f')
    m.put(196, 19, 'X')
    m.put(194, 17, 't')
    return m


def l5_3():
    """The Bell Tower: a vertical climb chased by rising pale fire."""
    m = Map(40, 110)
    m.ground(0, 39, 106)
    m.put(4, 105, 'P')
    m.put(8, 105, '?')
    m.put(12, 105, 'K')
    m.put(18, 104, 'r')          # rising fire starts once you climb above here
    m.text(24, 105, 'ooo')
    # zig-zag climb: platforms every 3 rows
    y = 103
    i = 0
    xs = [(20, 25), (28, 33), (20, 25), (10, 15), (3, 8), (10, 15)]
    while y > 11:
        x0, x1 = xs[i % len(xs)]
        m.row(x0, x1, y, '=')
        if i % 4 == 1:
            m.text(x0 + 1, y - 1, 'oo')
        if i % 9 == 4:
            m.put(x0 + 2, y - 1, 's')
        if i % 11 == 7:
            m.put(x0 + 3, y - 1, 'A')
        i += 1
        y -= 3
    # checkpoints on solid landings
    for cy, x0, x1 in ((79, 1, 8), (52, 31, 38), (25, 1, 8)):
        m.row(x0, x1, cy, '#')
        m.put((x0 + x1) // 2, cy - 1, 'K')
    m.put(4, 78, 'f'); m.put(35, 51, 'f')
    m.row(31, 33, 66, '='); m.put(32, 65, 'g')
    m.row(1, 3, 40, '='); m.put(2, 39, 'g')
    m.row(34, 38, 16, '=')
    m.put(36, 15, 'g')
    m.put(5, 24, 'f')
    # bell chamber
    m.ground(1, 38, 7, bottom=7)
    m.clear(16, 7, 22, 7)
    m.row(16, 22, 7, '=')
    m.row(16, 22, 10, '=')
    m.put(30, 6, 'X')
    m.put(8, 6, 'T')
    m.text(11, 6, 'ooo')
    m.put(20, 3, 'd')
    return m


def l5_final():
    m = Map(70, 26)
    m.ceil(0, 69, 2)
    m.ground(0, 69, 22)
    m.put(3, 21, 'P')
    m.put(7, 21, '?')
    m.put(10, 21, 'K')
    m.put(12, 21, 'f')
    arena(m, 16, 69, 22, 5, '5')
    m.row(22, 26, 17, '=')
    m.row(58, 62, 17, '=')
    m.put(30, 3, 'd'); m.put(54, 3, 'd')
    return m

LEVELS = {
    1: [('L1', l1_1), ('L2', l1_2), ('L3', l1_3)],
    2: [('L1', l2_1), ('L2', l2_2), ('L3', l2_3)],
    3: [('L1', l3_1), ('L2', l3_2), ('L3', l3_3)],
    4: [('L1', l4_1), ('L2', l4_2), ('L3', l4_3)],
    5: [('L1', l5_1), ('L2', l5_2), ('L3', l5_3), ('FINAL', l5_final)],
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
