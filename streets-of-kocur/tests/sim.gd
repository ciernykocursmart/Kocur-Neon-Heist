extends SceneTree
## Plays levels with the autoplay bot as fast as possible and prints a trace.
##   godot --headless --path . -s res://tests/sim.gd -- <level|all> [god] [easy|normal|hard]
## Used for balance checks; tests/run_tests.gd uses the same stepping.

const Bot = preload("res://scripts/debug/autoplay_bot.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.get_node("SaveManager").path = "user://sim_save.json"
	root.get_node("Settings").path = "user://sim_settings.cfg"
	var game: Node = root.get_node("Game")
	game.data = game.defaults()
	var which: String = args[0] if args.size() > 0 else "0"
	var god := args.has("god")
	var diff := "normal"
	for d in ["easy", "normal", "hard"]:
		if args.has(d):
			diff = d
	var levels: Array = range(6) if which == "all" else [int(which)]
	game.difficulty = diff
	game.score = 0
	game.lives = int(game.diff()["lives"])
	for idx: int in levels:
		game.begin_level(idx)
		var r := await play(idx, god)
		print("LEVEL %d %s  time=%.0fs deaths=%d continues=%d dmg=%d enemies=%d food=%d score=%d best_combo=%d" % [
			idx + 1, r["outcome"], r["time"], r["deaths"], r["continues"], r["damage"], r["enemies"], r["food"], game.score, r["best_combo"]])
	quit()


func play(idx: int, god: bool) -> Dictionary:
	var game: Node = root.get_node("Game")
	var bot := Bot.new()
	game.bot_input = bot
	game.god_mode = god
	var outcome := "timeout"
	var sim_t := 0.0
	var continues := 0
	while true:
		change_scene_to_file("res://scenes/level.tscn")
		await process_frame
		await process_frame
		var lv: Node = current_scene
		lv.set_physics_process(false)
		var last_enc := -2
		var steps := 0
		while steps < 60 * 900:
			lv._physics_process(1.0 / 60.0)
			steps += 1
			if lv.enc.current != last_enc:
				last_enc = lv.enc.current
				if last_enc >= 0:
					print("   t=%5.1f  encounter %d starts  hp=%d lives=%d" % [game.attempt["time"], last_enc, int(lv.player.hp), game.lives])
			if lv.flow == "results":
				outcome = "CLEAR rank " + String(lv.result["rank"])
				break
			if lv.flow == "gameover":
				break
			if steps % 600 == 0:
				await process_frame
		sim_t += steps / 60.0
		if lv.flow == "gameover" and game.can_continue() and continues < 5:
			print("   GAME OVER at encounter %d -> continue" % game.checkpoint)
			game.use_continue()
			continues += 1
			continue
		if lv.flow == "gameover":
			outcome = "GAME OVER (no continues)"
		break
	var a: Dictionary = game.attempt
	game.bot_input = null
	game.god_mode = false
	return {"outcome": outcome, "time": a["time"], "deaths": a["deaths"], "continues": continues, "damage": a["damage"],
		"enemies": a["enemies"], "food": a["food"], "best_combo": a["best_combo"]}
