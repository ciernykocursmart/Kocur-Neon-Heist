extends SceneTree
## Captures the Microsoft Store screenshots of the real game at 1920x1080 on a
## mid-campaign save. Needs a display; tools/store_shots.sh runs it under xvfb-run.
##   godot --path . -s res://tools/store_shots.gd -- <out_dir>
## Uses its own save/settings files and deletes them afterwards.

const SAVE := "user://store_save.json"
const CFG := "user://store_settings.cfg"

var out_dir := ""
var camp: Node


func _initialize() -> void:
	call_deferred("_run")


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	await _wait(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(name))
	print("saved ", name, " ", img.get_size())


func _setup_save() -> void:
	root.get_node("SaveManager").path = SAVE
	root.get_node("Settings").path = CFG
	camp = root.get_node("Campaign")
	camp.data = camp.defaults()
	camp.data["started"] = true
	var opt := {"m01": [true, true], "m02": [true, true], "m03": [true, false], "m04": [true, true],
		"m05": [false, true], "m06": [true, true], "m07": [true, false]}
	for id: String in opt:
		camp.record_result(id, {"result": "victory", "turns": 7, "deployed": ["nox", "bramble", "willow", "moss"],
			"kills": {"nox": 3, "bramble": 2, "willow": 3, "moss": 1}, "optional": opt[id]})
	for up: Array in [["nox", "vitality"], ["bramble", "armor"], ["willow", "power"], ["nox", "special"]]:
		camp.data["shards"] = int(camp.data["shards"]) + 6
		camp.buy(up[0], up[1])
	camp.data["shards"] = 11


func _run() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	_setup_save()
	var tr: Node = root.get_node("Transition")

	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(60)
	await _snap("01_main_menu.png")

	tr.campaign_tab = "missions"
	change_scene_to_file("res://scenes/campaign.tscn")
	await _wait(20)
	current_scene.selected_mission = "m08"
	current_scene.squad.clear()
	current_scene.show_tab("missions")
	await _wait(10)
	await _snap("02_campaign_missions.png")

	# battles: [file, mission, ai turns before the shot, mode]
	var shots := [
		["03_battle_mill_bridge.png", "m02", 1, "move:shadowblade"],
		["04_boss_ironpaw_telegraph.png", "m06", 6, "telegraph"],
		["05_moonwell_defense.png", "m07", 2, "aim:ranger"],
		["06_border_keep_threat.png", "m08", 1, "threat"],
		["07_burning_orchard.png", "m09", 3, "aim:guardian"],
		["08_final_boss_pale_king.png", "m12", 1, "telegraph"],
	]
	for s: Array in shots:
		await _battle_shot(s[0], s[1], s[2], s[3])

	tr.campaign_tab = "upgrades"
	change_scene_to_file("res://scenes/campaign.tscn")
	await _wait(20)
	await _snap("09_upgrades.png")
	tr.campaign_tab = "roster"
	change_scene_to_file("res://scenes/campaign.tscn")
	await _wait(20)
	await _snap("10_roster.png")

	for f in [SAVE, CFG]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit()


func _battle_shot(file: String, id: String, turns: int, mode: String) -> void:
	var tr: Node = root.get_node("Transition")
	var squad: Array = camp.default_squad(id)
	if squad.size() < 4:
		for h in ["nox", "bramble", "willow", "moss", "soot", "pepper"]:
			if camp.is_recruited(h) and not squad.has(h) and squad.size() < int(camp.battle_mission(id).get("slots", 3)):
				squad.append(h)
	tr.battle_request = {"mission_id": id, "squad": squad}
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(20)
	var sc: Node = current_scene
	for c in sc.modal_layer.get_children():
		c.queue_free()
	sc.instant = true
	var b: RefCounted = sc.b
	var played := 0
	while played < turns and b.result == "":
		await sc.auto_player_turn()
		played += 1
		if mode == "telegraph" and not b.telegraphs.is_empty():
			break
	if mode == "telegraph":
		var extra := 0
		while b.telegraphs.is_empty() and b.result == "" and extra < 8:
			await sc.auto_player_turn()
			extra += 1
	sc.instant = false
	for c in sc.modal_layer.get_children():
		c.queue_free()
	var parts := mode.split(":")
	var kind := parts[1] if parts.size() > 1 else ""
	var hero: RefCounted = null
	for u: RefCounted in b.side_units("hero"):
		if u.can_act() and (kind == "" or u.kind == kind):
			hero = u
			break
	if hero == null:
		for u: RefCounted in b.side_units("hero"):
			if u.can_act():
				hero = u
				break
	match parts[0]:
		"move", "telegraph":
			if hero:
				sc.select_unit(hero)
		"aim":
			if hero:
				sc.select_unit(hero)
				_aim(sc, hero)
		"threat":
			if hero:
				sc.select_unit(hero)
			sc.hud.threat_button.button_pressed = true
	root.warp_mouse(Vector2(5, 5))  # keep a stray hover path out of the shot
	await _wait(45)  # let banners fade
	await _snap(file)


## Arms the best attack the hero has right now and aims it (shows the preview).
func _aim(sc: Node, hero: RefCounted) -> void:
	var b: RefCounted = sc.b
	for id: String in hero.abilities:
		if b.ability_block_reason(hero, id) != "":
			continue
		var t: Array = b.ability_targets(hero, id)
		for c: Vector2i in t:
			var o: RefCounted = b.unit_at(c)
			if o != null and o.side == "enemy":
				sc.ability = id
				sc.click_cell(c)
				return
	# nothing in range: move toward the nearest enemy first, then aim
	var best := Vector2i(-1, -1)
	var best_n := -1
	for c: Vector2i in b.reachable_cells(hero):
		for id: String in hero.abilities:
			var n: int = b.ability_targets(hero, id, c, 1).size()
			if n > best_n and b.ability_block_reason(hero, id, 1) == "":
				best_n = n
				best = c
	if best.x >= 0 and best_n > 0:
		await sc.do_move(best)
		for id: String in hero.abilities:
			if b.ability_block_reason(hero, id) != "":
				continue
			for c: Vector2i in b.ability_targets(hero, id):
				var o: RefCounted = b.unit_at(c)
				if o != null and o.side == "enemy":
					sc.ability = id
					sc.click_cell(c)
					return
