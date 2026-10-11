class_name TrackCatalog
extends RefCounted
## All six circuits and the three Grand Prix cups.
##
## Track points are [x, z, height, width] in metres; the start/finish line is
## at the first point, driving towards the second. Feature positions use the
## fraction of a lap (0..1) along the main circuit.
## medals: Time Trial targets for a 3-lap run in seconds (gold, silver, bronze).

const CUPS := [
	{"id": "cup1", "name": "Whisker Cup", "tracks": ["whiskerwood", "purrport"], "color": Color(0.35, 0.75, 0.35)},
	{"id": "cup2", "name": "Moonlight Cup", "tracks": ["neon", "frostpaw"], "color": Color(0.35, 0.6, 1.0)},
	{"id": "cup3", "name": "Royal Cup", "tracks": ["safari", "royal"], "color": Color(0.85, 0.55, 1.0)},
]

const ORDER := ["whiskerwood", "purrport", "neon", "frostpaw", "safari", "royal"]

const TRACKS := {
	"whiskerwood": {
		"name": "Whiskerwood Circuit", "theme": "woods", "laps": 3, "width": 14.0,
		"blurb": "A friendly forest loop with sweeping bends, a gentle hill and a hidden dirt path.",
		"points": [
			[0, 0, 0], [0, -60, 0], [2, -115, 1], [18, -160, 3], [55, -192, 5.5], [105, -200, 6.5], [148, -196, 6.5],
			[176, -180, 5.5], [188, -152, 4.5], [178, -126, 3.5], [152, -120, 2.5], [126, -112, 1.5], [112, -86, 1],
			[118, -55, 0.5], [142, -30, 0.5], [150, 5, 0.5], [132, 35, 0.5], [112, 62, 1], [122, 98, 1.5],
			[150, 118, 2], [160, 148, 2.5], [138, 172, 3], [96, 176, 2.5], [52, 162, 1.5], [22, 130, 0.5],
			[6, 90, 0], [0, 45, 0],
		],
		"shortcuts": [
			{"points": [[124, 112, 1.6], [106, 126, 1.9], [114, 146, 2.2], [98, 162, 2.4], [80, 172, 2.5]], "width": 7.5, "surface": "dirt"},
		],
		"pads": [[0.035, 0.0]],
		"ramps": [],
		"hazards": [],
		"landmarks": [["windmill", 60, -115, 30], ["treehouse", -48, -60, 0], ["cat_totem", 70, 78, 200],
			["cabin", -32, 40, 80], ["cabin", 222, -128, -90], ["cabin", 95, 20, 10]],
		"gates": [[0.52, "wood_arch"]],
		"stand_side": -1,
		"checkpoints": 10,
		"medals": [117.5, 126.0, 137.5],
	},
	"purrport": {
		"name": "Purrport Pier", "theme": "pier", "laps": 3, "width": 13.0, "ground_y": 0.0,
		"blurb": "Salt air, wooden piers and open edges above the harbour. Mind the crabs!",
		"points": [
			[0, 0, 2], [0, -60, 2], [6, -108, 2], [32, -140, 2], [80, -152, 2], [140, -152, 2], [196, -150, 2],
			[232, -136, 2], [250, -108, 2], [244, -78, 2], [218, -60, 2], [170, -56, 2], [122, -56, 2],
			[88, -44, 2], [74, -14, 2], [86, 18, 2], [74, 50, 2], [42, 66, 2], [14, 52, 2], [2, 24, 2],
		],
		"land": [[-110, -128, 64, 110, 2.0], [262, -132, 300, -70, 2.0]],
		"open": [[0.27, 0.36, 1], [0.6, 0.7, 1]],
		"pads": [[0.21, 0.0], [0.64, -2.5]],
		"hazards": [
			{"type": "sweeper", "f": 0.66, "amplitude": 0.75, "period": 4.2, "radius": 1.3, "model": "crab"},
			{"type": "sweeper", "f": 0.71, "amplitude": 0.75, "period": 3.6, "phase": 2.0, "radius": 1.3, "model": "crab"},
		],
		"landmarks": [["lighthouse", 280, -100, 0], ["crane", 30, -95, 90], ["ship", 150, -105, 90], ["fish_market", 30, 20, 90],
			["boat", 120, -200, 30], ["boat", 230, -10, 120]],
		"gates": [[0.17, "pier_banner"]],
		"stand_side": -1,
		"checkpoints": 10,
		"medals": [85.5, 91.5, 100.0],
	},
	"neon": {
		"name": "Neon Catway", "theme": "neon", "laps": 3, "width": 14.0, "ground_y": -10.0,
		"blurb": "A glowing night run across the rooftops of Kat City, with a leap between towers.",
		"points": [
			[0, 0, 0], [0, -70, 0], [3, -112, 0], [24, -138, 0], [62, -146, 0], [112, -146, 2.5], [160, -146, 6],
			[204, -142, 8], [228, -122, 8.5], [234, -92, 8.5], [233, -55, 8], [230, -20, 6], [222, 12, 3.5],
			[196, 32, 1.5], [160, 38, 0], [128, 30, 0], [98, 44, 0], [66, 34, 0], [36, 48, 0],
			[10, 36, 0], [1, 14, 0],
		],
		"gaps": [[0.5165, 0.5295]],
		"ramps": [[0.505, 0.0, 13.0, 9.0, 1.7]],
		"pads": [[0.488, 0.0], [0.05, -3.0], [0.05, 3.0], [0.8, 0.0]],
		"hazards": [
			{"type": "sweeper", "f": 0.25, "amplitude": 0.7, "period": 3.4, "radius": 1.2, "model": "drone"},
			{"type": "sweeper", "f": 0.62, "amplitude": 0.7, "period": 3.0, "phase": 1.5, "radius": 1.2, "model": "drone"},
		],
		"landmarks": [["neon_cat", 120, -90, 0], ["billboard", 270, -100, -90], ["billboard", -40, -60, 90]],
		"gates": [[0.12, "neon_arch", 4], [0.7, "neon_arch", 3]],
		"stand_side": 1,
		"checkpoints": 10,
		"medals": [85.5, 91.5, 100.0],
	},
	"frostpaw": {
		"name": "Frostpaw Pass", "theme": "snow", "laps": 3, "width": 14.0,
		"blurb": "Climb to the icy summit tunnel and keep your paws steady on the frozen descent.",
		"points": [
			[0, 0, 0], [0, -70, 1], [8, -128, 3], [40, -168, 6], [92, -182, 9], [140, -170, 12], [166, -136, 14],
			[162, -98, 16], [134, -76, 17], [96, -80, 18], [64, -66, 18], [52, -32, 17], [68, 4, 15],
			[108, 22, 12], [150, 28, 9], [184, 52, 7], [190, 96, 5], [164, 132, 3], [114, 142, 2],
			[64, 128, 1], [26, 98, 0], [6, 52, 0],
		],
		"ice": [[0.37, 0.47], [0.75, 0.82]],
		"pads": [[0.6, 0.0]],
		"hazards": [
			{"type": "sweeper", "f": 0.55, "amplitude": 0.7, "period": 4.6, "radius": 1.4, "model": "snowball"},
		],
		"landmarks": [["cable_car", -60, -80, 70], ["observatory", 120, -120, 0], ["chalet", 230, 60, -90], ["chalet", -40, 60, 90]],
		"gates": [[0.405, "ice_tunnel", 6]],
		"stand_side": -1,
		"checkpoints": 10,
		"medals": [119.5, 128.0, 139.5],
	},
	"safari": {
		"name": "Sunset Safari", "theme": "safari", "laps": 3, "width": 15.0,
		"blurb": "Red earth, giant rocks and a dune jump under a burning sunset sky.",
		"points": [
			[0, 0, 0], [0, -80, 0], [-8, -138, 1], [8, -188, 2], [52, -216, 3], [108, -214, 4.5], [150, -200, 6],
			[170, -170, 5], [160, -144, 4], [140, -130, 3], [134, -106, 2], [154, -82, 2], [208, -50, 3], [250, -18, 3],
			[248, 30, 2.5], [214, 62, 1.5], [168, 58, 1], [140, 76, 1], [112, 106, 1], [72, 112, 1], [40, 92, 0.5], [14, 60, 0],
		],
		"ramps": [[0.30, 0.0, 14.0, 9.0, 1.5]],
		"shortcuts": [
			{"points": [[208, -42, 3.0], [218, -18, 3.0], [230, 10, 2.8], [238, 34, 2.5]], "width": 8.0, "surface": "dirt"},
		],
		"pads": [[0.255, 0.0], [0.77, 0.0]],
		"hazards": [
			{"type": "static", "f": 0.12, "lateral": -4.5, "radius": 2.2, "model": "boulder"},
			{"type": "static", "f": 0.135, "lateral": 4.5, "radius": 2.2, "model": "boulder"},
			{"type": "sweeper", "f": 0.62, "amplitude": 0.75, "period": 4.0, "radius": 1.1, "model": "tumbleweed"},
			{"type": "sweeper", "f": 0.85, "amplitude": 0.7, "period": 3.4, "phase": 1.0, "radius": 1.1, "model": "tumbleweed"},
		],
		"landmarks": [["cat_rock", 80, -140, 200], ["watchtower", 210, 20, 0], ["hut", -40, -40, 0], ["hut", -46, -10, 40], ["giraffe", 110, 30, 60]],
		"gates": [[0.45, "rock_arch"]],
		"stand_side": -1,
		"checkpoints": 10,
		"medals": [107.5, 115.0, 125.5],
	},
	"royal": {
		"name": "Royal Catnip Run", "theme": "royal", "laps": 3, "width": 14.0, "ground_y": -3.0,
		"blurb": "The championship finale through the palace gardens: hairpins, a moat leap and the royal gate.",
		"points": [
			[0, 0, 0], [0, -80, 0], [6, -132, 1], [36, -165, 2], [84, -172, 3], [126, -158, 3], [150, -126, 3],
			[146, -92, 3], [118, -78, 2.5], [90, -92, 2], [66, -116, 2], [40, -112, 2], [34, -82, 2],
			[60, -50, 2.5], [108, -40, 3], [160, -46, 4], [206, -30, 4], [232, 6, 3.5], [226, 50, 2.5],
			[192, 76, 1.5], [146, 82, 1], [104, 98, 1], [62, 112, 0.5], [26, 92, 0], [6, 50, 0],
		],
		"gaps": [[0.5432, 0.5522]],
		"ramps": [[0.535, 0.0, 13.0, 9.0, 1.6]],
		"shortcuts": [
			{"points": [[212, -22, 3.8], [210, 10, 3.2], [204, 44, 2.4], [194, 68, 1.6]], "width": 7.0, "surface": "dirt"},
		],
		"pads": [[0.518, 0.0], [0.07, 0.0], [0.86, -3.0], [0.86, 3.0]],
		"hazards": [
			{"type": "sweeper", "f": 0.33, "amplitude": 0.65, "period": 4.4, "radius": 1.2, "model": "guard"},
			{"type": "sweeper", "f": 0.74, "amplitude": 0.65, "period": 3.8, "phase": 2.2, "radius": 1.2, "model": "guard"},
		],
		"landmarks": [["castle", 90, -250, 0], ["throne_cat", 90, -120, 180], ["fountain_big", 100, 30, 0], ["fountain", 260, -80, 0]],
		"gates": [[0.4, "royal_gate"], [0.95, "royal_gate"]],
		"stand_side": -1,
		"checkpoints": 12,
		"medals": [119.5, 127.5, 139.5],
	},
}


static func get_track(id: String) -> Dictionary:
	var d: Dictionary = TRACKS.get(id, {})
	if d.is_empty():
		return d
	d = d.duplicate(true)
	d["id"] = id
	return d


static func track_name(id: String) -> String:
	return String(TRACKS.get(id, {}).get("name", id))


static func cup(id: String) -> Dictionary:
	for c in CUPS:
		if c["id"] == id:
			return c
	return {}


static func cup_name(id: String) -> String:
	return String(cup(id).get("name", id))


static func cup_of_track(track_id: String) -> String:
	for c in CUPS:
		if track_id in c["tracks"]:
			return c["id"]
	return ""
