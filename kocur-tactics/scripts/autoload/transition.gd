extends CanvasLayer
## Transition autoload: fade-to-black scene changes, plus the small amount of
## state handed from one scene to the next (which battle to start).

signal finished

var battle_request := {}  ## {mission_id, squad: [hero ids]}
var campaign_tab := ""
var last_result := {}  ## rewards of the last battle, shown by the campaign screen
var busy := false
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.04, 0.03, 0.07, 0.0)
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
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, fade)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	finished.emit()


func go_battle(mission_id: String, squad: Array) -> void:
	battle_request = {"mission_id": mission_id, "squad": squad.duplicate()}
	change_scene("res://scenes/battle.tscn")


func go_campaign(tab := "") -> void:
	campaign_tab = tab
	change_scene("res://scenes/campaign.tscn")


func go_menu() -> void:
	change_scene("res://scenes/main_menu.tscn")


func go_ending() -> void:
	change_scene("res://scenes/ending.tscn")
