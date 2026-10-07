extends Node
## Audio manager (autoload "Sfx").
##
## Every sound effect and the ambient music loop are synthesised at startup
## into AudioStreamWAV resources, so the project ships with no third-party
## audio at all. Playback uses small pools of players (UI/global and 2D
## positional) routed to the "SFX" and "Music" buses.

const MIX_RATE := 22050
const POOL_SIZE := 12
const POOL_2D_SIZE := 20
const MIN_REPEAT := 0.035

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_i := 0
var _pool_2d_i := 0
var _last_played := {}
var _music: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in POOL_2D_SIZE:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = 1500.0
		p2.attenuation = 1.4
		add_child(p2)
		_pool_2d.append(p2)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_build_all()


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

func play(sound: String, volume_db := 0.0, pitch := 1.0, pitch_var := 0.04) -> void:
	if not _allow(sound):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


func play_at(sound: String, pos: Vector2, volume_db := 0.0, pitch := 1.0, pitch_var := 0.06) -> void:
	if not _allow(sound):
		return
	var p := _pool_2d[_pool_2d_i]
	_pool_2d_i = (_pool_2d_i + 1) % _pool_2d.size()
	p.stream = streams[sound]
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


func play_music(sound := "music") -> void:
	if not streams.has(sound):
		return
	if _music.stream == streams[sound] and _music.playing:
		return
	_music.stream = streams[sound]
	_music.volume_db = -4.0
	_music.play()


func stop_music() -> void:
	_music.stop()


func set_music_pitch(pitch: float) -> void:
	_music.pitch_scale = pitch


func _allow(sound: String) -> bool:
	if not streams.has(sound):
		push_warning("Unknown sound: %s" % sound)
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < MIN_REPEAT:
		return false
	_last_played[sound] = now
	return true


# --------------------------------------------------------------------------
# Synthesis
# --------------------------------------------------------------------------

func _build_all() -> void:
	var s: PackedFloat32Array

	# Player blaster: bright square chirp + noise crack.
	s = _tone(0.13, 1500.0, 170.0, "square", 0.28, 0.002, 2.6)
	_mix(s, _noise(0.06, 0.45, 0.55), 0.0)
	streams["shoot"] = _wav(s)

	# Enemy rifle: lower saw chirp.
	s = _tone(0.16, 650.0, 110.0, "saw", 0.26, 0.002, 2.2)
	_mix(s, _noise(0.07, 0.4, 0.35), 0.0)
	streams["enemy_shoot"] = _wav(s)

	# Reload: mag out click, slide, mag in click.
	s = _silence(0.42)
	_mix(s, _noise(0.03, 0.5, 0.9), 0.0)
	_mix(s, _tone(0.12, 260.0, 520.0, "square", 0.12, 0.01, 1.0), 0.08)
	_mix(s, _noise(0.035, 0.6, 0.95), 0.33)
	_mix(s, _tone(0.05, 1200.0, 900.0, "square", 0.15, 0.001, 2.0), 0.34)
	streams["reload"] = _wav(s)

	streams["empty"] = _wav(_tone(0.05, 1800.0, 1500.0, "square", 0.14, 0.001, 3.0))
	streams["hit_wall"] = _wav(_noise(0.06, 0.35, 0.8))

	s = _tone(0.09, 1900.0, 800.0, "tri", 0.35, 0.001, 2.0)
	_mix(s, _noise(0.05, 0.3, 0.6), 0.0)
	streams["enemy_hit"] = _wav(s)

	s = _tone(0.28, 240.0, 80.0, "square", 0.3, 0.002, 1.6)
	_mix(s, _noise(0.15, 0.45, 0.2), 0.0)
	streams["player_hurt"] = _wav(s)

	s = _noise(0.65, 0.7, 0.07)
	_mix(s, _tone(0.6, 110.0, 35.0, "sine", 0.7, 0.003, 1.4), 0.0)
	streams["explode"] = _wav(s)

	s = _tone(0.08, 880.0, 880.0, "square", 0.22, 0.002, 0.6)
	_mix(s, _tone(0.16, 1320.0, 1320.0, "square", 0.24, 0.002, 1.2), 0.085)
	streams["detect"] = _wav(s)

	streams["suspicious"] = _wav(_tone(0.18, 620.0, 780.0, "tri", 0.3, 0.01, 1.4))
	streams["alarm"] = _wav(_siren(1.0))

	streams["hack_tick"] = _wav(_tone(0.035, 2100.0, 2100.0, "square", 0.1, 0.001, 2.0))
	streams["hack_hit"] = _wav(_tone(0.11, 1100.0, 1900.0, "square", 0.2, 0.002, 1.5))
	s = _silence(0.4)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_mix(s, _tone(0.12, notes[i], notes[i], "square", 0.18, 0.002, 1.8), i * 0.065)
	streams["hack_success"] = _wav(s)
	s = _tone(0.38, 180.0, 95.0, "saw", 0.3, 0.003, 1.2)
	_mix(s, _tone(0.38, 186.0, 98.0, "square", 0.15, 0.003, 1.2), 0.0)
	streams["hack_fail"] = _wav(s)
	streams["hack_miss"] = _wav(_tone(0.16, 300.0, 160.0, "square", 0.22, 0.002, 1.5))

	s = _tone(0.09, 987.77, 987.77, "tri", 0.3, 0.002, 1.5)
	_mix(s, _tone(0.16, 1318.5, 1318.5, "tri", 0.3, 0.002, 1.8), 0.06)
	streams["pickup"] = _wav(s)
	s = _tone(0.07, 1567.98, 1567.98, "square", 0.14, 0.002, 1.5)
	_mix(s, _tone(0.14, 2093.0, 2093.0, "square", 0.14, 0.002, 1.8), 0.05)
	streams["credits"] = _wav(s)

	s = _silence(1.5)
	var jingle := [392.0, 523.25, 659.25, 783.99, 659.25, 1046.5]
	for i in jingle.size():
		var length := 0.6 if i == jingle.size() - 1 else 0.16
		_mix(s, _tone(length, jingle[i], jingle[i], "square", 0.16, 0.003, 1.3), i * 0.13)
		_mix(s, _tone(length, jingle[i] * 0.5, jingle[i] * 0.5, "tri", 0.2, 0.003, 1.3), i * 0.13)
	streams["mission_complete"] = _wav(s)

	s = _tone(1.1, 520.0, 55.0, "saw", 0.3, 0.003, 1.1)
	_mix(s, _noise(0.5, 0.4, 0.15), 0.0)
	streams["game_over"] = _wav(s)

	streams["dash"] = _wav(_noise_sweep(0.2, 0.08, 0.6, 0.35))
	s = _noise_sweep(0.12, 0.7, 0.2, 0.32)
	_mix(s, _tone(0.08, 2400.0, 900.0, "tri", 0.12, 0.001, 2.0), 0.0)
	streams["claw"] = _wav(s)
	s = _noise(0.45, 0.25, 0.08)
	_mix(s, _tone(0.4, 140.0, 70.0, "square", 0.12, 0.01, 1.0), 0.0)
	streams["door"] = _wav(s)
	streams["ui_click"] = _wav(_tone(0.045, 1500.0, 1300.0, "square", 0.14, 0.001, 2.0))
	streams["ui_hover"] = _wav(_tone(0.03, 2600.0, 2600.0, "sine", 0.08, 0.001, 2.0))
	streams["warp"] = _wav(_tone(0.5, 120.0, 1400.0, "saw", 0.16, 0.05, 0.8))
	streams["denied"] = _wav(_tone(0.2, 220.0, 220.0, "square", 0.16, 0.002, 0.8))
	streams["footstep"] = _wav(_noise(0.04, 0.2, 0.25))

	streams["music"] = _music_loop()


func _silence(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(duration * MIX_RATE))
	out.fill(0.0)
	return out


## Single oscillator with an exponential pitch sweep and attack/decay envelope.
func _tone(duration: float, f0: float, f1: float, wave: String, volume: float, attack: float, decay_pow: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq := f0 * pow(f1 / f0, t)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if phase < 0.5 else -1.0
			"saw":
				v = phase * 2.0 - 1.0
			"tri":
				v = 4.0 * absf(phase - 0.5) - 1.0
			_:
				v = sin(phase * TAU)
		var time := float(i) / MIX_RATE
		var env := minf(1.0, time / maxf(attack, 0.0001)) * pow(1.0 - t, decay_pow)
		out[i] = v * env * volume
	return out


## Low-passed white noise burst. `cutoff` in 0..1 (one-pole coefficient).
func _noise(duration: float, volume: float, cutoff: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += cutoff * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * volume * pow(1.0 - t, 1.6)
	return out


## Noise with a moving filter cutoff — used for whooshes.
func _noise_sweep(duration: float, c0: float, c1: float, volume: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var c := lerpf(c0, c1, t)
		y += c * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * volume * sin(t * PI)
	return out


func _siren(duration: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq := 640.0 + 320.0 * sin(t * PI)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var v := (4.0 * absf(phase - 0.5) - 1.0) * 0.6 + (1.0 if phase < 0.5 else -1.0) * 0.15
		out[i] = v * 0.32 * minf(1.0, t * 20.0) * minf(1.0, (1.0 - t) * 10.0)
	return out


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, offset_sec: float, gain := 1.0) -> void:
	var off := int(offset_sec * MIX_RATE)
	for i in src.size():
		var j := off + i
		if j >= dst.size():
			break
		dst[j] += src[i] * gain


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## 8-second minor-key synthwave loop: pulsing bass, soft pad and hi-hats.
func _music_loop() -> AudioStreamWAV:
	var bpm := 96.0
	var beat := 60.0 / bpm
	var bars := 4
	var duration := beat * 4.0 * bars
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Chord roots (Hz) per bar: Am - F - C - G (bass octave).
	var roots := [55.0, 43.65, 65.41, 49.0]
	var pads := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 261.63, 329.63], [196.0, 246.94, 293.66]]
	var bass_phase := 0.0
	var pad_phase := [0.0, 0.0, 0.0]
	var lp := 0.0
	var hat := 0.0
	for i in n:
		var time := float(i) / MIX_RATE
		var bar := int(time / (beat * 4.0)) % bars
		var eighth_pos := fmod(time, beat * 0.5) / (beat * 0.5)
		# Bass: saw through a simple low-pass, gated on eighth notes.
		var root: float = roots[bar]
		bass_phase = fmod(bass_phase + root * 2.0 / MIX_RATE, 1.0)
		var raw := bass_phase * 2.0 - 1.0
		lp += 0.08 * (raw - lp)
		var gate := pow(1.0 - eighth_pos, 1.5)
		var v := lp * 0.32 * gate
		# Pad: three detuned sines with slow swell.
		var chord: Array = pads[bar]
		var pad := 0.0
		for k in 3:
			pad_phase[k] = fmod(pad_phase[k] + chord[k] * 1.002 / MIX_RATE, 1.0)
			pad += sin(pad_phase[k] * TAU)
		var bar_pos := fmod(time, beat * 4.0) / (beat * 4.0)
		v += pad * 0.045 * (0.6 + 0.4 * sin(bar_pos * PI))
		# Hi-hat on off-beats.
		var sixteenth := fmod(time, beat * 0.25) / (beat * 0.25)
		var step := int(time / (beat * 0.25)) % 4
		if step == 2:
			hat = _rng.randf_range(-1.0, 1.0) * pow(1.0 - sixteenth, 6.0)
			v += hat * 0.05
		# Soft kick on beats 1 and 3.
		var beat_pos := fmod(time, beat * 2.0)
		if beat_pos < 0.18:
			var kt := beat_pos / 0.18
			v += sin(TAU * (90.0 - 50.0 * kt) * beat_pos) * pow(1.0 - kt, 2.0) * 0.35
		out[i] = v
	return _wav(out, true)
