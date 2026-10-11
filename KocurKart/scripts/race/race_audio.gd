class_name RaceAudio
extends Node
## Race sound: engine loops whose pitch follows speed (player in 2D, rivals
## positional), tyre squeal while drifting or sliding, and one-shots for
## every driving and race event. Everything here is freed with the race.

var race: Race
var _player_engine: AudioStreamPlayer
var _player_drift: AudioStreamPlayer
var _engines := {}          ## Kart -> AudioStreamPlayer3D
var _pitch := {}
var _ww_timer := 0.0
var _wrong := false


func setup(r: Race) -> void:
	race = r
	_player_engine = AudioStreamPlayer.new()
	_player_engine.bus = "SFX"
	_player_engine.stream = Audio.streams.get("engine")
	_player_engine.volume_db = -9.0
	add_child(_player_engine)
	_player_drift = AudioStreamPlayer.new()
	_player_drift.bus = "SFX"
	_player_drift.stream = Audio.streams.get("drift")
	_player_drift.volume_db = -60.0
	add_child(_player_drift)
	for e in race.entries:
		var k := e.kart
		if e == race.player:
			_connect_player(k)
		else:
			var p := AudioStreamPlayer3D.new()
			p.bus = "SFX"
			p.stream = Audio.streams.get("engine")
			p.unit_size = 5.0
			p.max_distance = 70.0
			p.volume_db = -8.0
			k.add_child(p)
			_engines[k] = p
			k.kart_bumped.connect(func(_o, imp): if imp > 4.0: Audio.play_at("bump", k.global_position, -6.0))
			k.hazard_hit.connect(func(): Audio.play_at("hazard", k.global_position, -4.0))
			k.boost_started.connect(func(kind): if kind == &"purr" or kind == &"drift2": Audio.play_at("boost_big", k.global_position, -10.0))
		_pitch[k] = 0.6
	race.countdown_tick.connect(func(v): Audio.play("count" if v > 0 else "go"))
	race.lap_completed.connect(_on_lap)
	race.final_lap.connect(func(e): if e == race.player: Audio.play("final_lap"))
	race.kart_finished.connect(func(e):
		if e == race.player:
			Audio.play("finish")
			Audio.play("cheer", -4.0))
	race.wrong_way_changed.connect(func(a): _wrong = a)
	var th := race.track.theme
	Audio.play_music(String(th.get("music", "woods")))
	Audio.play_ambience(String(th.get("ambience", "")))
	if Audio.streams.has("engine"):
		_player_engine.play()
		for k in _engines:
			_engines[k].play()
		_player_drift.play()


func _connect_player(k: Kart) -> void:
	k.drift_level_changed.connect(func(l): if l > 0: Audio.play("spark%d" % l, -4.0))
	k.boost_started.connect(_on_player_boost)
	k.jumped.connect(func(): Audio.play("jump", -4.0))
	k.landed.connect(func(imp): Audio.play("land", clampf(-14.0 + imp * 0.8, -14.0, 0.0)))
	k.wall_hit.connect(func(imp): Audio.play("wall", clampf(-16.0 + imp * 0.9, -16.0, 0.0), randf_range(0.9, 1.1)))
	k.kart_bumped.connect(func(_o, imp): Audio.play("bump", clampf(-12.0 + imp * 0.8, -12.0, 0.0)))
	k.hazard_hit.connect(func(): Audio.play("hazard"))
	k.recovered.connect(func(): Audio.play("respawn", -4.0))


const BOOST_SOUNDS := {"drift1": ["boost_small", -3.0], "drift2": ["boost_big", -1.0], "purr": ["boost_purr", 0.0],
	"pad": ["pad", -2.0], "start": ["boost_small", 0.0]}


func _on_player_boost(kind: StringName) -> void:
	var snd: Array = BOOST_SOUNDS.get(String(kind), [])
	if not snd.is_empty():
		Audio.play(snd[0], snd[1])


func _on_lap(e: RaceEntry, lap: int, _t: float, best: bool) -> void:
	if e != race.player or lap >= race.laps:
		return
	Audio.play("record" if best and lap > 1 else "lap", -2.0)


func _process(delta: float) -> void:
	if race == null:
		return
	var k := race.player.kart
	_update_engine(k, delta, _player_engine, true)
	for kk in _engines:
		if is_instance_valid(kk):
			_update_engine(kk, delta, null, false)
	# Tyre squeal: drifting, sliding sideways or scrabbling on ice.
	var squeal := 0.0
	if k.is_on_floor():
		if k.drifting:
			squeal = 1.0
		elif absf(k.lateral_speed) > 4.0:
			squeal = clampf((absf(k.lateral_speed) - 4.0) / 6.0, 0.0, 1.0)
	var target_db := lerpf(-60.0, -11.0, squeal) if squeal > 0.01 else -60.0
	_player_drift.volume_db = lerpf(_player_drift.volume_db, target_db, clampf(delta * 12.0, 0.0, 1.0))
	_player_drift.pitch_scale = 0.9 + 0.2 * k.drift_level
	if _wrong and race.state == Race.State.RACING:
		_ww_timer -= delta
		if _ww_timer <= 0.0:
			_ww_timer = 1.0
			Audio.play("wrong_way", -6.0)


func _update_engine(k: Kart, delta: float, p2: AudioStreamPlayer, is_player: bool) -> void:
	var top := k.top_speed()
	var target := 0.55 + 1.05 * clampf(absf(k.forward_speed) / top, 0.0, 1.4)
	if race.state == Race.State.COUNTDOWN and is_player and Input.get_action_strength("accelerate") > 0.5:
		target = 1.25   # revving on the grid
	if k.boost_time > 0.0:
		target += 0.12
	if not k.is_on_floor():
		target += 0.15   # wheels spin free in the air
	var cur: float = _pitch.get(k, 0.6)
	cur = lerpf(cur, target, clampf(delta * 6.0, 0.0, 1.0))
	_pitch[k] = cur
	if p2:
		p2.pitch_scale = cur
		p2.volume_db = -11.0 + clampf(k.throttle, 0.0, 1.0) * 3.0
	elif _engines.has(k):
		_engines[k].pitch_scale = cur * 0.97
