extends Node2D
## Lever: interact to open the iron gate group linked to it.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

signal pulled

var level: Node
var on := false
var gates: Array[Node] = []
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -8)
	add_child(_sprite)
	var area := U.player_area(self, Vector2(24, 20), Vector2(0, -8))
	U.make_interactable(self, area)
	_refresh()


func _refresh() -> void:
	_sprite.texture = Sprites.region("lever.png", Rect2(16 if on else 0, 0, 16, 16))


func can_interact() -> bool:
	return not on


func interact(_p: Node) -> void:
	if on:
		return
	on = true
	_refresh()
	Audio.play("lever")
	for g in gates:
		if is_instance_valid(g):
			g.open()
	pulled.emit()
	if level and level.has_method("toast"):
		level.toast("A gate rumbles open!")
