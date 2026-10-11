extends Node
## Game flow (autoload "Game"): starts races for each mode, keeps Grand Prix
## state, applies results to progression and saves, and switches scenes with
## a short fade.

signal scene_changed

const RACE_SCENE := "res://scenes/race.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GARAGE_SCENE := "res://scenes/garage.tscn"

var race_config := {}
## Grand Prix in progress: {cup, difficulty, index, standings {racer: points},
## race_results [Array of results]}.
var gp := {}
var last_summary := {}
var race_counter := 0
var menu_page := ""          ## page the main menu should open on return
var _fade: ColorRect
var _loading: Label
var _layer: CanvasLayer
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.07, 0.05, 0.12, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)
	_loading = UI.label("Loading...", 34, UI.TEXT, true, 8)
	_loading.anchor_left = 1.0
	_loading.anchor_right = 1.0
	_loading.anchor_top = 1.0
	_loading.anchor_bottom = 1.0
	_loading.offset_left = -260
	_loading.offset_top = -80
	_loading.visible = false
	_layer.add_child(_loading)
	var at_phase := Autotest.requested()
	if at_phase != "":
		var at := Autotest.new()
		at.name = "Autotest"
		add_child(at)
		at.start(at_phase)


func selection() -> Dictionary:
	return Save.data["selection"].duplicate()


# ---------------------------------------------------------------------------
# Starting races
# ---------------------------------------------------------------------------

func start_grand_prix(cup_id: String, difficulty: String) -> void:
	begin_grand_prix(cup_id, difficulty)
	_start_gp_race()


## Sets up Grand Prix state (standings, rivals) without loading a race.
func begin_grand_prix(cup_id: String, difficulty: String) -> void:
	var sel := selection()
	var rivals := Race.default_rivals(sel["racer"], 5)
	var standings := {sel["racer"]: 0}
	for r in rivals:
		standings[r] = 0
	gp = {"cup": cup_id, "difficulty": difficulty, "index": 0, "standings": standings, "rivals": rivals,
		"race_results": [], "player": sel["racer"]}
	Save.data["last_difficulty"] = difficulty


func _start_gp_race() -> void:
	gp["snapshot"] = gp["standings"].duplicate()
	gp["results_count"] = gp["race_results"].size()
	var cup := TrackCatalog.cup(gp["cup"])
	var track_id: String = cup["tracks"][gp["index"]]
	# Race 1: player starts at the back. Race 2: grid in reverse standings
	# order (leader starts last), so a strong lead has to be defended.
	var order: Array = gp["rivals"].duplicate()
	var slot := order.size()
	if gp["index"] > 0:
		var all: Array = gp["standings"].keys()
		all.sort_custom(func(a, b): return gp["standings"][a] < gp["standings"][b])
		slot = all.find(gp["player"])
		all.erase(gp["player"])
		order = all
	race_config = {"track": track_id, "mode": "grand_prix", "laps": 3, "difficulty": gp["difficulty"],
		"player": selection(), "rivals": gp["rivals"], "grid_order": order, "grid_slot": slot, "seed": _next_seed()}
	change_scene(RACE_SCENE)


func start_single(track_id: String, difficulty: String, laps: int) -> void:
	gp = {}
	Save.data["last_difficulty"] = difficulty
	Save.data["last_laps"] = laps
	race_config = {"track": track_id, "mode": "single", "laps": laps, "difficulty": difficulty,
		"player": selection(), "grid_slot": 3, "seed": _next_seed()}
	change_scene(RACE_SCENE)


func start_time_trial(track_id: String) -> void:
	gp = {}
	race_config = {"track": track_id, "mode": "time_trial", "laps": 3, "difficulty": "normal",
		"player": selection(), "grid_slot": 0, "seed": _next_seed()}
	change_scene(RACE_SCENE)


func restart_race() -> void:
	# A restarted Grand Prix race replays the same track with the standings
	# from before it; nothing from the abandoned attempt is kept.
	if not gp.is_empty() and gp.has("snapshot"):
		gp["standings"] = gp["snapshot"].duplicate()
		gp["race_results"] = gp["race_results"].slice(0, int(gp["results_count"]))
	race_config["seed"] = _next_seed()
	change_scene(RACE_SCENE)


func retry_gp_race() -> void:
	restart_race()


func _next_seed() -> int:
	race_counter += 1
	return int(Time.get_unix_time_from_system()) % 100000 + race_counter


# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

## Called by Race when it ends. Applies progression (only for valid, real
## races) and returns a summary for the results screen.
func on_race_over(race: Race, res: Dictionary) -> Dictionary:
	var persist: bool = race.cfg.get("persist", true)
	var summary := {"results": res, "records": {}, "unlocks": [], "gp": {}}
	if res["mode"] == "grand_prix" and not gp.is_empty():
		var pts := {}
		for row in res["rows"]:
			var p := Progression.points_for(int(row["position"]))
			pts[row["racer"]] = p
			gp["standings"][row["racer"]] = int(gp["standings"].get(row["racer"], 0)) + p
		gp["race_results"].append(res)
		var standings := standings_sorted()
		var cup := TrackCatalog.cup(gp["cup"])
		var last: bool = int(gp["index"]) >= cup["tracks"].size() - 1
		summary["gp"] = {"points": pts, "standings": standings, "last": last, "cup": gp["cup"], "index": gp["index"]}
		if last:
			var standing := 1
			for i in standings.size():
				if standings[i]["racer"] == gp["player"]:
					standing = i + 1
			var player_pts := int(gp["standings"][gp["player"]])
			summary["gp"]["standing"] = standing
			summary["gp"]["trophy"] = Progression.trophy_for(standing)
			if persist:
				summary["gp"]["improved"] = Progression.record_cup(Save.data, gp["cup"], standing, player_pts, gp["difficulty"])
				summary["gp"]["champion"] = Progression.champion(Save.data) and gp["cup"] == TrackCatalog.CUPS[-1]["id"]
	if persist:
		summary["records"] = Progression.record_race(Save.data, res)
		Progression.add_recent(Save.data, res)
		summary["unlocks"] = Progression.collect_new_unlocks(Save.data)
		Save.save_game()
	last_summary = summary
	return summary


func standings_sorted() -> Array:
	var rows := []
	for r in gp["standings"]:
		rows.append({"racer": r, "points": gp["standings"][r], "player": r == gp["player"],
			"name": Catalog.RACERS[r]["name"]})
	# Ties broken by the most recent race result.
	var last_res: Dictionary = gp["race_results"][-1] if not gp["race_results"].is_empty() else {}
	var last_pos := {}
	for row in last_res.get("rows", []):
		last_pos[row["racer"]] = row["position"]
	rows.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return int(last_pos.get(a["racer"], 99)) < int(last_pos.get(b["racer"], 99)))
	return rows


func gp_next() -> void:
	if gp.is_empty():
		to_menu()
		return
	gp["index"] = int(gp["index"]) + 1
	var cup := TrackCatalog.cup(gp["cup"])
	if gp["index"] >= cup["tracks"].size():
		gp = {}
		to_menu("grand_prix")
		return
	_start_gp_race()


func to_menu(page := "") -> void:
	get_tree().paused = false
	menu_page = page
	change_scene(MENU_SCENE)


func to_garage() -> void:
	change_scene(GARAGE_SCENE)


# ---------------------------------------------------------------------------
# Scene switching
# ---------------------------------------------------------------------------

func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	Audio.stop_all_loops()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	_loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	scene_changed.emit()
	_loading.visible = false
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw2.finished
	_busy = false
