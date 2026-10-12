extends Node2D
## Frostfang icicle: shivers when the cat passes underneath, then drops.

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var level: Node
var state := 0  # 0 hanging, 1 shaking, 2 falling, 3 gone
var _t := 0.0
var _vy := 0.0
var _sprite: Sprite2D
var _area: Area2D
var _home := Vector2.ZERO


func _ready() -> void:
	_home = position
	_sprite = Sprite2D.new()
	_sprite.texture = Sprites.texture("icicle.png")
	_sprite.position = Vector2(0, 8)
	add_child(_sprite)
	_area = U.player_area(self, Vector2(8, 12), Vector2(0, 8))
	_area.body_entered.connect(func(b: Node) -> void:
		if state == 2 and U.is_player(b):
			b.hurt(2, global_position)
			_shatter())


func _physics_process(delta: float) -> void:
	var p: Node2D = level.player if level else null
	match state:
		0:
			if p and absf(p.global_position.x - global_position.x) < 20 and p.global_position.y > global_position.y \
					and p.global_position.y - global_position.y < 16 * 7:
				state = 1
				_t = 0.45
				Audio.play("ice", -6.0)
		1:
			_t -= delta
			_sprite.position.x = randf_range(-1, 1)
			if _t <= 0:
				state = 2
				_vy = 0.0
		2:
			_vy = minf(_vy + 900 * delta, 420)
			position.y += _vy * delta
			var c: Vector2i = level.grid.cell_of(global_position + Vector2(0, 16))
			if level.grid.is_solid(c.x, c.y) or level.grid.is_oneway(c.x, c.y) or position.y > _home.y + 16 * 30:
				_shatter()
		3:
			_t -= delta
			if _t <= 0:
				reset()


func _shatter() -> void:
	state = 3
	_t = 3.0
	visible = false
	Fx.burst(level, global_position + Vector2(0, 12), Color(0.7, 0.9, 1.0), 10, 60)
	Audio.play("ice", -8.0)


func reset() -> void:
	state = 0
	position = _home
	visible = true
	_sprite.position = Vector2(0, 8)
