extends Node
## AI: leaves the grid, follows the route, completes full races on every
## circuit, recovers without looping, and difficulty levels differ.

var t


func run(suite) -> void:
	t = suite
	await _launch_and_follow()
	for id in TrackCatalog.ORDER:
		if TrackCatalog.TRACKS.has(id):
			await _full_race(id)
	await _difficulty_spread()


func _launch_and_follow() -> void:
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 3, "difficulty": "normal"})
	await t.physics_frames(240 + 300)
	var left := true
	var min_prog := INF
	for e in race.entries:
		var p := e.progress(race.track.length)
		min_prog = minf(min_prog, p)
		if p < 40.0:
			left = false
	t.check(left, "Every AI leaves the starting grid", "slowest progress after 5 s: %.0f m" % min_prog)
	var max_lat := 0.0
	var off := 0
	for i in 600:
		await t.physics_frames(1)
		for e in race.entries:
			var k := e.kart
			if k.loc.path == 0:
				max_lat = maxf(max_lat, absf(k.loc.lateral) - k.loc.half_width)
			if k.loc.surface == &"offroad":
				off += 1
	var share := float(off) / (600.0 * race.entries.size())
	t.check(share < 0.08, "AI stays on the road", "off-road %.1f%% of samples, worst %.1f m past the road edge" % [share * 100.0, max_lat])
	race.queue_free()
	await t.physics_frames(2)


func _full_race(id: String) -> void:
	var race := RaceHelper.make_race(self, {"track": id, "laps": 3, "difficulty": "normal", "seed": 3})
	var recoveries := {}
	var drifts := [0, 0]
	var shortcut_uses := [0]
	await t.physics_frames(1)
	for e in race.entries:
		var rid := e.kart.racer_id
		recoveries[rid] = 0
		e.kart.recovered.connect(func(): recoveries[rid] += 1)
		e.kart.drift_released.connect(func(lvl): drifts[0] += 1; drifts[1] += int(lvl > 0))
	var ok: bool = await RaceHelper.run_to_end(t, race, 420.0)
	var real := 0
	var worst := 0
	var times := []
	for e in race.entries:
		if not e.estimated:
			real += 1
		worst = maxi(worst, recoveries[e.kart.racer_id])
		times.append("%s %s%s" % [e.kart.display_name, UI.time_text(e.finish_time), "~" if e.estimated else ""])
	t.check(ok and real == race.entries.size(), "%s: all 6 karts finish 3 laps" % TrackCatalog.track_name(id), "%d real finishers; %s" % [real, ", ".join(times)])
	t.check(worst <= 3, "%s: AI recovery never loops" % TrackCatalog.track_name(id), "max recoveries by one kart: %d %s" % [worst, recoveries])
	var lap_best := INF
	for e in race.entries:
		lap_best = minf(lap_best, e.best_lap)
	print("    %s best lap %.2f s, winner %.2f s, drifts %d (%d boosted)" % [id, lap_best, race.results["rows"][0]["time"], drifts[0], drifts[1]])
	race.queue_free()
	await t.physics_frames(2)


func _difficulty_spread() -> void:
	var avg := {}
	for diff in ["easy", "normal", "hard"]:
		var race := RaceHelper.make_race(self, {"track": "whiskerwood", "laps": 2, "difficulty": diff, "seed": 5,
			"autopilot_difficulty": "easy"})
		await RaceHelper.run_to_end(t, race, 300.0)
		var sum := 0.0
		var n := 0
		for e in race.entries:
			if e != race.player:
				sum += e.finish_time
				n += 1
		avg[diff] = sum / n
		race.queue_free()
		await t.physics_frames(2)
	var easy: float = avg["easy"]
	var normal: float = avg["normal"]
	var hard: float = avg["hard"]
	t.check(easy > normal * 1.04 and normal > hard * 1.03, "Difficulty levels produce clearly different pace", "avg AI 2-lap time: easy %.1f s, normal %.1f s, hard %.1f s" % [easy, normal, hard])
