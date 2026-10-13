extends Control
## Battle scene controller: turns mouse/keyboard input into validated battle
## commands and plays back the model's events as animations. Input is locked
## while anything animates, during the enemy phase and once the battle ends.

const Battle = preload("res://scripts/core/battle.gd")
const AI = preload("res://scripts/core/ai.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
const UD = preload("res://scripts/data/units_data.gd")
const Missions = preload("res://scripts/data/missions.gd")
const HUD = preload("res://scripts/battle/battle_hud.gd")
const MapView = preload("res://scripts/battle/map_view.gd")
const UnitView = preload("res://scripts/battle/unit_view.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

const TILE := 48
const MAP_AREA := Rect2(8, 52, 864, 576)
const ATTACK_SFX := {"claw": "claw", "pounce": "claw", "strike": "strike", "heavy": "heavy", "shot": "shot",
	"swipe": "claw", "jab": "strike", "bash": "strike", "arrow": "shot", "frost": "frost", "ambush": "claw",
	"iron_claw": "heavy", "royal_claw": "heavy"}

var b: Battle
var mission_id := ""
var mission := {}
var squad_ids: Array = []
var map_root: Node2D
var map_view: MapView
var units_root: Node2D
var fx_root: Node2D
var hud: HUD
var modal_layer: Control
var views := {}
var selected: RefCounted = null
var inspected: RefCounted = null
var ability := ""
var pending := Vector2i(-1, -1)
var busy := false
var show_threat := false
var result_recorded := false
var rewards := {}
var instant := false  ## tests: skip animation timing
var _hover := Vector2i(-99, -99)


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The board is drawn by Node2Ds and clicked through _unhandled_input. A
	# full-screen root Control with the default STOP filter would swallow
	# every board click in the GUI pass, so let them fall through.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var req: Dictionary = Transition.battle_request
	mission_id = str(req.get("mission_id", "m01"))
	if Missions.get_mission(mission_id).is_empty():
		mission_id = "m01"
	squad_ids = req.get("squad", [])
	if squad_ids.is_empty():
		squad_ids = Campaign.default_squad(mission_id)
	start_battle()


func start_battle() -> void:
	for c in get_children():
		c.queue_free()
	views.clear()
	selected = null
	inspected = null
	ability = ""
	pending = Vector2i(-1, -1)
	busy = false
	result_recorded = false
	mission = Campaign.battle_mission(mission_id)
	b = Battle.new()
	b.setup(mission, Campaign.squad_entries(mission_id, squad_ids), Campaign.difficulty())
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	map_root = Node2D.new()
	var px := Vector2(b.grid.w * TILE, b.grid.h * TILE)
	map_root.position = (MAP_AREA.position + (MAP_AREA.size - px) / 2.0).floor()
	add_child(map_root)
	map_view = MapView.new()
	map_view.battle = b
	map_view.region = str(mission.get("region", "wood"))
	map_root.add_child(map_view)
	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	map_root.add_child(units_root)
	fx_root = Node2D.new()
	fx_root.z_index = 5
	map_root.add_child(fx_root)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = HUD.new()
	hud.region = map_view.region
	hud_layer.add_child(hud)
	hud.build()
	hud.end_button.pressed.connect(_on_end_turn_pressed)
	hud.threat_button.toggled.connect(func(on: bool) -> void:
		show_threat = on
		_refresh())
	hud.menu_button.pressed.connect(open_pause)
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.theme = UI.theme()
	overlay.add_child(modal_layer)
	for u: RefCounted in b.units:
		if u.on_field():
			_add_view(u)
	hud.add_log("[color=#f2c230]%s[/color] - turn 1. Good luck, commander!" % mission["name"])
	for line in b.log_lines:
		hud.add_log(line)
	b.take_events()
	Audio.play_music(str(mission.get("music", "act1")))
	_refresh()
	if not instant:
		show_briefing()


# --------------------------------------------------------------------------
# Views
# --------------------------------------------------------------------------

func _add_view(u: RefCounted) -> UnitView:
	var v := UnitView.new()
	v.setup(u)
	v.position = v.pos_for(u.pos)
	units_root.add_child(v)
	views[u.uid] = v
	return v


func _sync_views() -> void:
	for u: RefCounted in b.units:
		var v: UnitView = views.get(u.uid)
		if u.on_field():
			if v == null:
				v = _add_view(u)
			v.position = v.pos_for(u.pos)
			v.hp = u.hp
			v.max_hp = u.max_hp
			v.asleep = not u.awake
			v.statuses.clear()
			for k: String in u.status:
				v.statuses.append(k)
			v.set_done(u.side == "hero" and not u.is_object and u.acted and b.phase == "player")
			v.selected = (u == selected)
			v.modulate.a = 1.0
		elif v != null:
			v.queue_free()
			views.erase(u.uid)


func _modal_open() -> bool:
	return modal_layer != null and modal_layer.get_child_count() > 0


# --------------------------------------------------------------------------
# Refresh (overlays, panels, action bar)
# --------------------------------------------------------------------------

func _refresh() -> void:
	_sync_views()
	hud.set_top(str(mission["name"]), b.turn, b.phase, b.difficulty)
	hud.set_objectives(b.objective_text(), b.optional_status())
	map_view.move_cells.clear()
	map_view.target_cells.clear()
	map_view.range_cells.clear()
	map_view.area_cells.clear()
	map_view.path.clear()
	map_view.landing = Vector2i(-1, -1)
	map_view.pending = pending
	map_view.selected_cell = selected.pos if selected else Vector2i(-1, -1)
	map_view.inspect_threat = b.threat_cells(inspected) if inspected and inspected.on_field() else {}
	map_view.threat = _all_threat() if show_threat else {}
	if selected and not selected.on_field():
		selected = null
	var can := selected != null and b.can_command(selected) and not busy
	if can:
		if not selected.moved:
			map_view.move_cells = b.reachable_cells(selected)
		if ability != "":
			map_view.target_cells = b.ability_targets(selected, ability)
			var ab := UD.ability(ability)
			if int(ab["rmax"]) > 1 and str(ab["kind"]) in ["attack", "area"]:
				map_view.range_cells = _range_cells(selected, ab)
			if pending.x >= 0:
				if ab["kind"] == "area":
					map_view.area_cells = b.area_cells(pending)
				elif ab["kind"] == "pounce":
					map_view.landing = b.preview(selected, ability, pending)["landing"]
	hud.show_unit(selected if selected else inspected, b)
	_build_actions()
	hud.end_button.disabled = not b.is_player_turn() or busy
	_update_hover(true)


func _all_threat() -> Dictionary:
	var out := {}
	for e: RefCounted in b.side_units("enemy"):
		if e.awake:
			for c: Vector2i in b.threat_cells(e):
				out[c] = true
	return out


func _range_cells(u: RefCounted, ab: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rmax: int = b.range_max(u, ab, u.pos)
	for y in b.grid.h:
		for x in b.grid.w:
			var c := Vector2i(x, y)
			var d := absi(c.x - u.pos.x) + absi(c.y - u.pos.y)
			if d >= int(ab["rmin"]) and d <= rmax and (not bool(ab["los"]) or b.grid.has_los(u.pos, c)):
				out.append(c)
	return out


func _build_actions() -> void:
	hud.clear_actions()
	if selected == null or selected.side != "hero" or selected.is_object:
		var tip := "Select a hero (click, or Tab for the next ready hero)." if b.is_player_turn() else "Enemy turn..."
		hud.add_action(tip, "", false, false, tip, func() -> void: pass)
		return
	var u: RefCounted = selected
	var can: bool = b.can_command(u) and not busy
	var i := 0
	for id: String in u.abilities:
		i += 1
		var ab := UD.ability(id)
		var reason: String = b.ability_block_reason(u, id)
		var has_targets: bool = reason == "" and not b.ability_targets(u, id).is_empty()
		var label := "%d %s" % [i, ab["name"]]
		if int(u.cooldowns.get(id, 0)) > 0:
			label += " (%d)" % int(u.cooldowns[id])
		var tip: String = str(ab["desc"])
		if reason != "":
			tip = "%s - %s" % [reason, tip]
		elif not has_targets:
			tip = "No valid target from here. " + tip
		var icon := "icon_" + id if UI.tex("icon_" + id) else "icon_claw"
		var idc := id
		hud.add_action(label, icon, can and reason == "", ability == id, tip, func() -> void: select_ability(idc))
	for it: Dictionary in b.interactions(u):
		var itc := it
		var icon_name: String = {"free": "icon_free", "claim": "icon_claim", "escape": "icon_escape"}[it["kind"]]
		hud.add_action("F " + str(it["text"]), icon_name, can, false, str(it["text"]) + " (uses this hero's action)",
			func() -> void: do_interact(itc))
	hud.add_action("Wait (W)", "icon_wait", can, false, "End this hero's turn without acting.", func() -> void: do_wait())
	var can_undo: bool = can and u.moved and not u.boss_state.get("move_locked", false)
	hud.add_action("Undo move (Z)", "", can_undo, false, "Return to the starting tile (only before acting).",
		func() -> void: do_undo())


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func mouse_cell() -> Vector2i:
	return _cell_at(map_root.get_local_mouse_position())


## Board cell under a mouse event, taken from the event's own position so a
## click lands where it was made at any window size or display scaling.
func event_cell(event: InputEventMouse) -> Vector2i:
	return _cell_at((map_root.make_input_local(event) as InputEventMouse).position)


func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _process(_delta: float) -> void:
	_update_hover(false)


func _update_hover(force: bool) -> void:
	if b == null or map_view == null:
		return
	var c := mouse_cell()
	if c == _hover and not force:
		return
	_hover = c
	var inside: bool = b.grid.in_bounds(c)
	map_view.hover = c if inside else Vector2i(-1, -1)
	if not inside:
		# keep the confirmation preview visible while the mouse is off the map
		if pending.x >= 0 and selected and ability != "" and b.can_command(selected) and not busy:
			hud.set_preview(b.preview(selected, ability, pending)["text"] + "   - click again to CONFIRM")
		else:
			hud.set_preview("")
		return
	hud.show_tile(c, b)
	map_view.path.clear()
	if busy or not b.is_player_turn():
		return
	var preview_cell := pending if pending.x >= 0 else c
	if selected and b.can_command(selected):
		if ability != "" and b.ability_targets(selected, ability).has(preview_cell):
			var pv: Dictionary = b.preview(selected, ability, preview_cell)
			var txt: String = pv["text"]
			txt += "   - click again to CONFIRM" if pending == preview_cell else "   - click to aim"
			hud.set_preview(txt)
			if UD.ability(ability)["kind"] == "area":
				map_view.area_cells = b.area_cells(preview_cell)
			if UD.ability(ability)["kind"] == "pounce":
				map_view.landing = pv["landing"]
			return
		if not selected.moved and map_view.move_cells.has(c):
			map_view.path = b.path_to(selected, c)
			var cost: int = b.move_field(selected)["cost"].get(c, 0)
			hud.set_preview("Move %s here (cost %d of %d)" % [selected.name, cost, selected.effective_move()])
			return
	var o: RefCounted = b.unit_at(c)
	if o:
		hud.set_preview("%s - %d/%d HP. Click to %s." % [o.name, o.hp, o.max_hp, "select" if o.side == "hero" and not o.is_object else "inspect"])
	elif pending.x < 0:
		hud.set_preview("")


func _unhandled_input(event: InputEvent) -> void:
	if b == null or _modal_open() or Transition.busy:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			click_cell(event_cell(mb))
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	if event.is_action("pause"):
		if selected or pending.x >= 0:
			cancel()
		else:
			open_pause()
	elif event.is_action("cancel"):
		cancel()
	elif event.is_action("end_turn"):
		_on_end_turn_pressed()
	elif event.is_action("wait"):
		do_wait()
	elif event.is_action("undo"):
		do_undo()
	elif event.is_action("next_unit"):
		select_next()
	elif event.is_action("threat"):
		hud.threat_button.button_pressed = not hud.threat_button.button_pressed
	elif event.is_action("confirm"):
		if pending.x >= 0:
			click_cell(pending)
	elif event.is_action("interact"):
		if selected:
			var its: Array = b.interactions(selected)
			if not its.is_empty():
				do_interact(its[0])
	else:
		for i in 4:
			if event.is_action("ability_%d" % (i + 1)) and selected and i < selected.abilities.size():
				select_ability(selected.abilities[i])
	get_viewport().set_input_as_handled()


func click_cell(c: Vector2i) -> void:
	if busy or not b.is_player_turn() or not b.grid.in_bounds(c):
		return
	var o: RefCounted = b.unit_at(c)
	if selected and b.can_command(selected):
		if ability != "" and b.ability_targets(selected, ability).has(c):
			if pending == c:
				do_ability(ability, c)
			else:
				pending = c
				Audio.play("ui_move")
				_refresh()
			return
		if not selected.moved and b.reachable_cells(selected).has(c):
			do_move(c)
			return
	if o != null and o.side == "hero" and not o.is_object:
		select_unit(o)
		return
	if o != null:
		inspected = o
		if selected and not b.can_command(selected):
			selected = null
		pending = Vector2i(-1, -1)
		Audio.play("select", -4.0)
		_refresh()
		return
	inspected = null
	pending = Vector2i(-1, -1)
	if selected and not b.can_command(selected):
		selected = null
	_refresh()


func select_unit(u: RefCounted) -> void:
	selected = u
	inspected = null
	pending = Vector2i(-1, -1)
	ability = _default_ability(u)
	Audio.play("select")
	_refresh()


func _default_ability(u: RefCounted) -> String:
	if not b.can_command(u):
		return ""
	for id: String in u.abilities:
		var k: String = UD.ability(id)["kind"]
		if k in ["attack"] and b.ability_block_reason(u, id) == "" and not b.ability_targets(u, id).is_empty():
			return id
	for id: String in u.abilities:
		if UD.ability(id)["kind"] == "attack" and b.ability_block_reason(u, id) == "":
			return id
	return ""


func select_ability(id: String) -> void:
	if selected == null or not b.can_command(selected) or busy:
		return
	if b.ability_block_reason(selected, id) != "":
		Audio.play("denied")
		return
	if UD.ability(id)["kind"] == "stance":
		if ability == id and pending == selected.pos:
			do_ability(id, selected.pos)
			return
		ability = id
		pending = selected.pos
		hud.set_preview(b.preview(selected, id, selected.pos)["text"] + "   - press again (or Space) to CONFIRM")
		Audio.play("ui_move")
		_refresh()
		return
	ability = id
	pending = Vector2i(-1, -1)
	Audio.play("ui_move")
	_refresh()


func select_next() -> void:
	if not b.is_player_turn() or busy:
		return
	var heroes: Array = b.side_units("hero")
	var start := heroes.find(selected)
	for k in heroes.size():
		var u: RefCounted = heroes[(start + 1 + k) % heroes.size()]
		if u.can_act():
			select_unit(u)
			return


func cancel() -> void:
	if busy:
		return
	if pending.x >= 0:
		pending = Vector2i(-1, -1)
		Audio.play("ui_back")
	elif selected and selected.moved and b.can_command(selected) and not selected.boss_state.get("move_locked", false):
		do_undo()
		return
	elif selected or inspected:
		selected = null
		inspected = null
		ability = ""
		Audio.play("ui_back")
	_refresh()


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

func do_move(c: Vector2i) -> void:
	if b.cmd_move(selected, c):
		pending = Vector2i(-1, -1)
		await _play_events()
		if selected and b.can_command(selected):
			if ability == "" or b.ability_block_reason(selected, ability) != "" or b.ability_targets(selected, ability).is_empty():
				ability = _default_ability(selected)
		_refresh()


func do_ability(id: String, c: Vector2i) -> void:
	if selected and b.cmd_ability(selected, id, c):
		pending = Vector2i(-1, -1)
		ability = ""
		await _play_events()
		_after_action()


func do_interact(it: Dictionary) -> void:
	if selected and not busy and b.cmd_interact(selected, it["kind"], it["cell"]):
		pending = Vector2i(-1, -1)
		await _play_events()
		_after_action()


func do_wait() -> void:
	if selected and not busy and b.cmd_wait(selected):
		Audio.play("ui_ok")
		_after_action()


func do_undo() -> void:
	if selected and not busy and b.cmd_undo_move(selected):
		Audio.play("ui_back")
		pending = Vector2i(-1, -1)
		b.take_events()
		ability = _default_ability(selected)
		_refresh()


func _after_action() -> void:
	if b.result != "":
		_refresh()
		return
	if selected and not b.can_command(selected):
		selected = null
		ability = ""
	_refresh()


func _on_end_turn_pressed() -> void:
	if busy or not b.is_player_turn() or _modal_open():
		return
	var left: int = b.heroes_left_to_act()
	if left > 0 and not instant:
		UI.confirm(modal_layer, "%d hero(es) can still act. End your turn anyway?" % left, end_turn, "End Turn")
	else:
		end_turn()


func end_turn() -> void:
	if busy or not b.is_player_turn():
		return
	selected = null
	inspected = null
	ability = ""
	pending = Vector2i(-1, -1)
	if b.cmd_end_phase():
		await _play_events()
		_refresh()


## Lets the AI play the current player phase (used by automated tests).
func auto_player_turn() -> void:
	if busy or not b.is_player_turn():
		return
	var ai := AI.new()
	ai.play_hero_phase(b)
	await _play_events()
	_refresh()


# --------------------------------------------------------------------------
# Event playback
# --------------------------------------------------------------------------

func _wait(t: float) -> void:
	if instant or t <= 0.0:
		return
	await get_tree().create_timer(t / Settings.anim_speed()).timeout


func _play_events() -> void:
	busy = true
	_refresh()
	var evs := b.take_events()
	for e: Dictionary in evs:
		await _play_event(e)
	busy = false
	_refresh()
	if b.result != "" and not result_recorded:
		_on_battle_end()


func _play_event(e: Dictionary) -> void:
	var v: UnitView = views.get(int(e.get("uid", -1)))
	var sp := Settings.anim_speed()
	match str(e["t"]):
		"phase":
			hud.set_top(str(mission["name"]), int(e["turn"]), str(e["phase"]), b.difficulty)
			if e["phase"] == "player":
				Audio.play("turn_player")
				hud.banner("YOUR TURN  -  Turn %d" % int(e["turn"]), UI.HERO, 0.6 / sp)
			else:
				Audio.play("turn_enemy")
				hud.banner("ENEMY TURN", UI.ENEMY, 0.5 / sp)
				for vv: UnitView in views.values():
					vv.set_done(false)
			await _wait(0.8)
		"move":
			if v:
				var path: Array = e["path"]
				for i in range(1, path.size()):
					var target := v.pos_for(path[i])
					if instant:
						v.position = target
					else:
						var tw := create_tween()
						tw.tween_property(v, "position", target, 0.09 / sp)
						Audio.play("step", -8.0)
						await tw.finished
		"teleport":
			if v:
				v.position = v.pos_for(e["to"])
		"pounce":
			if v:
				Audio.play("pounce")
				var target := v.pos_for(e["to"])
				if instant:
					v.position = target
				else:
					var tw := create_tween().set_parallel(true)
					tw.tween_property(v, "position", target, 0.25 / sp).set_trans(Tween.TRANS_QUAD)
					tw.tween_property(v.sprite, "position:y", v.sprite.position.y - 18, 0.12 / sp).set_ease(Tween.EASE_OUT)
					tw.chain().tween_property(v.sprite, "position:y", v.sprite.position.y, 0.12 / sp).set_ease(Tween.EASE_IN)
					await tw.finished
		"attack":
			var tv: UnitView = views.get(int(e["target"]))
			Audio.play(ATTACK_SFX.get(str(e["ability"]), "strike"))
			if v and tv and not instant:
				if bool(e["ranged"]):
					await _projectile(v.position, tv.position, "fx_bolt" if e["ability"] == "frost" else "fx_arrow")
				else:
					await v.lunge(tv.position, sp)
		"area":
			Audio.play("volley")
			if not instant and v:
				for c: Vector2i in e["cells"]:
					_projectile(v.position, map_view.cell_center(c), "fx_arrow")
				await _wait(0.35)
		"damage":
			if v:
				v.hp = int(e["hp"])
				if bool(e.get("immune", false)):
					_float_text(v.position, "IMMUNE", UI.ACCENT)
					Audio.play("block")
				else:
					v.flash(Color(1, 0.3, 0.3))
					_float_text(v.position, "-%d" % int(e["amount"]), Color("ff7a7a"))
					Audio.play("hit")
					if int(e["amount"]) >= 10:
						_shake(4.0)
			await _wait(0.18)
		"heal":
			if v:
				v.hp = int(e["hp"])
				v.flash(Color(0.4, 1, 0.5))
				_float_text(v.position, "+%d" % int(e["amount"]), UI.GOOD)
			Audio.play("heal")
			await _wait(0.25)
		"ko":
			if v:
				var u: RefCounted = b.unit_by_uid(int(e["uid"]))
				Audio.play("ko" if u and u.side == "hero" else "enemy_ko")
				_float_text(v.position, "K.O.", Color.WHITE)
				views.erase(int(e["uid"]))
				if instant:
					v.queue_free()
				else:
					var tw := create_tween()
					tw.tween_property(v, "modulate:a", 0.0, 0.35 / sp)
					tw.tween_callback(v.queue_free)
					await tw.finished
		"status":
			if v:
				var names := {"stance": "STANCE", "chilled": "CHILLED", "exhausted": "EXHAUSTED!", "drained": "DRAINED!",
					"iron_guard": "IRON GUARD"}
				_float_text(v.position + Vector2(0, -16), names.get(str(e["status"]), str(e["status"])), UI.ACCENT)
				if not v.statuses.has(str(e["status"])):
					v.statuses.append(str(e["status"]))
			await _wait(0.2)
		"status_end":
			if v:
				v.statuses.erase(str(e["status"]))
		"spawn":
			var u2: RefCounted = b.unit_by_uid(int(e["uid"]))
			if u2 and not views.has(u2.uid):
				var nv := _add_view(u2)
				nv.modulate.a = 0.0
				var tw2 := create_tween()
				tw2.tween_property(nv, "modulate:a", 1.0, 0.3 / sp)
			Audio.play("summon", -4.0)
			await _wait(0.25)
		"free":
			Audio.play("free")
			_float_text(map_view.cell_center(e["cell"]), "Freed!", UI.GOOD)
			if int(e["uid"]) >= 0:
				var u3: RefCounted = b.unit_by_uid(int(e["uid"]))
				if u3 and not views.has(u3.uid):
					_add_view(u3)
			await _wait(0.4)
		"claim":
			Audio.play("claim")
			_float_text(map_view.cell_center(e["cell"]), "Relic claimed!", UI.ACCENT)
			await _wait(0.4)
		"escape":
			Audio.play("escape")
			if v:
				_float_text(v.position, "Escaped!", UI.GOOD)
				views.erase(int(e["uid"]))
				var tw3 := create_tween()
				tw3.tween_property(v, "modulate:a", 0.0, 0.3 / sp)
				tw3.tween_callback(v.queue_free)
			await _wait(0.3)
		"treasure":
			Audio.play("treasure")
			_float_text(map_view.cell_center(e["cell"]), "Fish crate!", UI.ACCENT)
			await _wait(0.3)
		"telegraph":
			if v:
				_float_text(v.position + Vector2(0, -20), "!", Color("ffb030"))
			await _wait(0.5)
		"blast":
			Audio.play("blast")
			_shake(6.0)
			for c: Vector2i in e["cells"]:
				_cell_flash(c, Color(1.0, 0.7, 0.3, 0.8))
			await _wait(0.35)
		"banner":
			hud.banner(str(e["text"]), UI.ACCENT, 1.0 / sp)
			await _wait(1.0)
		"log":
			hud.add_log(str(e["text"]))
		"sfx":
			Audio.play(str(e["name"]))
		"wake":
			if v:
				v.asleep = false
				_float_text(v.position + Vector2(0, -20), "!", UI.ENEMY)
			Audio.play("wake", -6.0)
		"end":
			pass


func _projectile(from: Vector2, to: Vector2, tex_name: String) -> void:
	if instant:
		return
	var s := Sprite2D.new()
	s.texture = UI.tex(tex_name)
	s.scale = Vector2(2.5, 2.5)
	s.position = from
	s.rotation = (to - from).angle()
	fx_root.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position", to, 0.22 / Settings.anim_speed())
	tw.tween_callback(s.queue_free)
	await tw.finished


func _float_text(at: Vector2, text: String, color: Color) -> void:
	if instant:
		return
	var l := UI.label(text, 20, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(120, 28)
	l.position = at + Vector2(-60, -48)
	l.z_index = 10
	fx_root.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 26, 0.8 / Settings.anim_speed())
	tw.tween_property(l, "modulate:a", 0.0, 0.8 / Settings.anim_speed()).set_delay(0.3 / Settings.anim_speed())
	tw.chain().tween_callback(l.queue_free)


func _cell_flash(c: Vector2i, color: Color) -> void:
	if instant:
		return
	var r := ColorRect.new()
	r.color = color
	r.position = Vector2(c.x * TILE, c.y * TILE)
	r.size = Vector2(TILE, TILE)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_root.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.5)
	tw.tween_callback(r.queue_free)


func _shake(amount: float) -> void:
	if instant:
		return
	var base := map_root.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(map_root, "position", base + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(map_root, "position", base, 0.03)


# --------------------------------------------------------------------------
# Overlays: briefing, pause, result
# --------------------------------------------------------------------------

func show_briefing() -> void:
	var m := UI.modal(modal_layer, 720)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "Briefing"
	v.add_child(UI.label(str(mission["name"]), 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.wrap_label(str(mission["brief"]), 16))
	v.add_child(UI.label("Objective: " + b.objective_text(), 16, UI.GOOD))
	for o: Dictionary in mission.get("optional", []):
		v.add_child(UI.label("Optional: " + str(o["text"]), 14, UI.TEXT_DIM))
	for h: String in mission.get("hints", []):
		v.add_child(UI.wrap_label("Tip: " + h, 14, UI.ACCENT))
	v.add_child(UI.wrap_label("Each hero moves once and then acts once per turn. Right click cancels. Esc opens the menu.", 13, UI.TEXT_DIM))
	var go := UI.button("Begin Battle", func() -> void:
		dim.queue_free()
		hud.banner("YOUR TURN  -  Turn 1", UI.HERO, 0.6)
		Audio.play("turn_player"), 220, 18)
	go.name = "Begin"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	go.call_deferred("grab_focus")


func open_pause() -> void:
	if _modal_open():
		return
	var m := UI.modal(modal_layer, 420)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "Pause"
	v.add_child(UI.label("PAUSED", 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var close := func() -> void: dim.queue_free()
	var resume := UI.button("Resume", close, 300)
	v.add_child(resume)
	v.add_child(UI.button("Restart Mission", func() -> void:
		UI.confirm(modal_layer, "Restart this mission from the beginning?", func() -> void:
			dim.queue_free()
			restart()), 300))
	v.add_child(UI.button("Settings", func() -> void: SettingsPanel.open(modal_layer, true), 300))
	v.add_child(UI.button("Controls & Rules", func() -> void: SettingsPanel.open_help(modal_layer), 300))
	v.add_child(UI.button("Return to Campaign", func() -> void:
		UI.confirm(modal_layer, "Leave this battle? Progress in this battle will be lost (your campaign is safe).", func() -> void:
			Transition.go_campaign()), 300))
	v.add_child(UI.button("Quit to Main Menu", func() -> void:
		UI.confirm(modal_layer, "Quit to the main menu? Progress in this battle will be lost.", func() -> void:
			Transition.go_menu()), 300))
	resume.call_deferred("grab_focus")


func restart() -> void:
	for c in modal_layer.get_children():
		c.queue_free()
	start_battle()


func _on_battle_end() -> void:
	result_recorded = true
	var summary: Dictionary = b.summary()
	rewards = Campaign.record_result(mission_id, summary)
	if b.result == "victory":
		Audio.play("victory")
		hud.banner("VICTORY!", UI.GOOD, 1.2)
	else:
		Audio.play("defeat")
		hud.banner("DEFEAT", UI.BAD, 1.2)
	await _wait(1.4)
	show_result()


func show_result() -> void:
	var win := b.result == "victory"
	var m := UI.modal(modal_layer, 640)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "Result"
	v.add_child(UI.label("VICTORY!" if win else "DEFEAT", 32, UI.GOOD if win else UI.BAD, HORIZONTAL_ALIGNMENT_CENTER))
	if win:
		v.add_child(UI.wrap_label(str(mission.get("win_text", "")), 15))
	else:
		v.add_child(UI.wrap_label(b.defeat_reason + "  Nobody is lost - try again with a new plan!", 15))
	v.add_child(UI.label("Turns: %d     Knock-outs: %d" % [b.turn, b.ko_count], 15, UI.TEXT_DIM))
	for o: Dictionary in b.optional_status():
		var ok: bool = o["state"] == "done" and win
		v.add_child(UI.label("%s %s" % ["[OK]" if ok else "[  ]", o["text"]], 14, UI.GOOD if ok else UI.TEXT_DIM))
	if win and not mission.get("challenge", false):
		var medal_names := ["", "Bronze", "Silver", "Gold"]
		v.add_child(UI.label("Medal: %s" % medal_names[int(rewards.get("medal", 1))], 16, UI.ACCENT))
		if int(rewards.get("shards", 0)) > 0:
			v.add_child(UI.label("+%d Relic Shards (spend them on upgrades)" % int(rewards["shards"]), 15, UI.ACCENT))
		if bool(rewards.get("first_clear", false)):
			var parts: Array[String] = []
			for hid: String in rewards["xp"]:
				parts.append("%s +%d" % [UD.HEROES[hid]["name"], int(rewards["xp"][hid])])
			v.add_child(UI.wrap_label("XP: " + ", ".join(parts), 14))
			for hid: String in rewards["level_ups"]:
				v.add_child(UI.label("%s reached level %d!" % [UD.HEROES[hid]["name"], Campaign.hero_level(hid)], 15, UI.GOOD))
				Audio.play("levelup")
			for hid: String in rewards["recruits"]:
				v.add_child(UI.label("%s the %s joins your squad!" % [UD.HEROES[hid]["name"], UD.CLASSES[UD.HEROES[hid]["class"]]["name"]], 16, UI.HERO))
		else:
			v.add_child(UI.wrap_label("Replay: XP and mission rewards are only given the first time. New optional objectives still pay out.", 13, UI.TEXT_DIM))
	elif win:
		v.add_child(UI.label("Challenge complete! Best: %d turns" % int(Campaign.data["challenges"][mission_id]["best_turns"]), 15, UI.ACCENT))
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UI.button("Retry", func() -> void: restart(), 160))
	var cont := UI.button("Continue", func() -> void:
		if bool(rewards.get("campaign_complete", false)):
			Transition.go_ending()
		else:
			Transition.go_campaign("challenges" if mission.get("challenge", false) else ""), 200)
	cont.name = "Continue"
	row.add_child(cont)
	cont.call_deferred("grab_focus")
