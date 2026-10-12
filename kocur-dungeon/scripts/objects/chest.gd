extends Node2D
## Treasure chest: interact to open once for a burst of coins.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

const VALUE := 25

var level: Node
var key := ""
var opened := false
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -8)
	add_child(_sprite)
	var area := U.player_area(self, Vector2(26, 20), Vector2(0, -8))
	U.make_interactable(self, area)
	_refresh()


func _refresh() -> void:
	_sprite.texture = Sprites.region("chest.png", Rect2(16 if opened else 0, 0, 16, 16))


func can_interact() -> bool:
	return not opened


func interact(_p: Node) -> void:
	if opened:
		return
	opened = true
	_refresh()
	Audio.play("chest")
	if level and level.has_method("on_chest"):
		level.on_chest(self)
