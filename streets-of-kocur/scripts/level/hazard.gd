extends Node2D
## Environmental hazards on a fixed, visible cycle:
##  puddle - an electrified puddle that crackles (warning) and then shocks
##           everyone standing in it, gang cats included;
##  press  - a hydraulic press that lights yellow, then red, then slams down.
## Each activation hits each target at most once.

var kind := "puddle"
var w := 70.0
var h := 22.0
var period := 3.0
var on_time := 1.0
var offset := 0.0
var t := 0.0
var cycle := -1
var hit_this_cycle: Array = []
const WARN := 0.8


func setup(d: Dictionary) -> void:
	kind = String(d["kind"])
	position = Vector2(float(d["x"]), float(d["y"]))
	w = float(d.get("w", 70.0))
	h = float(d.get("h", 22.0))
	period = float(d.get("period", 3.0))
	on_time = float(d.get("on", 1.0))
	offset = float(d.get("offset", 0.0))
	z_index = -1 if kind == "puddle" else 0


func phase() -> float:
	return fposmod(t + offset, period)


## "idle", "warn" or "active".
func status() -> String:
	var ph := phase()
	if ph >= period - on_time:
		return "active"
	if ph >= period - on_time - WARN:
		return "warn"
	return "idle"


func tick(dt: float, level: Node) -> void:
	t += dt
	var c := int(floor((t + offset) / period))
	if c != cycle:
		cycle = c
		hit_this_cycle = []
	var st := status()
	if st == "active":
		if kind == "press" and phase() - (period - on_time) < dt * 1.5:
			level.play_sfx("press", -2.0)
			level.shake(4.0, 0.12)
			level.fx.dust(position, 1.4)
		if kind == "puddle" and int(t * 10.0) % 4 == 0:
			level.play_sfx("electric", -10.0, 0.2)
		for f: Fighter in level.all_fighters():
			if f.dead or f in hit_this_cycle or f.z > 6.0:
				continue
			if inside(f.position):
				hit_this_cycle.append(f)
				level.hazard_hit(self, f)


func inside(p: Vector2) -> bool:
	var d := p - position
	if kind == "puddle":
		return (d.x * d.x) / (w * w) + (d.y * d.y) / (h * h) <= 1.0
	return absf(d.x) <= w and absf(d.y) <= h


func attack_data() -> Dictionary:
	if kind == "press":
		return {"dmg": 20.0, "kb": 200.0, "launch": 260.0, "knockdown": true, "type": "hazard", "stun": 0.5}
	return {"dmg": 12.0, "kb": 80.0, "stun": 0.5, "type": "hazard"}


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var st := status()
	if kind == "puddle":
		var base := Color(0.2, 0.35, 0.6, 0.55)
		draw_colored_polygon(CatPainter._ellipse(Vector2.ZERO, w, h, 0, 24), base)
		draw_colored_polygon(CatPainter._ellipse(Vector2(-w * 0.2, -h * 0.2), w * 0.5, h * 0.35, 0, 16), Color(0.6, 0.8, 1.0, 0.25))
		if st != "idle":
			var a := 1.0 if st == "active" else 0.35 + 0.35 * sin(t * 40.0)
			for i in 6:
				var ang := t * 9.0 + i * 1.7
				var p0 := Vector2(cos(ang) * w * 0.7, sin(ang * 1.3) * h * 0.6)
				var p1 := p0 + Vector2(cos(ang * 3.0) * 14.0, -10.0 - absf(sin(ang * 2.0)) * (26.0 if st == "active" else 8.0))
				draw_line(p0, p1, Color(0.7, 0.95, 1.0, a), 2.0)
				draw_line(p1, p1 + Vector2(6, -6), Color(1, 1, 0.6, a), 2.0)
			if st == "active":
				draw_colored_polygon(CatPainter._ellipse(Vector2.ZERO, w, h, 0, 24), Color(0.6, 0.9, 1.0, 0.35))
		# A small sign so the hazard is readable before it fires.
		draw_rect(Rect2(w + 6, -40, 4, 40), Color("4a4a58"))
		draw_colored_polygon(PackedVector2Array([Vector2(w + 8, -64), Vector2(w + 22, -40), Vector2(w - 6, -40)]), Color("f2c230"))
		draw_line(Vector2(w + 8, -58), Vector2(w + 8, -47), Color("2a2235"), 3.0)
	else:
		# Press: floor plate, two rails and a heavy head that drops when active.
		var ph := phase()
		var drop := 0.0
		if st == "active":
			var k := clampf((ph - (period - on_time)) / 0.08, 0.0, 1.0)
			drop = k
		elif st == "warn":
			drop = -0.06 * sin(t * 50.0)
		var top := -340.0
		var head_y := lerpf(-220.0, -6.0, clampf(drop, 0.0, 1.0)) + (drop * 10.0 if drop < 0.0 else 0.0)
		draw_rect(Rect2(-w - 6, -6, w * 2.0 + 12, 12), Color("3a3a48"))
		draw_rect(Rect2(-w + 4, top, 10, -top), Color("4a4a5a"))
		draw_rect(Rect2(w - 14, top, 10, -top), Color("4a4a5a"))
		draw_rect(Rect2(-12, top, 24, head_y - top), Color("8a94a0"))
		draw_rect(Rect2(-w, head_y - 40, w * 2.0, 40).grow(3.0), Color("2a2235"))
		draw_rect(Rect2(-w, head_y - 40, w * 2.0, 40), Color("c8a030"))
		for i in 6:
			var x := -w + i * (w * 2.0 / 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, head_y - 40), Vector2(x + 12, head_y - 40), Vector2(x + 24, head_y), Vector2(x + 12, head_y)]), Color("2a2235"))
		var light := Color("3adf6a")
		if st == "warn":
			light = Color("ffd23a") if ph < period - on_time - 0.3 else Color("ff3a3a")
		elif st == "active":
			light = Color("ff3a3a")
		draw_circle(Vector2(0, head_y - 52), 9.0, Color("2a2235"))
		draw_circle(Vector2(0, head_y - 52), 6.5, light)
		if st != "idle":
			draw_rect(Rect2(-w, -h, w * 2.0, h * 2.0), Color(1, 0.2, 0.1, 0.12 if st == "warn" else 0.25))
			draw_rect(Rect2(-w, -h, w * 2.0, h * 2.0), Color(1, 0.3, 0.2, 0.5), false, 2.0)
