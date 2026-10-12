extends RefCounted
## Static, data-driven definitions: permanent upgrades, rescued cats and
## temporary run blessings. Gameplay code reads values through Progress.

const UPGRADES := {
	"heart": {"name": "Nine Lives Charm", "desc": "+1 maximum heart per level.", "costs": [80, 160, 260], "icon": "heart"},
	"claws": {"name": "Razor Claws", "desc": "+1 claw damage per level.", "costs": [100, 220], "icon": "sword"},
	"pounce": {"name": "Spring Paws", "desc": "Pounce cooldown -0.2s per level.", "costs": [70, 150], "icon": "paw"},
	"heavy": {"name": "Heavy Pounce", "desc": "+2 pounce damage.", "costs": [120], "icon": "speed"},
	"remedy": {"name": "Fishmonger's Recipe", "desc": "Fish heal +half a heart per level.", "costs": [60, 140], "icon": "fish"},
	"fur": {"name": "Thick Fur", "desc": "Start every level with a shield that blocks one hit.", "costs": [180], "icon": "shield"},
	"whiskers": {"name": "Whisker Sense", "desc": "Bigger coin magnet. HUD shows secrets left in the level.", "costs": [90], "icon": "star"},
}
const UPGRADE_ORDER := ["heart", "claws", "pounce", "heavy", "remedy", "fur", "whiskers"]

## Rescued black cats. Each one gives a real, permanent gameplay perk.
const CATS := {
	"pip": {"name": "Pip", "level": "1-2", "color": 0, "perk": "+1 maximum heart."},
	"bramble": {"name": "Bramble", "level": "1-3", "color": 1, "perk": "Camp shop prices -15%."},
	"soot": {"name": "Soot", "level": "2-1", "color": 2, "perk": "+15% coins from pickups."},
	"cinder": {"name": "Cinder", "level": "2-2", "color": 3, "perk": "Spikes and lava deal only half a heart."},
	"nibbles": {"name": "Nibbles", "level": "3-1", "color": 4, "perk": "Pounce cooldown -0.15s."},
	"flurry": {"name": "Flurry", "level": "3-2", "color": 5, "perk": "Checkpoints fully restore health."},
	"whisper": {"name": "Whisper", "level": "4-1", "color": 6, "perk": "Secret walls shimmer faintly."},
	"inkblot": {"name": "Inkblot", "level": "4-2", "color": 7, "perk": "Defeated enemies may drop fish."},
	"moonpaw": {"name": "Moonpaw", "level": "5-1", "color": 8, "perk": "+1 maximum heart."},
	"old_tom": {"name": "Old Tom", "level": "5-2", "color": 9, "perk": "+1 starting shield charge every level."},
}
const CAT_ORDER := ["pip", "bramble", "soot", "cinder", "nibbles", "flurry", "whisper", "inkblot", "moonpaw", "old_tom"]

## Temporary blessings, offered between levels; lost when returning to camp.
const BLESSINGS := {
	"sharp": {"name": "Sharpened Claws", "desc": "+1 claw damage.", "icon": "sword"},
	"swift": {"name": "Swift Paws", "desc": "+12% run speed.", "icon": "speed"},
	"bubble": {"name": "Bubble Charm", "desc": "+1 shield charge at each level start.", "icon": "shield"},
	"tonic": {"name": "Catnip Tonic", "desc": "Fish heal +half a heart more.", "icon": "fish"},
	"lucky": {"name": "Lucky Whiskers", "desc": "+50% coins from pickups.", "icon": "coin"},
	"quick": {"name": "Quick Pounce", "desc": "Pounce cooldown -25%.", "icon": "paw"},
	"spring": {"name": "Moon Spring", "desc": "Jump a little higher.", "icon": "star"},
	"ninth": {"name": "Ninth Life", "desc": "Once: survive a fatal blow with 2 hearts.", "icon": "heart"},
}

const CHALLENGE_NAMES := {
	"secrets": "Find every secret",
	"deathless": "Finish without dying",
	"no_heal": "Defeat the guardian without eating fish",
	"gems": "Collect every Shadow Gem",
}
const CHALLENGE_REWARD := 25
