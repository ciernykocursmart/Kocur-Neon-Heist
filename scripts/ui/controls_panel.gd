class_name ControlsPanel
extends PanelContainer
## Read-only control reference shown from the main and pause menus.

signal closed


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(UITheme.make_title("CONTROLS", 34, Palette.CYAN))
	for row in GameState.CONTROLS_HELP:
		var h := HBoxContainer.new()
		var a := UITheme.make_label(row[0], 18, Palette.DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(UITheme.make_label(row[1], 18, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
		box.add_child(h)
	var back := UITheme.make_button("BACK", func(): closed.emit(), 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	visibility_changed.connect(func():
		if visible:
			back.call_deferred("grab_focus"))
