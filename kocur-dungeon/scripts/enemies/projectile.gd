extends Area2D
## Enemy projectile (arrow, magic orb, fireball, ice shard, pale orb, ground
## shockwave). Destroyed by walls, on hitting the cat, by a claw swipe
## (deflect) or when its lifetime ends - so none are ever left behind.

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")

var level: Node
var kind := "arrow"
var velocity := Vector2.ZERO
var damage := 2
var lifetime := 4.0
var grav := 0.0
var ground_wave := false
var deflectable := true
var _sprite: Node2D
var _dead := false


func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 16
	collision_mask = 2 | 1
	var cs := CollisionShape2D.new()
	if kind == "shockwave":
		var r := RectangleShape2D.new()
		r.size = Vector2(22, 12)
		cs.shape = r
		cs.position = Vector2(0, -6)
	else:
		var c := CircleShape2D.new()
		c.radius = 4.0 if kind == "arrow" or kind == "ice_shard" else 5.0
		cs.shape = c
	add_child(cs)
	if kind == "arrow" or kind == "ice_shard":
		var s := Sprite2D.new()
		s.texture = Sprites.texture(kind + ".png")
		_sprite = s
	else:
		_sprite = Sprites.make_sprite(kind)
		if kind == "shockwave":
			_sprite.position = Vector2(0, -8)
	add_child(_sprite)
	if kind in ["orb", "fireball", "pale_orb", "shadow_orb"]:
		var l := PointLight2D.new()
		l.texture = Sprites.texture("light.png")
		l.texture_scale = 1.0
		l.energy = 0.7
		l.color = {"orb": Color(0.8, 0.5, 1), "fireball": Color(1, 0.6, 0.2), "pale_orb": Color(0.9, 0.9, 1),
			"shadow_orb": Color(0.6, 0.3, 1)}[kind]
		add_child(l)
	body_entered.connect(_on_body)
	if not ground_wave:
		rotation = velocity.angle() if kind == "arrow" or kind == "ice_shard" else 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_destroy(false)
		return
	velocity.y += grav * delta
	global_position += velocity * delta
	if kind == "arrow" or kind == "ice_shard":
		rotation = velocity.angle()
	if level:
		var g: RefCounted = level.grid
		var c: Vector2i = g.cell_of(global_position)
		if g.is_static_solid(c.x, c.y):
			_destroy(true)
			return
		if ground_wave:
			var ahead: Vector2i = g.cell_of(global_position + Vector2(signf(velocity.x) * 8, 4))
			if not (g.is_solid(ahead.x, ahead.y) or g.is_oneway(ahead.x, ahead.y)):
				_destroy(true)
				return
		if global_position.y > g.pixel_size().y + 64:
			_destroy(false)


func _on_body(b: Node) -> void:
	if _dead:
		return
	if b.is_in_group("player"):
		if b.hurt(damage, global_position - velocity.normalized() * 8):
			_destroy(true)
		elif not ground_wave:
			_destroy(true)
	elif b is StaticBody2D and not ground_wave:
		_destroy(true)


func deflect() -> void:
	if not deflectable or _dead:
		return
	Audio.play("hit", -6.0)
	_destroy(true)


func _destroy(fx: bool) -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	if fx and level:
		Fx.spark(level, global_position)
	queue_free()
