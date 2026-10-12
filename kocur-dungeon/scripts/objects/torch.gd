extends Node2D
## Wall torch with a flickering light.

const Sprites := preload("res://scripts/fx/sprites.gd")

var _light: PointLight2D
var _t := 0.0


func _ready() -> void:
	var s := Sprites.make_sprite("torch")
	s.frame = randi() % 3
	add_child(s)
	_light = PointLight2D.new()
	_light.texture = Sprites.texture("light.png")
	_light.texture_scale = 3.2
	_light.color = Color(1.0, 0.75, 0.45)
	_light.energy = 1.0
	add_child(_light)
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	_light.energy = 0.9 + sin(_t * 9.0) * 0.06 + sin(_t * 23.0) * 0.04
