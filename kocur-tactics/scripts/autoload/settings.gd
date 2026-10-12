extends Node
## Settings autoload: audio volumes, display mode, battle speed and the input
## map. Stored in user://settings.cfg, separate from campaign progress.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SPEEDS := [1.0, 1.6, 2.5]
const SPEED_NAMES := ["Normal", "Fast", "Very fast"]

var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.8
var fullscreen := false
var resolution_index := 0
var speed_index := 0
var path := PATH

## Keyboard shortcuts (mouse is the primary control).
const BINDINGS := {
	"confirm": [KEY_SPACE, KEY_KP_ENTER],
	"cancel": [KEY_BACKSPACE],
	"end_turn": [KEY_ENTER, KEY_E],
	"wait": [KEY_W],
	"undo": [KEY_Z],
	"next_unit": [KEY_TAB],
	"threat": [KEY_T],
	"interact": [KEY_F],
	"pause": [KEY_ESCAPE],
	"ability_1": [KEY_1],
	"ability_2": [KEY_2],
	"ability_3": [KEY_3],
	"ability_4": [KEY_4],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input()
	ensure_buses()
	load_settings()
	apply()


func setup_input() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	resolution_index = clampi(int(cfg.get_value("display", "resolution", resolution_index)), 0, RESOLUTIONS.size() - 1)
	speed_index = clampi(int(cfg.get_value("game", "speed", speed_index)), 0, SPEEDS.size() - 1)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution_index)
	cfg.set_value("game", "speed", speed_index)
	cfg.save(path)


func reset_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.6
	sfx_volume = 0.8
	fullscreen = false
	resolution_index = 0
	speed_index = 0


func apply() -> void:
	apply_audio()
	apply_display()
	changed.emit()


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func apply_display() -> void:
	if is_headless():
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = RESOLUTIONS[resolution_index]
		var screen := DisplayServer.screen_get_usable_rect()
		if screen.size.x > 0:
			size.x = mini(size.x, screen.size.x)
			size.y = mini(size.y, screen.size.y)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func set_volume(kind: String, v: float) -> void:
	match kind:
		"master": master_volume = clampf(v, 0.0, 1.0)
		"music": music_volume = clampf(v, 0.0, 1.0)
		"sfx": sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_display()
	save_settings()
	changed.emit()


func set_resolution(i: int) -> void:
	resolution_index = clampi(i, 0, RESOLUTIONS.size() - 1)
	apply_display()
	save_settings()
	changed.emit()


func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	save_settings()
	changed.emit()


func anim_speed() -> float:
	return SPEEDS[speed_index]


func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return ""
