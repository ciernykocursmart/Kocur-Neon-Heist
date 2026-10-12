extends Area2D
## Coins, fish (healing), Shadow Gems and boss relics.
## `ghost` pickups were already banked on an earlier run: they can still be
## touched but award nothing, so replays never duplicate permanent rewards.

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var kind := "coin"   # coin | fish | gem | relic
var key := ""
var value := 1
var ghost := false
var level: Node
var relic_index := 0
var collected := false
var _base_y := 0.0
var _t := 0.0
var _sprite: Node2D
var _magnet := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = U.PLAYER_MASK
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 7.0
	cs.shape = c
	add_child(cs)
	if kind == "relic":
		var s := Sprite2D.new()
		s.texture = Sprites.region("relic.png", Rect2(relic_index * 16, 0, 16, 16))
		_sprite = s
	else:
		var a := Sprites.make_sprite(kind)
		a.frame = randi() % 4
		_sprite = a
	add_child(_sprite)
	if ghost:
		_sprite.modulate = Color(1, 1, 1, 0.3)
	if kind == "gem" or kind == "relic":
		var glow := PointLight2D.new()
		glow.texture = Sprites.texture("light.png")
		glow.texture_scale = 1.2
		glow.energy = 0.8
		glow.color = Color(0.7, 0.4, 1.0) if kind == "gem" else Color(1, 0.9, 0.5)
		add_child(glow)
	_base_y = position.y
	_t = randf() * TAU
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if collected:
		return
	_t += delta
	if kind != "coin" or not _magnet:
		_sprite.position.y = sin(_t * 3.0) * 1.5
	if kind == "coin" and level and level.player and not ghost:
		var p: Node2D = level.player
		var target := p.global_position + Vector2(0, -8)
		var d := global_position.distance_to(target)
		if d < Progress.magnet_radius():
			_magnet = true
		if _magnet:
			global_position = global_position.move_toward(target, (140.0 + 200.0 / maxf(d, 8.0) * 10.0) * delta)


func _on_body(b: Node) -> void:
	if collected or not U.is_player(b):
		return
	if kind == "fish" and b.hp >= b.max_hp:
		return  # Leave fish for when it is needed.
	collect(b)


func collect(p: Node) -> void:
	if collected:
		return
	collected = true
	set_deferred("monitoring", false)
	if level and level.has_method("on_pickup"):
		level.on_pickup(self, p)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "position:y", _sprite.position.y - 10, 0.25)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
