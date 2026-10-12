extends Node2D
## Visual for one unit: team marker, animated sprite, HP bar and status icons.
## Purely cosmetic - it never changes game state.

const UI = preload("res://scripts/ui/ui_kit.gd")

const TILE := 48
const STATUS_ICONS := {"stance": "icon_stance", "chilled": "icon_chilled", "exhausted": "icon_exhausted",
	"drained": "icon_exhausted", "iron_guard": "icon_stance"}

var uid := 0
var side := "hero"
var hp := 1
var max_hp := 1
var done := false
var asleep := false
var statuses: Array[String] = []
var is_boss := false
var is_object := false
var selected := false
var sprite: Sprite2D
var _t := 0.0
var _font: Font


func setup(u: RefCounted) -> void:
	uid = u.uid
	side = u.side
	hp = u.hp
	max_hp = u.max_hp
	is_boss = u.is_boss
	is_object = u.is_object
	asleep = not u.awake
	_font = ThemeDB.fallback_font
	sprite = Sprite2D.new()
	sprite.texture = UI.tex("unit_" + u.kind)
	sprite.hframes = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := 3.0 * (1.35 if is_boss else 1.0)
	sprite.scale = Vector2(sc, sc)
	sprite.position = Vector2(0, -4 if not is_boss else -12)
	add_child(sprite)
	_t = float(uid % 7) * 0.13
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if sprite and not done:
		sprite.frame = int(_t * 1.6) % 2
	queue_redraw()


func set_done(d: bool) -> void:
	done = d
	modulate = Color(0.55, 0.55, 0.62) if d else Color.WHITE


func _draw() -> void:
	# team marker: heroes = blue ring, enemies = red diamond (shape differs, not just colour)
	if not is_object:
		if side == "hero":
			draw_arc(Vector2(0, 16), 17, 0, TAU, 24, Color(0.35, 0.69, 1.0, 0.9), 3.0)
		else:
			var pts := PackedVector2Array([Vector2(0, 5), Vector2(19, 16), Vector2(0, 27), Vector2(-19, 16), Vector2(0, 5)])
			draw_polyline(pts, Color(1.0, 0.35, 0.42, 0.9), 3.0)
	if selected:
		var a := 0.6 + 0.4 * sin(_t * 6.0)
		draw_rect(Rect2(-TILE / 2 + 2, -TILE / 2 + 2, TILE - 4, TILE - 4), Color(1, 1, 1, a), false, 2.0)
	# hp bar
	var w := 38.0
	var y := -TILE / 2.0 - (14 if is_boss else 2)
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.85))
	var r := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	var col := Color("6ee08a") if side == "hero" else Color("ff6a6a")
	if is_object:
		col = Color("7fd8ff") if side == "hero" else Color("c79bff")
	draw_rect(Rect2(-w / 2, y, w * r, 5), col)
	draw_string(_font, Vector2(-w / 2, y - 2), str(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# statuses
	var x := 6.0
	for s in statuses:
		var t := UI.tex(STATUS_ICONS.get(s, "icon_warn"))
		if t:
			draw_texture_rect(t, Rect2(x, y - 15, 14, 14), false)
		x += 14
	if asleep:
		var z := UI.tex("icon_sleep")
		if z:
			draw_texture_rect(z, Rect2(10, -TILE / 2.0 + 4 + sin(_t * 2) * 2, 18, 18), false)
	if done and side == "hero":
		var wi := UI.tex("icon_wait")
		if wi:
			draw_texture_rect(wi, Rect2(-24, 6, 14, 14), false)


func pos_for(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2, cell.y * TILE + TILE / 2)


func flash(color: Color) -> void:
	if sprite == null:
		return
	var tw := create_tween()
	sprite.modulate = color
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)


func lunge(toward: Vector2, speed: float) -> void:
	if sprite == null:
		return
	var base := sprite.position
	var off := (toward - position).normalized() * 12.0
	var tw := create_tween()
	tw.tween_property(sprite, "position", base + off, 0.08 / speed)
	tw.tween_property(sprite, "position", base, 0.12 / speed)
	await tw.finished
