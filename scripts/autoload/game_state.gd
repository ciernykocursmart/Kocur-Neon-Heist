extends Node
## Global, persistent game state (autoload "GameState").
##
## Owns campaign progress (mission index, credits, upgrades, weapons, intel,
## campaign completion, endless depth), derived player stats, settings,
## input-map setup and robust save/load to `user://` (atomic writes with a
## backup copy and version migration).

signal credits_changed(value: int)
signal settings_changed

const SAVE_PATH := "user://kocur_save.json"
const SAVE_BACKUP_PATH := "user://kocur_save.bak"
const SETTINGS_PATH := "user://kocur_settings.cfg"
const SAVE_VERSION := 2

## Upgrade catalogue. `max` is the maximum level, cost = base_cost * (level + 1).
const UPGRADES := {
	"armor": {"name": "Armor Plating", "desc": "+25 max health per level.", "base_cost": 120, "max": 4},
	"nanoweave": {"name": "Nano-Repair Weave", "desc": "Regenerate health after 4s without taking damage.", "base_cost": 180, "max": 2},
	"servos": {"name": "Servo Legs", "desc": "+8% movement speed per level.", "base_cost": 100, "max": 3},
	"dash": {"name": "Phase Dash", "desc": "-20% dash cooldown. Level 3: silent dash.", "base_cost": 100, "max": 3},
	"ghost": {"name": "Ghost Step", "desc": "Faster sneaking and harder to see while sneaking.", "base_cost": 110, "max": 3},
	"camo": {"name": "Optic Camo", "desc": "Enemies and cameras detect you 12% slower.", "base_cost": 150, "max": 3},
	"plasma": {"name": "Plasma Rounds", "desc": "+15% damage for every weapon.", "base_cost": 150, "max": 3},
	"magazine": {"name": "Extended Mags", "desc": "+25% magazine size for every weapon.", "base_cost": 100, "max": 3},
	"reflex": {"name": "Reflex Booster", "desc": "Reload 12% faster per level.", "base_cost": 90, "max": 3},
	"silencer": {"name": "Whisper Suppressor", "desc": "Gunshots make 30% less noise.", "base_cost": 110, "max": 3},
	"claws": {"name": "Monofilament Claws", "desc": "+40% claw damage and longer reach.", "base_cost": 130, "max": 2},
	"hacking": {"name": "Neural Hack Suite", "desc": "Wider hack window; level 2 adds a spare miss.", "base_cost": 110, "max": 3},
}
const UPGRADE_ORDER := ["armor", "nanoweave", "servos", "dash", "ghost", "camo", "plasma", "magazine", "reflex", "silencer", "claws", "hacking"]

## Campaign mission at which each weapon becomes available.
const WEAPON_UNLOCK := {"pistol": 1, "smg": 3, "shotgun": 5}

const DEFAULT_SETTINGS := {
	"master_volume": 0.8,
	"music_volume": 0.55,
	"sfx_volume": 0.85,
	"fullscreen": false,
	"screen_shake": true,
	"tutorial_tips": true,
}

var credits := 0
var mission_index := 1
var campaign_seed := 0
var campaign_complete := false
var mode := "campaign"
var endless_depth := 1
var endless_best := 0
var upgrades := {}
var intel: Array = []
var stats := {}
var settings := DEFAULT_SETTINGS.duplicate()
var last_load_error := ""

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
	campaign_complete = false
	mode = "campaign"
	endless_depth = 1
	endless_best = 0
	intel = []
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
		"takedowns": 0,
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


func is_endless() -> bool:
	return mode == "endless"


func campaign_progress_index() -> int:
	return Campaign.MISSION_COUNT + 1 if campaign_complete else mission_index


func weapon_unlocked(id: String) -> bool:
	return campaign_progress_index() >= int(WEAPON_UNLOCK.get(id, 99))


func owned_weapons() -> Array:
	var out := []
	for id in Weapons.ORDER:
		if weapon_unlocked(id):
			out.append(id)
	return out


func has_intel(id: int) -> bool:
	return id in intel


func collect_intel(id: int) -> void:
	if id < 0 or has_intel(id):
		return
	intel.append(id)
	intel.sort()
	save_game()


## Records a successful mission and persists progress.
func complete_mission(result: Dictionary) -> void:
	var total := int(result.get("total", 0))
	add_credits(total)
	stats["credits_earned"] = int(stats.get("credits_earned", 0)) + total
	stats["missions_completed"] = int(stats.get("missions_completed", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + int(result.get("kills", 0))
	stats["takedowns"] = int(stats.get("takedowns", 0)) + int(result.get("takedowns", 0))
	stats["alarms"] = int(stats.get("alarms", 0)) + int(result.get("alarms", 0))
	if bool(result.get("ghost", false)):
		stats["ghost_runs"] = int(stats.get("ghost_runs", 0)) + 1
	if is_endless():
		endless_best = maxi(endless_best, endless_depth)
		endless_depth += 1
	else:
		if mission_index >= Campaign.MISSION_COUNT:
			campaign_complete = true
			mission_index = Campaign.MISSION_COUNT
		else:
			mission_index += 1
	save_game()


func register_death(kills: int) -> void:
	stats["deaths"] = int(stats.get("deaths", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + kills
	save_game()


func start_endless() -> void:
	mode = "endless"
	save_game()


func start_campaign_mode() -> void:
	mode = "campaign"
	save_game()


# --------------------------------------------------------------------------
# Player stat helpers (derived from upgrades)
# --------------------------------------------------------------------------

func player_max_hp() -> float:
	return 100.0 + 25.0 * upgrade_level("armor")


func regen_rate() -> float:
	return 3.0 * upgrade_level("nanoweave")


func player_speed() -> float:
	return 225.0 * (1.0 + 0.08 * upgrade_level("servos"))


func sneak_speed_multiplier() -> float:
	return 0.5 + 0.08 * upgrade_level("ghost")


func sneak_visibility_multiplier() -> float:
	return 0.55 - 0.07 * upgrade_level("ghost")


func dash_cooldown() -> float:
	return 1.0 * (1.0 - 0.2 * upgrade_level("dash"))


func silent_dash() -> bool:
	return upgrade_level("dash") >= 3


func weapon_mag(id: String) -> int:
	var base := int(Weapons.get_data(id)["mag"])
	return int(round(base * (1.0 + 0.25 * upgrade_level("magazine"))))


func reload_multiplier() -> float:
	return 1.0 - 0.12 * upgrade_level("reflex")


func damage_multiplier() -> float:
	return 1.0 + 0.15 * upgrade_level("plasma")


func noise_multiplier() -> float:
	return pow(0.7, upgrade_level("silencer"))


func gun_noise_radius() -> float:
	return 540.0 * noise_multiplier()


func melee_damage() -> float:
	return 35.0 * (1.0 + 0.4 * upgrade_level("claws"))


func melee_range() -> float:
	return 50.0 + 8.0 * upgrade_level("claws")


func detection_multiplier() -> float:
	return 1.0 - 0.12 * upgrade_level("camo")


func hack_window_bonus() -> float:
	return 0.18 * upgrade_level("hacking")


func hack_extra_misses() -> int:
	return 1 if upgrade_level("hacking") >= 2 else 0


# --------------------------------------------------------------------------
# Missions
# --------------------------------------------------------------------------

func get_mission_def() -> Dictionary:
	if is_endless():
		return MissionCatalog.build_endless(endless_depth, campaign_seed)
	return MissionCatalog.build(mission_index, campaign_seed)


# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BACKUP_PATH)


func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"credits": credits,
		"mission_index": mission_index,
		"campaign_seed": campaign_seed,
		"campaign_complete": campaign_complete,
		"mode": mode,
		"endless_depth": endless_depth,
		"endless_best": endless_best,
		"upgrades": upgrades.duplicate(),
		"intel": intel.duplicate(),
		"stats": stats.duplicate(),
	}


## Applies saved data, clamping every field so corrupt or hand-edited saves
## can never put the game in an invalid state. Older versions are migrated.
func from_save_dict(data: Dictionary) -> void:
	reset_campaign()
	var version := int(data.get("version", 1))
	credits = maxi(0, int(data.get("credits", 0)))
	mission_index = clampi(int(data.get("mission_index", 1)), 1, Campaign.MISSION_COUNT)
	campaign_seed = int(data.get("campaign_seed", campaign_seed))
	campaign_complete = bool(data.get("campaign_complete", false))
	if version < 2 and int(data.get("mission_index", 1)) > Campaign.MISSION_COUNT:
		campaign_complete = true
	mode = "endless" if String(data.get("mode", "campaign")) == "endless" and campaign_complete else "campaign"
	endless_depth = maxi(1, int(data.get("endless_depth", 1)))
	endless_best = maxi(0, int(data.get("endless_best", 0)))
	var saved_upgrades = data.get("upgrades", {})
	if typeof(saved_upgrades) == TYPE_DICTIONARY:
		for id in UPGRADE_ORDER:
			var max_level: int = int(UPGRADES[id]["max"])
			upgrades[id] = clampi(int(saved_upgrades.get(id, 0)), 0, max_level)
	var saved_intel = data.get("intel", [])
	if typeof(saved_intel) == TYPE_ARRAY:
		for v in saved_intel:
			var id := int(v)
			if id >= 0 and id < Campaign.INTEL.size() and not (id in intel):
				intel.append(id)
		intel.sort()
	var saved_stats = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key in saved_stats.keys():
			stats[key] = maxi(0, int(saved_stats[key]))
	credits_changed.emit(credits)


## Atomic save: write to a temp file, keep the previous save as backup, then
## swap the new file in. A crash mid-write can never destroy progress.
func save_game() -> bool:
	if not persistence_enabled:
		return true
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(to_save_dict(), "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if dir.file_exists(SAVE_BACKUP_PATH.get_file()):
			dir.remove(SAVE_BACKUP_PATH.get_file())
		dir.rename(SAVE_PATH.get_file(), SAVE_BACKUP_PATH.get_file())
	return dir.rename(tmp_path.get_file(), SAVE_PATH.get_file()) == OK


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


## Loads the main save, falling back to the backup if it is missing/corrupt.
func load_game() -> bool:
	last_load_error = ""
	var data = _read_save(SAVE_PATH)
	if data == null:
		data = _read_save(SAVE_BACKUP_PATH)
		if data == null:
			last_load_error = "No readable save data found."
			return false
		last_load_error = "Main save was damaged - restored from backup."
		push_warning(last_load_error)
	from_save_dict(data)
	return true


func delete_save() -> void:
	for p in [SAVE_PATH, SAVE_BACKUP_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in DEFAULT_SETTINGS.keys():
		var v = cfg.get_value("settings", key, DEFAULT_SETTINGS[key])
		if typeof(v) == typeof(DEFAULT_SETTINGS[key]):
			settings[key] = v


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
		var wmode := DisplayServer.window_get_mode()
		var is_fs := wmode == DisplayServer.WINDOW_MODE_FULLSCREEN or wmode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
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

const CONTROLS_HELP := [
	["Move", "W A S D / Arrows"],
	["Aim / Fire", "Mouse / Left button"],
	["Reload", "R"],
	["Claw / takedown", "Right button / F"],
	["Dash", "Space"],
	["Sneak", "Hold Shift"],
	["Hack / interact", "E"],
	["Yarn decoy", "G"],
	["Weapons", "1 2 3 / Wheel / Q"],
	["Pause", "Esc / P"],
]


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
	_bind_keys("decoy", [KEY_G])
	_bind_keys("weapon_1", [KEY_1])
	_bind_keys("weapon_2", [KEY_2])
	_bind_keys("weapon_3", [KEY_3])
	_bind_keys("weapon_swap", [KEY_Q])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("melee", MOUSE_BUTTON_RIGHT)
	_bind_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	# E also confirms dialogs/story panels.
	_bind_keys("ui_accept", [KEY_E])


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
