extends CanvasLayer
## In-game HUD: health bar, PAWQUAKE energy (2 bars), lives, continues,
## score, street name, combo counter, boss health bar, "GO" arrow, banners
## and tutorial hints. Drawn directly for crisp, cheap rendering.

var level: Node
var view: HudView


func setup(lvl: Node) -> void:
	level = lvl
	layer = 10
	view = HudView.new()
	view.level = lvl
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


func show_banner(title: String, sub: String, time: float) -> void:
	view.banner = [title, sub]
	view.banner_t = time
	view.banner_total = time


func show_hint(text: String, time: float) -> void:
	view.hint = text
	view.hint_t = time


func show_boss(b: Node) -> void:
	view.boss = b


func hide_boss() -> void:
	view.boss = null


func show_go() -> void:
	view.go_t = 3.0


class HudView extends Control:
	var level: Node
	var font: Font
	var banner := ["", ""]
	var banner_t := 0.0
	var banner_total := 1.0
	var hint := ""
	var hint_t := 0.0
	var boss: Node = null
	var go_t := 0.0
	var shown_hp := 100.0
	var combo_shown := 0
	var combo_pop := 0.0
	var t := 0.0
	var last_combo := 0

	func _ready() -> void:
		font = ThemeDB.fallback_font

	func _process(delta: float) -> void:
		t += delta
		banner_t = maxf(0.0, banner_t - delta)
		hint_t = maxf(0.0, hint_t - delta)
		go_t = maxf(0.0, go_t - delta)
		var p: Node = level.player
		shown_hp = move_toward(shown_hp, p.hp, 60.0 * delta)
		if p.hit_count != last_combo:
			if p.hit_count > last_combo:
				combo_pop = 0.25
			last_combo = p.hit_count
		combo_pop = maxf(0.0, combo_pop - delta)
		queue_redraw()

	func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6) -> void:
		draw_string_outline(font, pos, s, align, width, size, outline, Color(0.08, 0.03, 0.1, col.a))
		draw_string(font, pos, s, align, width, size, col)

	func _draw() -> void:
		var p: Node = level.player
		# --- player panel
		draw_rect(Rect2(14, 12, 470, 96), Color(0.08, 0.04, 0.12, 0.72))
		draw_rect(Rect2(14, 12, 470, 96), Color("6a3a7a"), false, 2.0)
		draw_set_transform(Vector2(58, 100), 0.0, Vector2(0.62, 0.62))
		CatPainter.draw_cat(self, p.look, {"eyes": "angry" if p.hp > 30 else "hurt", "mouth": "grin" if p.hp > 30 else "open", "arm_f": Vector2(12, 14)})
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_text(Vector2(108, 36), "KOCUR", 20, Color("ffd23a"))
		_text(Vector2(190, 36), "x%d" % Game.lives, 20, Color("ff8ab8"))
		var cont := "CONT. INF" if Game.continues_left < 0 else "CONT. %d" % Game.continues_left
		_text(Vector2(244, 36), cont, 14, Color("b9a8e8"))
		# health
		var hb := Rect2(108, 46, 300, 20)
		draw_rect(hb.grow(2.0), Color("140a18"))
		draw_rect(hb, Color("3a1a24"))
		var frac: float = p.hp / p.max_hp
		var sfrac: float = shown_hp / p.max_hp
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * sfrac, hb.size.y)), Color("ffffff"))
		var hc := Color("4ae06a").lerp(Color("ff3a3a"), 1.0 - frac) if frac > 0.3 else Color("ff3a3a") if int(t * 5.0) % 2 == 0 else Color("ff8a5a")
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * frac, hb.size.y)), hc)
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * frac, 5)), Color(1, 1, 1, 0.25))
		_text(Vector2(414, 63), "%d" % int(ceil(p.hp)), 18, Color.WHITE)
		# special energy: two bars, one per PAWQUAKE
		var eb := Rect2(108, 74, 146, 14)
		for i in 2:
			var r := Rect2(eb.position + Vector2(i * 150, 0), eb.size)
			draw_rect(r.grow(2.0), Color("140a18"))
			draw_rect(r, Color("1a2440"))
			var f: float = clampf((p.energy - i * 50.0) / 50.0, 0.0, 1.0)
			var full := f >= 1.0
			draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Color("7ab8ff") if full else Color("3a6ab0"))
			if full:
				draw_rect(r, Color(1, 1, 1, 0.15 + 0.15 * sin(t * 6.0)))
		_text(Vector2(414, 88), "K", 16, Color("7ab8ff") if p.energy >= 50.0 else Color("5a6a8a"))
		_text(Vector2(108, 104), "PAWQUAKE", 12, Color("7ab8ff"))
		# --- street + score
		var d: Dictionary = level.data
		_text(Vector2(0, 34), "STREET %d  -  %s" % [int(d["num"]), String(d["name"]).to_upper()], 18, Color("f0eaff"), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
		_text(Vector2(0, 64), "SCORE  %07d" % Game.score, 26, Color("ffd23a"), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
		# --- combo counter
		if p.hit_count >= 2:
			var s := 1.0 + combo_pop * 1.6
			draw_set_transform(Vector2(1180, 70), -0.08, Vector2(s, s))
			_text(Vector2(-120, 0), "%d" % p.hit_count, 48, Color("ffd23a"), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 8)
			_text(Vector2(6, 0), "HITS!", 22, Color("ff8ab8"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# --- GO arrow
		var show_go: bool = go_t > 0.0 or (not level.locked and level.flow == "play" and level.enc.next_index() >= 0 and level.player.position.x < level.cam_x - 100.0) or level.flow == "exit"
		if show_go and int(t * 3.0) % 2 == 0:
			_text(Vector2(1080, 200), "GO", 44, Color("ffd23a"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
			draw_colored_polygon(PackedVector2Array([Vector2(1160, 172), Vector2(1200, 186), Vector2(1160, 200)]), Color("ffd23a"))
		# --- boss bar
		if boss != null and is_instance_valid(boss) and boss.state != "enter":
			var bb := Rect2(240, 662, 800, 22)
			draw_rect(Rect2(226, 624, 828, 72), Color(0.08, 0.04, 0.12, 0.75))
			_text(Vector2(240, 654), String(boss.display_name), 20, Color("ff6a6a"))
			_text(Vector2(240, 654), String(boss.title), 14, Color("b9a8e8"), HORIZONTAL_ALIGNMENT_RIGHT, 800.0)
			draw_rect(bb.grow(2.0), Color("140a18"))
			draw_rect(bb, Color("3a1a24"))
			var bf: float = boss.hp / boss.max_hp
			draw_rect(Rect2(bb.position, Vector2(bb.size.x * bf, bb.size.y)), Color("e8413c"))
			draw_rect(Rect2(bb.position, Vector2(bb.size.x * bf, 6)), Color(1, 1, 1, 0.25))
			for th: float in boss.thresholds:
				draw_line(bb.position + Vector2(bb.size.x * th, -4), bb.position + Vector2(bb.size.x * th, bb.size.y + 4), Color("ffd23a"), 3.0)
		# --- banner
		if banner_t > 0.0:
			var a := clampf(banner_t * 3.0, 0.0, 1.0) * clampf((banner_total - banner_t) * 4.0, 0.0, 1.0)
			draw_rect(Rect2(0, 250, 1280, 130), Color(0.08, 0.03, 0.12, 0.65 * a))
			_text(Vector2(0, 318), String(banner[0]), 54, Color(1, 0.82, 0.23, a), HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 10)
			_text(Vector2(0, 360), String(banner[1]), 24, Color(0.94, 0.92, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
		# --- hint
		if hint_t > 0.0:
			var ha := clampf(hint_t * 2.0, 0.0, 1.0)
			var w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 40.0
			var y := 160.0
			draw_rect(Rect2(640 - w * 0.5, y - 26, w, 38), Color(0.08, 0.03, 0.12, 0.7 * ha))
			draw_rect(Rect2(640 - w * 0.5, y - 26, w, 38), Color(1, 0.82, 0.23, 0.6 * ha), false, 2.0)
			_text(Vector2(0, y), hint, 20, Color(1, 1, 1, ha), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
