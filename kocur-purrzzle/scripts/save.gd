extends Node
## Autoload "SaveData": progress + settings in user:// (atomic write, tolerant load).

const VERSION := 1
var path := "user://purrzzle_save.json"
var data: Dictionary = {}
var load_error := ""

func _ready() -> void:
	load_game()

func _defaults() -> Dictionary:
	return {"version": VERSION, "levels": {}, "seen_tutorial": false, "last_level": 0,
		"settings": {"music": 0.6, "sfx": 0.8, "fullscreen": false, "pad": true}}

func load_game() -> void:
	data = _defaults()
	load_error = ""
	if not FileAccess.file_exists(path):
		return
	var js := JSON.new()
	var parsed = js.data if js.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not (parsed is Dictionary):
		load_error = "Save file was unreadable; started fresh."
		push_warning(load_error)
		return
	# Merge field by field so older/partial saves still work.
	var lv = parsed.get("levels", {})
	if lv is Dictionary:
		for k in lv:
			var e = lv[k]
			if e is Dictionary and str(k).is_valid_int() and int(k) >= 0 and int(k) < Levels.LIST.size():
				data.levels[str(int(k))] = {"moves": maxi(0, int(e.get("moves", 0))), "stars": clampi(int(e.get("stars", 1)), 1, 3), "fish": maxi(0, int(e.get("fish", 0)))}
	data.seen_tutorial = bool(parsed.get("seen_tutorial", false))
	data.last_level = clampi(int(parsed.get("last_level", 0)), 0, Levels.LIST.size() - 1)
	var st = parsed.get("settings", {})
	if st is Dictionary:
		data.settings.music = clampf(float(st.get("music", 0.6)), 0.0, 1.0)
		data.settings.sfx = clampf(float(st.get("sfx", 0.8)), 0.0, 1.0)
		data.settings.fullscreen = bool(st.get("fullscreen", false))
		data.settings.pad = bool(st.get("pad", true))

func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var da := DirAccess.open(path.get_base_dir())
	if da == null:
		return false
	if da.file_exists(path.get_file()):
		da.remove(path.get_file())
	return da.rename(tmp.get_file(), path.get_file()) == OK

func is_completed(i: int) -> bool:
	return data.levels.has(str(i))

func is_unlocked(i: int) -> bool:
	return i == 0 or is_completed(i - 1)

func level_info(i: int) -> Dictionary:
	return data.levels.get(str(i), {})

func stars(i: int) -> int:
	return int(level_info(i).get("stars", 0))

func total_stars() -> int:
	var n := 0
	for i in Levels.LIST.size():
		n += stars(i)
	return n

func total_fish() -> int:
	var n := 0
	for i in Levels.LIST.size():
		n += int(level_info(i).get("fish", 0))
	return n

func completed_count() -> int:
	return data.levels.size()

## Records a finished level, keeping the best result. Returns {stars, new_best}.
func record(i: int, moves: int, fish_got: int, fish_total: int) -> Dictionary:
	var s := Levels.stars_for(moves, Levels.target(i), fish_got, fish_total)
	var old := level_info(i)
	var best_moves: int = moves if old.is_empty() else mini(int(old.moves), moves)
	var best_stars: int = maxi(s, int(old.get("stars", 0)))
	var best_fish: int = maxi(fish_got, int(old.get("fish", 0)))
	var new_best := old.is_empty() or moves < int(old.moves)
	data.levels[str(i)] = {"moves": best_moves, "stars": best_stars, "fish": best_fish}
	data.last_level = mini(i + 1, Levels.LIST.size() - 1)
	save()
	return {"stars": s, "new_best": new_best}

func reset_progress() -> void:
	var st: Dictionary = data.settings
	data = _defaults()
	data.settings = st
	save()
