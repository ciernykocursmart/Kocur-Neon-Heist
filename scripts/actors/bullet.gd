class_name Bullet
extends Node2D
## Lightweight projectile using swept raycasts (no physics body), which keeps
## fast bullets from tunnelling through thin walls.

const WORLD := 1
const PLAYER := 2
const ENEMY := 4

var game: Game
var velocity := Vector2.ZERO
var damage := 10.0
var from_player := true
var color := Palette.CYAN
var life := 1.4
var sneak_bonus := 1.0
var knockback := 110.0
var heavy := false
var _trail := 0.0
var _start_life := 1.4


func configure(opts: Dictionary) -> void:
	life = float(opts.get("life", life))
	sneak_bonus = float(opts.get("sneak_bonus", 1.0))
	knockback = float(opts.get("knockback", knockback))
	heavy = bool(opts.get("heavy", false))


func _ready() -> void:
	z_index = 4
	rotation = velocity.angle()
	_start_life = life


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, WORLD | (ENEMY if from_player else PLAYER))
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_on_hit(hit)
		return
	global_position = to
	_trail = minf(_trail + delta * 8.0, 1.0)
	queue_redraw()


func _on_hit(hit: Dictionary) -> void:
	var pos: Vector2 = hit["position"]
	var normal: Vector2 = hit["normal"]
	var collider = hit["collider"]
	var source := global_position - velocity.normalized() * 30.0
	if collider is Enemy:
		var enemy: Enemy = collider
		var dmg := damage
		if sneak_bonus > 1.0 and enemy.is_unaware():
			dmg *= sneak_bonus
			FX.float_text(game.fx_layer, pos + Vector2(0, -26), "SNEAK x%d" % int(sneak_bonus), Palette.MAGENTA, 13)
		enemy.take_damage(dmg, source, false, knockback)
		FX.burst(game.fx_layer, pos, Palette.WHITE, 6, 200.0, 0.18, 2.0, -velocity, 60.0)
		FX.burst(game.fx_layer, pos, enemy.color, 5, 160.0, 0.3, 2.5, velocity, 40.0)
	elif collider != null and collider.has_method("take_damage"):
		collider.take_damage(damage, source, false)
		FX.burst(game.fx_layer, pos, Palette.ORANGE, 6, 180.0, 0.18, 2.0, -velocity, 60.0)
	else:
		FX.burst(game.fx_layer, pos, color, 7, 200.0, 0.25, 2.2, normal, 70.0)
		FX.flash(game.fx_layer, pos, color, 40.0, 0.1, 0.6)
		Sfx.play_at("hit_wall", pos, -10.0)
	queue_free()


func _draw() -> void:
	var length := 22.0 * _trail + 6.0
	var width := 2.5
	if heavy:
		length += 18.0
		width = 4.5
	# Short-range pellets fade out as they travel.
	var a := clampf(life / maxf(_start_life, 0.01) * 2.0, 0.3, 1.0)
	draw_line(Vector2(-length, 0), Vector2.ZERO, Palette.with_alpha(color, 0.25 * a), width * 3.0, true)
	draw_line(Vector2(-length, 0), Vector2.ZERO, Palette.with_alpha(color, a), width, true)
	draw_circle(Vector2.ZERO, width * 0.9, Palette.with_alpha(Palette.WHITE, a))
