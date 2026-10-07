class_name EndScreen
extends CanvasLayer
## Mission complete / game over screen with an animated reward breakdown.

var game: Game
var _root: Control
var _panel: PanelContainer
var _box: VBoxContainer


func setup(g: Game) -> void:
	game = g
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	_root.visible = false
	add_child(_root)


func _build(title: String, color: Color) -> void:
	for c in _root.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.78, 0.4)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_box)
	_box.add_child(UITheme.make_title(title, 46, color))
	_root.visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = Vector2(280, 200)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().paused = true
	UITheme.set_crosshair_cursor(false)


func _row(label: String, value: String, color := Palette.WHITE) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.make_label(label, 18, Palette.DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UITheme.make_label(value, 18, color, HORIZONTAL_ALIGNMENT_RIGHT))
	_box.add_child(row)


func _spacer(h := 10.0) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	_box.add_child(s)


static func format_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func show_victory(r: Dictionary) -> void:
	_build("MISSION COMPLETE", Palette.GREEN)
	_box.add_child(UITheme.make_label(String(r["mission"]), 18, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	_spacer()
	_row("Time", format_time(float(r["time"])))
	_row("Enemies neutralised", "%d  (%d silent)" % [int(r["kills"]), int(r["takedowns"])])
	_row("Alarms triggered", str(r["alarms"]), Palette.GREEN if int(r["alarms"]) == 0 else Palette.RED)
	_spacer(6)
	_row("Contract payment", "%d CR" % int(r["base"]), Palette.YELLOW)
	_row("Credits found", "%d CR" % int(r["found"]), Palette.YELLOW)
	_row("Silent takedown bonus", "%d CR" % int(r["takedown_bonus"]), Palette.YELLOW)
	_row("Ghost bonus (no alarms)", ("%d CR" % int(r["ghost_bonus"])) if bool(r["ghost"]) else "-", Palette.YELLOW if bool(r["ghost"]) else Palette.DIM)
	_spacer(6)
	var total_label := UITheme.make_title("+0 CR", 34, Palette.YELLOW)
	_box.add_child(total_label)
	var total := int(r["total"])
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_method(func(v: float): total_label.text = "+%d CR" % int(v), 0.0, float(total), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Sfx.play("credits"))
	_box.add_child(UITheme.make_label("Balance: %d CR" % GameState.credits, 16, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_spacer()
	var b1 := UITheme.make_button("UPGRADE AT HIDEOUT", func(): game.go_to_hideout())
	_box.add_child(b1)
	_box.add_child(UITheme.make_button("NEXT MISSION", func(): game.restart_mission()))
	_box.add_child(UITheme.make_button("MAIN MENU", func(): game.go_to_menu()))
	b1.call_deferred("grab_focus")


func show_defeat(r: Dictionary) -> void:
	_build("KOCUR DOWN", Palette.RED)
	_box.add_child(UITheme.make_label(String(r["mission"]), 18, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	_box.add_child(UITheme.make_label("The heist failed. Credits found on this run were lost.", 15, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_spacer()
	_row("Time survived", format_time(float(r["time"])))
	_row("Enemies neutralised", str(r["kills"]))
	_spacer()
	var b1 := UITheme.make_button("RETRY MISSION", func(): game.restart_mission())
	_box.add_child(b1)
	_box.add_child(UITheme.make_button("HIDEOUT / UPGRADES", func(): game.go_to_hideout()))
	_box.add_child(UITheme.make_button("MAIN MENU", func(): game.go_to_menu()))
	b1.call_deferred("grab_focus")
