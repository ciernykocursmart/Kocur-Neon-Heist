extends RefCounted
## Campaign definition: 5 regions x 3 levels, plus the final encounter.
## Maps are generated into scripts/data/maps by tools/build_maps.py.

const R1 := preload("res://scripts/data/maps/region1.gd")
const R2 := preload("res://scripts/data/maps/region2.gd")
const R3 := preload("res://scripts/data/maps/region3.gd")
const R4 := preload("res://scripts/data/maps/region4.gd")
const R5 := preload("res://scripts/data/maps/region5.gd")
const LevelGrid := preload("res://scripts/world/level_grid.gd")

const REGION_NAMES := ["Mossroot Catacombs", "Emberpaw Mines", "Frostfang Crypt", "Shadowclaw Depths",
	"Pale King's Citadel"]
const REGION_INTROS := [
	"The white-cat clan dragged your friends into the old catacombs. Moss, roots and rusted traps await.",
	"Below the catacombs, the clan works the Emberpaw Mines. Mind the lava and the machinery.",
	"The Frostfang Crypt is slick with ice. Every step slides - plan your landings.",
	"No torch burns in the Shadowclaw Depths for long. Trust your whiskers and the lantern light.",
	"The Pale King waits atop his marble citadel. Free the last captives and end his reign.",
]

const LEVELS := [
	{"id": "1-1", "region": 1, "name": "Mossy Steps", "music": "r1", "map": R1.L1, "cat": "",
		"signs": ["A / D or Arrows to run. SPACE to jump - hold it to jump higher.",
			"Mind the spikes! Jump the gap.",
			"Claws out! Press J (or Left Mouse) to swipe at the white scouts.",
			"Catnip lanterns are checkpoints. Touch one to light it.",
			"Pounce with K (or Right Mouse). Hold W / Up while pouncing to leap upward - a great way to reach high ledges!",
			"Doors lead onward. Stand at the door and press E."]},
	{"id": "1-2", "region": 1, "name": "Root Hollow", "music": "r1", "map": R1.L2, "cat": "pip",
		"signs": ["Someone is meowing deep in the hollow... find the cage and press E to break it open.",
			"Cracked stones crumble soon after you step on them. Keep moving!",
			"A White Guard! Its shield blocks claws from the front. Pounce through it, or strike from behind.",
			"Some walls are not what they seem. Secret rooms hide treasure."]},
	{"id": "1-3", "region": 1, "name": "The Iron Gate", "music": "r1", "map": R1.L3, "cat": "bramble",
		"boss": "mouser", "relic_name": "Moss Relic",
		"signs": ["Pull levers (E) to open iron gates.",
			"Beyond lies the Iron Mouser. Dodge its slam, then strike while it is stuck!"]},
	{"id": "2-1", "region": 2, "name": "Cinder Shafts", "music": "r2", "map": R2.L1, "cat": "soot",
		"signs": ["Flame jets puff smoke before they fire. Watch the rhythm.",
			"Guards hold the mines. Remember: pounce through shields, or strike from behind!"]},
	{"id": "2-2", "region": 2, "name": "Bellows Deep", "music": "r2", "map": R2.L2, "cat": "cinder",
		"signs": ["Mine lifts carry you over the lava.",
			"Archers loose arrows after drawing their bows. Swipe arrows out of the air!",
			"Some floors are as fake as some walls! Tip: hold S / Down + SPACE to drop through thin platforms."]},
	{"id": "2-3", "region": 2, "name": "The Forge Heart", "music": "r2", "map": R2.L3, "cat": "",
		"boss": "ember", "relic_name": "Ember Relic",
		"signs": ["The Ember Guardian's hammer leaves fire in its wake. Watch the warning marks!"]},
	{"id": "3-1", "region": 3, "name": "Rime Gallery", "music": "r3", "map": R3.L1, "cat": "nibbles",
		"signs": ["Ice is slippery: you speed up and slow down gradually on it.",
			"Icicles shiver before they fall.",
			"The Frost Matron's hall is near. Rest at camp if you need more upgrades."]},
	{"id": "3-2", "region": 3, "name": "Icicle Vaults", "music": "r3", "map": R3.L2, "cat": "flurry",
		"signs": ["White Mages mark the floor with runes before they erupt. Step away!",
			"Springs launch you high. Land on them from above."]},
	{"id": "3-3", "region": 3, "name": "Matron's Hall", "music": "r3", "map": R3.L3, "cat": "",
		"boss": "frost", "relic_name": "Frost Relic",
		"signs": ["The Frost Matron rains icicles. Look up for the warning sparkle."]},
	{"id": "4-1", "region": 4, "name": "Lightless Way", "music": "r4", "map": R4.L1, "cat": "whisper", "dark": true,
		"signs": ["It is dark down here. Torches and your own glow light the way.",
			"The White Beast charges after it roars. Let it crash into a wall, then pounce!"]},
	{"id": "4-2", "region": 4, "name": "Hollow Echoes", "music": "r4", "map": R4.L2, "cat": "inkblot", "dark": true,
		"signs": ["Hidden passages are everywhere in the Depths. Explore every corner."]},
	{"id": "4-3", "region": 4, "name": "Stalker's Den", "music": "r4", "map": R4.L3, "cat": "", "dark": true,
		"boss": "stalker", "relic_name": "Shadow Relic",
		"signs": ["Something prowls in the dark ahead. Its eyes flash before it leaps."]},
	{"id": "5-1", "region": 5, "name": "Marble Ramparts", "music": "r5", "map": R5.L1, "cat": "moonpaw",
		"signs": ["The citadel guard is the best the clan has. Use everything you have learned."]},
	{"id": "5-2", "region": 5, "name": "Hall of Banners", "music": "r5", "map": R5.L2, "cat": "old_tom",
		"signs": ["The last captive is held somewhere in these halls."]},
	{"id": "5-3", "region": 5, "name": "The Bell Tower", "music": "boss", "map": R5.L3, "cat": "", "rise_speed": 17.0,
		"signs": ["The King has set the tower ablaze with pale fire. Climb, little cat, CLIMB!"]},
	{"id": "final", "region": 5, "name": "The Pale Throne", "music": "r5", "map": R5.FINAL, "cat": "",
		"boss": "king", "relic_name": "Pale Crown",
		"signs": ["The Pale King awaits. This is it."]},
]


static func count() -> int:
	return LEVELS.size()


static func index_of(id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return -1


static func get_level(id: String) -> Dictionary:
	var i := index_of(id)
	return LEVELS[i] if i >= 0 else LEVELS[0]


static func level_title(id: String) -> String:
	var m := get_level(id)
	return ("FINAL" if id == "final" else id) + "  " + str(m["name"])


static var _totals := {}


## Collectible totals parsed from a level's map: {"gems", "secrets", "coins", "cat"}.
static func totals(id: String) -> Dictionary:
	if _totals.has(id):
		return _totals[id]
	var g := LevelGrid.new()
	g.parse(get_level(id)["map"])
	var t := {"gems": g.entities_of("g").size(), "secrets": g.components("$", true).size(),
		"coins": g.entities_of("o").size(), "cat": str(get_level(id).get("cat", ""))}
	_totals[id] = t
	return t


static func all_gems() -> int:
	var n := 0
	for lv in LEVELS:
		n += int(totals(lv["id"])["gems"])
	return n


static func all_secrets() -> int:
	var n := 0
	for lv in LEVELS:
		n += int(totals(lv["id"])["secrets"])
	return n
