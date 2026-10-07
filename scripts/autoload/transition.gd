extends CanvasLayer
## Scene transitions (autoload "Transition"): a short fade to black between
## scenes so screen changes never pop. Works while the tree is paused.

const FADE_TIME := 0.22

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.01, 0.0, 0.03, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func is_busy() -> bool:
	return _busy


func change_scene(path: String) -> void:
	_go(func(): get_tree().change_scene_to_file(path))


func reload_scene() -> void:
	_go(func(): get_tree().reload_current_scene())


func _go(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, FADE_TIME)
	await tw.finished
	Engine.time_scale = 1.0
	get_tree().paused = false
	action.call()
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, FADE_TIME)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
