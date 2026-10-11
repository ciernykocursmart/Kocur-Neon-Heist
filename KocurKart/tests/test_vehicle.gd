extends Node
## Vehicle model: acceleration, braking, steering, drift, boost, jumps,
## collisions, recovery and frame-rate independence.

const OVAL := {
	"id": "test_oval", "name": "Test Oval", "theme": "woods", "width": 16.0,
	"points": [[0, 0, 0], [0, -100, 0], [0, -200, 0], [0, -300, 0], [20, -345, 0], [60, -362, 0], [100, -345, 0],
		[120, -300, 0], [120, -200, 0], [120, -100, 0], [120, 0, 0], [100, 45, 0], [60, 62, 0], [20, 45, 0]],
	"ramps": [[0.66, 0.0, 8.0, 7.0, 1.4]],
	"checkpoints": 8,
}

var t
var root: Node3D
var track: Track


func run(suite) -> void:
	t = suite
	root = Node3D.new()
	add_child(root)
	track = Track.new()
	root.add_child(track)
	track.setup(OVAL)
	var arena := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000, 2, 2000)
	shape.shape = box
	arena.add_child(shape)
	arena.position = Vector3(5000, -1, 0)
	root.add_child(arena)
	await _acceleration()
	await _braking_and_reverse()
	await _steering()
	await _drift_and_boost()
	await _purr_boost()
	await _jump_and_landing()
	await _wall_hit()
	await _recover()
	await _stuck_escape()
	await _surfaces()
	await _tick_rate_independence()
	root.queue_free()


func _kart(on_track := true) -> Array:
	var k := KartFactory.create({"racer": "kocur", "kart": "alley"})
	k.track = track if on_track else null
	root.add_child(k)
	var input := ScriptedInput.new()
	k.controller = input
	k.control_enabled = true
	return [k, input]


## Places a track-less kart on the open arena (no walls, plain road grip).
func _place_arena(k: Kart) -> void:
	k.place(Transform3D(Basis(), Vector3(5000, 0.5, 600)))
	await t.physics_frames(20)


## Places the kart on the first straight at progress s, facing along the track.
func _place(k: Kart, s := 20.0, lateral := 0.0) -> void:
	k.place(track.respawn_transform(s, lateral))
	await t.physics_frames(20)


func _free(k: Kart) -> void:
	k.queue_free()
	await t.physics_frames(2)


func _acceleration() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k)
	var s0 := k.forward_speed
	inp.throttle = 1.0
	await t.physics_frames(60)
	var v1 := k.forward_speed
	await t.physics_frames(180)
	var v4 := k.forward_speed
	t.check(s0 < 0.5 and v1 > 10.0, "Acceleration from standstill", "speed %.1f -> %.1f m/s after 1 s" % [s0, v1])
	t.check(v4 > k.top_speed() * 0.92 and v4 <= k.top_speed() + 0.01, "Reaches but does not exceed top speed", "%.2f m/s after 4 s (top %.1f)" % [v4, k.top_speed()])
	await _free(k)


func _braking_and_reverse() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k)
	inp.throttle = 1.0
	await t.physics_frames(200)
	var before := k.forward_speed
	inp.throttle = 0.0
	inp.brake = 1.0
	await t.physics_frames(30)
	var after := k.forward_speed
	t.check(after < before - 12.0, "Braking reduces speed", "%.1f -> %.1f m/s in 0.5 s" % [before, after])
	await t.physics_frames(90)
	t.check(k.forward_speed < -2.0, "Holding brake from standstill reverses", "speed %.1f m/s" % k.forward_speed)
	inp.brake = 0.0
	await t.physics_frames(240)
	t.check(absf(k.forward_speed) < 1.5, "Coasting rolls to a stop", "speed %.2f m/s" % k.forward_speed)
	await _free(k)


func _steering() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k)
	inp.throttle = 1.0
	await t.physics_frames(90)
	var y0 := k.yaw
	inp.steer = 1.0
	await t.physics_frames(30)
	var turned := wrapf(k.yaw - y0, -PI, PI)
	t.check(turned < -0.4, "Steering right turns the kart right", "yaw change %.2f rad in 0.5 s" % turned)
	inp.steer = -1.0
	await t.physics_frames(30)
	var back := wrapf(k.yaw - y0, -PI, PI)
	t.check(back > turned + 0.4, "Steering left turns the kart left", "yaw %.2f -> %.2f rad" % [turned, back])
	# Steering authority should be higher at moderate speed than at top speed.
	var low := Kart.turn_rate(8.0, k.top_speed())
	var high := Kart.turn_rate(k.top_speed(), k.top_speed())
	var stop := Kart.turn_rate(0.0, k.top_speed())
	t.check(low > high and stop == 0.0, "Steering rate scales sensibly with speed", "0 m/s %.2f, 8 m/s %.2f, top %.2f rad/s" % [stop, low, high])
	await _free(k)


func _drift_and_boost() -> void:
	var r := _kart(false)
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place_arena(k)
	inp.throttle = 1.0
	await t.physics_frames(150)
	var v0 := k.forward_speed
	inp.steer = 0.6
	inp.drift = true
	await t.physics_frames(2)
	t.check(k.drifting and k.drift_dir == -1, "Drift starts when steering with drift held", "drifting=%s dir=%d at %.1f m/s" % [k.drifting, k.drift_dir, v0])
	inp.steer = 0.0
	await t.physics_frames(54)
	var lvl1 := k.drift_level
	await t.physics_frames(66)
	var lvl2 := k.drift_level
	var keep := k.forward_speed
	t.check(lvl1 >= 1 and lvl2 == 2, "Sustained drift charges two boost levels", "level %d after 0.9 s, %d after 2 s" % [lvl1, lvl2])
	t.check(keep > v0 * 0.8, "Drift keeps forward momentum", "speed %.1f -> %.1f m/s" % [v0, keep])
	inp.drift = false
	await t.physics_frames(1)
	t.check(not k.drifting and k.boost_time > 0.9 and k.purr > 0.5, "Releasing a charged drift fires a large boost and fills Purr", "boost %.2f s, purr %.2f" % [k.boost_time, k.purr])
	await t.physics_frames(20)
	t.check(k.forward_speed > k.top_speed(), "Mini-turbo pushes past normal top speed", "%.1f m/s" % k.forward_speed)
	# A drift released before charging gives no boost.
	await t.physics_frames(90)
	inp.steer = -0.8
	inp.drift = true
	await t.physics_frames(15)
	inp.drift = false
	await t.physics_frames(1)
	t.check(k.boost_time <= 0.0, "Uncharged drift gives no boost", "boost %.2f s" % k.boost_time)
	await _free(k)


func _purr_boost() -> void:
	var r := _kart(false)
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place_arena(k)
	inp.throttle = 1.0
	await t.physics_frames(200)
	k.purr = 0.4
	inp.boost = true
	await t.physics_frames(2)
	t.check(k.boost_time <= 0.0 and is_equal_approx(k.purr, 0.4), "Purr Boost needs a full segment", "boost %.2f, purr %.2f" % [k.boost_time, k.purr])
	k.purr = 1.2
	inp.boost = true
	await t.physics_frames(2)
	t.check(k.boost_time > 1.0 and is_equal_approx(k.purr, 0.2), "Purr Boost spends one segment", "boost %.2f s, purr %.2f" % [k.boost_time, k.purr])
	await t.physics_frames(40)
	t.check(k.forward_speed > k.top_speed() * 1.15, "Purr Boost accelerates hard", "%.1f m/s (top %.1f)" % [k.forward_speed, k.top_speed()])
	await _free(k)


func _jump_and_landing() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	var ramp_s: float = track.ramps[0]["s"]
	await _place(k, ramp_s - 75.0)
	var air := [0.0]
	var landings := [0]
	k.landed.connect(func(_i): landings[0] += 1)
	inp.throttle = 1.0
	var max_air := 0.0
	var peak := -INF
	for i in 420:
		await t.physics_frames(1)
		max_air = maxf(max_air, k.airborne_time)
		peak = maxf(peak, k.global_position.y)
		if k.loc.s > ramp_s + 70.0:
			break
	t.check(max_air > 0.25 and peak > 1.5, "Ramp launches the kart", "airtime %.2f s, peak height %.2f m" % [max_air, peak])
	t.check(landings[0] == 1, "Lands once without bouncing", "%d landing events" % landings[0])
	t.check(k.is_on_floor() and k.forward_speed > 15.0, "Keeps driving after landing", "on floor %s, %.1f m/s" % [k.is_on_floor(), k.forward_speed])
	await _free(k)


func _wall_hit() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k, 40.0)
	k.yaw += 0.5
	k.rotation.y = k.yaw
	inp.throttle = 1.0
	var hits := [0]
	k.wall_hit.connect(func(_i): hits[0] += 1)
	var max_rate := 0.0
	var prev := k.yaw
	for i in 240:
		await t.physics_frames(1)
		max_rate = maxf(max_rate, absf(wrapf(k.yaw - prev, -PI, PI)) * 60.0)
		prev = k.yaw
	t.check(hits[0] >= 1, "Wall collision is detected", "%d hit events" % hits[0])
	t.check(max_rate < 6.0, "Wall hit never spins the kart", "max yaw rate %.2f rad/s" % max_rate)
	track.locate(k.global_position, k.loc)
	t.check(not k.loc.off_track and k.forward_speed > 8.0, "Kart slides along the wall and keeps going", "lateral %.1f m, %.1f m/s" % [k.loc.lateral, k.forward_speed])
	await _free(k)


func _recover() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k, 60.0)
	inp.throttle = 1.0
	await t.physics_frames(60)
	# Drop the kart far outside the circuit, then recover.
	k.global_position = Vector3(400, 5, 400)
	k.reset_physics_interpolation()
	await t.physics_frames(5)
	k.recover()
	await t.physics_frames(30)
	track.locate(k.global_position, k.loc)
	var on_road := absf(k.loc.lateral) < k.loc.half_width and not k.loc.off_track
	var aligned := absf(wrapf(k.yaw - track.main.yaw_at(k.loc.main_index), -PI, PI)) < 0.2
	t.check(on_road and aligned and k.is_on_floor(), "Recovery puts the kart on the road facing forward", "lateral %.1f, heading error %.2f" % [k.loc.lateral, wrapf(k.yaw - track.main.yaw_at(k.loc.main_index), -PI, PI)])
	t.check(k.ghost_time > 0.0 and k.collision_layer == 0, "Recovered kart is briefly non-colliding", "ghost %.2f s" % k.ghost_time)
	await t.physics_frames(120)
	t.check(k.forward_speed > 10.0 and k.collision_layer == 2, "Recovered kart is drivable again", "%.1f m/s" % k.forward_speed)
	await _free(k)


func _stuck_escape() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k, 40.0)
	# Face the wall head-on and drive into it.
	k.yaw -= PI * 0.5
	k.rotation.y = k.yaw
	inp.throttle = 1.0
	await t.physics_frames(120)
	track.locate(k.global_position, k.loc)
	var lat0 := k.loc.lateral
	inp.throttle = 0.0
	inp.brake = 1.0
	inp.steer = 1.0
	await t.physics_frames(90)
	inp.brake = 0.0
	inp.throttle = 1.0
	await t.physics_frames(60)
	track.locate(k.global_position, k.loc)
	t.check(absf(k.loc.lateral) < absf(lat0) - 1.0, "Reversing away from a wall frees the kart", "lateral %.1f -> %.1f m" % [lat0, k.loc.lateral])
	await _free(k)


func _surfaces() -> void:
	var r := _kart()
	var k: Kart = r[0]
	var inp: ScriptedInput = r[1]
	await _place(k, 20.0, 0.0)
	inp.throttle = 1.0
	await t.physics_frames(240)
	var road_v := k.forward_speed
	# Move onto the verge (off-road) and keep driving straight.
	var i := track.main.index_at_s(80.0)
	k.global_position = track.main.positions[i] + track.main.rights[i] * (track.main.widths[i] * 0.5 + Track.CURB_W + 2.0) + Vector3.UP * 0.4
	k.yaw = track.main.yaw_at(i)
	k.rotation.y = k.yaw
	k.reset_physics_interpolation()
	await t.physics_frames(90)
	t.check(k.surface == &"offroad" and k.forward_speed < road_v * 0.7, "Off-road verge slows the kart", "road %.1f m/s, verge %.1f m/s (%s)" % [road_v, k.forward_speed, k.surface])
	await _free(k)


func _tick_rate_independence() -> void:
	var results := []
	for tps in [60, 120]:
		Engine.physics_ticks_per_second = tps
		var r := _kart()
		var k: Kart = r[0]
		var inp: ScriptedInput = r[1]
		k.place(track.respawn_transform(20.0))
		for i in 20 * tps / 60:
			await get_tree().physics_frame
		inp.throttle = 1.0
		var start := k.global_position
		var frames: int = 2 * tps
		for i in frames:
			await get_tree().physics_frame
		results.append([k.forward_speed, start.distance_to(k.global_position)])
		k.queue_free()
		await get_tree().physics_frame
	Engine.physics_ticks_per_second = 60
	var dv := absf(results[0][0] - results[1][0])
	var dd := absf(results[0][1] - results[1][1])
	t.check(dv < 0.6 and dd < 1.5, "Handling is consistent at 60 and 120 Hz physics", "speed %.2f vs %.2f m/s, distance %.1f vs %.1f m" % [results[0][0], results[1][0], results[0][1], results[1][1]])
