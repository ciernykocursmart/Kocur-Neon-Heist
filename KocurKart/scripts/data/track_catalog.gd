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
		"medals": [118.0, 128.0, 142.0],
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
