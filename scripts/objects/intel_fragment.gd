class_name IntelFragment
extends Hackable
## Hidden story fragment. Reading it is instant and stores it in the
## Hideout's intel archive permanently.

var intel_id := 0


func _ready() -> void:
	super._ready()
	display_name = "INTEL FRAGMENT"
	action_name = "READ"
	instant = true
	interact_radius = 46.0


func describe() -> String:
	return "Story intel - added to your archive"


func on_hacked() -> void:
	game.read_intel(intel_id)
	FX.burst(game.fx_layer, global_position, Palette.GREEN, 14, 140.0, 0.5, 2.5)


func _draw() -> void:
	if hacked_done:
		return
	var bob := sin(_t * 2.5) * 2.5
	draw_circle(Vector2(0, bob), 14.0, Palette.with_alpha(Palette.GREEN, 0.07 + 0.05 * sin(_t * 4.0)))
	draw_set_transform(Vector2(0, bob), _t * 0.8, Vector2.ONE)
	draw_rect(Rect2(-7, -7, 14, 14), Color(0.05, 0.12, 0.08))
	draw_rect(Rect2(-7, -7, 14, 14), Palette.GREEN, false, 1.5)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	draw_line(Vector2(-4, -2), Vector2(4, -2), Palette.GREEN, 1.5)
	draw_line(Vector2(-4, 2), Vector2(2, 2), Palette.GREEN, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_focus_ring(22.0)
