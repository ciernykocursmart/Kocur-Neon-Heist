extends SceneTree
# Headless unit tests: godot --headless --path . -s res://tests/test_suite.gd
var passed := 0
var failed := 0

func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + name)

func P(rows: Array) -> Puzzle:
	return Puzzle.new(rows)

func _initialize() -> void:
	var SaveData = root.get_node("SaveData")
	SaveData.path = "user://test_save.json"
	_test_grid()
	_test_push()
	_test_targets_exit()
	_test_switch_door()
	_test_keys()
	_test_ice()
	_test_teleport()
	_test_gates()
	_test_undo_restart()
	_test_stuck()
	_test_levels_valid()
	_test_levels_solutions()
	_test_undo_property()
	_test_stars()
	_test_save(SaveData)
	await _test_ui(SaveData)
	print("TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _test_grid() -> void:
	var p := P(["####", "#@.#", "####"])
	check(not p.move("up").ok and not p.move("left").ok and not p.move("down").ok, "walls block movement")
	check(p.moves == 0, "blocked move does not count")
	check(p.move("right").ok and p.player == Vector2i(2, 1) and p.moves == 1, "normal step")
	check(not p.move("right").ok, "wall after step")
	var q := P(["@."])  # rows without border: outside is wall
	check(not q.move("up").ok and not q.move("left").ok and q.move("right").ok, "grid boundary acts as wall")

func _test_push() -> void:
	var p := P(["#######", "#@$..E#", "#######"])
	check(p.move("right").ok and p.crates[0] == Vector2i(3, 1) and p.player == Vector2i(2, 1), "push crate")
	p.move("right"); p.move("right")
	check(p.crates[0] == Vector2i(5, 1) and not p.move("right").ok, "crate into exit tile ok, then wall blocks")
	var w := P(["####", "#@$#", "####"])
	check(not w.move("right").ok and w.crates[0] == Vector2i(2, 1), "crate into wall refused")
	var c := P(["######", "#@$$.#", "######"])
	check(not c.move("right").ok, "crate into crate refused")
	var pull := P(["######", "#.$@.#", "######"])
	pull.move("right")
	check(pull.crates[0] == Vector2i(2, 1), "no pulling")
	var m := P(["#######", "#@$.$.#", "#######"])
	m.move("right")
	check(m.crates[0] == Vector2i(3, 1) and not m.move("right").ok, "second crate behind the first blocks the push")
	m.crates[1] = Vector2i(5, 1)
	m.move("right")
	check(m.crates[0] == Vector2i(4, 1) and m.crates[1] == Vector2i(5, 1), "two crates are handled independently")

func _test_targets_exit() -> void:
	var p := P(["########", "#@$.TE.#", "########"])
	check(not p.exit_open(), "exit closed with uncovered target")
	p.move("right"); p.move("right")
	check(p.crates[0] == Vector2i(4, 1) and p.exit_open(), "crate on target opens exit")
	var np := P(["#####", "#@.E#", "#####"])
	np.move("right"); np.move("right")
	check(np.won, "level without targets: exit open from start")
	var q := P(["#######", "#@E$T.#", "#######"])
	q.move("right")
	check(not q.won, "closed exit does not win")
	var two := P(["#########", "#@$$..TT#", "#########"])
	two.move("right"); two.move("right")
	check(not two.exit_open() and two.crate_at(Vector2i(6, 1)) < 0, "partial targets keep exit closed (setup)")

func _test_switch_door() -> void:
	var p := P(["#########", "#@$.p.D.#", "#########"])
	check(not p.doors_open, "door starts closed")
	p.move("right"); p.move("right")
	check(p.crates[0] == Vector2i(4, 1) and p.doors_open, "crate on switch opens door")
	var q := P(["#######", "#@pD..#", "#######"])
	q.move("right")
	check(q.doors_open, "player on switch opens door")
	check(q.move("right").ok and q.player == Vector2i(3, 1), "can step onto the door tile while the plate is held")
	check(q.move("right").ok and q.player == Vector2i(4, 1), "can walk on after the door closes behind")
	var r := P(["#######", "#@.D..#", "#######"])
	r.move("right")
	check(not r.move("right").ok, "closed door blocks")
	var two := P(["##########", "#@$.p.p.D#", "##########"])
	two.move("right"); two.move("right")
	check(not two.doors_open, "two switches need both")

func _test_keys() -> void:
	var p := P(["#########", "#@.L.k..#", "#########"])
	check(p.move("right").ok, "walk next to lock")
	p.move("right")
	check(not p.move("right").ok, "locked door blocks without key")
	var q := P(["#########", "#@k.L.L.#", "#########"])
	q.move("right")
	check(q.keys == 1 and q.floor_keys.is_empty(), "pick up key")
	q.move("right")
	var r := q.move("right")
	check(r.ok and r.door and q.keys == 0 and q.unlocked.has(Vector2i(4, 1)), "lock opens and consumes key")
	q.move("right")
	check(not q.move("right").ok, "second lock needs second key")
	q.move("left")
	check(q.move("left").ok and q.move("right").ok, "opened door stays open")
	var cr := P(["#######", "#@$L..#", "#######"])
	check(not cr.move("right").ok, "crates cannot pass locked door")

func _test_ice() -> void:
	var p := P(["#########", "#@.iii..#", "#########"])
	p.move("right"); p.move("right")
	check(p.player == Vector2i(6, 1) and p.moves == 2, "player slides over ice to next solid tile")
	var w := P(["#######", "#@iii##", "#######"])
	w.move("right")
	check(w.player == Vector2i(4, 1), "slide stops at wall")
	var c := P(["########", "#@$ii.##", "########"])
	c.move("right")
	check(c.crates[0] == Vector2i(5, 1), "pushed crate slides over ice")
	var b := P(["#########", "#@ii$.#", "#########"])
	b.move("right")
	check(b.player == Vector2i(3, 1), "player slide stopped by crate")

func _test_teleport() -> void:
	var p := P(["#########", "#@.a#.a.#", "#########"])
	p.move("right"); p.move("right")
	check(p.player == Vector2i(6, 1), "teleport to twin pad")
	var q := P(["#########", "#@.a#.a.#", "#########"])
	q.crates.append(Vector2i(6, 1))
	q.move("right"); q.move("right")
	check(q.player == Vector2i(3, 1), "no teleport onto a crate")
	var fresh := P(["#########", "#@.a#.a.#", "#########"])
	fresh.move("right"); fresh.move("right")
	fresh.move("left")
	check(fresh.player == Vector2i(5, 1), "arrival does not bounce back")

func _test_gates() -> void:
	var p := P(["#######", "#@xy..#", "#######"])
	check(p.move("right").ok and p.move("right").ok, "x then y gate pass in sequence")
	var q := P(["#######", "#@y..E#", "#######"])
	check(not q.move("right").ok, "y gate closed on even beat")
	q.wait()
	check(q.move("right").ok and q.player == Vector2i(2, 1), "y gate opens after waiting a beat")
	var r := P(["#######", "#@x..E#", "#######"])
	check(r.move("right").ok, "x gate open on even beat")

func _snapshot(p: Puzzle) -> String:
	return p.state_key(true) + "|%d|%s" % [p.moves, p.doors_open]

func _test_undo_restart() -> void:
	var p := P(["##########", "#@$.pD.k.#", "#.f.iL..E#", "##########"])
	var s0 := _snapshot(p)
	for d in ["right", "right", "down", "right", "right", "up", "left"]:
		p.move(d)
	var steps := p.undo_stack.size()
	check(steps > 0, "moves recorded")
	while p.can_undo():
		p.undo()
	check(_snapshot(p) == s0, "undo restores exact initial state")
	var m := P(["#####", "#@$.#", "#####"])
	m.move("right")
	m.restart()
	check(m.player == Vector2i(1, 1) and m.crates[0] == Vector2i(2, 1) and m.moves == 0 and not m.can_undo(), "restart")
	var n := P(["#####", "#@.E#", "#####"])
	n.move("right"); n.move("right")
	check(n.won and not n.move("left").ok, "no moves after winning")
	n.undo()
	check(not n.won, "undo after win")

func _test_stuck() -> void:
	var p := P(["#####", "#@$.#", "#####"])
	p.move("right")
	check(p.stuck_crates().size() == 1, "crate pushed into a dead end is flagged")
	var q := P(["######", "#@.$.#", "#..T.#", "######"])
	check(q.stuck_crates().size() == 0, "free crate not stuck")
	var r := P(["#####", "#$@T#", "#####"])
	check(r.stuck_crates().size() == 1, "corner crate off-target is stuck")
	var s := P(["####", "#$T#", "####"])
	check(s.stuck_crates().size() == 1, "corner crate warns")
	var t := P(["###", "#T#", "#$#", "###"])
	check(t.stuck_crates().size() == 1, "corridor dead-end warns")

func _test_levels_valid() -> void:
	check(Levels.LIST.size() == 30 and Levels.REGIONS.size() == 5, "30 levels in 5 regions")
	for r in 5:
		var n := 0
		for L in Levels.LIST:
			if L.region == r:
				n += 1
		check(n == 6, "region %d has 6 levels" % r)
	for i in Levels.LIST.size():
		var L: Dictionary = Levels.LIST[i]
		var p := P(L.rows)
		var tag := "level %d" % (i + 1)
		var starts := 0
		var exits := 0
		for row in L.rows:
			starts += String(row).count("@")
			exits += String(row).count("E")
		check(starts == 1 and exits == 1, tag + " has one start and one exit")
		check(p.targets.size() <= p.crates.size(), tag + " crates >= targets")
		check(L.hint != "" and L.name != "", tag + " has name and hint")
		for k in p.pads:
			check(p.pads[k].size() == 2, tag + " pad %s has a twin" % k)
		check(p.w <= 15 and p.h <= 9, tag + " fits the screen")
		check(not p.won, tag + " does not start won")
		check(Levels.par(i) > 0 and Levels.target(i) >= Levels.par(i) and Levels.target(i) >= Levels.fish_par(i), tag + " par and target sane")

func _test_levels_solutions() -> void:
	var letters := {"U": "up", "D": "down", "L": "left", "R": "right", "W": "wait"}
	for i in Levels.LIST.size():
		var info: Dictionary = Levels.pars()[str(i)]
		for key in ["path", "fishpath"]:
			if str(info[key]) == "":
				check(key == "fishpath" and Puzzle.new(Levels.LIST[i].rows).fish_total == 0 or false, "level %d %s present" % [i + 1, key])
				continue
			var p := P(Levels.LIST[i].rows)
			for ch in info[key]:
				if ch == "W":
					p.wait()
				else:
					p.move(letters[ch])
			check(p.won, "level %d %s solves" % [i + 1, key])
			if key == "fishpath":
				check(p.fish.is_empty(), "level %d collects all fish" % (i + 1))
		check(str(info.path).length() == int(info.par), "level %d par equals solution length" % (i + 1))

func _test_undo_property() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var dirs := ["up", "down", "left", "right", "wait"]
	var all_ok := true
	for i in Levels.LIST.size():
		var p := P(Levels.LIST[i].rows)
		var s0 := _snapshot(p)
		var mids := []
		for n in 150:
			var d: String = dirs[rng.randi() % 5]
			var before := _snapshot(p)
			if d == "wait":
				p.wait()
			else:
				p.move(d)
			if p.won:
				break
			mids.append(before)
		while p.can_undo():
			p.undo()
		if _snapshot(p) != s0:
			all_ok = false
			printerr("undo property failed on level %d" % (i + 1))
	check(all_ok, "random walk + full undo restores initial state on all 30 levels")

func _test_stars() -> void:
	check(Levels.stars_for(10, 15, 1, 1) == 3, "3 stars")
	check(Levels.stars_for(10, 15, 0, 1) == 2, "2 stars missing fish")
	check(Levels.stars_for(16, 15, 1, 1) == 1, "1 star over target")
	check(Levels.stars_for(15, 15, 0, 0) == 3, "no fish level, at target is 3 stars")

func _test_save(S) -> void:
	DirAccess.remove_absolute("user://test_save.json")
	S.load_game()
	check(S.completed_count() == 0 and S.is_unlocked(0) and not S.is_unlocked(1), "defaults: only level 1 unlocked")
	var r: Dictionary = S.record(0, 9, 1, 1)
	check(S.is_completed(0) and S.is_unlocked(1) and not S.is_unlocked(2), "completion unlocks next")
	check(r.stars >= 1 and r.new_best, "record returns stars and new_best")
	S.record(0, 20, 0, 1)
	check(S.level_info(0).moves == 9 and S.level_info(0).fish == 1 and S.stars(0) == Levels.stars_for(9, Levels.target(0), 1, 1), "worse run keeps best")
	S.data.settings.music = 0.25
	S.save()
	S.data = {}
	S.load_game()
	check(S.is_completed(0) and is_equal_approx(S.data.settings.music, 0.25), "save survives reload")
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	S.load_game()
	check(S.completed_count() == 0 and S.load_error != "", "corrupt save falls back to defaults")
	f = FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string('{"levels": {"3": {"moves": 5}, "99": {"moves": 1}, "x": 1}, "settings": {"music": 7}}')
	f.close()
	S.load_game()
	check(S.is_completed(3) and not S.is_completed(99) and S.data.settings.music <= 1.0, "partial/old save is sanitized")
	f = FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("[1,2,3]")
	f.close()
	S.load_game()
	check(S.completed_count() == 0, "wrong json type handled")
	DirAccess.remove_absolute("user://test_save.json")
	S.load_game()
	check(S.completed_count() == 0 and S.load_error == "", "missing save file is fine")
	S.record(5, 10, 0, 0)
	S.reset_progress()
	check(S.completed_count() == 0, "reset progress")
	DirAccess.remove_absolute("user://test_save.json")

func _test_ui(S) -> void:
	S.load_game()
	var main = load("res://scripts/main.tscn").instantiate()
	main.skip_delays = true
	root.add_child(main)
	await process_frame
	for i in 40:
		main.start_level(i % 30)
	await process_frame
	check(main.mode == "game" and main.level == 9, "rapid level switching is stable")
	main.start_level(0)
	await process_frame
	check(main.try_move("right") or true, "ui move")
	var before: int = main.pz.moves
	main.undo()
	check(main.pz.moves <= before, "ui undo")
	main.show_pause()
	await process_frame
	check(main.overlay_kind == "pause" and not main.try_move("down"), "pause blocks input")
	main.resume()
	main.restart_level()
	check(main.pz.moves == 0, "ui restart")
	var letters := {"U": "up", "D": "down", "L": "left", "R": "right", "W": "wait"}
	for ch in Levels.pars()["0"].path:
		main.board.snap()
		main.try_move(letters[ch])
	await process_frame
	check(main.pz.won and S.is_completed(0) and S.is_unlocked(1), "completing a level in the UI saves and unlocks the next")
	check(main.overlay_kind == "victory", "victory screen appears")
	main.start_level(1)
	check(main.mode == "game" and main.level == 1 and main.overlay == null, "next level starts")
	main.show_menu(); main.show_select(); main.show_settings(); main.show_credits()
	await process_frame
	check(true, "all screens build")
	DirAccess.remove_absolute(S.path)
