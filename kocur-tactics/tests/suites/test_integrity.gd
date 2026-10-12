extends "res://tests/test_case.gd"
## Assets, scenes, project and export configuration.

const Grid = preload("res://scripts/core/grid.gd")
const AudioMgr = preload("res://scripts/autoload/audio_manager.gd")
const UnitView = preload("res://scripts/battle/unit_view.gd")
const BattleScene = preload("res://scripts/battle/battle_scene.gd")


func test_unit_sprites() -> void:
	var kinds := {}
	for k in UD.CLASSES:
		kinds[k] = true
	for k in UD.ENEMIES:
		kinds[k] = true
	for k in kinds:
		var path := "res://assets/sprites/unit_%s.png" % k
		check(ResourceLoader.exists(path), "sprite sheet for %s" % k)
		var t: Texture2D = load(path)
		if t:
			eq(Vector2i(t.get_size()), Vector2i(32, 16), "%s sheet is 2 frames of 16x16" % k)


func test_tiles_for_every_region() -> void:
	var regions := {}
	for id in Missions.mission_ids() + Missions.challenge_ids():
		regions[str(Missions.get_mission(id).get("region", "wood"))] = true
	for r in regions:
		for t in Grid.TERRAIN:
			check(ResourceLoader.exists("res://assets/sprites/tile_%s_%s.png" % [r, t]), "tile %s/%s" % [r, t])
		check(ResourceLoader.exists("res://assets/sprites/tile_%s_grass2.png" % r), "grass variant for %s" % r)
	for mk in ["defend", "exit", "incoming", "relic", "relic_taken", "treasure"]:
		check(ResourceLoader.exists("res://assets/sprites/mark_%s.png" % mk), "marker %s" % mk)


func test_icons() -> void:
	var used := {}
	for h in UD.HEROES:
		for a in UD.CLASSES[UD.HEROES[h]["class"]]["abilities"]:
			used[a] = true
	for a in used:
		check(ResourceLoader.exists("res://assets/sprites/icon_%s.png" % a), "action icon for %s" % a)
	for s in UnitView.STATUS_ICONS.values():
		check(ResourceLoader.exists("res://assets/sprites/%s.png" % s), "status icon %s" % s)
	for n in ["icon_wait", "icon_end", "icon_free", "icon_claim", "icon_escape", "icon_sleep", "icon_warn", "fx_arrow", "fx_bolt", "fx_spark"]:
		check(ResourceLoader.exists("res://assets/sprites/%s.png" % n), "%s exists" % n)


func test_audio_files() -> void:
	for s in AudioMgr.SFX_NAMES:
		check(ResourceLoader.exists("res://assets/audio/%s.wav" % s), "sfx %s" % s)
	for m in AudioMgr.MUSIC_NAMES:
		check(ResourceLoader.exists("res://assets/audio/music_%s.wav" % m), "music %s" % m)
	for id in Missions.mission_ids() + Missions.challenge_ids():
		check(AudioMgr.MUSIC_NAMES.has(str(Missions.get_mission(id).get("music", "act1"))), "%s music registered" % id)
	for v in BattleScene.ATTACK_SFX.values():
		check(AudioMgr.SFX_NAMES.has(v), "attack sound %s registered" % v)


func test_sound_names_in_code() -> void:
	# every literal Audio.play("...") / sfx event name in the scripts is a known sound
	var re := RegEx.new()
	re.compile("(?:Audio\\.play\\(|\"name\": )\"([a-z_0-9]+)\"")
	var files := _scripts("res://scripts")
	check(files.size() > 15, "scripts found (%d)" % files.size())
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		for m in re.search_all(text):
			var n := m.get_string(1)
			check(AudioMgr.SFX_NAMES.has(n), "%s: sound '%s' exists" % [f.get_file(), n])


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


func test_scenes_load() -> void:
	for s in ["main_menu", "campaign", "battle", "ending"]:
		var p := "res://scenes/%s.tscn" % s
		var ps: PackedScene = load(p)
		check(ps != null and ps.can_instantiate(), "%s loads" % p)


func test_project_settings() -> void:
	eq(ProjectSettings.get_setting("application/config/name"), "Kocur Tactics", "project name")
	eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main_menu.tscn", "main scene")
	eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1280, "base width 1280")
	eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 720, "base height 720")
	eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "scales to any resolution")
	check(str(ProjectSettings.get_setting("application/config/version")) != "", "version set")
	for a in ["Settings", "SaveManager", "Campaign", "Audio", "Transition"]:
		check(ProjectSettings.has_setting("autoload/" + a), "autoload %s" % a)


func test_export_preset() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg exists")
	eq(cfg.get_value("preset.0", "platform", ""), "Windows Desktop", "Windows preset")
	check(str(cfg.get_value("preset.0", "exclude_filter", "")).contains("tests/*"), "tests excluded from the build")
	eq(cfg.get_value("preset.0.options", "binary_format/architecture", ""), "x86_64", "x86_64")
	check(bool(cfg.get_value("preset.0.options", "binary_format/embed_pck", false)), "single-file exe (embedded pck)")


func test_no_network_or_external_paths() -> void:
	for f in _scripts("res://scripts"):
		var text := FileAccess.get_file_as_string(f)
		for bad in ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "WebSocket", "OS.shell_open"]:
			check(not text.contains(bad), "%s does not use %s (fully offline)" % [f.get_file(), bad])
