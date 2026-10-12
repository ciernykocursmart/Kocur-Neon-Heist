extends "res://tests/test_case.gd"
## Project integrity: scripts/scenes load, assets exist, input map, catalog.

const LevelCatalog := preload("res://scripts/data/level_catalog.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Sprites := preload("res://scripts/fx/sprites.gd")


func _files(dir: String, ext: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), ext, out)


func test_all_scripts_and_scenes_load() -> void:
	var files: Array[String] = []
	_files("res://scripts", ".gd", files)
	_files("res://scenes", ".tscn", files)
	gt(files.size(), 60, "project has its scripts and scenes")
	for f in files:
		var r: Resource = load(f)
		check(r != null, "loads: " + f)
		if r is GDScript:
			check((r as GDScript).can_instantiate() or f.contains("/data/"), "script compiles: " + f)


func test_main_scene_and_display_settings() -> void:
	eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main_menu.tscn", "main scene")
	eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640, "base width")
	eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360, "base height")
	eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	for r: Vector2i in Settings.RESOLUTIONS:
		check(r.x * 9 == r.y * 16, "16:9 resolution %s" % r)
	check(Settings.RESOLUTIONS.has(Vector2i(1280, 720)) and Settings.RESOLUTIONS.has(Vector2i(1920, 1080)),
		"720p and 1080p offered")


func test_autoloads_present_once() -> void:
	for n in ["Settings", "SaveManager", "Progress", "Audio", "Transition"]:
		var count := 0
		for c in tree.root.get_children():
			if c.name == n:
				count += 1
		eq(count, 1, "exactly one %s autoload" % n)


func test_input_actions_mapped() -> void:
	var expect := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE],
		"attack": [KEY_J], "pounce": [KEY_K], "interact": [KEY_E], "pause": [KEY_ESCAPE],
	}
	for a: String in expect:
		check(InputMap.has_action(a), "action exists: " + a)
		var keys: Array[int] = []
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				keys.append((ev as InputEventKey).physical_keycode)
		for k: int in expect[a]:
			check(keys.has(k), "%s bound to %s" % [a, OS.get_keycode_string(k)])
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "pounce": MOUSE_BUTTON_RIGHT}
	for a: String in mouse:
		var found := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == mouse[a]:
				found = true
		check(found, "%s has its mouse button" % a)


func test_every_sound_referenced_in_code_exists() -> void:
	var files: Array[String] = []
	_files("res://scripts", ".gd", files)
	var re := RegEx.create_from_string("Audio\\.play\\(\"([a-z_0-9]+)\"")
	var rm := RegEx.create_from_string("play_music\\(\"([a-z_0-9]+)\"")
	var sounds := {}
	var music := {}
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			sounds[m.get_string(1)] = f
		for m in rm.search_all(src):
			music[m.get_string(1)] = f
	for lv: Dictionary in LevelCatalog.LEVELS:
		music[lv["music"]] = "catalog " + lv["id"]
	music["boss"] = "level boss"
	gt(sounds.size(), 30, "many distinct sound effects used")
	for s: String in sounds:
		check(ResourceLoader.exists("res://assets/audio/%s.wav" % s), "sound exists: %s (used in %s)" % [s, sounds[s]])
		check(Audio.streams.has(s), "sound is preloaded by the audio manager: " + s)
	for m: String in music:
		check(ResourceLoader.exists("res://assets/audio/music_%s.wav" % m), "music exists: %s" % m)


func test_sprite_sheets_exist() -> void:
	for name: String in Sprites.SHEETS:
		var sf: SpriteFrames = Sprites.frames(name)
		check(sf != null and sf.get_animation_names().size() > 0, "sheet has animations: " + name)
	for name: String in Sprites.STRIPS:
		check(Sprites.frames(name) != null, "strip loads: " + name)
	for r in range(1, 6):
		for f in ["tiles_r%d.png", "bg_r%d_far.png", "bg_r%d_mid.png"]:
			check(ResourceLoader.exists("res://assets/sprites/" + f % r), "exists " + f % r)
	check(ResourceLoader.exists("res://assets/fonts/kocur_font.png"), "pixel font exists")


func test_campaign_content_counts() -> void:
	eq(LevelCatalog.count(), 16, "15 main levels + final encounter")
	var per_region := {}
	var bosses := []
	for lv: Dictionary in LevelCatalog.LEVELS:
		per_region[lv["region"]] = int(per_region.get(lv["region"], 0)) + 1
		if lv.has("boss"):
			bosses.append(lv["boss"])
	for r in range(1, 6):
		check(int(per_region.get(r, 0)) >= 3, "region %d has 3+ levels" % r)
	eq(LevelCatalog.REGION_NAMES.size(), 5, "five regions")
	check(bosses.has("mouser") and bosses.has("ember") and bosses.has("king"), "required bosses present")
	gt(bosses.size(), 2, "at least three bosses")
	eq(LevelCatalog.LEVELS[-1].get("boss", ""), "king", "the Pale King is the last encounter")
	gt(GameData.UPGRADES.size(), 4, "at least five permanent upgrades")
	eq(GameData.CAT_ORDER.size(), 10, "ten cats to rescue")
	var cats_in_levels := []
	for lv: Dictionary in LevelCatalog.LEVELS:
		if lv["cat"] != "":
			cats_in_levels.append(lv["cat"])
	for c: String in GameData.CAT_ORDER:
		check(cats_in_levels.has(c), "cat %s is placed in a level" % c)
	for ch in ["s", "G", "A", "W", "B"]:
		var found := false
		for lv: Dictionary in LevelCatalog.LEVELS:
			if (lv["map"] as String).contains(ch):
				found = true
		check(found, "enemy archetype '%s' appears in the campaign" % ch)


func test_godot_licence_bundled() -> void:
	check(FileAccess.file_exists("res://LICENSE_GODOT.txt"), "Godot MIT licence text is shipped with the game")
