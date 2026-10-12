extends "res://tests/test_case.gd"
## Scene-level tests: menus, campaign screen and battle interaction through
## the same entry points the mouse/keyboard handlers use.

var camp: Node
var tr: Node


func before_each() -> void:
	camp = tree.root.get_node("Campaign")
	tr = tree.root.get_node("Transition")


func after_each() -> void:
	await clear_scene()


func find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.begins_with(text) and n.is_visible_in_tree():
		return n
	for c in n.get_children():
		var r := find_button(c, text)
		if r:
			return r
	return null


func find_named(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := find_named(c, nm)
		if r:
			return r
	return null


func wait_transition() -> void:
	for i in 120:
		await frames(1)
		if not tr.busy:
			break
	await frames(3)


func test_main_menu_fresh() -> void:
	camp.data = camp.defaults()
	var menu: Node = await spawn_scene("res://scenes/main_menu.tscn")
	for k in ["continue", "new", "missions", "roster", "upgrades", "challenges", "settings", "credits", "reset", "quit"]:
		check(menu.buttons.has(k), "menu has %s" % k)
	check(menu.buttons["continue"].disabled, "Continue disabled without a save")
	check(menu.buttons["reset"].disabled, "Reset disabled without progress")
	check(not menu.buttons["new"].disabled, "New Campaign enabled")
	menu.buttons["new"].pressed.emit()
	await frames(2)
	check(find_named(menu.modal_layer, "Difficulty") != null, "fresh New Campaign goes straight to difficulty choice")
	var hard := find_named(menu.modal_layer, "Diff_hard") as Button
	check(hard != null, "Hard option exists")
	hard.pressed.emit()
	await wait_transition()
	eq(camp.difficulty(), "hard", "difficulty chosen")
	check(camp.has_progress(), "campaign started")
	check(tree.current_scene.scene_file_path.ends_with("campaign.tscn"), "went to the campaign screen")


func test_main_menu_with_save_confirms() -> void:
	camp.new_campaign("normal")
	camp.record_result("m01", {"result": "victory", "turns": 5, "deployed": ["nox"], "kills": {}, "optional": [true, true]})
	var menu: Node = await spawn_scene("res://scenes/main_menu.tscn")
	check(not menu.buttons["continue"].disabled, "Continue enabled with a save")
	menu.buttons["new"].pressed.emit()
	await frames(2)
	var cancel := find_button(menu.modal_layer, "Cancel")
	check(cancel != null, "New Campaign asks for confirmation when a save exists")
	cancel.pressed.emit()
	await frames(2)
	check(camp.is_completed("m01"), "cancel keeps progress")
	menu.buttons["reset"].pressed.emit()
	await frames(2)
	var yes := find_button(menu.modal_layer, "Reset")
	check(yes != null, "Reset asks for confirmation")
	yes.pressed.emit()
	await frames(4)
	check(not camp.is_completed("m01"), "confirmed reset clears progress")


func test_settings_and_credits_open() -> void:
	var menu: Node = await spawn_scene("res://scenes/main_menu.tscn")
	menu.buttons["settings"].pressed.emit()
	await frames(2)
	check(menu.modal_layer.get_child_count() > 0, "settings window opens")
	var sliders: Array = menu.modal_layer.find_children("*", "HSlider", true, false)
	check(sliders.size() >= 3, "volume sliders present (%d)" % sliders.size())
	for c in menu.modal_layer.get_children():
		c.queue_free()
	await frames(2)
	menu.buttons["credits"].pressed.emit()
	await frames(2)
	check(menu.modal_layer.get_child_count() > 0, "credits open")


func test_campaign_tabs() -> void:
	camp.new_campaign("normal")
	var cs: Node = await spawn_scene("res://scenes/campaign.tscn")
	for t in ["missions", "roster", "upgrades", "challenges", "records"]:
		cs.show_tab(t)
		await frames(2)
		check(cs.content.get_child_count() > 0, "%s tab has content" % t)
	cs.show_tab("missions")
	await frames(2)
	var start := find_named(cs.content, "StartMission") as Button
	check(start != null and not start.disabled, "Start Mission available")
	eq(cs.squad.size(), 3, "default squad of 3")
	var nox_btn := find_named(cs.content, "Squad_nox") as Button
	nox_btn.pressed.emit()
	await frames(2)
	eq(cs.squad.size(), 2, "clicking a squad member removes them")
	(find_named(cs.content, "Squad_nox") as Button).pressed.emit()
	await frames(2)
	eq(cs.squad.size(), 3, "and adds them back")


func test_upgrade_purchase_ui() -> void:
	camp.new_campaign("normal")
	camp.data["shards"] = 5
	var cs: Node = await spawn_scene("res://scenes/campaign.tscn")
	cs.show_tab("upgrades")
	await frames(2)
	var b := find_button(cs.content, "Buy")
	check(b != null, "a Buy button is shown")
	if b:
		b.pressed.emit()
		await frames(2)
		check(int(camp.data["shards"]) < 5, "buying spends shards")


func _start_battle(id: String, squad: Array) -> Node:
	tr.battle_request = {"mission_id": id, "squad": squad}
	var bs: Node = await spawn_scene("res://scenes/battle.tscn")
	return bs


func test_battle_briefing_and_clicks() -> void:
	camp.new_campaign("normal")
	var bs: Node = await _start_battle("m01", ["nox", "bramble", "willow"])
	check(find_named(bs.modal_layer, "Briefing") != null, "briefing shown first")
	check(bs._modal_open(), "input blocked while the briefing is open")
	(find_named(bs.modal_layer, "Begin") as Button).pressed.emit()
	await frames(2)
	check(not bs._modal_open(), "briefing closed")
	bs.instant = true
	var b = bs.b
	var nox = null
	for u in b.side_units("hero"):
		if u.kind == "shadowblade":
			nox = u
	# click on the hero selects it
	bs.click_cell(nox.pos)
	check(bs.selected == nox, "clicking a hero selects it")
	var cells: Array = b.reachable_cells(nox)
	check(cells.size() > 0, "blue tiles available")
	var dest: Vector2i = cells[0]
	bs.click_cell(dest)
	await frames(3)
	eq(nox.pos, dest, "clicking a blue tile moves the hero")
	bs.cancel()
	await frames(2)
	check(not nox.moved, "right click after a move undoes it")
	# place nox next to a recruit and attack with two clicks
	var r = null
	for u in b.side_units("enemy"):
		r = u
		break
	var adj := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if b.grid.walkable(r.pos + d) and b.unit_at(r.pos + d) == null:
			adj = r.pos + d
			break
	nox.pos = adj
	nox.start_pos = adj
	bs.select_unit(nox)
	eq(bs.ability, "claw", "attack ability preselected when a target is in reach")
	var hp0: int = r.hp
	bs.click_cell(r.pos)
	await frames(2)
	eq(bs.pending, r.pos, "first click marks the target and shows a preview")
	eq(r.hp, hp0, "no damage on the first click")
	check(bs.hud.preview_label.text != "", "damage preview shown")
	bs.click_cell(r.pos)
	await frames(4)
	check(r.hp < hp0 or not r.alive, "second click confirms the attack")
	check(nox.acted, "hero has acted")


func test_end_turn_confirmation_and_enemy_phase() -> void:
	camp.new_campaign("normal")
	var bs: Node = await _start_battle("m01", ["nox", "bramble", "willow"])
	for c in bs.modal_layer.get_children():
		c.queue_free()
	await frames(2)
	bs._on_end_turn_pressed()
	await frames(2)
	var yes := find_button(bs.modal_layer, "End Turn")
	check(yes != null, "ending the turn with idle heroes asks for confirmation")
	bs.instant = true
	yes.pressed.emit()
	for i in 30:
		await frames(1)
		if not bs.busy:
			break
	eq(bs.b.turn, 2, "enemy phase played, turn 2")
	check(bs.b.is_player_turn(), "back to the player")


func test_pause_menu_and_restart() -> void:
	camp.new_campaign("normal")
	var bs: Node = await _start_battle("m02", ["nox", "bramble", "willow"])
	for c in bs.modal_layer.get_children():
		c.queue_free()
	await frames(2)
	bs.instant = true
	await bs.auto_player_turn()
	eq(bs.b.turn, 2, "a turn was played")
	bs.open_pause()
	await frames(2)
	check(find_named(bs.modal_layer, "Pause") != null, "pause menu opens")
	for t in ["Resume", "Restart Mission", "Settings", "Controls & Rules", "Return to Campaign", "Quit to Main Menu"]:
		check(find_button(bs.modal_layer, t) != null, "pause has %s" % t)
	find_button(bs.modal_layer, "Restart Mission").pressed.emit()
	await frames(2)
	var yes := find_button(bs.modal_layer, "Yes")
	check(yes != null, "restart asks for confirmation")
	yes.pressed.emit()
	await frames(3)
	eq(bs.b.turn, 1, "mission restarted at turn 1")


func test_full_battle_result_and_rewards() -> void:
	camp.new_campaign("normal")
	var bs: Node = await _start_battle("m01", ["nox", "bramble", "willow"])
	for c in bs.modal_layer.get_children():
		c.queue_free()
	await frames(2)
	bs.instant = true
	var guard := 0
	while bs.b.result == "" and guard < 30:
		guard += 1
		await bs.auto_player_turn()
	eq(bs.b.result, "victory", "m01 won through the battle scene")
	for i in 10:
		await frames(1)
	check(bs.result_recorded, "result recorded once")
	check(find_named(bs.modal_layer, "Result") != null, "result screen shown")
	check(camp.is_completed("m01"), "campaign updated")
	check(camp.is_unlocked("m02"), "next mission unlocked")
	var shards: int = int(camp.data["shards"])
	check(shards >= 3, "shards awarded")
	bs._on_battle_end()
	eq(int(camp.data["shards"]), shards, "a second result call on a replay gives no duplicate first-clear shards")
	(find_named(bs.modal_layer, "Continue") as Button).pressed.emit()
	await wait_transition()
	check(tree.current_scene.scene_file_path.ends_with("campaign.tscn"), "Continue returns to the campaign")


func test_keyboard_shortcuts() -> void:
	camp.new_campaign("normal")
	var bs: Node = await _start_battle("m01", ["nox", "bramble", "willow"])
	for c in bs.modal_layer.get_children():
		c.queue_free()
	await frames(2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	key.pressed = true
	bs._unhandled_input(key)
	await frames(1)
	check(bs.selected != null, "Tab selects the next hero")
	var t := InputEventKey.new()
	t.physical_keycode = KEY_T
	t.pressed = true
	bs._unhandled_input(t)
	await frames(1)
	check(bs.show_threat, "T toggles the threat display")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	bs._unhandled_input(esc)
	await frames(1)
	check(bs.selected == null, "Esc first deselects")
	bs._unhandled_input(esc)
	await frames(2)
	check(find_named(bs.modal_layer, "Pause") != null, "Esc again opens the pause menu")


func test_ending_scene() -> void:
	var s: Node = await spawn_scene("res://scenes/ending.tscn")
	check(s != null and s.get_child_count() > 0, "ending scene builds")
