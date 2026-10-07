class_name SecurityDoor
extends Hackable
## Locked blast door filling a 3-tile doorway. Blocks movement, bullets,
## sight and enemy pathing until hacked open.

var cells: Array = []
var horizontal := true
var open_amount := 0.0
var _body: StaticBody2D
var _shape: CollisionShape2D


func setup(facility: Facility, door_cells: Array, is_horizontal: bool) -> void:
	cells = door_cells
	horizontal = is_horizontal
	display_name = "SECURITY DOOR"
	difficulty = 2
	interact_radius = 64.0
	var center := Vector2.ZERO
	for c in cells:
		center += facility.cell_center(c)
	position = center / cells.size()
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(Facility.TILE * cells.size(), Facility.TILE) if horizontal else Vector2(Facility.TILE, Facility.TILE * cells.size())
	_shape.shape = rect
	_body.add_child(_shape)
	add_child(_body)
	facility.set_cells_blocked(cells, true)


func describe() -> String:
	return sealed_reason() if sealed else "Opens this route"


func sealed_reason() -> String:
	return "Breach every uplink to unseal the core"


## Final mission: slam the vault shut while the WARDEN fight is on.
var locked_in := false


func force_close() -> void:
	locked_in = true
	sealed = true
	_shape.set_deferred("disabled", false)
	game.facility.set_cells_blocked(cells, true)
	Sfx.play_at("door", global_position, 0.0, 0.7)
	create_tween().tween_property(self, "open_amount", 0.0, 0.3)


func force_open() -> void:
	locked_in = false
	sealed = false
	hacked_done = true
	on_hacked()


func on_hacked() -> void:
	_shape.set_deferred("disabled", true)
	game.facility.set_cells_blocked(cells, false)
	Sfx.play_at("door", global_position)
	var tw := create_tween()
	tw.tween_property(self, "open_amount", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	FX.burst(game.fx_layer, global_position, Palette.GREEN, 14, 160.0, 0.4, 2.5)


func _draw() -> void:
	var span := Facility.TILE * cells.size()
	var along := Vector2.RIGHT if horizontal else Vector2.DOWN
	var across := Vector2.DOWN if horizontal else Vector2.RIGHT
	var half_len := span * 0.5
	var col := Palette.GREEN if hacked_done else (Palette.PURPLE if sealed else Palette.RED)
	if locked_in:
		col = Palette.RED
	var panel_len := half_len * (1.0 - open_amount * 0.92)
	for side in [-1.0, 1.0]:
		var outer: Vector2 = along * half_len * side
		var inner: Vector2 = outer - along * panel_len * side
		var a: Vector2 = inner - across * 10.0
		var b: Vector2 = outer + across * 10.0
		var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		draw_rect(r, Color(0.12, 0.1, 0.18))
		draw_rect(r, Palette.with_alpha(col, 0.85), false, 2.0)
		if not hacked_done or locked_in:
			# Hazard stripes.
			var steps := int(panel_len / 12.0)
			for i in steps:
				var p: Vector2 = outer - along * (6.0 + i * 12.0) * side
				draw_line(p - across * 8.0, p + across * 8.0 - along * 6.0 * side, Palette.with_alpha(col, 0.35), 2.0)
	if not hacked_done or locked_in:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2.ZERO, 5.0, Palette.with_alpha(Palette.RED, 0.5 + 0.5 * pulse))
		draw_line(-along * half_len, along * half_len, Palette.with_alpha(Palette.RED, 0.15 * pulse), 18.0)
	draw_focus_ring(30.0)
