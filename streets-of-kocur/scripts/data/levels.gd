extends RefCounted
## The six streets of the campaign. Each level is a list of encounters
## (arena centre x, waves of enemies, optional boss), plus props, pickups,
## solid obstacles, hazards and tutorial hints. A wave entry is an enemy kind;
## a trailing "<" makes it enter from the left side of the screen.
##
## Rules the level loader relies on (checked by tests/run_tests.gd):
## - encounter x values are increasing and at least 640 px inside the level,
## - every encounter has at least one wave or a boss,
## - pickups/props/obstacles lie inside the level and the street depth.

const LEVELS := [
	{
		"id": "alley", "name": "Alley Trouble", "num": 1, "theme": "alley", "music": "alley",
		"intro": "The White Crown gang stole the neighbourhood's food. Time to take it back.",
		"length": 5300, "depth": [450, 670], "par_time": 360,
		"challenge": {"type": "combo", "value": 8, "text": "Land an 8-hit combo"},
		"hints": [
			{"x": 200, "text": "A/D or ARROWS walk  -  W/S move along the street"},
			{"x": 560, "text": "Food heals! Walk over the fish to eat it"},
			{"x": 760, "text": "J = attack. Tap J three times for the paw-claw-WHAM combo"},
			{"x": 1500, "text": "SPACE = jump. J in the air = flying kick (jumps over thrown things too)"},
			{"x": 2300, "text": "K = PAWQUAKE spin. Costs one blue bar of the special meter"},
			{"x": 2750, "text": "E next to a gang cat = grab. J = knee, E = throw him into his friends"},
			{"x": 3350, "text": "Double-tap a direction (or hold SHIFT) to run, J while running = pounce"},
		],
		"encounters": [
			{"x": 1000, "waves": [["punk"], ["punk", "punk<"]]},
			{"x": 1950, "waves": [["punk", "punk"], ["punk<", "punk", "punk"]]},
			{"x": 2900, "waves": [["punk", "punk<"], ["punk", "punk", "punk<"]]},
			{"x": 3750, "waves": [["punk", "punk<"], ["punk", "punk", "punk<"]]},
			{"x": 4650, "waves": [["punk", "punk<", "punk"], ["punk", "punk<"], ["punk", "punk<", "punk"]], "final": true},
		],
		"pickups": [{"kind": "fish", "x": 640, "y": 600}],
		"props": [
			{"kind": "crate", "x": 1420, "y": 480, "drop": "fish"},
			{"kind": "trashcan", "x": 2450, "y": 650, "drop": "yarn"},
			{"kind": "crate", "x": 3220, "y": 470, "drop": "golden"},
			{"kind": "barrel", "x": 3380, "y": 645, "drop": "chicken"},
			{"kind": "trashcan", "x": 4000, "y": 470, "drop": ""},
			{"kind": "crate", "x": 4250, "y": 640, "drop": "fish"},
		],
		"obstacles": [],
		"hazards": [],
	},
	{
		"id": "market", "name": "Market Mayhem", "num": 2, "theme": "market", "music": "market",
		"intro": "The gang is looting the street market. Fast runners and big brawlers ahead.",
		"length": 6300, "depth": [455, 675], "par_time": 480,
		"challenge": {"type": "damage", "value": 60, "text": "Take at most 60 damage"},
		"hints": [
			{"x": 800, "text": "RUNNERS sprint around you and kick from the side. Keep them in front!"},
			{"x": 2800, "text": "BRAWLERS shrug off single hits. Finish your combos on them"},
		],
		"encounters": [
			{"x": 1000, "waves": [["punk", "runner"], ["punk<", "punk"]]},
			{"x": 1950, "waves": [["runner", "runner<"], ["punk", "punk", "runner<"]]},
			{"x": 2950, "waves": [["brawler"], ["punk", "punk<"]]},
			{"x": 3850, "waves": [["runner", "punk<", "punk"], ["brawler", "runner<"]]},
			{"x": 4750, "waves": [["runner", "brawler<"], ["punk", "punk<", "runner"]]},
			{"x": 5650, "waves": [["brawler", "punk<"], ["runner", "runner<", "punk"], ["brawler", "brawler<"]], "final": true},
		],
		"pickups": [{"kind": "fish", "x": 1500, "y": 640}],
		"props": [
			{"kind": "stall", "x": 1350, "y": 472, "drop": "chicken"},
			{"kind": "crate", "x": 2380, "y": 640, "drop": "fish"},
			{"kind": "stall", "x": 3300, "y": 472, "drop": "yarn"},
			{"kind": "barrel", "x": 3420, "y": 655, "drop": "golden"},
			{"kind": "crate", "x": 4260, "y": 480, "drop": "can"},
			{"kind": "barrel", "x": 5200, "y": 650, "drop": "fish"},
			{"kind": "stall", "x": 6000, "y": 472, "drop": ""},
		],
		"obstacles": [],
		"hazards": [],
	},
	{
		"id": "neon", "name": "Neon Boulevard", "num": 3, "theme": "neon", "music": "neon",
		"intro": "Night falls on the boulevard. Throwers on the corners, Slick Whiskers runs this block.",
		"length": 6700, "depth": [460, 680], "par_time": 560,
		"challenge": {"type": "no_special", "value": 0, "text": "Clear the street without PAWQUAKE"},
		"hints": [
			{"x": 800, "text": "THROWERS keep their distance. Step off their line or jump the bottle"},
			{"x": 1900, "text": "Sparking puddles shock anyone standing in them when they flash - gang cats too"},
		],
		"encounters": [
			{"x": 1000, "waves": [["thrower"], ["punk", "punk<"]]},
			{"x": 2000, "waves": [["thrower", "punk", "punk<"], ["runner", "runner<"]]},
			{"x": 3000, "waves": [["thrower", "thrower<"], ["brawler", "punk"]]},
			{"x": 4000, "waves": [["runner", "thrower", "punk<"], ["brawler", "thrower<"]]},
			{"x": 5000, "waves": [["thrower", "thrower<", "runner"], ["brawler", "punk<", "punk"]]},
			{"x": 6060, "waves": [], "boss": "slick", "final": true},
		],
		"pickups": [{"kind": "fish", "x": 1580, "y": 660}],
		"props": [
			{"kind": "crate", "x": 1230, "y": 480, "drop": "fish"},
			{"kind": "barrel", "x": 2480, "y": 660, "drop": "chicken"},
			{"kind": "crate", "x": 3330, "y": 510, "drop": "golden"},
			{"kind": "trashcan", "x": 4470, "y": 650, "drop": "can"},
			{"kind": "barrel", "x": 4560, "y": 480, "drop": "fish"},
			{"kind": "crate", "x": 5520, "y": 500, "drop": "chicken"},
		],
		"obstacles": [
			{"kind": "barrier", "x0": 1400, "x1": 1500, "y0": 460, "y1": 540},
			{"kind": "barrier", "x0": 2620, "x1": 2720, "y0": 600, "y1": 680},
			{"kind": "barrier", "x0": 3620, "x1": 3720, "y0": 460, "y1": 550},
		],
		"hazards": [
			{"kind": "puddle", "x": 2150, "y": 610, "w": 70, "h": 22, "period": 3.0, "on": 1.0, "offset": 0.0},
			{"kind": "puddle", "x": 3150, "y": 520, "w": 70, "h": 22, "period": 3.0, "on": 1.0, "offset": 1.5},
			{"kind": "puddle", "x": 4250, "y": 640, "w": 80, "h": 24, "period": 3.2, "on": 1.1, "offset": 0.7},
		],
	},
	{
		"id": "industrial", "name": "Industrial Paws", "num": 4, "theme": "industrial", "music": "industrial",
		"intro": "Warehouses, cranes and crushers. The gang's muscle guards the yard.",
		"length": 7100, "depth": [450, 670], "par_time": 640,
		"challenge": {"type": "combo", "value": 15, "text": "Land a 15-hit combo"},
		"hints": [
			{"x": 800, "text": "ENFORCERS can't be grabbed and ignore light hits. Watch for the red glow, then strike"},
			{"x": 1800, "text": "Hydraulic presses slam down when the light turns red. Lure the gang under them!"},
		],
		"encounters": [
			{"x": 1000, "waves": [["punk", "punk<"], ["enforcer"]]},
			{"x": 2050, "waves": [["runner", "runner<", "punk"], ["thrower", "enforcer<"]]},
			{"x": 3250, "waves": [["brawler", "thrower"], ["enforcer", "punk<", "punk"]]},
			{"x": 4350, "waves": [["runner", "runner<", "thrower"], ["enforcer", "brawler<"]]},
			{"x": 5450, "waves": [["enforcer", "enforcer<"], ["runner", "thrower<", "punk"]]},
			{"x": 6450, "waves": [], "boss": "bruno", "final": true},
		],
		"pickups": [{"kind": "chicken", "x": 1650, "y": 640}],
		"props": [
			{"kind": "drum", "x": 1250, "y": 650, "drop": "fish"},
			{"kind": "crate", "x": 2550, "y": 480, "drop": "chicken"},
			{"kind": "drum", "x": 3700, "y": 640, "drop": "golden"},
			{"kind": "crate", "x": 4800, "y": 480, "drop": "can"},
			{"kind": "drum", "x": 4900, "y": 650, "drop": "fish"},
			{"kind": "drum", "x": 5950, "y": 480, "drop": "chicken"},
		],
		"obstacles": [
			{"kind": "crates", "x0": 1400, "x1": 1560, "y0": 450, "y1": 545},
			{"kind": "crates", "x0": 2800, "x1": 2960, "y0": 585, "y1": 670},
			{"kind": "crates", "x0": 3900, "x1": 4060, "y0": 450, "y1": 540},
		],
		"hazards": [
			{"kind": "press", "x": 2250, "y": 560, "w": 60, "h": 40, "period": 3.4, "on": 0.5, "offset": 0.0},
			{"kind": "press", "x": 3450, "y": 600, "w": 60, "h": 40, "period": 3.0, "on": 0.5, "offset": 1.2},
			{"kind": "press", "x": 4550, "y": 520, "w": 60, "h": 40, "period": 3.2, "on": 0.5, "offset": 2.0},
		],
	},
	{
		"id": "hq", "name": "White Crown Headquarters", "num": 5, "theme": "hq", "music": "hq",
		"intro": "The gang's fortress. Gate, courtyard, kitchens, guard hall - then the General.",
		"length": 7500, "depth": [455, 675], "par_time": 760,
		"challenge": {"type": "damage", "value": 120, "text": "Take at most 120 damage"},
		"hints": [
			{"x": 400, "text": "Everything you've learned, all at once. Use the doorways to fight one side at a time"},
		],
		"encounters": [
			{"x": 1000, "waves": [["punk", "punk<", "thrower"], ["brawler", "runner<"]], "label": "Front Gate"},
			{"x": 2000, "waves": [["enforcer", "thrower<"], ["runner", "runner<", "punk"]], "label": "Courtyard"},
			{"x": 3000, "waves": [["brawler", "brawler<"], ["thrower", "thrower<", "punk"]], "label": "Kitchens"},
			{"x": 4000, "waves": [["enforcer", "runner<", "punk"], ["brawler", "thrower<"], ["enforcer<"]], "label": "Guard Hall"},
			{"x": 5000, "waves": [["runner", "runner<", "runner"], ["punk", "punk<", "brawler", "thrower<"]], "label": "Lift Lobby"},
			{"x": 6000, "waves": [["enforcer", "brawler<"], ["thrower", "thrower<", "runner", "punk"]], "label": "Armory"},
			{"x": 6860, "waves": [], "boss": "snowmane", "final": true, "label": "Throne Room"},
		],
		"pickups": [{"kind": "fish", "x": 1520, "y": 620}],
		"props": [
			{"kind": "crate", "x": 1350, "y": 480, "drop": "chicken"},
			{"kind": "barrel", "x": 2470, "y": 655, "drop": "fish"},
			{"kind": "crate", "x": 3420, "y": 480, "drop": "can"},
			{"kind": "trashcan", "x": 3520, "y": 650, "drop": "golden"},
			{"kind": "barrel", "x": 4450, "y": 650, "drop": "chicken"},
			{"kind": "crate", "x": 5420, "y": 480, "drop": "can"},
			{"kind": "barrel", "x": 6420, "y": 650, "drop": "chicken"},
		],
		"obstacles": [
			{"kind": "pillar", "x0": 1450, "x1": 1510, "y0": 455, "y1": 520},
			{"kind": "pillar", "x0": 2560, "x1": 2620, "y0": 610, "y1": 675},
			{"kind": "pillar", "x0": 4560, "x1": 4620, "y0": 455, "y1": 520},
		],
		"hazards": [
			{"kind": "puddle", "x": 2200, "y": 520, "w": 70, "h": 22, "period": 3.0, "on": 1.0, "offset": 0.0},
			{"kind": "press", "x": 3200, "y": 600, "w": 60, "h": 40, "period": 3.4, "on": 0.5, "offset": 0.8},
			{"kind": "puddle", "x": 4200, "y": 640, "w": 80, "h": 24, "period": 3.0, "on": 1.0, "offset": 1.3},
			{"kind": "press", "x": 4800, "y": 520, "w": 60, "h": 40, "period": 3.0, "on": 0.5, "offset": 0.3},
		],
	},
	{
		"id": "showdown", "name": "The Fat Cat Showdown", "num": 6, "theme": "pantry", "music": "hq", "boss_music": "final",
		"intro": "The Golden Pantry. Every stolen snack in town is piled up here - and so is Lord Lardpaw.",
		"length": 4700, "depth": [455, 680], "par_time": 520,
		"challenge": {"type": "no_death", "value": 0, "text": "Beat the boss without losing a life"},
		"hints": [
			{"x": 3350, "text": "Lardpaw is huge but slow. Dodge the telegraphed move, then punish while he huffs"},
		],
		"encounters": [
			{"x": 1000, "waves": [["enforcer", "punk<"], ["brawler", "runner<", "thrower"], ["enforcer<", "runner"]], "label": "Bodyguards"},
			{"x": 2100, "waves": [["brawler", "brawler<"], ["runner", "runner<", "thrower"], ["enforcer"]], "label": "Kitchen Guard"},
			{"x": 4060, "waves": [], "boss": "lardpaw", "final": true, "label": "The Golden Pantry"},
		],
		"pickups": [{"kind": "fish", "x": 600, "y": 620}],
		"props": [
			{"kind": "barrel", "x": 1550, "y": 650, "drop": "fish"},
			{"kind": "crate", "x": 2750, "y": 480, "drop": "can"},
			{"kind": "barrel", "x": 2900, "y": 650, "drop": "chicken"},
			{"kind": "crate", "x": 3100, "y": 600, "drop": "golden"},
		],
		"obstacles": [],
		"hazards": [],
	},
]


static func count() -> int:
	return LEVELS.size()


static func get_level(i: int) -> Dictionary:
	return LEVELS[clampi(i, 0, LEVELS.size() - 1)]


static func food_total(i: int) -> int:
	var lv := get_level(i)
	var n := 0
	for p: Dictionary in lv["pickups"]:
		if p["kind"] in ["fish", "chicken", "can"]:
			n += 1
	for p: Dictionary in lv["props"]:
		if p.get("drop", "") in ["fish", "chicken", "can"]:
			n += 1
	return n


static func has_boss(i: int) -> bool:
	for e: Dictionary in get_level(i)["encounters"]:
		if e.has("boss"):
			return true
	return false
