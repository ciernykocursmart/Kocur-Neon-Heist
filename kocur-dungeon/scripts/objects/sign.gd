extends Node2D
## Wooden sign: shows a hint while the cat stands near it.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var text := ""
var _panel: PanelContainer


func _ready() -> void:
	var s := Sprite2D.new()
	s.texture = Sprites.texture("sign.png")
	s.position = Vector2(0, -8)
	add_child(s)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.12, 0.92)
	sb.border_color = Color(0.85, 0.7, 0.4)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(170, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(l)
	_panel.visible = false
	_panel.z_index = 40
	add_child(_panel)
	var area := U.player_area(self, Vector2(56, 40), Vector2(0, -16))
	area.body_entered.connect(func(b: Node) -> void:
		if U.is_player(b):
			_show(true))
	area.body_exited.connect(func(b: Node) -> void:
		if U.is_player(b):
			_show(false))


func _show(v: bool) -> void:
	_panel.visible = v
	if v:
		await get_tree().process_frame
		_panel.position = Vector2(-_panel.size.x / 2, -24 - _panel.size.y)
