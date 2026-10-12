extends SceneTree
## Renders screens to PNG (needs a display, e.g. xvfb-run):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s res://tests/shot.gd -- OUT_DIR [what ...]
## what: menu, campaign, roster, upgrades, challenges, battle:<id>, battle_play:<id>, ending

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _snap(name: String) -> void:
	for i in 8:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	root.get_node("SaveManager").path = "user://shot_save.json"
	root.get_node("Settings").path = "user://shot_settings.cfg"
	var camp: Node = root.get_node("Campaign")
	camp.data = camp.defaults()
	camp.data["started"] = true
	# a mid-campaign save so menus have content
	for id in ["m01", "m02", "m03", "m04", "m05", "m06"]:
		camp.record_result(id, {"result": "victory", "turns": 6, "deployed": ["nox", "bramble", "willow", "moss"],
			"kills": {"nox": 2, "bramble": 1, "willow": 2}, "optional": [true, id != "m02"]})
	var what: Array = args.slice(1)
	for w: String in what:
		var parts := w.split(":")
		match parts[0]:
			"menu":
				change_scene_to_file("res://scenes/main_menu.tscn")
				await _wait(30)
				await _snap("menu")
			"campaign", "roster", "upgrades", "challenges", "records":
				root.get_node("Transition").campaign_tab = parts[0] if parts[0] != "campaign" else "missions"
				change_scene_to_file("res://scenes/campaign.tscn")
				await _wait(30)
				await _snap(parts[0])
			"battle", "battle_play":
				root.get_node("Transition").battle_request = {"mission_id": parts[1], "squad": camp.default_squad(parts[1])}
				change_scene_to_file("res://scenes/battle.tscn")
				await _wait(40)
				var sc: Node = current_scene
				if parts[0] == "battle":
					await _snap("battle_%s_brief" % parts[1])
				for c in sc.modal_layer.get_children():
					c.queue_free()
				await _wait(5)
				var turns := int(parts[2]) if parts.size() > 2 else 0
				sc.instant = true
				for t in turns:
					if sc.b.result != "":
						break
					await sc.auto_player_turn()
				sc.instant = false
				for c in sc.modal_layer.get_children():
					c.queue_free()
				var hero = null
				for u in sc.b.side_units("hero"):
					if u.can_act():
						hero = u
						break
				if hero:
					sc.select_unit(hero)
				await _wait(20)
				await _snap("battle_%s" % parts[1] + ("_t%d" % turns if turns > 0 else ""))
				if hero:
					sc.hud.threat_button.button_pressed = true
					await _wait(10)
					await _snap("battle_%s_threat" % parts[1])
					sc.hud.threat_button.button_pressed = false
			"ending":
				change_scene_to_file("res://scenes/ending.tscn")
				await _wait(30)
				await _snap("ending")
	for f in ["user://shot_save.json", "user://shot_settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit()


func _wait(n: int) -> void:
	for i in n:
		await process_frame
