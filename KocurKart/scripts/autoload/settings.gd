extends Node
## Player settings (autoload "Settings"), stored in user://settings.cfg and
## applied immediately: audio bus volumes, window mode and size, VSync,
## frame-rate cap, camera options and custom key bindings.

signal changed(key: String)

const FILE := "user://settings.cfg"
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
const FPS_CAPS := [0, 30, 60, 120, 144]
const DEFAULTS := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
	"fullscreen": false,
	"resolution": "1600x900",
	"vsync": true,
	"max_fps": 0,
	"camera_sensitivity": 1.0,
	"camera_distance": 1.0,
	"show_minimap": true,
	"keys": {},
}

var values := {}
var file_override := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply_all()


func _file() -> String:
	return file_override if file_override != "" else FILE


func load_settings() -> void:
	values = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(_file()) != OK:
		return
	for k in DEFAULTS:
		if not cf.has_section_key("settings", k):
			continue
		var v = cf.get_value("settings", k)
		var d = DEFAULTS[k]
		if typeof(v) == typeof(d) or (d is float and v is int):
			values[k] = v
	values["master_volume"] = clampf(float(values["master_volume"]), 0.0, 1.0)
	values["music_volume"] = clampf(float(values["music_volume"]), 0.0, 1.0)
	values["sfx_volume"] = clampf(float(values["sfx_volume"]), 0.0, 1.0)
	values["camera_sensitivity"] = clampf(float(values["camera_sensitivity"]), 0.5, 1.5)
	values["camera_distance"] = clampf(float(values["camera_distance"]), 0.8, 1.3)
	if not (values["resolution"] in RESOLUTIONS):
		values["resolution"] = DEFAULTS["resolution"]
	if not (int(values["max_fps"]) in FPS_CAPS):
		values["max_fps"] = 0


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(_file())


func get_value(key: String, fallback = null):
	return values.get(key, DEFAULTS.get(key, fallback))


func set_value(key: String, value) -> void:
	values[key] = value
	apply(key)
	save_settings()
	changed.emit(key)


func apply_all() -> void:
	for k in values:
		apply(k)


func apply(key: String) -> void:
	match key:
		"master_volume":
			_set_bus("Master", float(values[key]))
		"music_volume":
			_set_bus("Music", float(values[key]))
		"sfx_volume":
			_set_bus("SFX", float(values[key]))
		"fullscreen", "resolution":
			_apply_window()
		"vsync":
			if _has_window():
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = int(values["max_fps"])
		"keys":
			Controls.apply_bindings(values["keys"])


func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


func _apply_window() -> void:
	if not _has_window():
		return
	if values["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var parts: PackedStringArray = String(values["resolution"]).split("x")
		var size := Vector2i(int(parts[0]), int(parts[1]))
		var screen := DisplayServer.screen_get_usable_rect()
		if screen.size.x > 0:
			size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
		DisplayServer.window_set_size(size)
		if screen.size.x > 0:
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## Linear volume actually applied to a bus (tests and settings UI).
func bus_linear(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return -1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
