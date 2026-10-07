class_name DataCore
extends Hackable
## Objective terminal. Roles:
##   data    - the single classified core of a normal mission
##   shard   - one of several cores in a multi-shard mission
##   uplink  - final mission: breach all three to unseal the WARDEN vault
##   archive - final mission: the LULLABY archive, sealed until WARDEN falls

var role := "data"


func _ready() -> void:
	super._ready()
	action_name = "DOWNLOAD FROM"
	interact_radius = 58.0
	match role:
		"shard":
			display_name = "DATA SHARD"
			difficulty = 3
		"uplink":
			display_name = "SECURITY UPLINK"
			action_name = "BREACH"
			difficulty = 3
		"archive":
			display_name = "LULLABY ARCHIVE"
			difficulty = 4
		_:
			display_name = "DATA CORE"
			difficulty = 4
	add_to_group("objectives")


func describe() -> String:
	if sealed:
		return sealed_reason()
	match role:
		"uplink":
			return "Weakens the core seal"
		"archive":
			return "The truth behind LULLABY"
	return "Mission objective - failure trips the alarm"


func sealed_reason() -> String:
	return "Defeat the WARDEN first"


func on_hacked() -> void:
	game.on_core_hacked(self)
	var col := _color()
	FX.burst(game.fx_layer, global_position, col, 30, 260.0, 0.7, 3.0)
	FX.ring(game.fx_layer, global_position, col, 160.0, 0.7, 3.0)


func on_hack_failed() -> void:
	if role == "data" or role == "archive":
		game.alarm.raise_alarm(global_position, "%s INTRUSION" % display_name)
	else:
		super.on_hack_failed()


func _color() -> Color:
	match role:
		"uplink":
			return Palette.CYAN
		"archive":
			return Palette.MAGENTA
	return Palette.YELLOW


func _draw() -> void:
	var col := _color() if not hacked_done else Palette.DIM
	if sealed:
		col = Palette.with_alpha(col, 0.45)
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	if not hacked_done and not sealed:
		draw_circle(Vector2.ZERO, 30.0, Palette.with_alpha(col, 0.05 + 0.05 * pulse))
	var sides := 6 if role != "uplink" else 4
	var poly := PackedVector2Array()
	for i in sides:
		poly.append(Vector2.from_angle(TAU * i / sides + PI / sides) * (18.0 if role != "archive" else 22.0))
	draw_colored_polygon(poly, Color(0.12, 0.1, 0.06))
	poly.append(poly[0])
	draw_polyline(poly, col, 2.5, true)
	draw_arc(Vector2.ZERO, 11.0, _t * 2.0, _t * 2.0 + 4.0, 16, Palette.with_alpha(col, 0.9), 2.0, true)
	draw_arc(Vector2.ZERO, 7.0, -_t * 3.0, -_t * 3.0 + 3.5, 12, Palette.with_alpha(col, 0.7), 2.0, true)
	draw_circle(Vector2.ZERO, 3.0, col)
	if sealed:
		draw_line(Vector2(-14, -14), Vector2(14, 14), Palette.with_alpha(Palette.PURPLE, 0.8), 2.0)
		draw_line(Vector2(14, -14), Vector2(-14, 14), Palette.with_alpha(Palette.PURPLE, 0.8), 2.0)
	draw_focus_ring(34.0)
