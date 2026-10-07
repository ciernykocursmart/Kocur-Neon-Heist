class_name Game
extends Node2D
## Mission controller (root of scenes/game.tscn).
##
## Builds the facility for the current mission definition, spawns the cat,
## enemies and hackable systems, routes interactions/noise/bullets, tracks
## objectives and resolves win (extraction with the data) or loss (death).
##
## Objective kinds (from the mission definition):
##   data    one data core; download it, then reach EVAC
##   shards  several cores; download all, then reach EVAC
##   final   breach 3 uplinks -> vault unseals -> defeat the WARDEN ->
##           download the archive -> lockdown escape to EVAC

const HACK_PROMPT_RADIUS := 64.0
const EXTRACT_TIME := 1.2

var def: Dictionary
var rng := RandomNumberGenerator.new()

var facility: Facility
var entities: Node2D
var bullets: Node2D
var fx_layer: Node2D
var player: Player
var camera: GameCamera
var alarm: AlarmSystem
var hud: HUD
var pause_menu: PauseMenu
var end_screen: EndScreen

var data_core: DataCore
var cores: Array[DataCore] = []
var extraction: ExtractionPad
var doors: Array[SecurityDoor] = []
var vault_doors: Array[SecurityDoor] = []
var boss: EnemyWarden
var arena_rooms: Array = []
var cores_done := 0
var boss_defeated := false
var lockdown := false
var bodies_found := 0
var reinforcements_spawned := 0
var _tips: Array = []
var _tip_timer := 3.5

var has_data := false
var mission_over := false
var mission_time := 0.0
var kills := 0
var takedowns := 0
var credits_found := 0
var damage_taken := 0.0
var zone_meter := 0.0
var cameras_loop_timer := 0.0
var focus: Node2D = null
var hacking_target: Hackable = null
var _hack_cooldown := 0.0
## Living enemies, refreshed once per physics tick (cheap shared lookup).
var enemy_list: Array = []


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	def = GameState.get_mission_def()
	rng.seed = int(def["seed"])

	_build_environment()

	facility = Facility.new()
	facility.name = "Facility"
	add_child(facility)
	facility.build(FacilityGenerator.generate(def, rng))

	entities = Node2D.new()
	entities.name = "Entities"
	add_child(entities)
	bullets = Node2D.new()
	bullets.name = "Bullets"
	add_child(bullets)
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 10
	add_child(fx_layer)

	alarm = AlarmSystem.new()
	alarm.name = "AlarmSystem"
	alarm.game = self
	add_child(alarm)

	_spawn_player()
	_populate()

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	var ws := facility.world_size()
	camera.limit_left = -TILE_MARGIN
	camera.limit_top = -TILE_MARGIN
	camera.limit_right = int(ws.x) + TILE_MARGIN
	camera.limit_bottom = int(ws.y) + TILE_MARGIN
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()

	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	hud.hack_finished.connect(_on_hack_finished)
	hud.hack_missed.connect(_on_hack_missed)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(self)

	end_screen = EndScreen.new()
	add_child(end_screen)
	end_screen.setup(self)

	alarm.level_changed.connect(_on_alarm_level_changed)
	player.died.connect(_on_player_died)

	UITheme.set_crosshair_cursor(true)
	Sfx.play_music("music")
	Sfx.set_music_pitch(1.0)
	hud.show_title(String(def.get("act_label", "")), String(def["name"]), String(def["corp"]))
	Sfx.play("act_sting", -4.0)
	if bool(GameState.settings.get("tutorial_tips", true)):
		_tips = (def.get("tips", []) as Array).duplicate()
	if bool(def.get("final", false)) and GameState.finale_checkpoint:
		_tips = ["CHECKPOINT: the uplinks stay breached - head straight for the core."]
		_tip_timer = 2.0


const TILE_MARGIN := 64


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	UITheme.set_crosshair_cursor(false)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.75
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 0.3)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# --------------------------------------------------------------------------
# Population
# --------------------------------------------------------------------------

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.game = self
	var spawn_room: int = facility.layout["spawn_room"]
	var spots := facility.room_markers(spawn_room, "S")
	var cell: Vector2i = spots[0] if not spots.is_empty() else facility.cell_of(facility.room_center(spawn_room))
	player.position = facility.cell_center(cell)
	entities.add_child(player)


func _populate() -> void:
	var layout := facility.layout
	var spawn_room: int = layout["spawn_room"]
	var data_room: int = layout["data_room"]
	var extract_room: int = layout["extract_room"]

	arena_rooms = layout.get("arena_rooms", [])

	# Objectives.
	var objective := String(def.get("objective", "data"))
	if objective == "final":
		_populate_final(data_room, spawn_room, extract_room)
	else:
		data_core = _spawn_core("data" if objective == "data" else "shard", _room_spot(data_room, "S"))
		if objective == "shards":
			for room in _far_rooms(int(def.get("shards", 2)) - 1, [spawn_room, data_room, extract_room]):
				_spawn_core("shard", _room_spot(room, "S"))

	extraction = ExtractionPad.new()
	extraction.game = self
	var pad_pos := _room_spot(extract_room, "S")
	if extract_room == data_room or extract_room in arena_rooms:
		pad_pos += Vector2(0, Facility.TILE * 3)
	extraction.position = pad_pos
	entities.add_child(extraction)

	# Security doors.
	for d in layout["doors"]:
		if not d["locked"]:
			continue
		var door := SecurityDoor.new()
		door.game = self
		door.setup(facility, d["cells"], d["horizontal"])
		var rooms_of: Array = d["rooms"]
		var is_vault: bool = data_room in rooms_of
		for ar in arena_rooms:
			if ar in rooms_of:
				is_vault = true
		door.set_meta("vault", is_vault)
		if is_vault and bool(def.get("final", false)):
			door.sealed = true
			vault_doors.append(door)
		entities.add_child(door)
		doors.append(door)

	var non_spawn: Array[int] = []
	for i in facility.rooms.size():
		if i != spawn_room and not (i in arena_rooms):
			non_spawn.append(i)

	# Cameras.
	var cam_spots := _collect_markers("K", non_spawn)
	for i in mini(int(def["cameras"]), cam_spots.size()):
		var info: Array = cam_spots[i]
		var cam := SecurityCamera.new()
		cam.game = self
		var cell: Vector2i = info[1]
		cam.position = _wall_mount_position(cell)
		cam.base_angle = (facility.room_center(info[0]) - cam.position).angle()
		entities.add_child(cam)

	# Alarm panels.
	var panel_spots := _collect_markers("A", non_spawn)
	var panels := int(def["alarm_panels"])
	for i in mini(panels, panel_spots.size()):
		var panel := AlarmPanel.new()
		panel.game = self
		panel.position = facility.cell_center(panel_spots[i][1])
		entities.add_child(panel)
	if panel_spots.is_empty():
		var panel := AlarmPanel.new()
		panel.game = self
		var room: int = non_spawn[rng.randi() % non_spawn.size()]
		panel.position = facility.cell_center(facility.random_floor_cell(room, rng))
		entities.add_child(panel)

	# Terminals with varied programs.
	var term_spots := _collect_markers("T", non_spawn)
	var programs := [Terminal.Program.CAMERA_LOOP, Terminal.Program.DOOR_OVERRIDE, Terminal.Program.CREDIT_SKIM]
	programs.shuffle()
	for i in mini(int(def["terminals"]), term_spots.size()):
		var term := Terminal.new()
		term.game = self
		term.program = programs[i % programs.size()]
		term.position = facility.cell_center(term_spots[i][1])
		entities.add_child(term)

	# Pickups.
	var all_rooms: Array[int] = []
	for i in facility.rooms.size():
		all_rooms.append(i)
	for info in _collect_markers("P", all_rooms):
		if rng.randf() > 0.75:
			continue
		var kind := rng.randi() % 3
		spawn_pickup(kind, facility.cell_center(info[1]))

	# Enemies.
	var spawn_pos := player.global_position
	var guard_spots := _collect_markers("E", non_spawn)
	var drone_spots := _collect_markers("D", non_spawn)
	for i in int(def["guards"]):
		var pos := _take_spot(guard_spots, non_spawn, spawn_pos)
		var g := EnemyGuard.new()
		_setup_enemy(g, pos, 3, 2)
	for i in int(def["drones"]):
		var pos := _take_spot(drone_spots, non_spawn, spawn_pos)
		var dr := EnemyDrone.new()
		_setup_enemy(dr, pos, 4, 0)
	for i in int(def["hunters"]):
		var room := data_room if i == 0 and not (data_room in arena_rooms) else non_spawn[rng.randi() % non_spawn.size()]
		var cell := facility.random_floor_cell(room, rng, spawn_pos, 400.0)
		var h := EnemyHunter.new()
		_setup_enemy(h, facility.cell_center(cell), 3, 2)
	for i in int(def.get("enforcers", 0)):
		var pos := _take_spot(guard_spots, non_spawn, spawn_pos)
		var en := EnemyEnforcer.new()
		_setup_enemy(en, pos, 2, 1)

	# Boss.
	if bool(def.get("final", false)):
		boss = EnemyWarden.new()
		var center := _arena_center()
		boss.game = self
		boss.facility = facility
		boss.position = center
		boss.patrol_points = [center]
		entities.add_child(boss)

	if bool(def.get("final", false)) and GameState.finale_checkpoint and String(def.get("mode", "")) == "campaign":
		_apply_finale_checkpoint()

	# Hidden intel fragment, placed away from the insertion point.
	var intel_id := int(def.get("intel", -1))
	if intel_id >= 0 and not GameState.has_intel(intel_id):
		var rooms_far := _far_rooms(1, [spawn_room])
		if not rooms_far.is_empty():
			var room: int = rooms_far[rng.randi() % rooms_far.size()]
			var frag := IntelFragment.new()
			frag.game = self
			frag.intel_id = intel_id
			frag.position = facility.cell_center(facility.random_floor_cell(room, rng, spawn_pos, 300.0))
			entities.add_child(frag)


## Retrying the finale after the uplinks were breached skips straight to the
## open vault.
func _apply_finale_checkpoint() -> void:
	for c in cores:
		if c.role == "uplink":
			c.hacked_done = true
	for d in vault_doors:
		d.sealed = false
		d.hacked_done = true
		d.call_deferred("on_hacked")


func _spawn_core(role: String, pos: Vector2) -> DataCore:
	var core := DataCore.new()
	core.game = self
	core.role = role
	core.position = pos
	entities.add_child(core)
	cores.append(core)
	return core


func _populate_final(data_room: int, spawn_room: int, extract_room: int) -> void:
	var excluded := [spawn_room, data_room, extract_room]
	excluded.append_array(arena_rooms)
	for room in _far_rooms(int(def.get("shards", 3)), excluded):
		_spawn_core("uplink", _room_spot(room, "S"))
	data_core = _spawn_core("archive", _arena_center() + Vector2(0, -Facility.TILE * 3))
	data_core.sealed = true


func _arena_center() -> Vector2:
	if arena_rooms.size() >= 2:
		return (facility.room_center(arena_rooms[0]) + facility.room_center(arena_rooms[1])) * 0.5
	return facility.room_center(facility.layout["data_room"])


## Rooms ordered by distance from the spawn (farthest first), excluding some.
func _far_rooms(count: int, exclude: Array) -> Array:
	var spawn_c := facility.room_center(facility.layout["spawn_room"])
	var candidates := []
	for i in facility.rooms.size():
		if not (i in exclude):
			candidates.append(i)
	candidates.sort_custom(func(a, b): return facility.room_center(a).distance_to(spawn_c) > facility.room_center(b).distance_to(spawn_c))
	# Take from the farther half, shuffled, for variety.
	var pool := candidates.slice(0, maxi(count, int(ceil(candidates.size() * 0.6))))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(count, pool.size()))


func _room_spot(room: int, ch: String) -> Vector2:
	var spots := facility.room_markers(room, ch)
	if spots.is_empty():
		return facility.room_center(room)
	return facility.cell_center(spots[0])


## Returns shuffled [room, cell] pairs for a marker character.
func _collect_markers(ch: String, room_list: Array[int]) -> Array:
	var out := []
	for r in room_list:
		for c in facility.room_markers(r, ch):
			out.append([r, c])
	# Deterministic shuffle using the mission RNG.
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _take_spot(spots: Array, rooms_list: Array[int], avoid: Vector2) -> Vector2:
	while not spots.is_empty():
		var info: Array = spots.pop_back()
		var p := facility.cell_center(info[1])
		if p.distance_to(avoid) > 380.0:
			return p
	var room: int = rooms_list[rng.randi() % rooms_list.size()]
	return facility.cell_center(facility.random_floor_cell(room, rng, avoid, 380.0))


func _wall_mount_position(cell: Vector2i) -> Vector2:
	var p := facility.cell_center(cell)
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if facility.is_solid_tile(cell + d):
			return p + Vector2(d) * 10.0
	return p


func _setup_enemy(e: Enemy, pos: Vector2, patrol_count: int, neighbour_points: int) -> void:
	e.game = self
	e.facility = facility
	e.position = pos
	var room := facility.room_at(pos)
	var points: Array[Vector2] = [pos]
	if room >= 0:
		for i in patrol_count:
			var c := facility.random_floor_cell(room, rng)
			if facility.has_path(pos, facility.cell_center(c)):
				points.append(facility.cell_center(c))
		# Some patrols wander into a connected neighbouring room.
		if neighbour_points > 0:
			for d in facility.layout["doors"]:
				if d["locked"] or not (room in d["rooms"]):
					continue
				var other: int = d["rooms"][0] if d["rooms"][1] == room else d["rooms"][1]
				if other == facility.layout["spawn_room"]:
					continue
				if rng.randf() < 0.5:
					var c2 := facility.random_floor_cell(other, rng)
					if facility.has_path(pos, facility.cell_center(c2)):
						points.insert(1 + rng.randi() % points.size(), facility.cell_center(c2))
						neighbour_points -= 1
						if neighbour_points <= 0:
							break
	e.patrol_points = points
	entities.add_child(e)


func spawn_pickup(kind: int, pos: Vector2, amount := 0) -> void:
	var p := Pickup.new()
	p.game = self
	p.kind = kind
	p.amount = amount
	p.position = pos
	entities.add_child(p)


func spawn_reinforcements(count: int, allow_hunters: bool) -> void:
	if mission_over or player == null or player.dead:
		return
	count = mini(count, int(def.get("max_reinforcements", 3)))
	reinforcements_spawned += count
	# Warp in at the room farthest from the player that still has a path.
	# Normally they come from the far side of the facility. During the final
	# lockdown they pursue from nearby instead of camping the EVAC room.
	var best := -1
	var best_d := -1.0
	var extract_room: int = facility.layout["extract_room"]
	for i in facility.rooms.size():
		var d := facility.room_center(i).distance_to(player.global_position)
		if d <= 500.0 or i in arena_rooms:
			continue
		if lockdown:
			if i == extract_room:
				continue
			if best < 0 or d < best_d:
				best_d = d
				best = i
		elif d > best_d:
			best_d = d
			best = i
	if best < 0:
		return
	for i in count:
		var e: Enemy
		if allow_hunters and i == 0:
			e = EnemyHunter.new()
		elif i == 2 and int(def.get("enforcers", 0)) > 0:
			e = EnemyEnforcer.new()
		elif i % 2 == 1:
			e = EnemyDrone.new()
		else:
			e = EnemyGuard.new()
		var cell := facility.random_floor_cell(best, rng)
		var pos := facility.cell_center(cell)
		_setup_enemy(e, pos, 2, 0)
		e.awareness = 0.8
		e.call_deferred("on_alarm", alarm.last_known)
		FX.ring(fx_layer, pos, Palette.MAGENTA, 70.0, 0.6, 3.0)
		FX.burst(fx_layer, pos, Palette.MAGENTA, 18, 220.0, 0.5, 3.0)
		Sfx.play_at("warp", pos, 0.0)
	notify("REINFORCEMENTS INBOUND (%d)" % count, Palette.MAGENTA)


func spawn_boss_escort(pos: Vector2, count: int) -> void:
	for i in count:
		var c := facility.nearest_walkable(facility.cell_of(pos + Vector2.from_angle(TAU * i / count + rng.randf()) * 90.0))
		var dr := EnemyDrone.new()
		_setup_enemy(dr, facility.cell_center(c), 0, 0)
		dr.call_deferred("on_alarm", player.global_position)
		FX.burst(fx_layer, facility.cell_center(c), Palette.MAGENTA, 14, 200.0, 0.4, 3.0)


func spawn_decoy(from: Vector2, to: Vector2) -> void:
	var d := Decoy.new()
	d.game = self
	d.start = from
	# Land on the nearest walkable cell along the throw (never inside walls).
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = (hit["position"] as Vector2) - (to - from).normalized() * 14.0
	d.target = to
	entities.add_child(d)


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	enemy_list = get_tree().get_nodes_in_group("enemies")
	if mission_over:
		return
	mission_time += delta
	_hack_cooldown = maxf(0.0, _hack_cooldown - delta)
	cameras_loop_timer = maxf(0.0, cameras_loop_timer - delta)
	_update_focus()
	_update_zones(delta)
	_update_extraction(delta)
	_update_boss_trigger()
	_update_tips(delta)


func _update_tips(delta: float) -> void:
	if _tips.is_empty():
		return
	_tip_timer -= delta
	if _tip_timer <= 0.0:
		_tip_timer = 9.0
		hud.show_tip(String(_tips.pop_front()))


func _update_boss_trigger() -> void:
	if boss == null or boss.active or boss.is_dead() or player == null or player.dead:
		return
	if not (facility.room_at(player.global_position) in arena_rooms):
		return
	for d in vault_doors:
		if d.global_position.distance_to(player.global_position) < 96.0:
			return
	_start_boss_fight()


func _start_boss_fight() -> void:
	for d in vault_doors:
		d.force_close()
	boss.activate()
	hud.show_boss(boss)
	# Supply drop so the fight is about skill, not leftover ammo.
	var center := _arena_center()
	for offset in [Vector2(-300, -110), Vector2(300, 110), Vector2(-300, 110), Vector2(300, -110)]:
		var c := facility.nearest_walkable(facility.cell_of(center + offset))
		var kind := Pickup.Kind.AMMO if offset.x * offset.y < 0 else Pickup.Kind.MEDKIT
		spawn_pickup(kind, facility.cell_center(c), 16 if kind == Pickup.Kind.AMMO else 40)
	Sfx.play_music("boss")
	notify("THE WARDEN AWAKENS", Palette.RED)


func _update_focus() -> void:
	focus = null
	if player == null or player.dead or hacking_target != null:
		return
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactables"):
		var h := n as Hackable
		if h == null or not h.can_interact():
			continue
		var d := player.global_position.distance_to(h.interact_position())
		if d < h.interact_radius and d < best_d:
			best_d = d
			focus = h


func _update_zones(delta: float) -> void:
	if player == null or player.dead:
		return
	if facility.zones_active and facility.is_in_zone(player.global_position):
		var prev := zone_meter
		var rate := 0.75 if player.velocity.length() > 20.0 else 0.25
		zone_meter = minf(1.0, zone_meter + delta * rate * player.visibility() * 1.6)
		if prev < 0.02 and zone_meter >= 0.02:
			Sfx.play("suspicious", -6.0, 1.6)
		if zone_meter >= 1.0:
			if alarm.level != AlarmSystem.Level.ALARM:
				alarm.raise_alarm(player.global_position, "MOTION SENSOR")
			else:
				alarm.report_sighting(player.global_position)
			zone_meter = 0.7
	else:
		zone_meter = maxf(0.0, zone_meter - delta * 0.35)


func _update_extraction(delta: float) -> void:
	if not has_data or player == null or player.dead:
		return
	if player.global_position.distance_to(extraction.global_position) < ExtractionPad.RADIUS:
		if extraction.progress <= 0.0:
			Sfx.play("hack_tick", 0.0, 0.8)
		extraction.progress = minf(1.0, extraction.progress + delta / EXTRACT_TIME)
		if extraction.progress >= 1.0:
			complete_mission()
	else:
		extraction.progress = maxf(0.0, extraction.progress - delta * 2.0)


## Highest detection level among everything currently watching the cat.
func detection_level() -> float:
	var v := zone_meter
	for e in get_tree().get_nodes_in_group("enemies"):
		v = maxf(v, e.awareness)
	for c in get_tree().get_nodes_in_group("cameras"):
		v = maxf(v, c.awareness)
	return v


func _unhandled_input(event: InputEvent) -> void:
	if mission_over:
		return
	if event.is_action_pressed("pause"):
		if hacking_target != null:
			hud.abort_hack()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# Interaction & hacking
# --------------------------------------------------------------------------

func request_interact() -> void:
	if hacking_target != null or focus == null or mission_over or _hack_cooldown > 0.0:
		return
	var h := focus as Hackable
	if h == null:
		return
	if h.sealed:
		notify(h.sealed_reason(), Palette.PURPLE)
		Sfx.play("denied", -4.0)
		_hack_cooldown = 0.8
		return
	if h.instant:
		_hack_cooldown = 0.4
		h.complete_hack()
		return
	hacking_target = h
	player.locked = true
	var hits := maxi(1, h.difficulty)
	var misses := 2 + GameState.hack_extra_misses()
	var window := 0.55 + GameState.hack_window_bonus()
	hud.begin_hack(h.display_name, h.describe(), hits, misses, window)
	Sfx.play("hack_tick")


func _on_hack_missed() -> void:
	if hacking_target != null:
		emit_noise(hacking_target.global_position, 160.0, false)


func _on_hack_finished(outcome: String) -> void:
	var h := hacking_target
	hacking_target = null
	_hack_cooldown = 0.35
	if player != null and not player.dead:
		player.locked = false
		player.fire_timer = 0.25
	if h == null or mission_over:
		return
	match outcome:
		"success":
			Sfx.play("hack_success")
			FX.float_text(fx_layer, h.global_position + Vector2(0, -30), "ACCESS GRANTED", Palette.GREEN, 16)
			h.complete_hack()
		"fail":
			Sfx.play("hack_fail")
			FX.float_text(fx_layer, h.global_position + Vector2(0, -30), "ACCESS DENIED", Palette.RED, 16)
			h.on_hack_failed()


func on_player_hit_enemy(killed: bool) -> void:
	if hud != null:
		hud.hitmarker(killed)


func on_player_damaged(amount: float) -> void:
	damage_taken += amount
	hud.flash_damage(amount)
	if hacking_target != null:
		hud.abort_hack()


func emit_noise(pos: Vector2, radius: float, visible_ring: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_squared_to(pos) < radius * radius:
			e.hear_noise(pos, radius > 300.0)
	if visible_ring:
		FX.ring(fx_layer, pos, Palette.with_alpha(Palette.WHITE, 0.25), radius, 0.6, 1.5)


func spawn_bullet(pos: Vector2, vel: Vector2, dmg: float, from_player: bool, color: Color, opts := {}) -> void:
	var b := Bullet.new()
	if not opts.is_empty():
		b.configure(opts)
	b.game = self
	b.velocity = vel
	b.damage = dmg
	b.from_player = from_player
	b.color = color
	b.position = pos
	bullets.add_child(b)


func notify(text: String, color: Color) -> void:
	if hud != null:
		hud.notify(text, color)


func collect_credits(amount: int, pos: Vector2) -> void:
	credits_found += amount
	FX.float_text(fx_layer, pos, "+%d CR" % amount, Palette.YELLOW, 15)
	Sfx.play("credits", -2.0)


func loop_cameras(duration: float) -> void:
	cameras_loop_timer = maxf(cameras_loop_timer, duration)
	notify("CAMERA FEEDS LOOPED for %ds" % int(duration), Palette.CYAN)


func override_doors() -> void:
	var opened := 0
	for d in doors:
		if not d.hacked_done and not bool(d.get_meta("vault", false)):
			d.complete_hack()
			opened += 1
	notify("DOOR OVERRIDE - %d doors unlocked" % opened, Palette.CYAN)


func on_enemy_killed(e: Enemy, silent: bool) -> void:
	kills += 1
	if silent:
		takedowns += 1
	camera.shake(0.25)
	hitstop(0.05)
	if rng.randf() < 0.55:
		spawn_pickup(Pickup.Kind.CREDITS, e.global_position, e.credit_drop)
	elif rng.randf() < 0.5:
		spawn_pickup(Pickup.Kind.AMMO, e.global_position, 8)
	if not silent:
		emit_noise(e.global_position, 260.0, false)


func hitstop(duration: float) -> void:
	Engine.time_scale = 0.08
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		if not mission_over:
			Engine.time_scale = 1.0)


func on_data_stolen() -> void:
	has_data = true
	extraction.activate()
	alarm.raise_caution(data_core.global_position)
	notify("DATA SECURED - get to the EVAC point!", Palette.YELLOW)
	Sfx.play("objective", 0.0)
	camera.shake(0.3)


## Routes a completed core hack to the right objective logic.
func on_core_hacked(core: DataCore) -> void:
	match core.role:
		"data":
			on_data_stolen()
		"shard":
			var done := _count_cores("shard", true)
			var total := _count_cores("shard", false)
			if done >= total:
				on_data_stolen()
			else:
				notify("SHARD %d/%d SECURED" % [done, total], Palette.YELLOW)
				Sfx.play("objective", -2.0, 0.9)
				alarm.raise_caution(core.global_position)
		"uplink":
			var done_u := _count_cores("uplink", true)
			var total_u := _count_cores("uplink", false)
			Sfx.play("objective", -2.0, 0.9)
			if done_u >= total_u:
				for d in vault_doors:
					d.sealed = false
					d.complete_hack()
				notify("UPLINKS BREACHED - THE CORE IS OPEN  (checkpoint saved)", Palette.CYAN)
				if String(def.get("mode", "")) == "campaign":
					GameState.finale_checkpoint = true
					GameState.save_game()
				alarm.raise_caution(core.global_position)
			else:
				notify("UPLINK %d/%d BREACHED" % [done_u, total_u], Palette.CYAN)
		"archive":
			Sfx.play("objective", 0.0, 0.7)
			hud.show_story(Campaign.TRUTH_TITLE, Campaign.TRUTH_TEXT, _begin_lockdown)


func _count_cores(role: String, only_done: bool) -> int:
	var n := 0
	for c in cores:
		if c.role == role and (c.hacked_done or not only_done):
			n += 1
	return n


func _begin_lockdown() -> void:
	if mission_over:
		return
	lockdown = true
	on_data_stolen()
	alarm.lockdown = true
	alarm.raise_alarm(player.global_position, "CRADLE LOCKDOWN")
	alarm.reinforce_timer = 3.0
	notify("LOCKDOWN - ESCAPE TO THE ROOF!", Palette.RED)
	Sfx.play_music("boss")


func on_boss_defeated(_b: EnemyWarden) -> void:
	boss_defeated = true
	hud.hide_boss()
	for d in vault_doors:
		d.force_open()
	data_core.sealed = false
	notify("WARDEN DESTROYED - the archive is open", Palette.MAGENTA)
	Sfx.play_music("music")
	Engine.time_scale = 0.3
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func():
		if not mission_over:
			Engine.time_scale = 1.0)


func on_body_found(pos: Vector2) -> void:
	bodies_found += 1
	alarm.raise_caution(pos)
	notify("A BODY WAS FOUND - security on caution", Palette.ORANGE)


func read_intel(id: int) -> void:
	GameState.collect_intel(id)
	var data: Dictionary = Campaign.INTEL[id]
	Sfx.play("intel", -2.0)
	hud.show_story("INTEL %02d - %s" % [id + 1, data["title"]], String(data["text"]), Callable())


func objectives() -> Array:
	var out := []
	var objective := String(def.get("objective", "data"))
	match objective:
		"shards":
			var done := _count_cores("shard", true)
			var total := _count_cores("shard", false)
			out.append({"text": "Download every data core (%d/%d)" % [done, total], "done": has_data})
		"final":
			var up := _count_cores("uplink", true)
			var up_total := _count_cores("uplink", false)
			out.append({"text": "Breach the security uplinks (%d/%d)" % [up, up_total], "done": up >= up_total})
			out.append({"text": "Destroy the WARDEN", "done": boss_defeated, "active": up >= up_total})
			out.append({"text": "Download the LULLABY archive", "done": has_data, "active": boss_defeated})
		_:
			out.append({"text": "Download %s" % def["target"], "done": has_data})
	out.append({"text": "Escape to the EVAC point" if lockdown else "Reach the EVAC point", "done": false, "active": has_data})
	out.append({"text": "Optional: stay undetected", "done": alarm.times_raised == 0, "optional": true, "failed": alarm.times_raised > 0})
	return out


## Positions the HUD should point at (pending objectives, else EVAC).
func objective_positions() -> Array:
	if has_data:
		return [extraction.global_position]
	var out := []
	if boss != null and not boss_defeated and _count_cores("uplink", true) >= _count_cores("uplink", false):
		out.append(boss.global_position)
		return out
	for c in cores:
		if not c.hacked_done and not c.sealed:
			out.append(c.global_position)
	if out.is_empty() and data_core != null:
		out.append(data_core.global_position)
	return out


## Nearest pending objective (used for the main HUD marker).
func objective_position() -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for pos in objective_positions():
		var d: float = player.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = pos
	return best


func _on_alarm_level_changed(level: int) -> void:
	match level:
		AlarmSystem.Level.ALARM:
			Sfx.set_music_pitch(1.12)
			camera.shake(0.3)
		AlarmSystem.Level.CAUTION:
			Sfx.set_music_pitch(1.05)
		_:
			Sfx.set_music_pitch(1.0)


# --------------------------------------------------------------------------
# End states
# --------------------------------------------------------------------------

func complete_mission() -> void:
	if mission_over:
		return
	mission_over = true
	hud.abort_hack()
	var base := int(def["reward"])
	var ghost := alarm.times_raised == 0
	var ghost_bonus := int(base * 0.5) if ghost else 0
	var takedown_bonus := takedowns * 10
	var penalty_ratio := minf(float(def.get("alarm_penalty", 0.15)) * alarm.times_raised, 0.45)
	if lockdown:
		penalty_ratio = 0.0  # The final escape alarm is scripted.
	var alarm_penalty := int(base * penalty_ratio)
	var result := {
		"mission": def["name"],
		"index": def["index"],
		"time": mission_time,
		"kills": kills,
		"takedowns": takedowns,
		"alarms": alarm.times_raised,
		"base": base,
		"found": credits_found,
		"ghost": ghost,
		"ghost_bonus": ghost_bonus,
		"takedown_bonus": takedown_bonus,
		"alarm_penalty": alarm_penalty,
		"final": bool(def.get("final", false)),
		"mode": String(def.get("mode", "campaign")),
		"total": base - alarm_penalty + credits_found + ghost_bonus + takedown_bonus,
	}
	GameState.complete_mission(result)
	Sfx.stop_music()
	Sfx.play("mission_complete")
	FX.ring(fx_layer, player.global_position, Palette.GREEN, 300.0, 1.0, 4.0)
	player.locked = true
	Engine.time_scale = 1.0
	end_screen.show_victory(result)


func _on_player_died() -> void:
	if mission_over:
		return
	mission_over = true
	hud.abort_hack()
	GameState.register_death(kills)
	Sfx.stop_music()
	Engine.time_scale = 0.35
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
		end_screen.show_defeat({"time": mission_time, "kills": kills, "mission": def["name"]}))


func restart_mission() -> void:
	Transition.reload_scene()


func go_to_hideout() -> void:
	Transition.change_scene("res://scenes/hideout.tscn")


func go_to_menu() -> void:
	Transition.change_scene("res://scenes/main_menu.tscn")


func go_to_ending() -> void:
	Transition.change_scene("res://scenes/ending.tscn")
