class_name AlarmPanel
extends Hackable
## Hacking the panel cancels the alarm, calls off reinforcements and powers
## down every security-zone motion sensor in the facility.


func _ready() -> void:
	super._ready()
	display_name = "ALARM PANEL"
	difficulty = 3
	interact_radius = 50.0


func describe() -> String:
	return "Cancels alarms, disables motion sensors"


func on_hacked() -> void:
	game.alarm.reset_alarm()
	game.facility.zones_active = false
	game.notify("ALARM GRID OFFLINE - sensors disabled", Palette.GREEN)
	FX.burst(game.fx_layer, global_position, Palette.GREEN, 18, 200.0, 0.5, 2.5)


func _draw() -> void:
	var alarm_on := game != null and game.alarm.level == AlarmSystem.Level.ALARM
	var col := Palette.GREEN if hacked_done else (Palette.RED if alarm_on else Palette.YELLOW)
	draw_rect(Rect2(-11, -13, 22, 26), Color(0.1, 0.08, 0.12))
	draw_rect(Rect2(-11, -13, 22, 26), col, false, 2.0)
	var pulse := 0.5 + 0.5 * sin(_t * (10.0 if alarm_on else 3.0))
	draw_circle(Vector2(0, -4), 5.0, Palette.with_alpha(col, 0.3 + 0.6 * pulse))
	draw_rect(Rect2(-6, 5, 12, 3), Palette.with_alpha(col, 0.7))
	draw_focus_ring(24.0)
