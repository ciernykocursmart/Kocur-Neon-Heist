extends Node
## Persistent progress (autoload "Save").
##
## Stored as versioned JSON in user://save.json. Writes are crash-safe: the
## new data goes to save.tmp first, the previous save is kept as save.bak,
## then the temp file is moved into place. Loading falls back
## save.json -> save.tmp -> save.bak -> defaults, and every value is
## validated against the defaults so a damaged or hand-edited file can never
## crash the game or inject wrong types.

signal saved

const VERSION := 1
const DIR := "user://"
const FILE := "save.json"

var data: Dictionary = {}
var load_status := "new"   ## new | loaded | recovered | reset_corrupt
var path_override := ""    ## tests use a separate folder


func _ready() -> void:
	load_game()


func base_dir() -> String:
	return path_override if path_override != "" else DIR


func _path(name: String) -> String:
	return base_dir().path_join(name)


static func defaults() -> Dictionary:
	var cups := {}
	for c in TrackCatalog.CUPS:
		cups[c["id"]] = {"trophy": 0, "best_points": 0, "trophy_easy": 0, "trophy_normal": 0, "trophy_hard": 0}
	var records := {}
	for t in TrackCatalog.ORDER:
		records[t] = {"tt_time": 0.0, "tt_lap": 0.0, "tt_medal": 0, "race_time": 0.0, "race_lap": 0.0, "wins": 0}
	return {
		"version": VERSION,
		"cups": cups,
		"records": records,
		"selection": {"racer": "kocur", "kart": "alley", "paint": "crimson", "wheels": "classic", "accessory": "scarf"},
		"stats": {"races": 0, "wins": 0, "podiums": 0, "distance_km": 0.0, "cups_finished": 0, "time_trials": 0},
		"recent": [],
		"seen_unlocks": [],
		"last_difficulty": "normal",
		"last_laps": 3,
	}


func load_game() -> void:
	var candidates := [FILE, "save.tmp", "save.bak"]
	for i in candidates.size():
		var parsed = _read_json(_path(candidates[i]))
		if parsed is Dictionary:
			data = sanitize(parsed)
			load_status = "loaded" if i == 0 else "recovered"
			if i > 0:
				save_game()
			return
	var existed := FileAccess.file_exists(_path(FILE))
	data = defaults()
	if existed:
		# Keep the unreadable file for inspection, then start fresh.
		DirAccess.copy_absolute(_path(FILE), _path("save.corrupt.json"))
		load_status = "reset_corrupt"
		save_game()
	else:
		load_status = "new"


func _read_json(p: String):
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


func save_game() -> bool:
	data["version"] = VERSION
	DirAccess.make_dir_recursive_absolute(base_dir())
	var tmp := _path("save.tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	# Verify what was written before replacing the real save.
	if not (_read_json(tmp) is Dictionary):
		return false
	var main := _path(FILE)
	if FileAccess.file_exists(main):
		DirAccess.copy_absolute(main, _path("save.bak"))
		DirAccess.remove_absolute(main)
	var err := DirAccess.rename_absolute(tmp, main)
	if err != OK:
		err = DirAccess.copy_absolute(tmp, main)
	saved.emit()
	return err == OK


## Wipes all progress, records, ghosts and selections (settings are kept).
func reset_progress() -> void:
	data = defaults()
	for f in ["save.bak", "save.tmp"]:
		if FileAccess.file_exists(_path(f)):
			DirAccess.remove_absolute(_path(f))
	for t in TrackCatalog.ORDER:
		var gp := _path("ghost_%s.json" % t)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
	save_game()


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Returns a copy of `raw` conformed to the default structure: unknown keys
## are dropped, wrong types replaced by defaults, numbers clamped.
static func sanitize(raw: Dictionary) -> Dictionary:
	var d := defaults()
	var out: Dictionary = _conform(raw, d)
	# Semantic checks.
	for cid in out["cups"]:
		var c: Dictionary = out["cups"][cid]
		for k in c:
			if k.begins_with("trophy"):
				c[k] = clampi(int(c[k]), 0, 3)
		c["best_points"] = clampi(int(c["best_points"]), 0, 1000)
	for tid in out["records"]:
		var r: Dictionary = out["records"][tid]
		for k in ["tt_time", "tt_lap", "race_time", "race_lap"]:
			var v := float(r[k])
			r[k] = v if v > 5.0 and v < 3600.0 else 0.0
		r["tt_medal"] = clampi(int(r["tt_medal"]), 0, 3)
		r["wins"] = maxi(int(r["wins"]), 0)
	var sel: Dictionary = out["selection"]
	if not Catalog.RACERS.has(sel["racer"]) or not (sel["racer"] in Catalog.PLAYABLE):
		sel["racer"] = "kocur"
	if not Catalog.KARTS.has(sel["kart"]):
		sel["kart"] = "alley"
	if not Catalog.PAINTS.has(sel["paint"]):
		sel["paint"] = "crimson"
	if not Catalog.WHEELS.has(sel["wheels"]):
		sel["wheels"] = "classic"
	if not Catalog.ACCESSORIES.has(sel["accessory"]):
		sel["accessory"] = "none"
	if not (out["last_difficulty"] in ["easy", "normal", "hard"]):
		out["last_difficulty"] = "normal"
	out["last_laps"] = clampi(int(out["last_laps"]), 1, 5)
	var recent: Array = []
	for r in out["recent"]:
		if r is Dictionary and r.has("track") and r.has("position"):
			recent.append(r)
	out["recent"] = recent.slice(0, 12)
	var seen: Array = []
	for s in out["seen_unlocks"]:
		if s is String:
			seen.append(s)
	out["seen_unlocks"] = seen
	out["version"] = VERSION
	return out


static func _conform(raw, def):
	if def is Dictionary:
		var out := {}
		var src: Dictionary = raw if raw is Dictionary else {}
		for k in def:
			out[k] = _conform(src.get(k), def[k]) if src.has(k) else _dup(def[k])
		return out
	if def is Array:
		return raw.duplicate(true) if raw is Array else def.duplicate(true)
	if def is float:
		return float(raw) if (raw is float or raw is int) and is_finite(float(raw)) else def
	if def is int:
		return int(raw) if (raw is float or raw is int) and is_finite(float(raw)) else def
	if def is bool:
		return bool(raw) if raw is bool else def
	if def is String:
		return String(raw) if raw is String else def
	return def


static func _dup(v):
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v
