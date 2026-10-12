extends StaticBody2D
## A cracked block that collapses shortly after the player stands on it and
## re-forms a few seconds later (never while the player is inside it).

const U := preload("res://scripts/objects/obj_util.gd")

const DELAY := 0.45
const RESPAWN := 3.0

var region := 1
var state := 0  # 0 intact, 1 shaking, 2 gone
var _timer := 0.0
var _shape: CollisionShape2D
var _sprite: Sprite2D
var _top: Area2D
var _player_inside := 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	_shape.shape = r
	_shape.position = Vector2(8, 8)
	add_child(_shape)
	_sprite = Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/tiles_r%d.png" % region)
	at.region = Rect2(9 * 16, 32, 16, 16)
	_sprite.texture = at
	_sprite.centered = false
	add_child(_sprite)
	_top = U.player_area(self, Vector2(14, 4), Vector2(8, -2))
	_top.body_entered.connect(func(b: Node) -> void:
		if U.is_player(b) and state == 0:
			state = 1
			_timer = DELAY
			Audio.play("crumble", -6.0))
	var inside := U.player_area(self, Vector2(14, 14), Vector2(8, 8))
	inside.body_entered.connect(func(_b: Node) -> void: _player_inside += 1)
	inside.body_exited.connect(func(_b: Node) -> void: _player_inside = maxi(0, _player_inside - 1))


func _physics_process(delta: float) -> void:
	match state:
		1:
			_timer -= delta
			_sprite.position = Vector2(randf_range(-1, 1), 0)
			(_sprite.texture as AtlasTexture).region = Rect2(10 * 16, 32, 16, 16)
			if _timer <= 0.0:
				state = 2
				_timer = RESPAWN
				_shape.set_deferred("disabled", true)
				var tw := create_tween()
				tw.tween_property(_sprite, "modulate:a", 0.0, 0.2)
		2:
			_timer -= delta
			if _timer <= 0.0 and _player_inside == 0:
				reset()


func reset() -> void:
	state = 0
	_shape.set_deferred("disabled", false)
	_sprite.position = Vector2.ZERO
	_sprite.modulate.a = 1.0
	(_sprite.texture as AtlasTexture).region = Rect2(9 * 16, 32, 16, 16)
