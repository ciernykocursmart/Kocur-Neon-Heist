extends Node2D
## Mine machinery: a floor nozzle that puffs smoke as a warning, then fires
## a column of flame on a fixed, learnable rhythm.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

const OFF_TIME := 1.6
const WARN_TIME := 0.55
const ON_TIME := 1.0

var offset := 0.0
var damage := 2
var _t := 0.0
var _flame: AnimatedSprite2D
var _area: Area2D
var _smoke: CPUParticles2D
var _light: PointLight2D
var _state := -1


func _ready() -> void:
	var base := Sprite2D.new()
	base.texture = Sprites.texture("flame_base.png")
	base.position = Vector2(0, -8)
	add_child(base)
	_flame = Sprites.make_sprite("flame")
	_flame.position = Vector2(0, -16 - 24)
	_flame.visible = false
	add_child(_flame)
	_area = U.player_area(self, Vector2(10, 44), Vector2(0, -38))
	_area.body_entered.connect(_on_body)
	_smoke = CPUParticles2D.new()
	_smoke.amount = 10
	_smoke.lifetime = 0.5
	_smoke.direction = Vector2.UP
	_smoke.spread = 15
	_smoke.initial_velocity_min = 20
	_smoke.initial_velocity_max = 40
	_smoke.gravity = Vector2.ZERO
	_smoke.color = Color(0.6, 0.55, 0.55, 0.6)
	_smoke.scale_amount_min = 1.5
	_smoke.scale_amount_max = 3.0
	_smoke.position = Vector2(0, -14)
	_smoke.emitting = false
	add_child(_smoke)
	_light = PointLight2D.new()
	_light.texture = Sprites.texture("light.png")
	_light.texture_scale = 2.0
	_light.color = Color(1, 0.6, 0.2)
	_light.energy = 0.0
	_light.position = Vector2(0, -32)
	add_child(_light)
	_t = fmod(offset, OFF_TIME + WARN_TIME + ON_TIME)


func is_firing() -> bool:
	return _state == 2


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, OFF_TIME + WARN_TIME + ON_TIME)
	var s := 0
	if _t >= OFF_TIME + WARN_TIME:
		s = 2
	elif _t >= OFF_TIME:
		s = 1
	if s != _state:
		_state = s
		_smoke.emitting = s == 1
		_flame.visible = s == 2
		_light.energy = 1.0 if s == 2 else 0.0
		if s == 2:
			_play_near("fire")
			for b in _area.get_overlapping_bodies():
				_on_body(b)


func _play_near(sound: String) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(global_position) < 260:
		Audio.play(sound, -8.0)


func _on_body(b: Node) -> void:
	if _state == 2 and U.is_player(b):
		b.hurt(damage, global_position)


func _process(_delta: float) -> void:
	if _state == 2:
		for b in _area.get_overlapping_bodies():
			if U.is_player(b):
				b.hurt(damage, global_position)
