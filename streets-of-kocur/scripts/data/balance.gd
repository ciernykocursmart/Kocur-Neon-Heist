extends RefCounted
## Balance tables: difficulty, player moves, enemy archetypes, food.
## All numbers are tuned for the Normal difficulty; Easy/Hard scale them.

const DIFFICULTIES := ["easy", "normal", "hard"]
const DIFFICULTY_INFO := {
	"easy": {"name": "Easy", "enemy_hp": 0.8, "enemy_dmg": 0.6, "attackers": 1, "lives": 5, "continues": -1,
		"score": 0.75, "aggro": 0.75, "desc": "Gentler gang: weaker hits, one attacker at a time, 5 lives, unlimited continues."},
	"normal": {"name": "Normal", "enemy_hp": 1.0, "enemy_dmg": 1.0, "attackers": 2, "lives": 3, "continues": 3,
		"score": 1.0, "aggro": 1.0, "desc": "The intended arcade challenge: 3 lives and 3 continues per street."},
	"hard": {"name": "Hard", "enemy_hp": 1.25, "enemy_dmg": 1.3, "attackers": 3, "lives": 2, "continues": 2,
		"score": 1.5, "aggro": 1.25, "desc": "Tough gang, three attackers at once, 2 lives, 2 continues per street. Score x1.5."},
}

## Player tuning (pixels, seconds). Depth = vertical position on the street.
const PLAYER := {
	"max_hp": 100.0,
	"walk_x": 250.0, "walk_y": 160.0, "run_x": 410.0,
	"accel": 2400.0, "decel": 2800.0,
	"jump_v": 560.0, "gravity": 1700.0,
	"hurt_invuln": 0.9, "getup_invuln": 1.3, "respawn_invuln": 2.5,
	"energy_max": 100.0, "special_cost": 50.0, "energy_per_hit": 5.0, "energy_when_hurt": 6.0, "energy_regen": 2.5,
	"combo_grace": 0.28, "grab_time": 1.6,
}

## Player moves. x0/x1: hitbox reach in front of the cat (negative = behind),
## depth: +- street depth the hit covers, z0/z1: covered heights above the feet.
const MOVES := {
	"jab": {"startup": 0.06, "active": 0.07, "recovery": 0.14, "dmg": 6.0, "x0": -4.0, "x1": 62.0, "depth": 18.0,
		"z0": 15.0, "z1": 85.0, "kb": 70.0, "stun": 0.34, "lunge": 50.0, "sound": "jab", "type": "light"},
	"swipe": {"startup": 0.07, "active": 0.08, "recovery": 0.16, "dmg": 8.0, "x0": -4.0, "x1": 70.0, "depth": 20.0,
		"z0": 10.0, "z1": 90.0, "kb": 90.0, "stun": 0.38, "lunge": 70.0, "sound": "swipe", "type": "light"},
	"finisher": {"startup": 0.11, "active": 0.1, "recovery": 0.34, "dmg": 14.0, "x0": -4.0, "x1": 78.0, "depth": 22.0,
		"z0": 0.0, "z1": 95.0, "kb": 380.0, "launch": 330.0, "knockdown": true, "stun": 0.5, "lunge": 130.0,
		"sound": "heavy", "type": "heavy"},
	"jump_kick": {"startup": 0.05, "active": 0.4, "recovery": 0.0, "dmg": 11.0, "x0": -6.0, "x1": 66.0, "depth": 20.0,
		"z0": -70.0, "z1": 60.0, "kb": 280.0, "launch": 260.0, "knockdown": true, "stun": 0.5, "sound": "swipe",
		"type": "heavy"},
	"pounce": {"startup": 0.05, "active": 0.24, "recovery": 0.3, "dmg": 12.0, "x0": -4.0, "x1": 70.0, "depth": 20.0,
		"z0": 0.0, "z1": 90.0, "kb": 340.0, "launch": 280.0, "knockdown": true, "stun": 0.5, "sound": "heavy",
		"type": "heavy"},
	"pawquake": {"startup": 0.12, "active": 0.26, "recovery": 0.3, "dmg": 18.0, "radial": true, "rx": 125.0,
		"depth": 48.0, "z0": -10.0, "z1": 120.0, "kb": 420.0, "launch": 380.0, "knockdown": true, "stun": 0.6,
		"sound": "special", "type": "special"},
	"knee": {"startup": 0.06, "active": 0.06, "recovery": 0.16, "dmg": 5.0, "sound": "jab", "type": "light"},
	"throw": {"dmg": 14.0, "thrown_dmg": 12.0, "speed": 560.0, "launch": 300.0},
}

## Enemy archetypes. dmg = per hit, range = preferred attack distance.
const ENEMIES := {
	"punk": {"name": "White Street Punk", "hp": 32.0, "speed": 125.0, "dmg": 7.0, "range": 52.0, "windup": 0.38,
		"cooldown": 1.25, "score": 100, "scale": 1.0, "hurt_w": 20.0, "armor": 0, "grab": true},
	"brawler": {"name": "White Brawler", "hp": 75.0, "speed": 85.0, "dmg": 11.0, "range": 60.0, "windup": 0.5,
		"cooldown": 1.7, "score": 250, "scale": 1.22, "hurt_w": 26.0, "armor": 0, "poise": 2, "grab": true},
	"runner": {"name": "White Runner", "hp": 26.0, "speed": 235.0, "dmg": 7.0, "range": 130.0, "windup": 0.28,
		"cooldown": 1.5, "score": 150, "scale": 0.95, "hurt_w": 18.0, "armor": 0, "grab": true},
	"thrower": {"name": "White Thrower", "hp": 24.0, "speed": 115.0, "dmg": 9.0, "range": 320.0, "windup": 0.5,
		"cooldown": 2.0, "score": 150, "scale": 1.0, "hurt_w": 20.0, "armor": 0, "grab": true},
	"enforcer": {"name": "White Enforcer", "hp": 130.0, "speed": 72.0, "dmg": 18.0, "range": 72.0, "windup": 0.75,
		"cooldown": 2.2, "score": 400, "scale": 1.42, "hurt_w": 30.0, "armor": 1, "grab": false},
}

## Bosses: hp, scale, score bonus. Their attacks live in scripts/bosses/.
const BOSSES := {
	"slick": {"name": "SLICK WHISKERS", "title": "Neon Lieutenant", "hp": 300.0, "scale": 1.12, "score": 5000,
		"hurt_w": 22.0, "dmg": 12.0},
	"bruno": {"name": "BIG BRUNO BOLTPAW", "title": "Foreman of the Yard", "hp": 420.0, "scale": 1.55,
		"score": 8000, "hurt_w": 34.0, "dmg": 17.0},
	"snowmane": {"name": "GENERAL SNOWMANE", "title": "Commander of the White Crown", "hp": 520.0, "scale": 1.35,
		"score": 10000, "hurt_w": 28.0, "dmg": 15.0},
	"lardpaw": {"name": "LORD LARDPAW", "title": "The Fat Cat Boss", "hp": 800.0, "scale": 2.1, "score": 25000,
		"hurt_w": 62.0, "dmg": 18.0},
}

## Food and score pickups.
const PICKUPS := {
	"fish": {"name": "Fish", "heal": 20.0, "score": 50},
	"chicken": {"name": "Chicken", "heal": 40.0, "score": 100},
	"can": {"name": "Cat food can", "heal": 70.0, "score": 150},
	"golden": {"name": "Golden Fish", "heal": 0.0, "score": 3000, "energy": 100.0},
	"yarn": {"name": "Yarn ball", "heal": 0.0, "score": 500},
}
const FOOD_KINDS := ["fish", "chicken", "can"]

const EXTRA_LIFE_EVERY := 40000
const MAX_LIVES := 9
const COMBO_TIMEOUT := 1.3


static func diff(d: String) -> Dictionary:
	return DIFFICULTY_INFO.get(d, DIFFICULTY_INFO["normal"])
