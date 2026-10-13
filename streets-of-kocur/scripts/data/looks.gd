extends RefCounted
## Visual identity of every cat: fur, outfit pieces and body proportions.
## Read by CatPainter. Silhouettes differ per archetype, not only colours.

const WHITE_OL := Color("2a2235")

const LOOKS := {
	# Kocur, the hero: black fur, light rim outline, red scarf, golden eyes.
	"hero": {"fur": Color("1c1824"), "fur_back": Color("110e17"), "belly": Color("2e2838"), "outline": Color("b9a8e8"),
		"eye": Color("ffd23a"), "acc": ["scarf"], "accent": Color("e8413c"), "ear_inner": Color("5a3550"),
		"whisker": Color("d9d0f0"), "bw": 1.0, "bh": 1.0, "hr": 1.05, "legs": 1.0},
	"punk": {"fur": Color("f4f1ea"), "belly": Color("ffffff"), "outline": WHITE_OL, "eye": Color("8fd0ff"),
		"acc": ["mohawk", "vest"], "accent": Color("ff4fa0"), "brows": true, "bw": 0.95, "bh": 0.95, "hr": 1.0},
	"brawler": {"fur": Color("ece8df"), "belly": Color("fbfaf6"), "outline": WHITE_OL, "eye": Color("ff9a3a"),
		"acc": ["tank", "wraps"], "accent": Color("3a8f5a"), "accent2": Color("e8d9b0"), "brows": true,
		"bw": 1.35, "bh": 1.1, "hr": 0.95, "legs": 0.95, "arms": 1.1, "limb_w": 1.35},
	"runner": {"fur": Color("f7f5ef"), "belly": Color("ffffff"), "outline": WHITE_OL, "eye": Color("9cff7a"),
		"acc": ["track", "headband", "sneakers"], "accent": Color("ffc21a"), "brows": true, "bw": 0.82, "bh": 0.92,
		"hr": 0.92, "legs": 1.2, "limb_w": 0.85, "tail": 1.25},
	"thrower": {"fur": Color("efece4"), "belly": Color("ffffff"), "outline": WHITE_OL, "eye": Color("c08aff"),
		"acc": ["hood"], "accent": Color("4a6fd8"), "brows": true, "bw": 1.0, "bh": 1.0, "hr": 1.0},
	"enforcer": {"fur": Color("e6e3dc"), "belly": Color("f6f4ef"), "outline": WHITE_OL, "eye": Color("ff3a3a"),
		"acc": ["helmet", "armor", "belt"], "accent": Color("d83a3a"), "accent2": Color("7d8796"), "brows": true,
		"bw": 1.4, "bh": 1.2, "hr": 0.9, "legs": 0.9, "arms": 1.05, "limb_w": 1.45},
	"slick": {"fur": Color("faf8f2"), "belly": Color("ffffff"), "outline": WHITE_OL, "eye": Color("ff4fd8"),
		"acc": ["jacket", "shades", "chain"], "accent": Color("8a3ad8"), "bw": 0.95, "bh": 1.0, "hr": 1.0,
		"legs": 1.15, "tail": 1.3},
	"bruno": {"fur": Color("e9e4da"), "belly": Color("f8f5ee"), "outline": WHITE_OL, "eye": Color("ffb03a"),
		"acc": ["tank", "wrench", "cap", "eyepatch"], "accent": Color("e0782a"), "accent2": Color("e8d9b0"),
		"brows": true, "bw": 1.45, "bh": 1.25, "hr": 0.95, "legs": 0.9, "arms": 1.15, "limb_w": 1.5},
	"snowmane": {"fur": Color("f8f6f0"), "belly": Color("ffffff"), "outline": WHITE_OL, "eye": Color("5ad8ff"),
		"acc": ["mane", "armor", "spear"], "accent": Color("3a6ad8"), "accent2": Color("c8ccd6"), "brows": true,
		"bw": 1.2, "bh": 1.15, "hr": 1.0, "legs": 1.0, "limb_w": 1.2},
	"lardpaw": {"fur": Color("fbf9f4"), "fur_back": Color("ddd8cf"), "belly": Color("fff4e4"), "outline": WHITE_OL,
		"eye": Color("ff5a3a"), "acc": ["crown", "chain"], "accent": Color("d83a6a"), "brows": true,
		"bw": 2.45, "bh": 1.7, "hr": 1.35, "legs": 0.62, "arms": 0.95, "limb_w": 1.7, "tail": 0.8},
}


static func get_look(kind: String) -> Dictionary:
	return LOOKS.get(kind, LOOKS["punk"])
