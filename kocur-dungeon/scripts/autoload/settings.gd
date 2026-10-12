extends Node
## Settings autoload: input map, audio bus volumes, display mode and difficulty.
## Stored in user://settings.cfg (ConfigFile), separate from campaign progress.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const DIFFICULTIES := ["easy", "normal", "hard"]
const DIFFICULTY_NAMES := {"easy": "Assist (half damage)", "normal": "Normal", "hard": "Hard (+50% damage)"}

var master_volume := 0.8
var music_volume := 0.7
var sfx_volume := 0.8
var fullscreen := false
var resolution_index := 0
var difficulty := "normal"
var screen_shake := true
var path := PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input()
	ensure_buses()
	load_settings()
	apply()


# --------------------------------------------------------------------------
# Input map (configurable Godot actions; never hard-coded keys in gameplay)
# --------------------------------------------------------------------------

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"attack": [KEY_J, KEY_X],
	"pounce": [KEY_K, KEY_C, KEY_SHIFT],
	"interact": [KEY_E],
	"pause": [KEY_ESCAPE, KEY_P],
}
const MOUSE_BINDINGS := {"attack": MOUSE_BUTTON_LEFT, "pounce": MOUSE_BUTTON_RIGHT}
const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "pounce": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_Y], "pause": [JOY_BUTTON_START],
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
}
const PAD_AXES := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}


func setup_input() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		InputMap.action_erase_events(action)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if MOUSE_BINDINGS.has(action):
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BINDINGS[action]
			InputMap.action_add_event(action, mb)
		for b: int in PAD_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[action][0]
			jm.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, jm)


func ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# --------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------

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
	var d := str(cfg.get_value("game", "difficulty", difficulty))
	difficulty = d if d in DIFFICULTIES else "normal"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution_index)
	cfg.set_value("display", "screen_shake", screen_shake)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.save(path)


func reset_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.7
	sfx_volume = 0.8
	fullscreen = false
	resolution_index = 0
	difficulty = "normal"
	screen_shake = true


# --------------------------------------------------------------------------
# Applying
# --------------------------------------------------------------------------

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
		var pos := screen.position + (screen.size - size) / 2
		DisplayServer.window_set_position(pos)


func set_volume(kind: String, v: float) -> void:
	match kind:
		"master": master_volume = clampf(v, 0.0, 1.0)
		"music": music_volume = clampf(v, 0.0, 1.0)
		"sfx": sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_difficulty(d: String) -> void:
	if d in DIFFICULTIES:
		difficulty = d
		save_settings()
		changed.emit()


## Multiplier applied to all damage the player receives (in half-heart units).
func incoming_damage(amount: int) -> int:
	match difficulty:
		"easy": return maxi(1, int(floor(amount * 0.5)))
		"hard": return int(ceil(amount * 1.5))
	return amount


func action_key_name(action: String) -> String:
	var names: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			names.append(OS.get_keycode_string((ev as InputEventKey).physical_keycode))
		elif ev is InputEventMouseButton:
			names.append("LMB" if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else "RMB")
	return " / ".join(names)
