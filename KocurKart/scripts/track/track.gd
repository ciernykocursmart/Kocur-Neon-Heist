class_name Track
extends Node3D
## Runtime track: geometry, surfaces, boost pads, hazards, checkpoints and the
## queries karts, AI and the race manager need. Built entirely from a track
## definition dictionary (see TrackCatalog), so every circuit shares the same
## rules code.

const CURB_W := 1.0
const DEFAULT_SHOULDER := 4.0
const PAD_LENGTH := 5.0
const PAD_WIDTH := 3.4

## Handling multipliers per surface.
const SURFACES := {
	&"road": {"grip": 1.0, "speed": 1.0, "accel": 1.0},
	&"curb": {"grip": 0.95, "speed": 0.97, "accel": 1.0},
	&"offroad": {"grip": 0.72, "speed": 0.58, "accel": 0.7},
	&"dirt": {"grip": 0.85, "speed": 0.93, "accel": 0.95},
	&"ice": {"grip": 0.2, "speed": 1.03, "accel": 0.72},
}

var def: Dictionary = {}
var theme: Dictionary = {}
var main: TrackPath
var shortcuts: Array[TrackPath] = []
var shortcut_surfaces: Array[StringName] = []
var shoulder := DEFAULT_SHOULDER
var length := 0.0
var checkpoints := PackedFloat32Array()   ## main-s of each checkpoint; [0] = finish line
var ice_ranges: Array[Vector2] = []
var gap_ranges: Array[Vector2] = []
var open_ranges: Array[Vector3] = []      ## (s0, s1, side)
var pads: Array[Vector3] = []             ## (s, lateral, path)
var ramps: Array[Dictionary] = []
var hazards: Array[TrackHazard] = []
var race_time := 0.0
var ground_y := -2.0
var water := false
var kill_y := -30.0
var racing_line: RacingLine
## Scenery can be skipped for fast headless logic tests.
var decorate := true


func setup(track_def: Dictionary) -> void:
	def = track_def
	theme = TrackThemes.get_theme(def.get("theme", "woods"))
	shoulder = float(def.get("shoulder", DEFAULT_SHOULDER))
	var width := float(def.get("width", 13.0))
	main = TrackPath.build(def["points"], true, width)
	length = main.length
	main.main_s_start = 0.0
	main.main_s_end = length
	for sc in def.get("shortcuts", []):
		var p := TrackPath.build(sc["points"], false, float(sc.get("width", 7.0)))
		var a := main.project(p.positions[0], main.nearest_index(p.positions[0], -1))
		var b := main.project(p.positions[p.size() - 1], main.nearest_index(p.positions[p.size() - 1], -1))
		p.main_s_start = a.x
		p.main_s_end = b.x
		if p.main_s_end < p.main_s_start:
			p.main_s_end += length
		shortcuts.append(p)
		shortcut_surfaces.append(StringName(sc.get("surface", "dirt")))
	for r in def.get("ice", []):
		ice_ranges.append(Vector2(r[0] * length, r[1] * length))
	for r in def.get("gaps", []):
		gap_ranges.append(Vector2(r[0] * length, r[1] * length))
	for r in def.get("open", []):
		open_ranges.append(Vector3(r[0] * length, r[1] * length, r[2]))
	for p in def.get("pads", []):
		pads.append(Vector3(p[0] * length, p[1], p[2] if p.size() > 2 else 0))
	for r in def.get("ramps", []):
		ramps.append({"s": r[0] * length, "lateral": r[1], "width": r[2], "length": r[3], "height": r[4]})
	ground_y = float(def.get("ground_y", _lowest_point() - 1.5))
	water = bool(theme.get("water", false))
	kill_y = ground_y - (2.0 if water else 8.0)
	_build_checkpoints(int(def.get("checkpoints", 10)))
	TrackBuilder.build(self)
	if decorate:
		TrackDecor.decorate(self)
	for h in def.get("hazards", []):
		var hz := TrackHazard.create(self, h)
		if hz:
			hazards.append(hz)
			add_child(hz)
	racing_line = RacingLine.new(self)


func _lowest_point() -> float:
	var low := INF
	for p in main.positions:
		low = minf(low, p.y)
	return low


func _build_checkpoints(count: int) -> void:
	checkpoints.resize(count)
	for i in count:
		checkpoints[i] = length * float(i) / count


func reset_race_time() -> void:
	race_time = 0.0
	for h in hazards:
		h.update(0.0)


func advance(delta: float) -> void:
	race_time += delta
	for h in hazards:
		h.update(race_time)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

static func in_range(s: float, a: float, b: float, total: float) -> bool:
	s = fposmod(s, total)
	var aa := fposmod(a, total)
	var bb := fposmod(b, total)
	if aa <= bb:
		return s >= aa and s <= bb
	return s >= aa or s <= bb


## Signed shortest distance from a to b along the circuit.
func s_delta(a: float, b: float) -> float:
	return wrapf(b - a, -length * 0.5, length * 0.5)


func locate(pos: Vector3, loc: TrackLocation) -> void:
	var hint := loc.main_index
	var mi := main.nearest_index(pos, hint)
	if hint >= 0 and pos.distance_squared_to(main.positions[mi]) > 2500.0:
		mi = main.nearest_index(pos, -1)
	loc.main_index = mi
	var proj := main.project(pos, mi)
	var best_path := 0
	var best_idx := mi
	var best_lat := proj.y
	var best_h := proj.z
	var best_hw := main.widths[mi] * 0.5
	var best_s := proj.x
	var best_norm := absf(best_lat) / best_hw
	if best_norm > 0.8:
		for k in shortcuts.size():
			var sc := shortcuts[k]
			if not in_range(proj.x, sc.main_s_start - 40.0, sc.main_s_end + 40.0, length):
				continue
			var si := sc.nearest_index(pos, loc.index if loc.path == k + 1 else -1)
			var sp := sc.project(pos, si)
			var hw := sc.widths[si] * 0.5
			var norm := absf(sp.y) / hw
			if norm < best_norm and absf(sp.z) < 5.0:
				best_norm = norm
				best_path = k + 1
				best_idx = si
				best_lat = sp.y
				best_h = sp.z
				best_hw = hw
				best_s = fposmod(sc.to_main_s(sp.x), length)
	loc.path = best_path
	loc.index = best_idx
	loc.lateral = best_lat
	loc.height = best_h
	loc.half_width = best_hw
	loc.s = best_s
	var a := absf(best_lat)
	var sh := shoulder if best_path == 0 else 2.0
	loc.off_track = a > best_hw + CURB_W + sh + 2.5
	loc.in_gap = best_path == 0 and _in_any(best_s, gap_ranges)
	if a <= best_hw:
		if best_path > 0:
			loc.surface = shortcut_surfaces[best_path - 1]
		elif _in_any(best_s, ice_ranges):
			loc.surface = &"ice"
		else:
			loc.surface = &"road"
	elif a <= best_hw + CURB_W and best_path == 0:
		loc.surface = &"ice" if _in_any(best_s, ice_ranges) else &"curb"
	else:
		loc.surface = &"offroad"
	loc.on_pad = false
	for p in pads:
		if int(p.z) != best_path:
			continue
		if absf(s_delta(p.x, best_s) - PAD_LENGTH * 0.5) <= PAD_LENGTH * 0.5 and absf(best_lat - p.y) <= PAD_WIDTH * 0.5:
			loc.on_pad = true
			break


func _in_any(s: float, ranges: Array[Vector2]) -> bool:
	for r in ranges:
		if in_range(s, r.x, r.y, length):
			return true
	return false


func is_open_side(s: float, side: int) -> bool:
	for r in open_ranges:
		if (int(r.z) == 0 or int(r.z) == side) and in_range(s, r.x, r.y, length):
			return true
	return false


func is_gap(s: float) -> bool:
	return _in_any(s, gap_ranges)


func is_ice(s: float) -> bool:
	return _in_any(s, ice_ranges)


## Safe respawn transform on the main circuit at progress `s`. Never inside a
## gap: steps back to solid road first.
func respawn_transform(s: float, lateral := 0.0) -> Transform3D:
	var tries := 0
	while is_gap(s) and tries < 200:
		s -= 2.0
		tries += 1
	var i := main.index_at_s(s)
	var hw := main.widths[i] * 0.5
	var pos := main.positions[i] + main.rights[i] * clampf(lateral, -hw * 0.6, hw * 0.6) + Vector3.UP * 0.6
	return Transform3D(Basis(Vector3.UP, main.yaw_at(i)), pos)


## Starting grid: slot 0 is pole position.
func grid_transform(slot: int) -> Transform3D:
	var row := slot / 2
	var col := slot % 2
	var s := -9.0 - row * 7.0 - col * 3.0
	var i := main.index_at_s(s)
	var hw := main.widths[i] * 0.5
	var lateral := (-0.38 if col == 0 else 0.38) * hw
	var pos := main.positions[i] + main.rights[i] * lateral + Vector3.UP * 0.5
	return Transform3D(Basis(Vector3.UP, main.yaw_at(i)), pos)


## Push vector if a sphere at pos/radius touches a hazard, else ZERO.
func hazard_contact(pos: Vector3, radius: float) -> Vector3:
	for h in hazards:
		var push := h.contact(pos, radius)
		if push != Vector3.ZERO:
			return push
	return Vector3.ZERO
