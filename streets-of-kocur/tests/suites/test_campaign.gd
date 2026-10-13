extends "res://tests/test_case.gd"
## Whole streets played start to finish by the autoplay bot, plus level flow.


## Plays the loaded level with the bot until results / game over / timeout.
func _play(lv: Node, max_s: float) -> String:
	var bot := Bot.new()
	game().bot_input = bot
	var n := 0
	while n < int(max_s * 60.0):
		step(lv, 1)
		n += 1
		if lv.flow in ["results", "gameover"]:
			break
		if n % 900 == 0:
			await frames(1)
	return lv.flow


func _clear_street(i: int) -> void:
	game().god_mode = true
	var lv: Node = await start_level(i, 0)
	var flow: String = await _play(lv, 600.0)
	eq(flow, "results", "street %d cleared by the bot (god mode)" % (i + 1))
	check(lv.enc.all_cleared(), "street %d: every encounter cleared" % (i + 1))
	eq(lv.enemies().size(), 0, "street %d: no enemies left" % (i + 1))
	var total := 0
	for e: Dictionary in lv.data["encounters"]:
		for w: Array in e["waves"]:
			total += w.size()
	check(lv.enc.spawned_total >= total, "street %d: all %d scripted enemies spawned (%d incl. summons)" % [i + 1, total, lv.enc.spawned_total])
	if Levels.has_boss(i):
		eq(int(game().attempt["bosses"]), 1, "street %d: boss defeated" % (i + 1))
	check(lv.overlays.root.find_child("Results", true, false) != null, "street %d: results screen" % (i + 1))
	check(game().is_completed(i), "street %d recorded as completed" % (i + 1))
	if i < 5:
		check(game().is_unlocked(i + 1), "street %d unlocked" % (i + 2))
	note("street %d: bot clear in %.0f s sim time, %d enemies, rank %s" % [i + 1, float(game().attempt["time"]), int(game().attempt["enemies"]), String(lv.result["rank"])])


func test_clear_street_1() -> void:
	await _clear_street(0)


func test_clear_street_2() -> void:
	await _clear_street(1)


func test_clear_street_3() -> void:
	await _clear_street(2)


func test_clear_street_4() -> void:
	await _clear_street(3)


func test_clear_street_5() -> void:
	await _clear_street(4)


func test_clear_street_6_final_boss_and_ending() -> void:
	await _clear_street(5)
	check(bool(game().data["campaign_complete"]), "campaign complete recorded")
	var lv: Node = tree.current_scene
	var b: Button = lv.overlays.root.find_child("Continue", true, false)
	check(b != null and b.text == "See the ending", "final results lead to the ending")
	b.pressed.emit()
	await tree.root.get_node("Transition").finished
	check(tree.current_scene.scene_file_path == "res://scenes/ending.tscn", "ending scene shown")


func test_street_without_god_mode() -> void:
	# Normal difficulty, no god mode: street 1 must be beatable by the simple bot.
	var lv: Node = await start_level(0, 0)
	game().lives = 3
	var flow: String = await _play(lv, 400.0)
	eq(flow, "results", "street 1 beaten on Normal without god mode")
	note("street 1 (no god mode): %d lives lost, %d damage" % [int(game().attempt["deaths"]), int(game().attempt["damage"])])


func test_encounter_triggers_only_when_reached() -> void:
	var pad := Pad.new()
	var lv: Node = await start_level(0, 0, pad)
	step(lv, 60)
	eq(lv.enc.current, -1, "no fight at the start of the street")
	eq(lv.enemies().size(), 0, "no enemies yet")
	var x0: float = lv.data["encounters"][0]["x"]
	pad.move = Vector2(1, 0)
	pad.run = true
	var n := 0
	while lv.enc.current < 0 and n < 1200:
		step(lv, 1)
		n += 1
	eq(lv.enc.current, 0, "first fight starts when the player reaches it")
	check(lv.player.position.x >= x0 - 160.0, "near x=%d" % int(x0))
	check(lv.locked, "camera locked")
	step(lv, 120)
	check(lv.enemies().size() >= 1, "enemies arrive")
	pad.move = Vector2(1, 0)
	step(lv, 300)
	check(lv.player.position.x <= lv.arena_cx + lv.HALF_W - 23.0, "player cannot leave the locked arena (right)")
	pad.move = Vector2(-1, 0)
	step(lv, 400)
	check(lv.player.position.x >= lv.arena_cx - lv.HALF_W + 23.0, "player cannot leave the locked arena (left)")


func test_next_street_transition() -> void:
	game().god_mode = true
	var lv: Node = await start_level(0, 0)
	await _play(lv, 600.0)
	var b: Button = lv.overlays.root.find_child("Continue", true, false)
	check(b != null and b.text == "Next street", "next street button")
	b.pressed.emit()
	await tree.root.get_node("Transition").finished
	var lv2: Node = tree.current_scene
	check(lv2 != lv and lv2.has_method("compute_result"), "a level scene loaded")
	eq(game().level_index, 1, "now on street 2")
	eq(String(lv2.data["id"]), "market", "street 2 data")
	check(bool(game().data["run"]["active"]) and int(game().data["run"]["level"]) == 1, "run saved at street 2")
	lv2.set_physics_process(false)


func test_restart_does_not_duplicate_enemies() -> void:
	var lv: Node = await start_level(0, 1)
	game().god_mode = true
	game().bot_input = Bot.new()
	var x: float = lv.data["encounters"][1]["x"]
	var x_first: float = lv.data["encounters"][0]["x"]
	lv.player.position.x = x - 100.0
	step(lv, 120)
	var n1: int = lv.enemies_list.size()
	check(n1 >= 1, "second fight started (%d)" % n1)
	# Restart from checkpoint (pause menu path): reload the scene.
	var lv2: Node = await spawn_scene("res://scenes/level.tscn")
	lv2.set_physics_process(false)
	lv2.flow = "play"
	lv2.player.control_locked = false
	eq(lv2.enemies_list.size(), 0, "fresh level has no leftover enemies")
	eq(lv2.enc.next_index(), 1, "resumes at the checkpoint")
	check(lv2.player.position.x > x_first, "spawned after the first fight")
	lv2.player.position.x = x - 100.0
	step(lv2, 120)
	eq(lv2.enemies_list.size(), n1, "same number of enemies as before (no duplicates)")


func test_continue_keeps_checkpoint_and_lives() -> void:
	var lv: Node = await start_level(2, 2)
	game().lives = 1
	game().continues_left = 3
	var p: Node = lv.player
	p.hp = 1.0
	var e: Node = lv.spawn_enemy("punk", 1, 7)
	e.position = p.position + Vector2(40, 0)
	p.receive_hit(e.make_attack({"dmg": 10.0, "kb": 10.0, "type": "light"}), e)
	step(lv, 150)
	eq(lv.flow, "gameover", "game over")
	check(game().use_continue(), "continue used")
	var lv2: Node = await spawn_scene("res://scenes/level.tscn")
	lv2.set_physics_process(false)
	eq(lv2.enc.next_index(), 2, "continue resumes at the checkpoint")
	eq(game().lives, 3, "lives refilled")
	eq(game().continues_left, 2, "continues decremented")


func test_results_compute_once() -> void:
	game().god_mode = true
	var lv: Node = await start_level(0, 0)
	await _play(lv, 600.0)
	var s: int = game().score
	var cleared: int = int(game().data["stats"]["levels_cleared"])
	lv._finish_level()
	lv._finish_level()
	eq(game().score, s, "bonuses never added twice")
	eq(int(game().data["stats"]["levels_cleared"]), cleared, "completion recorded once")
	var r: Dictionary = lv.result
	check(String(r["rank"]) in ["S", "A", "B", "C", "D"], "rank %s" % r["rank"])
	check(int(r["level_score"]) > 0, "street score positive")
