class_name Palette
extends RefCounted
## Shared neon colour palette. Keep every gameplay colour here so the visual
## identity stays coherent and easy to retune.

const BG := Color(0.02, 0.02, 0.05)
const FLOOR := Color(0.055, 0.055, 0.11)
const FLOOR_ALT := Color(0.065, 0.06, 0.125)
const GRID := Color(0.25, 0.35, 0.8, 0.10)
const WALL := Color(0.085, 0.075, 0.16)
const WALL_TOP := Color(0.13, 0.11, 0.24)
const CRATE := Color(0.11, 0.09, 0.15)

const CYAN := Color(0.25, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.25, 0.78)
const PURPLE := Color(0.62, 0.38, 1.0)
const YELLOW := Color(1.0, 0.86, 0.25)
const ORANGE := Color(1.0, 0.56, 0.18)
const RED := Color(1.0, 0.24, 0.32)
const GREEN := Color(0.32, 1.0, 0.58)
const WHITE := Color(0.92, 0.95, 1.0)
const DIM := Color(0.55, 0.6, 0.8)

const ROOM_ACCENTS := [CYAN, MAGENTA, PURPLE, Color(0.3, 0.6, 1.0), Color(0.2, 1.0, 0.8)]


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
