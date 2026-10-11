extends Node
## Track integrity for all six circuits: geometry builds, start/finish and
## grid, checkpoint order, AI route data, respawn points, continuous road
## collision (no holes except designed gaps), corner radii, shortcuts,
## feature placement, passable hazards and sane medal targets.

var t


func run(suite) -> void:
	t = suite
	t.check(TrackCatalog.ORDER.size() == 6 and TrackCatalog.CUPS.size() == 3, "Six tracks in three two-track cups", "")
	var in_cups := []
	for c in TrackCatalog.CUPS:
		in_cups.append_array(c["tracks"])
	t.check(in_cups == TrackCatalog.ORDER, "Every track belongs to exactly one cup, in order", str(in_cups))
	for id in TrackCatalog.ORDER:
		await _track(id)


func _track(id: String) -> void:
	var name := TrackCatalog.track_name(id)
	var t0 := Time.get_ticks_msec()
	var tr := Track.new()
	add_child(tr)
	tr.setup(TrackCatalog.get_track(id))
	var ms := Time.get_ticks_msec() - t0
	await t.physics_frames(2)
	t.check(tr.main.size() > 300 and tr.get_node_or_null("StartGantry") != null and tr.get_node_or_null("RoadMain") != null, "%s: builds with road and start gantry" % name, "%.0f m, built in %d ms" % [tr.length, ms])
	# Start, grid and checkpoints.
	var grid_ok := true
	for slot in 6:
		var g := tr.grid_transform(slot)
		var loc := TrackLocation.new()
		tr.locate(g.origin, loc)
		var behind := tr.s_delta(loc.s, 0.0)
		if behind <= 3.0 or behind > 60.0 or absf(loc.lateral) > loc.half_width - 1.0:
			grid_ok = false
	t.check(grid_ok, "%s: all 6 grid slots on the road behind the line" % name, "")
	var cps := tr.checkpoints
	var ordered := cps[0] == 0.0 and cps.size() >= 8
	var max_gap := 0.0
	for i in range(1, cps.size()):
		if cps[i] <= cps[i - 1]:
			ordered = false
		max_gap = maxf(max_gap, cps[i] - cps[i - 1])
	t.check(ordered and max_gap < 160.0, "%s: %d ordered checkpoints from the finish line" % [name, cps.size()], "largest spacing %.0f m" % max_gap)
	# AI route data.
	var rl := tr.racing_line
	var route_ok := rl.points.size() == tr.main.size()
	var min_v := INF
	for i in tr.main.size():
		min_v = minf(min_v, rl.speeds[i])
		if absf(rl.offsets[i]) > tr.main.widths[i] * 0.5 - 1.0 or rl.speeds[i] > Kart.BASE_TOP_SPEED + 0.01:
			route_ok = false
	t.check(route_ok and min_v >= 6.0, "%s: racing line stays on the road with sane speeds" % name, "slowest planned corner %.1f m/s" % min_v)
	# Corner radii (inner edge never folds over itself).
	var shoulder := tr.shoulder
	var worst := 0.0
	for i in tr.main.size():
		worst = maxf(worst, absf(tr.main.curvature[i]) * (tr.main.widths[i] * 0.5 + Track.CURB_W + shoulder))
	t.check(worst < 0.9, "%s: no impossible corners" % name, "inner-edge fold factor %.2f" % worst)
	# Respawn points and road collision continuity.
	var space := tr.get_world_3d().direct_space_state
	var bad_respawn := 0
	var holes := []
	var s := 0.0
	while s < tr.length:
		var xf := tr.respawn_transform(s)
		var loc2 := TrackLocation.new()
		tr.locate(xf.origin, loc2)
		if loc2.off_track or loc2.in_gap or absf(loc2.lateral) > loc2.half_width or loc2.path != 0:
			bad_respawn += 1
		var designed := tr.is_gap(s) or tr.is_gap(s - 3.0)
		for r in tr.ramps:
			if Track.in_range(s, r["s"] - 1.0, r["s"] + r["length"] + 1.0, tr.length):
				designed = true   # ramp surface sits above the road by design
		if not designed:
			var i := tr.main.index_at_s(s)
			for lat in [-0.8, 0.0, 0.8]:
				var p: Vector3 = tr.main.positions[i] + tr.main.rights[i] * lat * (tr.main.widths[i] * 0.5)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 3.0, 1))
				if hit.is_empty():
					# A ray exactly on a shared triangle edge can slip through;
					# a real hole misses again a few centimetres away.
					var q := p + Vector3(0.05, 0.0, 0.05)
					hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 3.0, q - Vector3.UP * 3.0, 1))
				if hit.is_empty() or absf(hit["position"].y - p.y) > 0.6:
					holes.append("%.0f" % s)
		s += 4.0
	t.check(bad_respawn == 0, "%s: every respawn point is on solid road" % name, "%d bad points" % bad_respawn)
	t.check(holes.is_empty(), "%s: road surface is continuous outside designed gaps" % name, "holes at s=%s" % ", ".join(holes.slice(0, 6)))
	# Designed gaps really are gaps, with a ramp before them.
	for g in tr.gap_ranges:
		var mid := (g.x + g.y) * 0.5
		var i2 := tr.main.index_at_s(mid)
		var p2 := tr.main.positions[i2]
		var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(p2 + Vector3.UP * 2.0, p2 - Vector3.UP * 2.5, 1))
		var ramp_before := false
		for r in tr.ramps:
			if tr.s_delta(r["s"] + r["length"], g.x) >= -1.0 and tr.s_delta(r["s"] + r["length"], g.x) < 6.0:
				ramp_before = true
		t.check(hit2.is_empty() and ramp_before, "%s: jump gap at %.0f m has a ramp and open air" % [name, g.x], "")
	# Shortcuts join the main road at both ends.
	for k in tr.shortcuts.size():
		var sc := tr.shortcuts[k]
		var ends_ok := true
		for p3 in [sc.positions[0], sc.positions[sc.size() - 1]]:
			var l3 := TrackLocation.new()
			l3.main_index = -1
			var mi := tr.main.nearest_index(p3, -1)
			var pr := tr.main.project(p3, mi)
			if absf(pr.y) > tr.main.widths[mi] * 0.5 + Track.CURB_W + 3.0:
				ends_ok = false
		var saving := (sc.main_s_end - sc.main_s_start) - sc.length
		t.check(ends_ok and saving > 0.0 and saving < 80.0, "%s: shortcut %d connects to the road and saves a fair distance" % [name, k + 1], "saves %.0f m" % saving)
	# Pads, ramps and hazards sit on the road; hazards never block it.
	var placed := true
	for pad in tr.pads:
		if int(pad.z) == 0 and absf(pad.y) > tr.main.widths[tr.main.index_at_s(pad.x)] * 0.5:
			placed = false
	var passable := true
	for h in tr.hazards:
		var hw := tr.main.widths[tr.main.index_at_s(h.s)] * 0.5
		if h.kind == "static":
			continue
		if h.radius * 2.0 > hw * 2.0 - 5.0:
			passable = false
	# Static obstacles at the same spot must leave a lane of at least 4.5 m.
	var statics := tr.hazards.filter(func(h): return h.kind == "static")
	for a in statics:
		var hw2 := tr.main.widths[tr.main.index_at_s(a.s)] * 0.5
		var blocks := [[-hw2 - 5.0, -hw2], [hw2, hw2 + 5.0]]
		for b in statics:
			if absf(tr.s_delta(a.s, b.s)) < 4.0:
				blocks.append([b.lateral - b.radius, b.lateral + b.radius])
		blocks.sort_custom(func(x, y): return x[0] < y[0])
		var widest := 0.0
		for j in range(1, blocks.size()):
			widest = maxf(widest, blocks[j][0] - blocks[j - 1][1])
		if widest < 4.5:
			passable = false
	t.check(placed and passable, "%s: features on the road and hazards always passable" % name, "%d hazards, %d pads, %d ramps" % [tr.hazards.size(), tr.pads.size(), tr.ramps.size()])
	var m: Array = tr.def["medals"]
	t.check(m[0] < m[1] and m[1] < m[2] and m[0] > tr.length * 3.0 / 40.0, "%s: medal targets are ordered and achievable" % name, str(m))
	tr.queue_free()
	await t.physics_frames(2)
