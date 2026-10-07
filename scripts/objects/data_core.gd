class_name DataCore
extends Hackable
## The mission objective: a server core holding the classified data.


func _ready() -> void:
	super._ready()
	display_name = "DATA CORE"
	action_name = "DOWNLOAD FROM"
	difficulty = 4
	interact_radius = 58.0
	add_to_group("objectives")


func describe() -> String:
	return "Mission objective"


func on_hacked() -> void:
	game.on_data_stolen()
	FX.burst(game.fx_layer, global_position, Palette.YELLOW, 30, 260.0, 0.7, 3.0)
	FX.ring(game.fx_layer, global_position, Palette.YELLOW, 160.0, 0.7, 3.0)


func on_hack_failed() -> void:
	game.alarm.raise_alarm(global_position, "DATA CORE INTRUSION")


func _draw() -> void:
	var col := Palette.YELLOW if not hacked_done else Palette.DIM
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	if not hacked_done:
		draw_circle(Vector2.ZERO, 30.0, Palette.with_alpha(col, 0.05 + 0.05 * pulse))
	var hexagon := PackedVector2Array()
	for i in 6:
		hexagon.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * 18.0)
	draw_colored_polygon(hexagon, Color(0.12, 0.1, 0.06))
	hexagon.append(hexagon[0])
	draw_polyline(hexagon, col, 2.5, true)
	# Rotating data rings.
	draw_arc(Vector2.ZERO, 11.0, _t * 2.0, _t * 2.0 + 4.0, 16, Palette.with_alpha(col, 0.9), 2.0, true)
	draw_arc(Vector2.ZERO, 7.0, -_t * 3.0, -_t * 3.0 + 3.5, 12, Palette.with_alpha(col, 0.7), 2.0, true)
	draw_circle(Vector2.ZERO, 3.0, col)
	draw_focus_ring(34.0)
