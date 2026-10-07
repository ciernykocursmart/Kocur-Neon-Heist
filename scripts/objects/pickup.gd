class_name Pickup
extends Node2D
## Auto-collected item: ammo, medkit or credit chip.

enum Kind { AMMO, MEDKIT, CREDITS }

var game: Game
var kind := Kind.AMMO
var amount := 0
var _t := 0.0
var _collected := false


func _ready() -> void:
	_t = randf() * TAU
	if amount <= 0:
		match kind:
			Kind.AMMO:
				amount = 16
			Kind.MEDKIT:
				amount = 35
			Kind.CREDITS:
				amount = 25


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _collected or game.player == null or game.player.dead:
		return
	var d := global_position.distance_to(game.player.global_position)
	if d < 70.0:
		# Magnet effect.
		global_position = global_position.move_toward(game.player.global_position, delta * (260.0 - d * 2.0))
	if d < 20.0:
		_collect()


func _collect() -> void:
	var p := game.player
	match kind:
		Kind.AMMO:
			if p.reserve >= Player.MAX_RESERVE:
				return
			p.add_ammo(amount)
			FX.float_text(game.fx_layer, global_position, "+%d AMMO" % amount, Palette.CYAN, 14)
			Sfx.play("pickup", -2.0)
		Kind.MEDKIT:
			if p.hp >= p.max_hp:
				return
			p.heal(amount)
			FX.float_text(game.fx_layer, global_position, "+%d HP" % amount, Palette.GREEN, 14)
			Sfx.play("pickup", -2.0, 1.2)
		Kind.CREDITS:
			game.collect_credits(amount, global_position)
	_collected = true
	FX.ring(game.fx_layer, global_position, _color(), 40.0, 0.3, 2.0)
	queue_free()


func _color() -> Color:
	match kind:
		Kind.MEDKIT:
			return Palette.GREEN
		Kind.CREDITS:
			return Palette.YELLOW
	return Palette.CYAN


func _draw() -> void:
	var col := _color()
	var bob := sin(_t * 3.0) * 2.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 12.0, Palette.with_alpha(col, 0.08))
	match kind:
		Kind.AMMO:
			draw_rect(Rect2(-7, -5, 14, 10), Color(0.08, 0.1, 0.15))
			draw_rect(Rect2(-7, -5, 14, 10), col, false, 1.5)
			for i in 3:
				draw_line(Vector2(-4 + i * 4, -3), Vector2(-4 + i * 4, 3), col, 1.5)
		Kind.MEDKIT:
			draw_rect(Rect2(-7, -7, 14, 14), Color(0.06, 0.12, 0.08))
			draw_rect(Rect2(-7, -7, 14, 14), col, false, 1.5)
			draw_line(Vector2(0, -4), Vector2(0, 4), col, 3.0)
			draw_line(Vector2(-4, 0), Vector2(4, 0), col, 3.0)
		Kind.CREDITS:
			var rot := _t * 2.0
			var pts := PackedVector2Array()
			for i in 4:
				pts.append(Vector2.from_angle(rot + PI * 0.5 * i) * Vector2(7.0, 7.0))
			draw_colored_polygon(pts, Palette.with_alpha(col, 0.3))
			pts.append(pts[0])
			draw_polyline(pts, col, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
