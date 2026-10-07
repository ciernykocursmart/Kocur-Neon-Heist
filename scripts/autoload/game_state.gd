extends Node
## Global, persistent game state (autoload "GameState").
##
## Owns campaign progress (credits, mission index, upgrades, stats), the
## player-facing settings, input-map setup and save/load to `user://`.

signal credits_changed(value: int)
signal settings_changed

const SAVE_PATH := "user://kocur_save.json"
const SETTINGS_PATH := "user://kocur_settings.cfg"
const SAVE_VERSION := 1

## Upgrade catalogue. `max` is the maximum level, cost = base_cost * (level + 1).
const UPGRADES := {
	"armor": {"name": "Armor Plating", "desc": "+25 max health per level.", "base_cost": 150, "max": 4},
	"servos": {"name": "Servo Legs", "desc": "+8% move speed and faster dash recharge.", "base_cost": 120, "max": 3},
	"magazine": {"name": "Extended Mag", "desc": "+4 rounds per magazine and 12% faster reload.", "base_cost": 110, "max": 3},
	"plasma": {"name": "Plasma Rounds", "desc": "+20% weapon damage.", "base_cost": 160, "max": 3},
	"silencer": {"name": "Whisper Suppressor", "desc": "Gunshots make 30% less noise.", "base_cost": 130, "max": 3},
	"camo": {"name": "Optic Camo", "desc": "Enemies and cameras detect you 12% slower.", "base_cost": 170, "max": 3},
	"hacking": {"name": "Neural Hack Suite", "desc": "Wider hack window and one extra allowed miss.", "base_cost": 140, "max": 3},
}
const UPGRADE_ORDER := ["armor", "servos", "magazine", "plasma", "silencer", "camo", "hacking"]

const DEFAULT_SETTINGS := {
	"master_volume": 0.8,
	"music_volume": 0.55,
	"sfx_volume": 0.85,
	"fullscreen": false,
	"screen_shake": true,
}

var credits := 0
var mission_index := 1
var campaign_seed := 0
var upgrades := {}
var stats := {}
var settings := DEFAULT_SETTINGS.duplicate()

## When true, nothing is written to disk (used by automated tests).
var persistence_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_audio_buses()
	reset_campaign()
	load_settings()
	apply_settings()


# --------------------------------------------------------------------------
# Campaign
# --------------------------------------------------------------------------

func reset_campaign() -> void:
	credits = 0
	mission_index = 1
	campaign_seed = randi() % 1000000
	upgrades = {}
	for id in UPGRADE_ORDER:
		upgrades[id] = 0
	stats = {
		"missions_completed": 0,
		"kills": 0,
		"deaths": 0,
		"credits_earned": 0,
		"ghost_runs": 0,
		"alarms": 0,
	}


func new_game() -> void:
	reset_campaign()
	save_game()


func add_credits(amount: int) -> void:
	credits = max(0, credits + amount)
	credits_changed.emit(credits)


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_cost(id: String) -> int:
	var data: Dictionary = UPGRADES[id]
	return int(data["base_cost"]) * (upgrade_level(id) + 1)


func can_buy_upgrade(id: String) -> bool:
	var data: Dictionary = UPGRADES[id]
	return upgrade_level(id) < int(data["max"]) and credits >= upgrade_cost(id)


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	add_credits(-upgrade_cost(id))
	upgrades[id] = upgrade_level(id) + 1
	save_game()
	return true


## Records a successful mission and persists progress.
func complete_mission(result: Dictionary) -> void:
	add_credits(int(result.get("total", 0)))
	stats["credits_earned"] = int(stats.get("credits_earned", 0)) + int(result.get("total", 0))
	stats["missions_completed"] = int(stats.get("missions_completed", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + int(result.get("kills", 0))
	stats["alarms"] = int(stats.get("alarms", 0)) + int(result.get("alarms", 0))
	if bool(result.get("ghost", false)):
		stats["ghost_runs"] = int(stats.get("ghost_runs", 0)) + 1
	mission_index += 1
	save_game()


func register_death(kills: int) -> void:
	stats["deaths"] = int(stats.get("deaths", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + kills
	save_game()


# --------------------------------------------------------------------------
# Player stat helpers (derived from upgrades)
# --------------------------------------------------------------------------

func player_max_hp() -> float:
	return 100.0 + 25.0 * upgrade_level("armor")


func player_speed() -> float:
	return 225.0 * (1.0 + 0.08 * upgrade_level("servos"))


func dash_cooldown() -> float:
	return 1.0 * (1.0 - 0.15 * upgrade_level("servos"))


func mag_size() -> int:
	return 12 + 4 * upgrade_level("magazine")


func reload_time() -> float:
	return 1.15 * (1.0 - 0.12 * upgrade_level("magazine"))


func weapon_damage() -> float:
	return 20.0 * (1.0 + 0.2 * upgrade_level("plasma"))


func gun_noise_radius() -> float:
	return 540.0 * pow(0.7, upgrade_level("silencer"))


func detection_multiplier() -> float:
	return 1.0 - 0.12 * upgrade_level("camo")


func hack_window_bonus() -> float:
	return 0.18 * upgrade_level("hacking")


func hack_extra_misses() -> int:
	return 1 if upgrade_level("hacking") >= 2 else 0


# --------------------------------------------------------------------------
# Missions
# --------------------------------------------------------------------------

func get_mission_def(index: int = -1) -> Dictionary:
	if index < 0:
		index = mission_index
	return MissionCatalog.build(index, campaign_seed)


# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"credits": credits,
		"mission_index": mission_index,
		"campaign_seed": campaign_seed,
		"upgrades": upgrades.duplicate(),
		"stats": stats.duplicate(),
	}


func from_save_dict(data: Dictionary) -> void:
	reset_campaign()
	credits = int(data.get("credits", 0))
	mission_index = max(1, int(data.get("mission_index", 1)))
	campaign_seed = int(data.get("campaign_seed", campaign_seed))
	var saved_upgrades: Dictionary = data.get("upgrades", {})
	for id in UPGRADE_ORDER:
		var max_level: int = int(UPGRADES[id]["max"])
		upgrades[id] = clampi(int(saved_upgrades.get(id, 0)), 0, max_level)
	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats.keys():
		stats[key] = int(saved_stats[key])
	credits_changed.emit(credits)


func save_game() -> bool:
	if not persistence_enabled:
		return true
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(to_save_dict(), "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is corrupted; ignoring it.")
		return false
	from_save_dict(parsed)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in DEFAULT_SETTINGS.keys():
		settings[key] = cfg.get_value("settings", key, DEFAULT_SETTINGS[key])


func save_settings() -> void:
	if not persistence_enabled:
		return
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


func apply_settings() -> void:
	_set_bus_volume("Master", float(settings["master_volume"]))
	_set_bus_volume("Music", float(settings["music_volume"]))
	_set_bus_volume("SFX", float(settings["sfx_volume"]))
	if DisplayServer.get_name() != "headless":
		var want_fs := bool(settings["fullscreen"])
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_fs and not is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not want_fs and is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _setup_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# --------------------------------------------------------------------------
# Input map (defined in code so the project needs no manual setup)
# --------------------------------------------------------------------------

func _setup_input() -> void:
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("reload", [KEY_R])
	_bind_keys("interact", [KEY_E])
	_bind_keys("dash", [KEY_SPACE])
	_bind_keys("sneak", [KEY_SHIFT])
	_bind_keys("melee", [KEY_F])
	_bind_keys("hack_abort", [KEY_Q])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("melee", MOUSE_BUTTON_RIGHT)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _bind_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
