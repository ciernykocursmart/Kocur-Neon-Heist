extends Node
## Settings autoload: audio volumes, display mode and the input map.
## Stored in user://settings.cfg, separate from campaign progress.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.8
var fullscreen := false
var resolution_index := 0
var screen_shake := true
var path := PATH

## Godot input actions. Keyboard first; every action also has a gamepad binding.
const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"attack": [KEY_J],
	"special": [KEY_K],
	"grab": [KEY_E],
	"run": [KEY_SHIFT],
	"pause": [KEY_ESCAPE, KEY_P],
}
const PAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X],
	"special": [JOY_BUTTON_Y],
	"grab": [JOY_BUTTON_B],
	"run": [JOY_BUTTON_RIGHT_SHOULDER],
	"pause": [JOY_BUTTON_START],
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input()
	ensure_buses()
	load_settings()
	apply()


func setup_input() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		InputMap.action_erase_events(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for b: int in PAD_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[action][0]
			jm.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, jm)
	# Menus: J also confirms, so keyboard-only players never need the mouse.
	for pair in [["ui_accept", KEY_J], ["ui_cancel", KEY_K]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)


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
	screen_shake = bool(cfg.get_value("display", "screen_shake", screen_shake))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution_index)
	cfg.set_value("display", "screen_shake", screen_shake)
	cfg.save(path)


func reset_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.6
	sfx_volume = 0.8
	fullscreen = false
	resolution_index = 0
	screen_shake = true


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


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save_settings()
	changed.emit()


func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return ""
