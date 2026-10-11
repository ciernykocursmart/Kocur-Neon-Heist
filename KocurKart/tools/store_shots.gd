extends SceneTree
## Captures Microsoft Store screenshots from real gameplay.
##   xvfb-run godot --path . --resolution 1920x1080 -s res://tools/store_shots.gd -- <shot_id> <out.png>

var shot := ""
var out := ""
var frames := 0
var armed := -1
var cond: Callable


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	shot = a[0]
	out = a[1]
	var g = root.get_node("Game")
	var sel := {"racer": "kocur", "kart": "alley", "paint": "crimson", "wheels": "sport", "accessory": "scarf"}
	var scene := "res://scenes/race.tscn"
	match shot:
		"menu":
			scene = "res://scenes/main_menu.tscn"
			cond = func(): return frames > 220
		"garage":
			scene = "res://scenes/garage.tscn"
			root.get_node("Save").data["selection"] = {"racer": "kocur", "kart": "pounce", "paint": "cyan", "wheels": "neon", "accessory": "crown"}
			cond = func(): return frames > 120
		"countdown":
			g.race_config = _cfg("whiskerwood", sel, 2, "grand_prix")
			cond = func(): return _race() != null and _race().state == Race.State.COUNTDOWN and _race().countdown < 2.55 and _race().countdown > 2.0
		"neon_start":
			g.race_config = _cfg("neon", sel, 2, "single")
			cond = func(): var r := _race(); return r != null and r.race_time > 2.2
		"drift":
			g.race_config = _cfg("neon", sel, 3, "single")
			cond = func(): var r := _race(); return r != null and r.race_time > 6.0 and r.player.kart.drifting and r.player.kart.drift_level == 2 and _rival_near(r, 25.0)
		"pier":
			g.race_config = _cfg("purrport", {"racer": "marmalade", "kart": "thunder", "paint": "tangerine", "wheels": "chunky", "accessory": "goggles"}, 4, "single")
			cond = func(): var r := _race(); return r != null and r.race_time > 4.0 and _frac(r) > 0.27 and _frac(r) < 0.34 and _rival_near(r, 30.0)
		"ice":
			g.race_config = _cfg("frostpaw", {"racer": "duchess", "kart": "pounce", "paint": "rose", "wheels": "sport", "accessory": "flower"}, 3, "single")
			cond = func(): var r := _race(); return r != null and r.race_time > 4.0 and _frac(r) > 0.405 and _frac(r) < 0.42
		"jump":
			g.race_config = _cfg("safari", {"racer": "tux", "kart": "alley", "paint": "sunny", "wheels": "classic", "accessory": "headphones"}, 3, "single")
			cond = func(): var r := _race(); return r != null and r.player.kart.airborne_time > 0.22
		"royal":
			g.race_config = _cfg("royal", sel, 5, "grand_prix")
			cond = func(): var r := _race(); return r != null and r.race_time > 4.0 and _frac(r) > 0.12 and _frac(r) < 0.16
		"results":
			g.race_config = _cfg("whiskerwood", sel, 1, "single")
			g.race_config["laps"] = 1
			cond = func(): var r := _race(); return r != null and r.get_node_or_null("Results") != null and frames > 30
	root.get_node("Save").path_override = "user://store_shots_save"
	change_scene_to_file.call_deferred(scene)
	process_frame.connect(_tick)


func _cfg(track: String, sel: Dictionary, slot: int, mode: String) -> Dictionary:
	return {"track": track, "mode": mode, "laps": 3, "difficulty": "hard", "player": sel, "autopilot": true,
		"autopilot_difficulty": "hard", "persist": false, "seed": 21, "grid_slot": slot}


func _race() -> Race:
	return current_scene as Race


func _frac(r: Race) -> float:
	return r.player.kart.loc.s / r.track.length


func _rival_near(r: Race, dist: float) -> bool:
	for e in r.entries:
		if e != r.player and e.kart.global_position.distance_to(r.player.kart.global_position) < dist:
			var ahead: Vector3 = e.kart.global_position - r.player.kart.global_position
			if ahead.dot(r.player.kart.forward_dir()) > 2.0:
				return true
	return false


func _tick() -> void:
	frames += 1
	if armed < 0 and current_scene != null and (cond.call() or frames > 60 * 200):
		armed = frames + 2
	if armed > 0 and frames >= armed:
		root.get_texture().get_image().save_png(out)
		print("captured %s at frame %d" % [shot, frames])
		quit()
