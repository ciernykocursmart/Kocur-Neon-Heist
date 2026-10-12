extends Node
## Audio autoload: pooled sound effects with rate limiting, and cross-faded
## looping music on the "Music" bus. All streams live in res://assets/audio
## and were synthesised by tools/gen_audio.py.

const SFX_NAMES := ["claw", "hit", "pounce", "jump", "land", "hurt", "death", "enemy_hurt", "enemy_die", "swing",
	"warn", "arrow", "magic", "fire", "ice", "roar", "boss_roar", "slam", "phase", "coin", "gem", "heal",
	"checkpoint", "secret", "meow", "rescue", "complete", "door", "chest", "lever", "spring", "crumble", "shield",
	"buy", "ui_move", "ui_ok", "ui_back", "denied"]
const MUSIC_NAMES := ["menu", "camp", "r1", "r2", "r3", "r4", "r5", "boss", "final", "victory"]
const POOL_SIZE := 16
const MIN_INTERVAL := 0.05
const MAX_SAME := 3
const FADE_TIME := 0.8

var streams := {}
var music_streams := {}
var current_music := ""
var _pool: Array[AudioStreamPlayer] = []
var _last_play := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _fade_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	for n: String in SFX_NAMES:
		var s: AudioStream = load("res://assets/audio/%s.wav" % n)
		if s:
			streams[n] = s


func _music_stream(track: String) -> AudioStream:
	if music_streams.has(track):
		return music_streams[track]
	var s: AudioStream = load("res://assets/audio/music_%s.wav" % track)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	if s:
		music_streams[track] = s
	return s


func play(sound: String, volume_db := 0.0, pitch_var := 0.05) -> void:
	if not streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sound, -1.0)) < MIN_INTERVAL:
		return
	var same := 0
	for p in _pool:
		if p.playing and p.stream == streams[sound]:
			same += 1
	if same >= MAX_SAME:
		return
	_last_play[sound] = now
	var player := _free_player()
	player.stream = streams[sound]
	player.volume_db = volume_db - 2.0 * same
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	player.play()


func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	# Steal the player that has been running longest.
	var best := _pool[0]
	for p in _pool:
		if p.get_playback_position() > best.get_playback_position():
			best = p
	return best


func play_music(track: String, fade := FADE_TIME) -> void:
	if track == current_music and (_music_a.playing or _music_b.playing):
		return
	var s := _music_stream(track)
	if s == null:
		return
	current_music = track
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	new.stream = s
	new.volume_db = -40.0
	new.play()
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(new, "volume_db", 0.0, fade)
	if old.playing:
		_fade_tween.tween_property(old, "volume_db", -40.0, fade)
		_fade_tween.chain().tween_callback(old.stop)


func stop_music(fade := 0.5) -> void:
	current_music = ""
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	for m in [_music_a, _music_b]:
		if m.playing:
			_fade_tween.tween_property(m, "volume_db", -40.0, fade)
	_fade_tween.chain().tween_callback(func() -> void:
		_music_a.stop()
		_music_b.stop())


func is_music_playing() -> bool:
	return _music_a.playing or _music_b.playing


func playing_music_count() -> int:
	return int(_music_a.playing) + int(_music_b.playing)
