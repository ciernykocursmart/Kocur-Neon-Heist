extends SceneTree
## Track design report: length, tightest corner, inner-edge folding, road
## overlaps and steepest slope for every circuit, plus a top-down PNG map.
##   godot --headless --path . -s res://tools/track_report.gd -- [out_dir] [track_id]

const MARGIN := 2.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://maps"
	var only := args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ok := true
	for id in TrackCatalog.ORDER:
		if not TrackCatalog.TRACKS.has(id) or (only != "" and id != only):
			continue
		ok = _report(id, out_dir) and ok
	quit(0 if ok else 1)


func _report(id: String, out_dir: String) -> bool:
	var d := TrackCatalog.get_track(id)
	var shoulder := float(d.get("shoulder", Track.DEFAULT_SHOULDER))
	var p := TrackPath.build(d["points"], true, float(d.get("width", 13.0)))
	var n := p.size()
	var min_r := INF
	var min_r_at := 0.0
	var fold := 0.0
	var fold_at := 0.0
	var max_slope := 0.0
	for i in n:
		var k := absf(p.curvature[i])
		if k > 0.0001 and 1.0 / k < min_r:
			min_r = 1.0 / k
			min_r_at = p.s_values[i] / p.length
		var edge := p.widths[i] * 0.5 + Track.CURB_W + shoulder
		if k * edge > fold:
			fold = k * edge
			fold_at = p.s_values[i] / p.length
		var j := p.wrap_index(i + 1)
		var dh := absf(p.positions[j].y - p.positions[i].y)
		max_slope = maxf(max_slope, rad_to_deg(atan2(dh, TrackPath.SPACING)))
	# Overlap between distant parts of the circuit.
	var worst := INF
	var worst_at := Vector2.ZERO
	for i in range(0, n, 2):
		for j in range(i + 1, n, 2):
			var arc := absf(p.s_values[j] - p.s_values[i])
			arc = minf(arc, p.length - arc)
			if arc < 80.0:
				continue
			var a := p.positions[i]
			var b := p.positions[j]
			if absf(a.y - b.y) > 6.0:
				continue
			var need := (p.widths[i] + p.widths[j]) * 0.5 + 2.0 * (Track.CURB_W + shoulder) + MARGIN
			var dist := Vector2(a.x - b.x, a.z - b.z).length()
			if dist - need < worst:
				worst = dist - need
				worst_at = Vector2(p.s_values[i], p.s_values[j]) / p.length
	print("== %s ==" % id)
	print("  length %.0f m, samples %d, est. lap @24m/s %.1f s" % [p.length, n, p.length / 24.0])
	print("  tightest radius %.1f m at f=%.3f" % [min_r, min_r_at])
	print("  inner-edge fold %.2f at f=%.3f (must be < 0.9)" % [fold, fold_at])
	print("  closest separate sections clearance %.1f m at f=%.3f/%.3f (must be > 0)" % [worst, worst_at.x, worst_at.y])
	print("  steepest slope %.1f deg" % max_slope)
	var marks := []
	for f in range(0, 20):
		var pos := p.point_at(p.length * f / 20.0)
		marks.append("%.2f:(%d,%d,h%.1f)" % [f / 20.0, pos.x, pos.z, pos.y])
	print("  marks " + " ".join(marks))
	var shortcuts := []
	for sc in d.get("shortcuts", []):
		var sp := TrackPath.build(sc["points"], false, float(sc.get("width", 7.0)))
		var a := p.project(sp.positions[0], p.nearest_index(sp.positions[0], -1))
		var b := p.project(sp.positions[sp.size() - 1], p.nearest_index(sp.positions[sp.size() - 1], -1))
		var main_len := fposmod(b.x - a.x, p.length)
		print("  shortcut %.0f m replaces %.0f m of main (f %.3f-%.3f), entry lateral %.1f exit lateral %.1f" % [sp.length, main_len, a.x / p.length, b.x / p.length, a.y, b.y])
		shortcuts.append(sp)
	_draw(p, shortcuts, d, out_dir.path_join(id + ".png"))
	return fold < 0.9 and worst > 0.0


func _draw(p: TrackPath, shortcuts: Array, d: Dictionary, path: String) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in p.positions:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	lo -= Vector2(30, 30)
	hi += Vector2(30, 30)
	var size := 900
	var scale := size / maxf(hi.x - lo.x, hi.y - lo.y)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.16, 0.12))
	# Grid every 50 m.
	for gx in range(int(floor(lo.x / 50.0)) * 50, int(hi.x), 50):
		var x := int((gx - lo.x) * scale)
		if x >= 0 and x < size:
			for y in size:
				img.set_pixel(x, y, Color(0.2, 0.25, 0.2))
	for gz in range(int(floor(lo.y / 50.0)) * 50, int(hi.y), 50):
		var y := int((gz - lo.y) * scale)
		if y >= 0 and y < size:
			for x in size:
				img.set_pixel(x, y, Color(0.2, 0.25, 0.2))
	var shoulder := float(d.get("shoulder", Track.DEFAULT_SHOULDER))
	for i in p.size():
		var hw := p.widths[i] * 0.5 + Track.CURB_W + shoulder
		_disc(img, p.positions[i], hw, lo, scale, Color(0.3, 0.38, 0.3))
	for sc in shortcuts:
		for i in sc.size():
			_disc(img, sc.positions[i], sc.widths[i] * 0.5, lo, scale, Color(0.65, 0.45, 0.25))
	for i in p.size():
		var h := clampf((p.positions[i].y + 2.0) / 14.0, 0.0, 1.0)
		var c := Color(0.45 + h * 0.5, 0.45 + h * 0.3, 0.5 - h * 0.3)
		var f := p.s_values[i] / p.length
		for r in d.get("ice", []):
			if f >= r[0] and f <= r[1]:
				c = Color(0.6, 0.85, 1.0)
		for r in d.get("gaps", []):
			if f >= r[0] and f <= r[1]:
				c = Color(0.9, 0.1, 0.1)
		_disc(img, p.positions[i], p.widths[i] * 0.5, lo, scale, c)
	for k in 20:
		var pos := p.point_at(p.length * k / 20.0)
		_disc(img, pos, 2.5, lo, scale, Color(1, 1, 1) if k % 5 else Color(1, 0.2, 1))
	_disc(img, p.positions[0], 4.0, lo, scale, Color(0.1, 1, 0.2))
	_disc(img, p.positions[4], 3.0, lo, scale, Color(0.1, 0.6, 1))
	img.save_png(path)


func _disc(img: Image, pos: Vector3, r: float, lo: Vector2, scale: float, c: Color) -> void:
	var cx := (pos.x - lo.x) * scale
	var cy := (pos.z - lo.y) * scale
	var rr := maxf(r * scale, 1.0)
	for y in range(int(cy - rr), int(cy + rr) + 1):
		for x in range(int(cx - rr), int(cx + rr) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= rr * rr:
				img.set_pixel(x, y, c)
