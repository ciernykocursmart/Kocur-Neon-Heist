extends SceneTree
## Runs a Time Trial with the Hard autopilot on every track and suggests
## medal targets (gold ~ expert pace, silver/bronze progressively easier).
##   godot --headless --fixed-fps 60 --path . -s res://tools/calibrate_medals.gd

func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	for id in TrackCatalog.ORDER:
		var race: Race = load("res://scripts/race/race.gd").new()
		race.configure({"track": id, "mode": "time_trial", "laps": 3, "autopilot": true, "persist": false,
			"decorate": false, "ui": false, "seed": 1})
		get_root().add_child(race)
		while race.state != Race.State.RESULTS:
			await physics_frame
		var t: float = race.results["player_time"]
		print("%s: autopilot %.2f s -> medals [%.1f, %.1f, %.1f]" % [id, t, snappedf(t * 1.01, 0.5), snappedf(t * 1.08, 0.5), snappedf(t * 1.18, 0.5)])
		race.queue_free()
		await physics_frame
	quit()
