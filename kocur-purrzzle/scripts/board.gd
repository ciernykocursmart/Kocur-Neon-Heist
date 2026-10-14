class_name Board
extends Control
## Draws the puzzle (pixel art, animated). Logic lives in Puzzle; this only follows it.

var pz: Puzzle
var region := 0
var vis_p := Vector2.ZERO
var vis_c: Array = []
var t := 0.0
var squash := 0.0
var shake := Vector2.ZERO
var happy := false
var facing := 1
var fx: Array = []   # {p: Vector2 (cell), age: float, col: Color, ring: bool}
var _dust: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 26:
		_dust.append(Vector3(rng.randf(), rng.randf(), rng.randf()))

func setup(p: Puzzle, r: int) -> void:
	pz = p
	region = r
	happy = false
	fx.clear()
	snap()

func snap() -> void:
	vis_p = Vector2(pz.player)
	vis_c = []
	for c in pz.crates:
		vis_c.append(Vector2(c))

func snap_player_to_logic() -> void:
	vis_p = Vector2(pz.player)

func busy() -> bool:
	return pz != null and vis_p.distance_to(Vector2(pz.player)) > 0.55

func bump(dir: Vector2i) -> void:
	shake = Vector2(dir) * 0.14

func burst(cell: Vector2i, col: Color, ring := false) -> void:
	fx.append({"p": Vector2(cell), "age": 0.0, "col": col, "ring": ring})

func _process(delta: float) -> void:
	t += delta
	if pz == null:
		return
	vis_p = _follow(vis_p, Vector2(pz.player), delta)
	while vis_c.size() < pz.crates.size():
		vis_c.append(Vector2(pz.crates[vis_c.size()]))
	for i in pz.crates.size():
		vis_c[i] = _follow(vis_c[i], Vector2(pz.crates[i]), delta)
	squash = maxf(0.0, squash - delta * 6.0)
	shake = shake.move_toward(Vector2.ZERO, delta * 1.2)
	for e in fx:
		e.age += delta
	fx = fx.filter(func(e): return e.age < 0.6)
	queue_redraw()

func _follow(cur: Vector2, goal: Vector2, delta: float) -> Vector2:
	var dist := cur.distance_to(goal)
	return cur.move_toward(goal, maxf(11.0, dist / 0.16) * delta)

func _metrics() -> Dictionary:
	var avail := Rect2(Vector2(0, 76), Vector2(size.x, size.y - 76 - 78))
	var s := clampi(int(floor(minf(avail.size.x / (16.0 * pz.w), avail.size.y / (16.0 * pz.h)))), 2, 6)
	var ts := 16.0 * s
	var org := avail.position + (avail.size - Vector2(pz.w, pz.h) * ts) * 0.5
	return {"ts": ts, "org": org}

func _draw() -> void:
	var th: Dictionary = Sprites.THEMES[region]
	draw_rect(Rect2(Vector2.ZERO, size), th.bg)
	for d in _dust:
		var x := fposmod(d.x * size.x + sin(t * 0.5 + d.z * 6.0) * 30.0, size.x)
		var y := fposmod(d.y * size.y + (t * 14.0 * (0.4 + d.z) if region == 2 else (-t * 10.0 * (0.4 + d.z) if region == 4 else sin(t + d.z * 9.0) * 16.0)), size.y)
		var a := 0.35 + 0.35 * sin(t * 2.0 + d.z * 20.0)
		draw_rect(Rect2(x, y, 4, 4), Color(th.spark, a))
	if pz == null:
		return
	var m := _metrics()
	var ts: float = m.ts
	var org: Vector2 = m.org + shake * ts
	var tsv := Vector2(ts, ts)
	var fl0 := Sprites.tex("floor0", region)
	var fl1 := Sprites.tex("floor1", region)
	for y in pz.h:
		for x in pz.w:
			var p := Vector2i(x, y)
			var r := Rect2(org + Vector2(x, y) * ts, tsv)
			var tl := pz.tile(p)
			if tl == "#":
				draw_texture_rect(Sprites.tex("wall", region), r, false)
				continue
			draw_texture_rect(fl0 if (x + y) % 2 == 0 else fl1, r, false)
			if pz.tile(p + Vector2i.UP) == "#":
				draw_rect(Rect2(r.position, Vector2(ts, ts * 0.25)), Color(0, 0, 0, 0.18))
			var tn := ""
			match tl:
				"T": tn = "target"
				"E": tn = "exit_open" if pz.exit_open() else "exit_closed"
				"p": tn = "switch_on" if (pz.crate_at(p) >= 0 or pz.player == p) else "switch"
				"D": tn = "door_open" if pz.doors_open else "door"
				"L": tn = "" if pz.unlocked.has(p) else "locked"
				"i": tn = "ice"
				"a", "b", "c": tn = "pad_" + tl
				"x": tn = "gate_x_open" if pz.moves % 2 == 0 else "gate_x"
				"y": tn = "gate_y_open" if pz.moves % 2 == 1 else "gate_y"
			if tn != "":
				var rr := r
				if tn == "exit_open":
					var pulse := 1.0 + sin(t * 4.0) * 0.06
					rr = Rect2(r.position - tsv * (pulse - 1.0) * 0.5, tsv * pulse)
				elif tn.begins_with("pad_"):
					rr = Rect2(r.position, tsv)
					draw_set_transform(r.position + tsv * 0.5, t * 1.5, Vector2.ONE)
					draw_texture_rect(Sprites.tex(tn, region), Rect2(-tsv * 0.5, tsv), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					continue
				draw_texture_rect(Sprites.tex(tn, region), rr, false)
	for f in pz.fish:
		var r := Rect2(org + Vector2(f) * ts + Vector2(0, sin(t * 3.0 + f.x * 1.7) * ts * 0.06), tsv)
		draw_texture_rect(Sprites.tex("fish", region), r, false)
	for k in pz.floor_keys:
		var r := Rect2(org + Vector2(k) * ts + Vector2(0, sin(t * 3.0 + k.y) * ts * 0.06), tsv)
		draw_texture_rect(Sprites.tex("key", region), r, false)
	var stuck := pz.stuck_crates()
	for i in pz.crates.size():
		var cp: Vector2 = vis_c[i]
		var r := Rect2(org + cp * ts, tsv)
		var done := pz.tile(pz.crates[i]) == "T"
		draw_texture_rect(Sprites.tex("crate_done" if done else "crate", region), r, false)
		if stuck.has(i):
			draw_rect(r, Color(1, 0.2, 0.2, 0.25 + 0.2 * sin(t * 8.0)), false, 3.0)
	# cat
	var cr := Rect2(org + vis_p * ts, tsv)
	draw_ellipse_shadow(cr)
	var hop := -absf(sin(vis_p.x * PI + vis_p.y * PI)) * ts * 0.12 if busy() else 0.0
	var sq := squash * 0.14
	var catr := Rect2(cr.position + Vector2(0, hop + ts * sq), Vector2(ts, ts * (1.0 - sq)))
	var cn := "cat_open"
	if happy:
		cn = "cat_happy"
		catr.position.y -= absf(sin(t * 8.0)) * ts * 0.2
	elif squash > 0.01 or fmod(t, 3.7) < 0.12:
		cn = "cat_blink"
	# Mirror with a transform: a negative-width rect is drawn one tile off on some renderers.
	if facing < 0:
		draw_set_transform(Vector2(catr.position.x + catr.size.x, catr.position.y), 0.0, Vector2(-1, 1))
		draw_texture_rect(Sprites.tex(cn, region), Rect2(Vector2.ZERO, catr.size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(Sprites.tex(cn, region), catr, false)
	for e in fx:
		var c: Vector2 = org + (e.p + Vector2(0.5, 0.5)) * ts
		var a: float = 1.0 - e.age / 0.6
		if e.ring:
			draw_arc(c, ts * (0.2 + e.age * 1.4), 0.0, TAU, 20, Color(e.col, a), 3.0)
		else:
			for j in 6:
				var ang := j * TAU / 6.0 + 0.5
				draw_rect(Rect2(c + Vector2.from_angle(ang) * ts * (0.2 + e.age * 0.9) - Vector2(3, 3), Vector2(6, 6)), Color(e.col, a))

func draw_ellipse_shadow(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.15, r.size.y * 0.88), Vector2(r.size.x * 0.7, r.size.y * 0.08)), Color(0, 0, 0, 0.25))
