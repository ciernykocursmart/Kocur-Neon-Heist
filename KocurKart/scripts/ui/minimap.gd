extends Control
## Top-down track outline with live kart positions.

var race: Race
var _pts := PackedVector2Array()
var _shortcuts: Array[PackedVector2Array] = []
var _lo := Vector2.ZERO
var _scale := 1.0
var _offset := Vector2.ZERO


func setup(r: Race) -> void:
	race = r
	var t := race.track
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in t.main.positions:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	_lo = lo
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	_scale = 200.0 / maxf(span, 1.0)
	_offset = (Vector2(230, 230) - (hi - lo) * _scale) * 0.5
	for i in range(0, t.main.size(), 2):
		_pts.append(_map(t.main.positions[i]))
	_pts.append(_pts[0])
	for sc in t.shortcuts:
		var arr := PackedVector2Array()
		for p in sc.positions:
			arr.append(_map(p))
		_shortcuts.append(arr)


func _map(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - _lo) * _scale + _offset


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if race == null:
		return
	draw_polyline(_pts, Color(0, 0, 0, 0.55), 11.0, true)
	draw_polyline(_pts, Color(0.95, 0.92, 0.88, 0.85), 6.0, true)
	for sc in _shortcuts:
		draw_polyline(sc, Color(0.85, 0.6, 0.35, 0.8), 4.0, true)
	var start := _map(race.track.main.positions[0])
	draw_circle(start, 5.0, Color(0.2, 1.0, 0.4))
	for e in race.entries:
		if e == race.player:
			continue
		var c: Color = Catalog.RACERS[e.kart.racer_id]["fur"]
		var p := _map(e.kart.global_position)
		draw_circle(p, 6.5, Color(0, 0, 0, 0.8))
		draw_circle(p, 5.0, c.lightened(0.25))
	var pp := _map(race.player.kart.global_position)
	draw_circle(pp, 9.0, Color(0, 0, 0, 0.85))
	draw_circle(pp, 7.0, UI.ACCENT)
