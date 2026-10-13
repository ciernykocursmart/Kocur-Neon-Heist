extends CanvasLayer
## Transition autoload: fade-to-black scene changes. Unpauses the tree and
## refuses overlapping requests, so a double-pressed button cannot load twice.

signal finished

var busy := false
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.04, 0.02, 0.06, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func change_scene(path: String, fade := 0.3) -> void:
	if busy:
		return
	busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, fade)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, fade)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	finished.emit()


func go_menu() -> void:
	change_scene("res://scenes/main_menu.tscn")


func go_level() -> void:
	change_scene("res://scenes/level.tscn")


func go_ending() -> void:
	change_scene("res://scenes/ending.tscn")
