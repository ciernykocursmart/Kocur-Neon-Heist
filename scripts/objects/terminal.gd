class_name Terminal
extends Hackable
## Data terminal running one of several programs with facility-wide effects.

enum Program { CAMERA_LOOP, DOOR_OVERRIDE, CREDIT_SKIM }

const PROGRAM_NAMES := ["CAMERA LOOP", "DOOR OVERRIDE", "CREDIT SKIM"]
const PROGRAM_DESC := ["Loops every camera feed for 45s", "Unlocks every security door (except the vault)", "Siphons corporate credits"]

var program := Program.CAMERA_LOOP


func _ready() -> void:
	super._ready()
	display_name = "TERMINAL"
	difficulty = 3
	interact_radius = 50.0


func prompt() -> String:
	return "[E] RUN %s" % PROGRAM_NAMES[program]


func describe() -> String:
	return PROGRAM_DESC[program]


func on_hacked() -> void:
	match program:
		Program.CAMERA_LOOP:
			game.loop_cameras(45.0)
		Program.DOOR_OVERRIDE:
			game.override_doors()
		Program.CREDIT_SKIM:
			var amount: int = 60 + 20 * int(game.def.get("index", 1))
			game.collect_credits(amount, global_position)
			game.notify("CREDIT SKIM +%d" % amount, Palette.YELLOW)
	FX.burst(game.fx_layer, global_position, Palette.CYAN, 16, 180.0, 0.5, 2.5)


func _draw() -> void:
	var col := Palette.CYAN if not hacked_done else Palette.DIM
	draw_rect(Rect2(-13, -10, 26, 20), Color(0.08, 0.1, 0.16))
	draw_rect(Rect2(-13, -10, 26, 20), col, false, 2.0)
	draw_rect(Rect2(-10, -7, 20, 11), Palette.with_alpha(col, 0.18))
	if not hacked_done:
		for i in 3:
			var w := 6.0 + fmod(_t * 13.0 + i * 5.0, 10.0)
			draw_line(Vector2(-8, -4 + i * 3.5), Vector2(-8 + w, -4 + i * 3.5), Palette.with_alpha(col, 0.8), 1.5)
	else:
		draw_line(Vector2(-6, -1), Vector2(-2, 3), Palette.GREEN, 2.0)
		draw_line(Vector2(-2, 3), Vector2(7, -5), Palette.GREEN, 2.0)
	draw_rect(Rect2(-9, 6, 18, 2), Palette.with_alpha(col, 0.5))
	draw_focus_ring(26.0)
