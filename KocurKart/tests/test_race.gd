extends Node
## Race lifecycle and rules: countdown, ordered checkpoints, laps, finish,
## results, anti-shortcut validation, wrong way, falls and restarts.

var t


func run(suite) -> void:
	t = suite
	await _full_race()
	await _checkpoint_rules()
	await _wrong_way_and_fall()
	await _restart_is_clean()
	await _time_trial_mode()


func _full_race() -> void:
	var ticks := []
	var finishes := {}
	var laps := {}
	var cp_seq := {}
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 2, "ui": true})
	race.countdown_tick.connect(func(v): ticks.append(v))
	race.kart_finished.connect(func(e): finishes[e.kart.racer_id] = finishes.get(e.kart.racer_id, 0) + 1)
	race.lap_completed.connect(func(e, lap, _time, _b): laps[e.kart.racer_id] = laps.get(e.kart.racer_id, []) + [lap])
	await t.physics_frames(2)
	t.check(race.entries.size() == 6 and race.state == Race.State.COUNTDOWN, "Race initializes with 6 karts in countdown", "%d karts, state %d" % [race.entries.size(), race.state])
	var moved := false
	for i in 200:
		await t.physics_frames(1)
		if race.state == Race.State.COUNTDOWN and race.player.kart.global_position.distance_to(race.track.grid_transform(5).origin) > 1.0:
			moved = true
	t.check(not moved, "Karts are held on the grid during the countdown", "")
	await t.physics_frames(60)
	t.check(ticks == [3, 2, 1, 0] and race.state == Race.State.RACING, "Countdown shows 3-2-1-GO then racing starts", "ticks %s" % [ticks])
	await t.physics_frames(180)
	t.check(race.player.kart.forward_speed > 12.0, "Player kart drives after GO", "%.1f m/s" % race.player.kart.forward_speed)
	# Track checkpoint order for every kart until the end.
	var bad_order := []
	var last_cp := {}
	for e in race.entries:
		last_cp[e] = e.next_cp
	var done := false
	for i in 60 * 260:
		await t.get_tree().physics_frame
		for e in race.entries:
			if e.next_cp != last_cp[e]:
				var n := race.track.checkpoints.size()
				var expected_fwd := (int(last_cp[e]) + 1) % n
				if e.next_cp != expected_fwd and not e.finished:
					bad_order.append("%s %d->%d" % [e.kart.racer_id, last_cp[e], e.next_cp])
				last_cp[e] = e.next_cp
		if race.state == Race.State.RESULTS:
			done = true
			break
	t.check(done, "Race reaches the results state", "race time %.1f s" % race.race_time)
	t.check(bad_order.is_empty(), "Checkpoints are only ever advanced in order", ", ".join(bad_order.slice(0, 5)))
	var all_laps := true
	for e in race.entries:
		if e.estimated:
			continue
		if laps.get(e.kart.racer_id, []) != [1, 2]:
			all_laps = false
	t.check(all_laps, "Laps increment 1, 2 for every finisher", str(laps))
	var once := true
	for k in finishes:
		if finishes[k] != 1:
			once = false
	t.check(once and finishes.size() >= 1, "Finish triggers exactly once per kart", str(finishes))
	var r := race.results
	var positions := []
	var times_ok := true
	var prev := 0.0
	for row in r["rows"]:
		positions.append(row["position"])
		if row["time"] < prev:
			times_ok = false
		prev = row["time"]
	t.check(positions == [1, 2, 3, 4, 5, 6] and times_ok, "Results are ordered by finishing time", "positions %s" % [positions])
	t.check(r["valid"] and r["player_laps"].size() == 2, "Player result is valid with 2 lap times", "laps %s" % [r["player_laps"]])
	await t.physics_frames(120)
	t.check(race.get_node_or_null("Results") != null, "Results screen appears after the race", "")
	race.queue_free()
	await t.physics_frames(2)


func _checkpoint_rules() -> void:
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 3})
	await t.physics_frames(2)
	var e := race.player
	var k := e.kart
	k.process_mode = Node.PROCESS_MODE_DISABLED
	var L := race.track.length
	var n := race.track.checkpoints.size()
	race.state = Race.State.RACING
	# Start behind the line.
	e.lap = 0
	e.next_cp = 0
	e.prev_s = L - 6.0
	_set_s(race, e, 2.0)
	t.check(e.lap == 1 and e.next_cp == 1, "Crossing the start line begins lap 1", "lap %d next_cp %d" % [e.lap, e.next_cp])
	# Drive back over the line: lap 1 is undone.
	_set_s(race, e, L - 3.0)
	t.check(e.lap == 0 and e.next_cp == 0, "Reversing over the line undoes the crossing", "lap %d next_cp %d" % [e.lap, e.next_cp])
	_set_s(race, e, 2.0)
	_set_s(race, e, L - 3.0)
	_set_s(race, e, 2.0)
	t.check(e.lap == 1, "Repeated line crossings never add laps", "lap %d" % e.lap)
	# Drive half a lap properly.
	var s := 2.0
	while s < L * 0.5:
		s += 8.0
		_set_s(race, e, s)
	var cp_mid := e.next_cp
	t.check(cp_mid == n / 2 + 1 or cp_mid == n / 2, "Checkpoints advance while driving", "next_cp %d of %d" % [cp_mid, n])
	# Teleport (no continuous path) to just before the line and cross it.
	_set_s(race, e, L - 4.0)
	_set_s(race, e, 3.0)
	t.check(e.lap == 1, "Skipping part of the lap is not credited", "lap %d next_cp %d" % [e.lap, e.next_cp])
	# Finish the lap legitimately.
	s = race.track.s_delta(0.0, e.prev_s) if e.prev_s < L * 0.5 else e.prev_s
	s = L * 0.5
	_set_s(race, e, s)
	while s < L + 3.0:
		s += 8.0
		_set_s(race, e, fposmod(s, L))
	t.check(e.lap == 2 and e.lap_times.size() == 1, "Completing every checkpoint counts the lap", "lap %d, %d lap times" % [e.lap, e.lap_times.size()])
	race.queue_free()
	await t.physics_frames(2)


func _set_s(race: Race, e: RaceEntry, s: float) -> void:
	e.kart.loc.s = fposmod(s, race.track.length)
	race._update_progress(e)


func _wrong_way_and_fall() -> void:
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 3, "autopilot": false})
	await t.physics_frames(2)
	var flags := []
	race.wrong_way_changed.connect(func(a): flags.append(a))
	var inp := ScriptedInput.new()
	race.player.kart.controller = inp
	race.countdown = 0.01
	await t.physics_frames(3)
	var k := race.player.kart
	k.place(race.track.respawn_transform(200.0))
	k.yaw += PI
	k.rotation.y = k.yaw
	race.player.prev_s = k.loc.s
	inp.throttle = 1.0
	await t.physics_frames(150)
	t.check(flags.has(true), "Wrong-way warning appears when driving backwards", "events %s" % [flags])
	k.yaw += PI
	k.rotation.y = k.yaw
	await t.physics_frames(150)
	t.check(flags.size() >= 2 and flags[-1] == false, "Wrong-way warning clears when turned around", "events %s" % [flags])
	# Fall below the world.
	var recovered := [false]
	k.recovered.connect(func(): recovered[0] = true)
	k.global_position = Vector3(k.global_position.x, race.track.kill_y - 5.0, k.global_position.z)
	k.reset_physics_interpolation()
	await t.physics_frames(30)
	race.track.locate(k.global_position, k.loc)
	t.check(recovered[0] and not k.loc.off_track and absf(k.loc.height) < 2.0, "Falling off the world respawns on the track", "height above road %.2f" % k.loc.height)
	# Off the circuit (outside the walls) for too long.
	recovered[0] = false
	k.global_position = race.track.main.positions[40] + race.track.main.rights[40] * 60.0 + Vector3.UP
	k.reset_physics_interpolation()
	await t.physics_frames(150)
	race.track.locate(k.global_position, k.loc)
	t.check(recovered[0] and not k.loc.off_track, "Leaving the circuit respawns the kart", "lateral %.1f" % k.loc.lateral)
	race.queue_free()
	await t.physics_frames(2)


func _restart_is_clean() -> void:
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 3})
	await t.physics_frames(400)
	var mid_time := race.race_time
	race.queue_free()
	await t.physics_frames(3)
	var race2 := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 3})
	await t.physics_frames(2)
	var karts := get_tree().root.find_children("*", "Kart", true, false).size()
	var tracks := get_tree().root.find_children("*", "Track", true, false).size()
	var clean := race2.race_time == 0.0 and race2.state == Race.State.COUNTDOWN
	for e in race2.entries:
		if e.lap != 0 or e.finished or not e.lap_times.is_empty():
			clean = false
	t.check(karts == 6 and tracks == 1, "Restart leaves no duplicate karts or tracks", "%d karts, %d tracks (previous race ran %.1f s)" % [karts, tracks, mid_time])
	t.check(clean, "Restarted race state is fresh", "time %.2f state %d" % [race2.race_time, race2.state])
	race2.queue_free()
	await t.physics_frames(2)


func _time_trial_mode() -> void:
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "mode": "time_trial", "laps": 3})
	await t.physics_frames(2)
	t.check(race.entries.size() == 1, "Time Trial races alone", "%d karts" % race.entries.size())
	var ok: bool = await RaceHelper.run_to_end(t, race, 260.0)
	var r := race.results
	t.check(ok and r["valid"] and r["player_laps"].size() == 3, "Time Trial completes with three valid laps", "total %s, laps %s" % [UI.time_text(r.get("player_time", 0.0)), r.get("player_laps", [])])
	race.queue_free()
	await t.physics_frames(2)
