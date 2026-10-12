extends RefCounted
## Static definitions: hero classes, hero roster, enemy archetypes, abilities,
## upgrades and difficulty modifiers. Pure data, no game state.

# --------------------------------------------------------------------------
# Abilities
# kind: "attack" (single target), "pounce", "area", "heal", "stance"
# rmin/rmax: Manhattan range. los: needs clear line of sight.
# power: added to the user's ATK (attack/area/pounce) or the heal amount.
# cd: turns before it can be used again (0 = every turn).
# --------------------------------------------------------------------------
const ABILITIES := {
	"claw": {"name": "Claw Strike", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0,
		"desc": "Reliable melee attack on an adjacent enemy. ATK damage."},
	"pounce": {"name": "Shadow Pounce", "kind": "pounce", "rmin": 1, "rmax": 3, "los": true, "power": 2, "cd": 2,
		"desc": "Leap up to 3 tiles (needs line of sight; jumps over units and water, never walls). Click an enemy to land beside it and strike for ATK+2, or an empty tile to just reposition. Cooldown 2."},
	"strike": {"name": "Strike", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0,
		"desc": "Solid melee attack on an adjacent enemy. ATK damage."},
	"heavy": {"name": "Heavy Strike", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 4, "cd": 0,
		"no_move": true, "desc": "Crushing melee blow for ATK+4. Only if the Guardian has NOT moved this turn."},
	"stance": {"name": "Protective Stance", "kind": "stance", "rmin": 0, "rmax": 0, "los": false, "power": 3, "cd": 1,
		"desc": "Until your next turn: Guardian +3 DEF, and every ally standing next to the Guardian +2 DEF. Cooldown 1."},
	"shot": {"name": "Aimed Shot", "kind": "attack", "rmin": 2, "rmax": 5, "los": true, "power": 0, "cd": 0,
		"steady": 2, "desc": "Ranged attack, range 2-5, needs line of sight. ATK damage, +2 if the Ranger has not moved this turn (Steady). Hills add +1 range."},
	"volley": {"name": "Volley", "kind": "area", "rmin": 2, "rmax": 4, "los": true, "power": -1, "cd": 2,
		"desc": "Rain arrows on a tile 2-4 away (line of sight): hits enemies on it and the 4 tiles around it for ATK-1. Never hits allies. Cooldown 2."},
	"swipe": {"name": "Paw Swipe", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0,
		"desc": "Light melee attack on an adjacent enemy. ATK damage."},
	"mend": {"name": "Mend", "kind": "heal", "rmin": 1, "rmax": 3, "los": false, "power": 8, "cd": 1,
		"desc": "Heal another ally within 3 tiles for 8 HP. Cooldown 1."},
	# enemy abilities
	"jab": {"name": "Spear Jab", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0, "desc": "Melee attack."},
	"bash": {"name": "Shield Bash", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0, "desc": "Melee attack."},
	"arrow": {"name": "Arrow", "kind": "attack", "rmin": 2, "rmax": 4, "los": true, "power": 0, "cd": 0, "desc": "Ranged attack, range 2-4, needs line of sight."},
	"frost": {"name": "Frost Bolt", "kind": "attack", "rmin": 2, "rmax": 4, "los": true, "power": 0, "cd": 0,
		"chill": true, "desc": "Ranged attack, range 2-4 (line of sight). Chills the target: -2 MOV on its next turn."},
	"mend_ally": {"name": "Pale Blessing", "kind": "heal", "rmin": 1, "rmax": 3, "los": false, "power": 6, "cd": 2,
		"desc": "Heals another White Crown unit within 3 tiles for 6 HP. Cooldown 2."},
	"ambush": {"name": "Ambush", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0,
		"isolated": 2, "desc": "Melee attack, +2 damage if the target has no allies next to it."},
	"iron_claw": {"name": "Iron Claw", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0, "desc": "Melee attack."},
	"royal_claw": {"name": "Royal Claw", "kind": "attack", "rmin": 1, "rmax": 1, "los": false, "power": 0, "cd": 0, "desc": "Melee attack."},
}

# --------------------------------------------------------------------------
# Hero classes
# --------------------------------------------------------------------------
const CLASSES := {
	"shadowblade": {"name": "Shadowblade", "role": "Mobile melee - flanks and finishes weak enemies.",
		"hp": 20, "atk": 7, "def": 1, "move": 5, "abilities": ["claw", "pounce"]},
	"guardian": {"name": "Guardian", "role": "Frontline defender - holds choke points and protects allies.",
		"hp": 30, "atk": 6, "def": 4, "move": 3, "abilities": ["strike", "heavy", "stance"]},
	"ranger": {"name": "Ranger", "role": "Ranged damage - needs line of sight, fragile up close (cannot shoot adjacent enemies).",
		"hp": 16, "atk": 6, "def": 0, "move": 4, "abilities": ["shot", "volley"]},
	"mender": {"name": "Mender", "role": "Support - heals allies and patches the line.",
		"hp": 18, "atk": 4, "def": 1, "move": 4, "abilities": ["swipe", "mend"]},
	"elder": {"name": "Elder", "role": "Escort target - cannot fight. Keep him alive!",
		"hp": 18, "atk": 0, "def": 1, "move": 3, "abilities": []},
}

## Persistent hero identities. "start": in the squad from the beginning.
## "joins": mission id after whose victory the hero joins (rescued).
const HEROES := {
	"nox": {"name": "Nox", "class": "shadowblade", "start": true,
		"bio": "A quick-pawed scout who never lands on the wrong foot."},
	"bramble": {"name": "Bramble", "class": "guardian", "start": true,
		"bio": "Big, calm and very hard to move. Carries a lid as a shield."},
	"willow": {"name": "Willow", "class": "ranger", "start": true,
		"bio": "Shadowwood's best shot. Has opinions about wind."},
	"moss": {"name": "Moss", "class": "mender", "start": false, "joins": "m03",
		"bio": "Valley herbalist. Smells faintly of catnip and courage."},
	"soot": {"name": "Soot", "class": "shadowblade", "start": false, "joins": "m06",
		"bio": "Escaped Ironpaw's dungeon by being extremely flat."},
	"pepper": {"name": "Pepper", "class": "ranger", "start": false, "joins": "m08",
		"bio": "Former border lookout. Sneezes before every critical moment."},
}
const HERO_ORDER := ["nox", "bramble", "willow", "moss", "soot", "pepper"]

# --------------------------------------------------------------------------
# Enemy archetypes (White Crown Legion) and objects
# ai: behaviour profile used by core/ai.gd
# --------------------------------------------------------------------------
const ENEMIES := {
	"recruit": {"name": "White Recruit", "hp": 10, "atk": 5, "def": 0, "move": 4, "abilities": ["jab"], "ai": "melee",
		"desc": "Basic spear cat. Charges the nearest reachable hero."},
	"guard": {"name": "White Guard", "hp": 16, "atk": 5, "def": 3, "move": 3, "abilities": ["bash"], "ai": "guard",
		"shield_wall": 1, "desc": "Durable. Shield Wall: White Crown allies next to it get +1 DEF. Stays close to archers and mages."},
	"archer": {"name": "White Archer", "hp": 10, "atk": 5, "def": 0, "move": 4, "abilities": ["arrow"], "ai": "ranged",
		"desc": "Range 2-4, needs line of sight. Keeps its distance and loves hills."},
	"mage": {"name": "White Mage", "hp": 11, "atk": 4, "def": 0, "move": 3, "abilities": ["frost", "mend_ally"], "ai": "caster",
		"desc": "Frost Bolt (range 2-4) chills: -2 MOV next turn. Heals wounded allies for 6."},
	"stalker": {"name": "White Stalker", "hp": 12, "atk": 5, "def": 1, "move": 6, "abilities": ["ambush"], "ai": "flanker",
		"pathfinder": true, "desc": "Fast. Ignores terrain movement costs. +2 damage against heroes with no ally next to them."},
	"ironpaw": {"name": "Ironpaw Commander", "hp": 52, "atk": 8, "def": 4, "move": 3, "abilities": ["iron_claw"], "ai": "ironpaw",
		"boss": true, "desc": "Telegraphs Crushing Blow on 3 tiles, then is Exhausted (DEF 0) for a turn. Raises Iron Guard at half health."},
	"king": {"name": "The Pale King", "hp": 70, "atk": 8, "def": 2, "move": 3, "abilities": ["royal_claw"], "ai": "king",
		"boss": true, "desc": "Phase 1: shielded by Crown Pylons, fires the Royal Lance down a marked line. Phase 2: leaves the throne and casts Pale Nova."},
	"pylon": {"name": "Crown Pylon", "hp": 12, "atk": 0, "def": 0, "move": 0, "abilities": [], "ai": "object", "object": true,
		"desc": "Shields the Pale King while it stands. Cannot act."},
	"moonwell": {"name": "Moonwell", "hp": 30, "atk": 0, "def": 2, "move": 0, "abilities": [], "ai": "object", "object": true,
		"desc": "The valley's sacred spring. Protect it! Cannot act."},
}

const ENEMY_CHARS := {"r": "recruit", "g": "guard", "a": "archer", "m": "mage", "s": "stalker", "I": "ironpaw", "K": "king", "Y": "pylon"}

# --------------------------------------------------------------------------
# Progression
# --------------------------------------------------------------------------
const XP_PER_LEVEL := 100
const MAX_LEVEL := 6
const LEVEL_HP := 2  ## +2 max HP per level above 1
const LEVEL_ATK_AT := [3, 5]  ## +1 ATK at these levels

## Upgrade costs per rank, in Relic Shards.
const UPGRADES := {
	"vitality": {"name": "Vitality", "desc": "+3 max HP per rank", "costs": [2, 3, 4]},
	"power": {"name": "Sharp Claws", "desc": "+1 ATK per rank", "costs": [3, 5]},
	"armor": {"name": "Thick Fur", "desc": "+1 DEF per rank", "costs": [3, 5]},
	"agility": {"name": "Swift Paws", "desc": "+1 MOV", "costs": [5]},
	"special": {"name": "Class Mastery", "desc": "", "costs": [4]},
}
const UPGRADE_ORDER := ["vitality", "power", "armor", "agility", "special"]
const SPECIAL_DESC := {
	"shadowblade": "Shadow Pounce range +1 and +1 damage",
	"guardian": "Protective Stance has no cooldown, allies get +3 DEF instead of +2",
	"ranger": "Volley cooldown 2 -> 1",
	"mender": "Mend heals +4 more",
}

# --------------------------------------------------------------------------
# Difficulty: deterministic modifiers applied to enemies at spawn
# --------------------------------------------------------------------------
const DIFFICULTIES := ["story", "normal", "hard"]
const DIFFICULTY_INFO := {
	"story": {"name": "Story", "enemy_atk": -2, "enemy_hp": 0.8, "desc": "Enemies deal 2 less damage and have 20% less HP."},
	"normal": {"name": "Normal", "enemy_atk": 0, "enemy_hp": 1.0, "desc": "The intended challenge."},
	"hard": {"name": "Hard", "enemy_atk": 1, "enemy_hp": 1.2, "desc": "Enemies deal 1 more damage and have 20% more HP."},
}


static func ability(id: String) -> Dictionary:
	return ABILITIES.get(id, {})


static func hero_level_for_xp(xp: int) -> int:
	return clampi(1 + xp / XP_PER_LEVEL, 1, MAX_LEVEL)


## Final stats for a hero from its class, level and purchased upgrades.
static func hero_stats(hero_id: String, level: int, upgrades: Dictionary) -> Dictionary:
	var h: Dictionary = HEROES[hero_id]
	var c: Dictionary = CLASSES[h["class"]]
	var s := {"hp": int(c["hp"]), "atk": int(c["atk"]), "def": int(c["def"]), "move": int(c["move"])}
	s["hp"] += LEVEL_HP * (level - 1)
	for l: int in LEVEL_ATK_AT:
		if level >= l:
			s["atk"] += 1
	s["hp"] += 3 * int(upgrades.get("vitality", 0))
	s["atk"] += int(upgrades.get("power", 0))
	s["def"] += int(upgrades.get("armor", 0))
	s["move"] += int(upgrades.get("agility", 0))
	return s
