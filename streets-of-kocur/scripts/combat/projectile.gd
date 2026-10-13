extends Node2D
## Thrown objects and travelling attacks: bottles, fish bones, ground
## shockwaves and cans falling from the sky. Each one carries one attack
## activation (unique hit list), so it can hit each target at most once.

var level: Node
var kind := "bottle"
var atk := {}
var vel_x := 0.0
var z := 0.0
var vz := 0.0
var facing := 1
var t := 0.0
var life := 2.0
var single_hit := true
var target_team := "player"
var spent := false
var warn := 0.0  ## falling objects: telegraph time before they drop


func setup_thrown(lvl: Node, owner_f: Node2D, k: String, dmg: float, dir: int, speed := 430.0, dz := 0.0) -> void:
	level = lvl
	kind = k
	facing = dir
	position = owner_f.position + Vector2(dir * 30.0, dz)
	z = 34.0
	vel_x = dir * speed
	life = 2.2
	atk = owner_f.make_attack({"dmg": 1.0, "radial": true, "rx": 14.0, "depth": 14.0, "z0": -14.0, "z1": 14.0,
		"kb": 120.0, "stun": 0.35, "type": "light"}, dmg)


func setup_shockwave(lvl: Node, owner_f: Node2D, dmg: float, dir: int, speed := 380.0) -> void:
	level = lvl
	kind = "shockwave"
	facing = dir
	position = owner_f.position + Vector2(dir * 40.0, 0)
	z = 0.0
	vel_x = dir * speed
	life = 1.7
	single_hit = false
	atk = owner_f.make_attack({"dmg": 1.0, "radial": true, "rx": 22.0, "depth": 20.0, "z0": -10.0, "z1": 24.0,
		"kb": 220.0, "launch": 240.0, "knockdown": true, "type": "heavy"}, dmg)


func setup_fall(lvl: Node, owner_f: Node2D, dmg: float, at: Vector2, delay := 0.9) -> void:
	level = lvl
	kind = "can_fall"
	position = at
	z = 520.0
	warn = delay
	life = delay + 1.0
	atk = owner_f.make_attack({"dmg": 1.0, "radial": true, "rx": 26.0, "depth": 20.0, "z0": -10.0, "z1": 40.0,
		"kb": 150.0, "stun": 0.4, "type": "heavy"}, dmg)


func tick(dt: float) -> void:
	t += dt
	if spent:
		return
	if kind == "can_fall":
		if t < warn:
			z = 520.0 * (1.0 - pow(t / warn, 2.0))
			if z < 40.0:
				level.resolve_attack(self, atk, target_team)
		else:
			z = 0.0
			level.fx.dust(position, 1.0)
			level.play_sfx("crate", -6.0, 0.15)
			_expire()
		return
	position.x += vel_x * dt
	level.resolve_attack(self, atk, target_team)
	if single_hit and not (atk["hit"] as Array).is_empty():
		level.fx.spark(position + Vector2(0, -z), 0.7)
		if kind == "bottle":
			level.play_sfx("glass", -4.0)
		_expire()
		return
	var b: Rect2 = level.view_rect()
	if t >= life or position.x < b.position.x - 120.0 or position.x > b.end.x + 120.0:
		_expire()


func _expire() -> void:
	spent = true
	level.remove_actor(self)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	match kind:
		"can_fall":
			var k := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
			draw_colored_polygon(CatPainter._ellipse(Vector2.ZERO, 30.0 * (0.5 + k * 0.5), 9.0 * (0.5 + k * 0.5)), Color(1, 0.2, 0.2, 0.25 + 0.35 * k))
			draw_arc(Vector2.ZERO, 30.0, 0, TAU, 20, Color(1, 0.3, 0.2, 0.6), 2.0)
			PickupArt.draw_item(self, "can", Vector2(0, -z - 12), 1.1, t * 8.0)
		"shockwave":
			var w := 30.0
			for i in 3:
				var hgt := 26.0 - i * 7.0
				draw_colored_polygon(PackedVector2Array([Vector2(-w + i * 6, 0), Vector2(0, -hgt), Vector2(w - i * 6, 0)]),
					Color(1.0, 0.85 - i * 0.2, 0.3, 0.75))
			draw_colored_polygon(CatPainter._ellipse(Vector2.ZERO, 34, 8), Color(1, 0.7, 0.3, 0.3))
		_:
			CatPainter.draw_shadow(self, 10.0, z)
			draw_set_transform(Vector2(0, -z), t * 14.0 * facing, Vector2.ONE)
			if kind == "fishbone":
				draw_line(Vector2(-12, 0), Vector2(12, 0), Color("2a2235"), 5.0)
				draw_line(Vector2(-12, 0), Vector2(12, 0), Color("f4f0e6"), 3.0)
				for i in 4:
					var x := -7.0 + i * 5.0
					draw_line(Vector2(x, -6), Vector2(x, 6), Color("f4f0e6"), 2.0)
				draw_circle(Vector2(13, 0), 4.0, Color("f4f0e6"))
			else:
				draw_rect(Rect2(-5, -10, 10, 16), Color("1e6a3a"))
				draw_rect(Rect2(-4, -9, 8, 14), Color("2fae5a"))
				draw_rect(Rect2(-2.5, -16, 5, 7), Color("2fae5a"))
				draw_rect(Rect2(-3, -4, 6, 4), Color("f4e6b0"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
