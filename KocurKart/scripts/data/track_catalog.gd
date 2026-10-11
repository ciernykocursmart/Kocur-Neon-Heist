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
			[0, 0, 0], [0, -70, 0], [4, -130, 1.5], [30, -180, 4], [80, -205, 6.5], [135, -195, 6.5],
			[175, -160, 4], [190, -110, 2], [175, -62, 0.5], [138, -40, 0], [112, -5, 0],
			[118, 38, 0.5], [150, 70, 1.5], [165, 115, 2.5], [140, 158, 3], [85, 170, 2.5],
			[35, 150, 1.5], [8, 105, 0.5], [0, 55, 0],
		],
		"shortcuts": [
			{"points": [[156, 92, 2.0], [128, 118, 2.2], [104, 150, 2.4], [92, 166, 2.5]], "width": 7.5, "surface": "dirt"},
		],
		"pads": [[0.035, 0.0]],
		"ramps": [],
		"hazards": [],
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
