class_name Catalog
extends RefCounted
## Racers, kart bodies and cosmetics. Every unlockable states exactly how it
## is earned via an `unlock` rule that Progression evaluates:
##   ""                       available from the start
##   "cup:<id>"               finish that Grand Prix cup with any trophy
##   "cup_gold:<id>"          win that cup with a gold trophy
##   "medal:<track>:<tier>"   earn at least that Time Trial medal (bronze/silver/gold)
##   "golds:<n>"              earn n gold Time Trial medals in total
##   "champion"               finish all three cups
##   "hard_champion"          finish all three cups on Hard

const RACERS := {
	"kocur": {"name": "Kocur", "desc": "The black cat of Kocur Studios. Calm, clever, fast.",
		"fur": Color(0.09, 0.09, 0.11), "fur2": Color(0.2, 0.2, 0.24), "eyes": Color(0.98, 0.82, 0.15), "pattern": "solid", "unlock": ""},
	"marmalade": {"name": "Marmalade", "desc": "Ginger tabby with endless confidence.",
		"fur": Color(0.95, 0.55, 0.2), "fur2": Color(0.99, 0.9, 0.78), "eyes": Color(0.35, 0.8, 0.3), "pattern": "tabby", "unlock": ""},
	"duchess": {"name": "Duchess", "desc": "A snow-white aristocrat who hates losing.",
		"fur": Color(0.96, 0.95, 0.93), "fur2": Color(0.98, 0.8, 0.85), "eyes": Color(0.3, 0.6, 1.0), "pattern": "solid", "unlock": "cup:cup1"},
	"tux": {"name": "Tux", "desc": "Tuxedo cat, always dressed for the podium.",
		"fur": Color(0.12, 0.12, 0.14), "fur2": Color(0.97, 0.97, 0.97), "eyes": Color(0.55, 0.9, 0.35), "pattern": "tuxedo", "unlock": "cup:cup2"},
	"sushi": {"name": "Sushi", "desc": "Calico chaos on four wheels.",
		"fur": Color(0.97, 0.94, 0.88), "fur2": Color(0.92, 0.5, 0.18), "eyes": Color(0.95, 0.65, 0.15), "pattern": "calico", "unlock": "champion"},
	"ziggy": {"name": "Ziggy", "desc": "Siamese speed-demon from Neon Catway.",
		"fur": Color(0.93, 0.86, 0.74), "fur2": Color(0.32, 0.22, 0.18), "eyes": Color(0.25, 0.55, 1.0), "pattern": "points", "unlock": "golds:3"},
	"pepper": {"name": "Pepper", "desc": "Grey shorthair, a quiet tactician.",
		"fur": Color(0.5, 0.52, 0.56), "fur2": Color(0.78, 0.8, 0.84), "eyes": Color(0.95, 0.7, 0.2), "pattern": "solid", "unlock": "ai"},
	"biscuit": {"name": "Biscuit", "desc": "Cream-coloured and always snacking.",
		"fur": Color(0.95, 0.82, 0.62), "fur2": Color(0.99, 0.95, 0.88), "eyes": Color(0.6, 0.4, 0.2), "pattern": "tabby", "unlock": "ai"},
}

## Playable racer order in the garage. Pepper and Biscuit are rivals only.
const PLAYABLE := ["kocur", "marmalade", "duchess", "tux", "sushi", "ziggy"]

## AI personalities: pace (corner speed share), line (how tight to the racing
## line), drift (likelihood of drifting long corners), aggression (holding a
## line next to rivals), consistency (fewer small mistakes).
const RIVALS := {
	"kocur": {"kart": "alley", "paint": "midnight", "pace": 1.0, "drift": 0.8, "aggression": 0.5, "consistency": 0.9},
	"marmalade": {"kart": "thunder", "paint": "tangerine", "pace": 1.0, "drift": 0.6, "aggression": 0.8, "consistency": 0.75},
	"duchess": {"kart": "pounce", "paint": "rose", "pace": 0.99, "drift": 0.9, "aggression": 0.3, "consistency": 0.95},
	"tux": {"kart": "alley", "paint": "snow", "pace": 0.995, "drift": 0.7, "aggression": 0.6, "consistency": 0.9},
	"sushi": {"kart": "pounce", "paint": "lime", "pace": 0.985, "drift": 0.5, "aggression": 0.9, "consistency": 0.7},
	"ziggy": {"kart": "thunder", "paint": "cyan", "pace": 1.0, "drift": 1.0, "aggression": 0.5, "consistency": 0.85},
	"pepper": {"kart": "alley", "paint": "steel", "pace": 0.99, "drift": 0.6, "aggression": 0.4, "consistency": 1.0},
	"biscuit": {"kart": "thunder", "paint": "sunny", "pace": 0.98, "drift": 0.4, "aggression": 0.7, "consistency": 0.8},
}

## Small, balanced stat differences. The starter is an all-rounder that is
## fully capable of winning the championship.
const KARTS := {
	"alley": {"name": "Alley Racer", "desc": "Balanced all-rounder. The kart that started it all.",
		"stats": {"speed": 1.0, "accel": 1.0, "handling": 1.0, "drift": 1.0, "weight": 1.0}, "unlock": ""},
	"pounce": {"name": "Pounce", "desc": "Light and nimble: quick off the line, sharp in turns.",
		"stats": {"speed": 0.985, "accel": 1.1, "handling": 1.07, "drift": 1.06, "weight": 0.88}, "unlock": "cup:cup1"},
	"thunder": {"name": "Thunderpaw", "desc": "Heavy bruiser with a higher top speed.",
		"stats": {"speed": 1.025, "accel": 0.92, "handling": 0.94, "drift": 0.96, "weight": 1.2}, "unlock": "cup:cup2"},
}
const KART_ORDER := ["alley", "pounce", "thunder"]

const PAINTS := {
	"crimson": {"name": "Crimson", "color": Color(0.86, 0.14, 0.18), "unlock": ""},
	"midnight": {"name": "Midnight", "color": Color(0.16, 0.18, 0.32), "unlock": ""},
	"tangerine": {"name": "Tangerine", "color": Color(0.98, 0.5, 0.1), "unlock": ""},
	"cyan": {"name": "Cyan Spark", "color": Color(0.1, 0.75, 0.9), "unlock": ""},
	"lime": {"name": "Catnip Lime", "color": Color(0.45, 0.85, 0.2), "unlock": "medal:whiskerwood:silver"},
	"rose": {"name": "Rose", "color": Color(0.95, 0.45, 0.65), "unlock": "medal:purrport:silver"},
	"snow": {"name": "Snow", "color": Color(0.94, 0.95, 0.97), "unlock": "medal:frostpaw:silver"},
	"sunny": {"name": "Sunny", "color": Color(0.98, 0.82, 0.2), "unlock": "medal:safari:silver"},
	"steel": {"name": "Steel", "color": Color(0.55, 0.58, 0.62), "unlock": "cup:cup1"},
	"royal": {"name": "Royal Purple", "color": Color(0.5, 0.2, 0.75), "unlock": "cup_gold:cup3"},
	"gold": {"name": "Champion Gold", "color": Color(0.95, 0.75, 0.2), "unlock": "hard_champion"},
}
const PAINT_ORDER := ["crimson", "midnight", "tangerine", "cyan", "steel", "lime", "rose", "snow", "sunny", "royal", "gold"]

const WHEELS := {
	"classic": {"name": "Classic", "unlock": ""},
	"sport": {"name": "Sport Rims", "unlock": "cup:cup1"},
	"chunky": {"name": "Chunky Treads", "unlock": "medal:neon:silver"},
	"neon": {"name": "Neon Rims", "unlock": "medal:neon:gold"},
}
const WHEEL_ORDER := ["classic", "sport", "chunky", "neon"]

const ACCESSORIES := {
	"none": {"name": "None", "unlock": ""},
	"scarf": {"name": "Racing Scarf", "unlock": ""},
	"goggles": {"name": "Goggles", "unlock": "cup:cup1"},
	"headphones": {"name": "Headphones", "unlock": "medal:neon:bronze"},
	"flower": {"name": "Catnip Flower", "unlock": "cup_gold:cup1"},
	"crown": {"name": "Royal Crown", "unlock": "champion"},
}
const ACCESSORY_ORDER := ["none", "scarf", "goggles", "headphones", "flower", "crown"]


static func unlock_text(rule: String) -> String:
	if rule == "":
		return "Available"
	var parts := rule.split(":")
	match parts[0]:
		"cup":
			return "Finish %s in Grand Prix" % TrackCatalog.cup_name(parts[1])
		"cup_gold":
			return "Win gold in %s" % TrackCatalog.cup_name(parts[1])
		"medal":
			return "Earn %s medal in %s Time Trial" % [parts[2].capitalize(), TrackCatalog.track_name(parts[1])]
		"golds":
			return "Earn %s gold Time Trial medals" % parts[1]
		"champion":
			return "Finish all three cups"
		"hard_champion":
			return "Finish all three cups on Hard"
		"ai":
			return "Rival racer"
	return rule
