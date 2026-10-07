class_name HackOverlay
extends Control
## Timing mini-game used for every hack. A cursor sweeps around a ring; the
## player locks it while it is inside the highlighted window. Each success
## speeds the cursor up and moves the window; misses make noise and too many
## misses fail the hack (leaving a trace).

signal finished(outcome: String)
signal missed

var active := false
var title := ""
var desc := ""
var hits_needed := 2
var hits := 0
var misses_left := 2
var window := 0.6
var cursor := 0.0
var speed := 3.4
var dir := 1.0
var target := 0.0
var _input_delay := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_col := Palette.GREEN
var _t := 0.0
var _font: Font
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = UITheme.font()
	_rng.randomize()


func begin(t: String, d: String, needed: int, allowed_misses: int, window_rad: float) -> void:
	title = t
	desc = d
	hits_needed = needed
	hits = 0
	misses_left = allowed_misses
	window = window_rad
	cursor = _rng.randf() * TAU
	speed = 3.2
	dir = 1.0
	_new_target()
	_input_delay = 0.15
	active = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func finish(outcome: String) -> void:
	if not active:
		return
	active = false
	visible = false
	finished.emit(outcome)


func _new_target() -> void:
	target = fmod(cursor + dir * _rng.randf_range(1.6, 4.2), TAU)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_input_delay -= delta
	_shake = maxf(0.0, _shake - delta * 4.0)
	_flash = maxf(0.0, _flash - delta * 3.0)
	cursor = fmod(cursor + speed * dir * delta + TAU, TAU)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("hack_abort") or event.is_action_pressed("melee"):
		get_viewport().set_input_as_handled()
		finish("abort")
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("fire") or event.is_action_pressed("dash"):
		get_viewport().set_input_as_handled()
		if _input_delay > 0.0:
			return
		_lock()


func _lock() -> void:
	if absf(angle_difference(cursor, target)) <= window * 0.5:
		hits += 1
		_flash = 1.0
		_flash_col = Palette.GREEN
		Sfx.play("hack_hit", 0.0, 1.0 + hits * 0.08)
		if hits >= hits_needed:
			finish("success")
			return
		speed += 0.7
		dir = -dir
		_new_target()
	else:
		misses_left -= 1
		_shake = 1.0
		_flash = 1.0
		_flash_col = Palette.RED
		Sfx.play("hack_miss")
		missed.emit()
		if misses_left < 0:
			finish("fail")


func _draw() -> void:
	# Offset to the side so the cat and nearby threats stay visible.
	var c := Vector2(size.x * 0.5 + minf(330.0, size.x * 0.28), size.y * 0.5 + 30.0)
	if _shake > 0.0:
		c += Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 8.0
	var radius := 86.0
	# Backdrop panel.
	var panel := Rect2(c - Vector2(190, 160), Vector2(380, 330))
	draw_rect(panel, Color(0.02, 0.02, 0.07, 0.86))
	draw_rect(panel, Palette.with_alpha(Palette.CYAN, 0.6), false, 2.0)
	draw_string(_font, panel.position + Vector2(0, 30), "// BREACH: %s" % title, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, Palette.CYAN)
	if desc != "":
		draw_string(_font, panel.position + Vector2(0, 50), desc, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 12, Palette.DIM)
	# Ring.
	draw_arc(c, radius, 0, TAU, 64, Color(0.15, 0.2, 0.35), 10.0, true)
	for i in 24:
		var a := TAU * i / 24.0
		draw_line(c + Vector2.from_angle(a) * (radius - 14), c + Vector2.from_angle(a) * (radius - 9), Palette.with_alpha(Palette.CYAN, 0.25), 1.0)
	# Target window.
	draw_arc(c, radius, target - window * 0.5, target + window * 0.5, 16, Palette.with_alpha(Palette.GREEN, 0.35), 18.0, true)
	draw_arc(c, radius, target - window * 0.5, target + window * 0.5, 16, Palette.GREEN, 10.0, true)
	# Cursor.
	var tip := c + Vector2.from_angle(cursor) * (radius + 14)
	draw_line(c + Vector2.from_angle(cursor) * (radius - 18), tip, Palette.WHITE, 4.0, true)
	draw_circle(tip, 4.0, Palette.MAGENTA)
	# Centre readout.
	var flash_col := Palette.with_alpha(_flash_col, _flash * 0.5)
	draw_circle(c, radius - 22, Color(0.03, 0.03, 0.08).lerp(flash_col, _flash * 0.4))
	draw_string(_font, c + Vector2(-60, 8), "%d / %d" % [hits, hits_needed], HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Palette.WHITE)
	# Progress pips.
	for i in hits_needed:
		var pc := c + Vector2((i - (hits_needed - 1) * 0.5) * 18.0, 30)
		draw_circle(pc, 5.0, Palette.GREEN if i < hits else Color(0.2, 0.25, 0.35))
	# Misses.
	var left := maxi(misses_left, 0)
	var miss_text := "TRACE BUFFER [" + "#".repeat(left) + "-".repeat(maxi(0, 3 - left)) + "]"
	draw_string(_font, panel.position + Vector2(0, panel.size.y - 40), miss_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Palette.YELLOW if misses_left > 0 else Palette.RED)
	draw_string(_font, panel.position + Vector2(0, panel.size.y - 16), "[E] / [LMB] / [SPACE] lock    [Q] / [RMB] abort", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 12, Palette.DIM)
