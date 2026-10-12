extends Node2D
## A cage holding a captured black cat. Interact (or claw it) to free them.

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const U := preload("res://scripts/objects/obj_util.gd")
const GameData := preload("res://scripts/data/game_data.gd")

var level: Node
var cat_id := ""
var freed := false
var already_rescued := false
var _cage: Sprite2D
var _cat: AnimatedSprite2D


func _ready() -> void:
	var color := int(GameData.CATS[cat_id]["color"]) if GameData.CATS.has(cat_id) else 0
	_cat = AnimatedSprite2D.new()
	_cat.sprite_frames = Sprites.captive_frames(color)
	_cat.play("default")
	_cat.flip_h = true
	_cat.position = Vector2(0, -16)
	add_child(_cat)
	_cage = Sprite2D.new()
	_cage.texture = Sprites.region("cage.png", Rect2(0, 0, 32, 32))
	_cage.position = Vector2(0, -16)
	add_child(_cage)
	var area := U.player_area(self, Vector2(40, 32), Vector2(0, -16))
	U.make_interactable(self, area)
	if already_rescued:
		_open(false)


func can_interact() -> bool:
	return not freed


func interact(_p: Node) -> void:
	if freed:
		return
	_open(true)
	if level and level.has_method("on_rescue"):
		level.on_rescue(cat_id, global_position)


func _open(fx: bool) -> void:
	freed = true
	_cage.texture = Sprites.region("cage.png", Rect2(32, 0, 32, 32))
	if fx:
		Audio.play("lever")
		Audio.play("meow")
		Fx.burst(level, global_position + Vector2(0, -16), Color(1, 0.5, 0.6), 18)
		var tw := create_tween()
		tw.tween_property(_cat, "position", Vector2(0, -34), 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(_cat, "position", Vector2(12, -16), 0.25).set_ease(Tween.EASE_IN)
		tw.tween_interval(1.2)
		tw.tween_property(_cat, "modulate:a", 0.0, 0.6)
	else:
		_cat.visible = false
