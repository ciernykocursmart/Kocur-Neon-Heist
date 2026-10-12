extends CanvasLayer
## Transition autoload: fade-to-black scene changes. Also carries the small
## amount of state handed from one scene to the next (which level to load).

signal finished

var next_level_id := ""
var camp_tab := ""  ## Tab the camp opens on ("" = adventure)
var busy := false
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.03, 0.02, 0.05, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func change_scene(path: String, fade := 0.35) -> void:
	if busy:
		return
	busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, fade)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, fade)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	finished.emit()


func go_level(level_id: String) -> void:
	next_level_id = level_id
	change_scene("res://scenes/level.tscn")


func go_camp() -> void:
	Progress.clear_run()
	change_scene("res://scenes/camp.tscn")


func go_menu() -> void:
	Progress.clear_run()
	change_scene("res://scenes/main_menu.tscn")


func flash(color := Color(1, 1, 1, 0.6), time := 0.25) -> void:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, time)
	tw.tween_callback(r.queue_free)
