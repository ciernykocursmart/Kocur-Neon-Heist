extends Node
## Autoload "Sfx": procedural sound effects and a looping lullaby, no audio files needed.

const RATE := 22050
var sounds := {}
var _players: Array = []
var _music: AudioStreamPlayer
var _next := 0

func _ready() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	sounds = {
		"step": _tone([[520.0, 0.035]], 0.12),
		"bump": _tone([[110.0, 0.07]], 0.25),
		"push": _tone([[150.0, 0.05], [120.0, 0.06]], 0.35),
		"fish": _tone([[784.0, 0.07], [988.0, 0.07], [1319.0, 0.12]], 0.3),
		"key": _tone([[1047.0, 0.06], [1568.0, 0.14]], 0.28),
		"switch": _tone([[330.0, 0.07], [440.0, 0.1]], 0.3),
		"door": _tone([[220.0, 0.08], [330.0, 0.08], [494.0, 0.12]], 0.28),
		"undo": _tone([[440.0, 0.05], [330.0, 0.08]], 0.25),
		"tp": _tone([[300.0, 0.05], [600.0, 0.05], [1200.0, 0.1]], 0.22),
		"slide": _tone([[900.0, 0.04], [700.0, 0.06]], 0.14),
		"click": _tone([[660.0, 0.04]], 0.22),
		"win": _tone([[523.0, 0.11], [659.0, 0.11], [784.0, 0.11], [1047.0, 0.35]], 0.32),
		"warn": _tone([[220.0, 0.1], [196.0, 0.16]], 0.28),
	}
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.stream = _make_music()
	apply_settings()

func apply_settings() -> void:
	var s: Dictionary = SaveData.data.settings
	for pair in [["Music", float(s.music)], ["SFX", float(s.sfx)]]:
		var idx := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)) - 6.0)
		AudioServer.set_bus_mute(idx, pair[1] <= 0.001)

func play(name: String) -> void:
	if not sounds.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = sounds[name]
	p.play()

func start_music() -> void:
	if not _music.playing:
		_music.play()

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _tone(notes: Array, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for n in notes:
		var cnt := int(RATE * float(n[1]))
		var phase := 0.0
		for i in cnt:
			var t := float(i) / cnt
			phase += TAU * float(n[0]) / RATE
			var env := minf(1.0, t * 12.0) * (1.0 - t) * (1.0 - t)
			out.append((sin(phase) * 0.7 + sin(phase * 2.0) * 0.15) * env * vol)
	return _wav(out)

func _make_music() -> AudioStreamWAV:
	# 4 chords x 8 eighth-notes, gentle plucked arpeggio over a soft bass. About 12.8 s loop.
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	var bass := [45, 41, 36, 43]
	var step := int(RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(step * 8 * chords.size())
	var pattern := [0, 1, 2, 1, 0, 1, 2, 2]
	for c in chords.size():
		for n in 8:
			var f := 440.0 * pow(2.0, (chords[c][pattern[n]] + 12 - 69) / 12.0)
			var base := (c * 8 + n) * step
			for i in step:
				var t := float(i) / step
				var env := minf(1.0, t * 30.0) * exp(-t * 4.0)
				out[base + i] += (sin(TAU * f * i / RATE) * 0.6 + sin(TAU * f * 2.0 * i / RATE) * 0.12) * env * 0.16
			if n % 4 == 0:
				var bf := 440.0 * pow(2.0, (bass[c] - 69) / 12.0)
				for i in step * 4:
					var t2 := float(i) / (step * 4)
					if base + i < out.size():
						out[base + i] += sin(TAU * bf * i / RATE) * (1.0 - t2) * minf(1.0, t2 * 20.0) * 0.12
	return _wav(out, true)
