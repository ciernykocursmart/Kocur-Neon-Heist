class_name Race
extends Node3D
## Race manager: builds the circuit, karts, camera and UI for one race and
## runs the rules - countdown, ordered checkpoints, laps, timing, positions,
## wrong-way detection, falls and recovery, finish and results.
##
## Configuration (Game.race_config or configure()):
##   track, mode ("grand_prix" | "single" | "time_trial"), laps, difficulty,
##   player {racer, kart, paint, wheels, accessory}, rivals [racer ids],
##   grid_slot, autopilot (tests/attract), seed, ui (bool).

signal countdown_tick(value: int)
signal race_started
signal lap_completed(entry: RaceEntry, lap: int, time: float, best: bool)
signal final_lap(entry: RaceEntry)
signal kart_finished(entry: RaceEntry)
signal race_over(results: Dictionary)
signal wrong_way_changed(active: bool)

enum State { COUNTDOWN, RACING, FINISHING, RESULTS }

const COUNTDOWN_TIME := 4.0   ## 1 s settle, then 3, 2, 1, GO
const AFTER_PLAYER_FINISH := 12.0
const MAX_RACE_TIME := 900.0

var cfg := {}
var state := State.COUNTDOWN
var track: Track
var camera: ChaseCamera
var entries: Array[RaceEntry] = []
var player: RaceEntry
var laps := 3
var mode := "single"
var race_time := 0.0
var countdown := COUNTDOWN_TIME
var finish_order: Array[RaceEntry] = []
var results := {}
var hud: Node
var _last_tick := 4
var _player_finish_time := -1.0
var _accel_pressed_at := -1.0
var _wrong_way := false
var _start_seed := 1
var _player_input := PlayerInput.new()
var ghost: GhostRecorder


func configure(c: Dictionary) -> void:
	cfg = c


func _ready() -> void:
	process_physics_priority = 100   # run after all karts each tick
	if cfg.is_empty():
		cfg = Game.race_config.duplicate(true)
	mode = String(cfg.get("mode", "single"))
	laps = int(cfg.get("laps", 3))
	_start_seed = int(cfg.get("seed", 1))
	_build()


func _build() -> void:
	var def := TrackCatalog.get_track(String(cfg.get("track", "whiskerwood")))
	track = Track.new()
	track.name = "Track"
	track.decorate = bool(cfg.get("decorate", true))
	add_child(track)
	track.setup(def)
	RaceEnvironment.apply(self, track.theme)
	_spawn_karts()
	camera = ChaseCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.current = true
	camera.sensitivity = float(Settings.get_value("camera_sensitivity", 1.0))
	camera.distance_scale = float(Settings.get_value("camera_distance", 1.0))
	camera.follow(player.kart)
	if bool(cfg.get("ui", true)):
		hud = preload("res://scripts/ui/hud.gd").new()
		hud.name = "HUD"
		add_child(hud)
		hud.setup(self)
		var pause := preload("res://scripts/ui/pause_menu.gd").new()
		pause.name = "PauseMenu"
		add_child(pause)
		pause.setup(self)
	var ra := RaceAudio.new()
	ra.name = "RaceAudio"
	add_child(ra)
	ra.setup(self)
	if mode == "time_trial":
		ghost = GhostRecorder.new()
		ghost.name = "Ghost"
		add_child(ghost)
		ghost.setup(self)
	track.reset_race_time()
	_set_lamps(0)


func _spawn_karts() -> void:
	var papp: Dictionary = cfg.get("player", {"racer": "kocur", "kart": "alley", "paint": "crimson"})
	var rivals: Array = cfg.get("rivals", [])
	if mode == "time_trial":
		rivals = []
	elif rivals.is_empty():
		rivals = default_rivals(String(papp.get("racer", "kocur")), 5)
	var total := rivals.size() + 1
	var player_slot := int(cfg.get("grid_slot", total - 1))
	player_slot = clampi(player_slot, 0, total - 1)
	var difficulty := String(cfg.get("difficulty", "normal"))
	var ai_index := 0
	var slots := []
	for i in total:
		slots.append(i)
	var grid_order: Array = cfg.get("grid_order", [])
	for slot in total:
		var is_player := slot == player_slot
		var kart: Kart
		if is_player:
			kart = KartFactory.create(papp, true)
			if bool(cfg.get("autopilot", false)):
				kart.controller = AIDriver.new(String(cfg.get("autopilot_difficulty", "hard")), {"pace": 1.0, "consistency": 1.0, "drift": 1.0, "aggression": 0.5}, _start_seed * 31 + 7)
			else:
				kart.controller = _player_input
		else:
			var rid: String = rivals[ai_index] if grid_order.is_empty() else grid_order[ai_index]
			ai_index += 1
			var pers: Dictionary = Catalog.RIVALS.get(rid, Catalog.RIVALS["pepper"])
			kart = KartFactory.create({"racer": rid, "kart": pers["kart"], "paint": pers["paint"],
				"wheels": "sport" if difficulty == "hard" else "classic", "accessory": "none"})
			var ai := AIDriver.new(difficulty, pers, hash(rid) % 9973 + _start_seed * 101)
			kart.controller = ai
		kart.track = track
		add_child(kart)
		kart.place(track.grid_transform(slot))
		var e := RaceEntry.new()
		e.setup(kart, track.checkpoints.size())
		e.position = slot + 1
		entries.append(e)
		if is_player:
			player = e
	for e in entries:
		if e.kart.controller is AIDriver:
			e.kart.controller.others = entries.map(func(x): return x.kart)


static func default_rivals(player_racer: String, count: int) -> Array:
	var pool := ["kocur", "marmalade", "duchess", "tux", "sushi", "ziggy", "pepper", "biscuit"]
	pool.erase(player_racer)
	return pool.slice(0, count)


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown(delta)
		State.RACING, State.FINISHING:
			race_time += delta
			track.advance(delta)
			_update_entries(delta)
			_update_positions()
			if state == State.FINISHING:
				_check_end()
			elif race_time > MAX_RACE_TIME:
				_end_race()


func _countdown(delta: float) -> void:
	countdown -= delta
	var tick := mini(int(ceil(countdown)), 3)
	if countdown <= 3.0 and tick < _last_tick and tick > 0:
		_last_tick = tick
		countdown_tick.emit(tick)
		_set_lamps(4 - tick)
	# Start technique: press accelerate during "1" for a boost; flooring it
	# while "3" is still showing causes a short wheelspin.
	if player.kart.controller is PlayerInput:
		var accel_down := Input.get_action_strength("accelerate") > 0.5
		if accel_down and _accel_pressed_at < 0.0:
			_accel_pressed_at = countdown
		elif not accel_down:
			_accel_pressed_at = -1.0
	if countdown <= 0.0:
		_start_race()


func _start_race() -> void:
	state = State.RACING
	race_time = 0.0
	_set_lamps(4)
	countdown_tick.emit(0)
	for e in entries:
		e.kart.control_enabled = true
		e.lap_start = 0.0
		if e.kart.controller is AIDriver:
			if e.kart.controller.wants_start_boost:
				e.kart.give_boost(Kart.START_BOOST_TIME * 0.8, &"start")
	if player.kart.controller is PlayerInput and _accel_pressed_at >= 0.0:
		if _accel_pressed_at <= 1.0:
			player.kart.give_boost(Kart.START_BOOST_TIME, &"start")
			if hud:
				hud.flash("PERFECT START!", Color(1.0, 0.85, 0.2))
		elif _accel_pressed_at > 2.0:
			player.kart.stall_time = 0.7
			if hud:
				hud.flash("WHEELSPIN!", Color(1.0, 0.5, 0.3))
	race_started.emit()


func _update_entries(delta: float) -> void:
	for e in entries:
		var k := e.kart
		e.recover_cooldown = maxf(e.recover_cooldown - delta, 0.0)
		var s_rate := track.s_delta(e.prev_s, k.loc.s) / maxf(delta, 0.001)
		if not e.finished:
			_update_progress(e)
		# Falls and leaving the circuit.
		var fell := k.global_position.y < track.kill_y or k.loc.height < -7.0 or (k.loc.in_gap and k.loc.height < -3.5)
		if k.loc.off_track:
			e.off_track_time += delta
		else:
			e.off_track_time = 0.0
		var wants := false
		if k.controller is AIDriver and k.controller.recover_requested:
			k.controller.recover_requested = false
			wants = true
		if e == player and k.controller is PlayerInput and Input.is_action_just_pressed("recover") and e.recover_cooldown <= 0.0:
			wants = true
		if fell or e.off_track_time > 1.6 or wants:
			_recover(e)
		# Wrong way: progress running backwards for over a second.
		if e == player and not e.finished:
			if s_rate < -2.5 and k.ghost_time <= 0.0:
				e.wrong_way_time += delta
			else:
				e.wrong_way_time = maxf(e.wrong_way_time - delta * 2.0, 0.0)
			var ww := e.wrong_way_time > 1.0
			if ww != _wrong_way:
				_wrong_way = ww
				wrong_way_changed.emit(ww)


func _recover(e: RaceEntry) -> void:
	e.recover_cooldown = 2.0
	e.off_track_time = 0.0
	e.kart.recover()
	if e.kart.controller is AIDriver:
		e.kart.controller.reset()
	e.prev_s = e.kart.loc.s
	if e == player and camera:
		camera.snap()


func _update_progress(e: RaceEntry) -> void:
	var s := e.kart.loc.s
	var ds := track.s_delta(e.prev_s, s)
	if absf(ds) > 60.0:
		e.prev_s = s
		return
	var cps := track.checkpoints
	var n := cps.size()
	var guard := 0
	while guard < n:
		guard += 1
		var c := cps[e.next_cp]
		var to_c := track.s_delta(e.prev_s, c)
		if ds > 0.0 and to_c > 0.0 and to_c <= ds:
			if e.next_cp == 0:
				_cross_finish(e)
				if e.finished:
					return
			e.next_cp = (e.next_cp + 1) % n
		else:
			break
	var prev_cp := (e.next_cp - 1 + n) % n
	var c2 := cps[prev_cp]
	if ds < 0.0 and track.s_delta(c2, e.prev_s) >= 0.0 and track.s_delta(c2, s) < 0.0:
		e.next_cp = prev_cp
		if prev_cp == 0:
			_undo_finish(e)
	e.prev_s = s


func _cross_finish(e: RaceEntry) -> void:
	if e.lap == 0:
		e.lap = 1
		return
	var t := race_time - e.lap_start
	e.lap_times.append(t)
	e.lap_start = race_time
	var best := t < e.best_lap
	if best:
		e.best_lap = t
	e.lap += 1
	lap_completed.emit(e, e.lap - 1, t, best)
	if e.lap > laps:
		e.lap = laps
		_finish(e)
	elif e.lap == laps:
		final_lap.emit(e)


func _undo_finish(e: RaceEntry) -> void:
	if e.lap <= 1:
		e.lap = 0
		return
	e.lap -= 1
	if not e.lap_times.is_empty():
		var t: float = e.lap_times.pop_back()
		e.lap_start -= t
		e.best_lap = INF
		for lt in e.lap_times:
			e.best_lap = minf(e.best_lap, lt)


func _finish(e: RaceEntry) -> void:
	e.finished = true
	e.finish_time = race_time
	finish_order.append(e)
	kart_finished.emit(e)
	if e == player:
		_player_finish_time = race_time
		state = State.FINISHING
		# Cruise on autopilot after the flag.
		e.kart.controller = AIDriver.new("normal", {"pace": 0.9, "consistency": 1.0, "drift": 0.0, "aggression": 0.2}, 5)
		e.kart.controller.others = entries.map(func(x): return x.kart)


func _update_positions() -> void:
	var L := track.length
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: RaceEntry, b: RaceEntry):
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.progress(L) > b.progress(L))
	for i in sorted.size():
		sorted[i].position = i + 1


func _check_end() -> void:
	var all_done := true
	for e in entries:
		if not e.finished:
			all_done = false
	if all_done or race_time - _player_finish_time > AFTER_PLAYER_FINISH:
		_end_race()


func _end_race() -> void:
	if state == State.RESULTS:
		return
	# Remaining karts get a finish time extrapolated from their own pace.
	var L := track.length
	for e in entries:
		if e.finished:
			continue
		var done := maxf(e.progress(L), 1.0)
		var remaining := laps * L - done
		var pace := done / maxf(race_time, 1.0)
		e.finish_time = race_time + remaining / maxf(pace, 5.0)
		e.estimated = true
		e.finished = true
		if e.best_lap == INF:
			e.best_lap = e.finish_time / laps
	_update_positions()
	state = State.RESULTS
	results = _build_results()
	race_over.emit(results)
	var summary: Dictionary = Game.on_race_over(self, results)
	if bool(cfg.get("ui", true)):
		await get_tree().create_timer(1.6).timeout
		if not is_inside_tree():
			return
		var rs := preload("res://scripts/ui/results_screen.gd").new()
		rs.name = "Results"
		add_child(rs)
		rs.setup(self, summary)


func _build_results() -> Dictionary:
	var order := entries.duplicate()
	order.sort_custom(func(a: RaceEntry, b: RaceEntry): return a.position < b.position)
	var rows := []
	for e in order:
		rows.append({"racer": e.kart.racer_id, "name": e.kart.display_name, "player": e == player,
			"time": e.finish_time, "best_lap": e.best_lap, "estimated": e.estimated, "position": e.position})
	return {"track": track.def["id"], "mode": mode, "laps": laps, "difficulty": cfg.get("difficulty", "normal"),
		"rows": rows, "player_position": player.position, "player_time": player.finish_time,
		"player_best_lap": player.best_lap, "player_laps": player.lap_times.duplicate(),
		"valid": player.finished and not player.estimated and player.lap_times.size() == laps}


func _set_lamps(lit: int) -> void:
	var lamps := track.get_node_or_null("StartLamps")
	if lamps == null:
		return
	for k in 4:
		var lamp: MeshInstance3D = lamps.get_node("Lamp%d" % k)
		var mat: StandardMaterial3D = lamp.material_override
		if lit >= 4:
			mat.emission = Color(0.2, 1.0, 0.3) * 3.0
		elif k < lit:
			mat.emission = Color(1.0, 0.15, 0.1) * 3.0
		else:
			mat.emission = Color(0, 0, 0)


## Restart the same race from scratch (clean scene reload).
func restart() -> void:
	Game.restart_race()
