class_name Enemy
extends CharacterBody2D
## Base security AI shared by all archetypes.
##
## State machine:
##   PATROL      walk patrol route, look around at waypoints
##   SUSPICIOUS  saw/heard something: turn, then walk over to investigate
##   CHASE       player confirmed: radio it in (alarm), pursue and attack
##   SEARCH      lost the player: sweep points around the last known position
##   DEAD
##
## Detection uses an awareness meter (0..1) fed by vision cone + line of sight.
## Subclasses override _configure() for stats and _draw_body() for visuals,
## and may override hooks such as _combat_move() for special behaviour.

signal died(enemy: Enemy)

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, DEAD }

const LAYER := 4
const STATE_NAMES := ["PATROL", "SUSPICIOUS", "CHASE", "SEARCH", "DEAD"]

var game: Game
var facility: Facility

# --- Tunables (set by subclasses in _configure) ---------------------------
var kind := "guard"
var display_name := "GUARD"
var max_hp := 60.0
var patrol_speed := 75.0
var chase_speed := 150.0
var vision_range := 320.0
var vision_fov := deg_to_rad(80.0)
var vision_rays := 18
var proximity_radius := 56.0
var detect_rate := 1.0
var turn_rate := 7.0
var fire_interval := 1.0
var burst_count := 3
var burst_gap := 0.1
var bullet_damage := 9.0
var bullet_speed := 620.0
var spread := deg_to_rad(5.0)
var pellets := 1
var attack_range := 380.0
var preferred_range := 230.0
var body_radius := 13.0
var color := Palette.ORANGE
var credit_drop := 15
var search_duration := 10.0
var radio_delay := 1.3
var reaction_time := 0.45

# --- Runtime state ----------------------------------------------------------
var hp := 60.0
var state := State.PATROL
var facing := 0.0
var awareness := 0.0
var sees_player := false
var patrol_points: Array[Vector2] = []
var patrol_i := 0
var wait_timer := 0.0
var look_base := 0.0
var look_timer := 0.0
var investigate_pos := Vector2.ZERO
var react_timer := 0.0
var last_known := Vector2.ZERO
var lost_timer := 0.0
var search_center := Vector2.ZERO
var search_timer := 0.0
var search_points: Array[Vector2] = []
var radio_timer := -1.0
var fire_timer := 0.0
var burst_left := 0
var burst_timer := 0.0
var strafe_dir := 1.0
var strafe_timer := 0.0
var hit_flash := 0.0
var knockback_scale := 1.0
var discovered := false
var _body_check := 0.0
var _last_flinch := -10.0
var anim_t := 0.0
var cone := PackedVector2Array()
var _cone_timer := 0.0
var _cone_node: Node2D
var _path := PackedVector2Array()
var _path_i := 0
var _path_target := Vector2.INF
var _repath_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _configure() -> void:
	pass


func _ready() -> void:
	_configure()
	_rng.randomize()
	hp = max_hp
	collision_layer = LAYER
	collision_mask = 1 | 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = body_radius
	cs.shape = shape
	add_child(cs)
	_cone_node = Node2D.new()
	_cone_node.z_index = -1
	_cone_node.draw.connect(_draw_cone)
	add_child(_cone_node)
	add_to_group("enemies")
	if not patrol_points.is_empty():
		facing = (patrol_points[0] - global_position).angle() if patrol_points[0].distance_to(global_position) > 1.0 else _rng.randf() * TAU
	look_base = facing
	strafe_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	# Stagger periodic work so enemies don't all raycast on the same tick.
	_cone_timer = _rng.randf() * 0.05
	_body_check = _rng.randf() * 0.4
	_repath_timer = _rng.randf() * 0.3


func is_dead() -> bool:
	return state == State.DEAD


## True when the enemy has not locked on to the player (takedown-able).
func is_unaware() -> bool:
	return state == State.PATROL or state == State.SUSPICIOUS or (state == State.SEARCH and not sees_player)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	anim_t += delta
	hit_flash = maxf(0.0, hit_flash - delta * 5.0)
	fire_timer -= delta
	_repath_timer -= delta

	_update_perception(delta)
	match state:
		State.PATROL:
			_state_patrol(delta)
		State.SUSPICIOUS:
			_state_suspicious(delta)
		State.CHASE:
			_state_chase(delta)
		State.SEARCH:
			_state_search(delta)

	_apply_separation()
	move_and_slide()

	_cone_timer -= delta
	if _cone_timer <= 0.0:
		_cone_timer = 0.05
		cone = VisionCone.compute(get_world_2d().direct_space_state, global_position, facing, vision_fov, _effective_range(), vision_rays)
	_cone_node.queue_redraw()
	queue_redraw()


# --------------------------------------------------------------------------
# Perception
# --------------------------------------------------------------------------

func _effective_range() -> float:
	var mult := 1.0
	if game.alarm.level == AlarmSystem.Level.CAUTION:
		mult = 1.12
	elif game.alarm.level == AlarmSystem.Level.ALARM:
		mult = 1.25
	return vision_range * mult


func can_see_player() -> bool:
	var p := game.player
	if p == null or p.dead:
		return false
	var to := p.global_position - global_position
	var d := to.length()
	if d > _effective_range():
		return false
	if d > proximity_radius and not VisionCone.angle_within(facing, to.angle(), vision_fov):
		return false
	return facility.has_los(global_position, p.global_position)


func _update_perception(delta: float) -> void:
	_body_check -= delta
	if _body_check <= 0.0:
		_body_check = 0.4
		_check_bodies()
	sees_player = can_see_player()
	var p := game.player
	if sees_player:
		var d := global_position.distance_to(p.global_position)
		var closeness := clampf(1.0 - d / _effective_range(), 0.0, 1.0)
		var mult := 1.0
		match game.alarm.level:
			AlarmSystem.Level.CAUTION:
				mult = 1.5
			AlarmSystem.Level.ALARM:
				mult = 4.0
		var gain := detect_rate * (0.45 + 2.4 * closeness * closeness) * p.visibility() * mult
		if d < proximity_radius:
			gain += 2.5
		elif d < maxf(proximity_radius, 50.0) * 1.8:
			# Point-blank: shadows and camo can't hide a cat right in front.
			gain = maxf(gain, 1.3)
		if state == State.SEARCH:
			gain *= 2.0
		awareness = minf(1.0, awareness + gain * delta)
		last_known = p.global_position
	elif state == State.PATROL or state == State.SUSPICIOUS:
		awareness = maxf(0.0, awareness - delta * 0.15)

	if state != State.CHASE and awareness >= 1.0:
		_enter_chase()
	elif state == State.PATROL and sees_player and awareness >= 0.25:
		_enter_suspicious(p.global_position)
	elif state == State.SUSPICIOUS and sees_player:
		investigate_pos = p.global_position


## Patrols that spot a fallen colleague go on the hunt and raise caution.
func _check_bodies() -> void:
	if state == State.CHASE:
		return
	var reach := _effective_range() * 0.8
	for c in get_tree().get_nodes_in_group("corpses"):
		var body := c as Enemy
		if body == null or body.discovered:
			continue
		var to := body.global_position - global_position
		if to.length() > reach:
			continue
		if not VisionCone.angle_within(facing, to.angle(), vision_fov) and to.length() > proximity_radius:
			continue
		if not facility.has_los(global_position, body.global_position):
			continue
		body.discovered = true
		body.remove_from_group("corpses")
		awareness = maxf(awareness, 0.6)
		Sfx.play_at("body_found", global_position, -2.0)
		FX.float_text(game.fx_layer, global_position + Vector2(0, -34), "BODY FOUND", Palette.ORANGE, 14)
		game.on_body_found(body.global_position)
		_enter_search(body.global_position)
		return


func hear_noise(pos: Vector2, loud: bool) -> void:
	if state == State.DEAD or state == State.CHASE:
		return
	if state == State.SEARCH:
		search_center = pos
		search_points.clear()
		search_timer = maxf(search_timer, search_duration * 0.6)
		return
	awareness = maxf(awareness, 0.55 if loud else 0.35)
	_enter_suspicious(pos)


func on_alarm(pos: Vector2) -> void:
	if state == State.DEAD or state == State.CHASE:
		return
	if state == State.SEARCH:
		if pos.distance_to(search_center) > 200.0:
			search_center = pos
			search_points.clear()
		search_timer = maxf(search_timer, search_duration * 0.5)
		return
	awareness = maxf(awareness, 0.7)
	_enter_search(pos)


func on_alarm_cleared() -> void:
	if state == State.SEARCH:
		search_timer = minf(search_timer, 2.0)


# --------------------------------------------------------------------------
# State transitions
# --------------------------------------------------------------------------

func _enter_suspicious(pos: Vector2) -> void:
	if state != State.SUSPICIOUS:
		Sfx.play_at("suspicious", global_position, -6.0)
		react_timer = 0.6
	state = State.SUSPICIOUS
	investigate_pos = pos
	look_timer = 0.0


func _enter_chase() -> void:
	var was := state
	state = State.CHASE
	awareness = 1.0
	lost_timer = 0.0
	fire_timer = maxf(fire_timer, reaction_time)
	burst_left = 0
	_path = PackedVector2Array()
	if game.player != null:
		last_known = game.player.global_position
	if was != State.CHASE:
		Sfx.play_at("detect", global_position, 0.0)
		FX.ring(game.fx_layer, global_position, Palette.RED, 60.0, 0.35, 3.0)
	if game.alarm.level == AlarmSystem.Level.ALARM:
		radio_timer = -1.0
		game.alarm.report_sighting(last_known)
	else:
		radio_timer = radio_delay


func _enter_search(center: Vector2) -> void:
	state = State.SEARCH
	search_center = center
	search_timer = search_duration
	search_points.clear()
	look_timer = 0.0
	_path = PackedVector2Array()


func _return_to_patrol() -> void:
	state = State.PATROL
	awareness = minf(awareness, 0.2)
	wait_timer = 0.5
	_path = PackedVector2Array()


# --------------------------------------------------------------------------
# States
# --------------------------------------------------------------------------

func _patrol_speed() -> float:
	return patrol_speed * (1.25 if game.alarm.level != AlarmSystem.Level.CALM else 1.0)


func _state_patrol(delta: float) -> void:
	if patrol_points.size() <= 1:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		facing = look_base + sin(anim_t * 0.7) * 1.2
		return
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		facing = lerp_angle(facing, look_base + sin(anim_t * 1.4) * 0.9, delta * 3.0)
		return
	var target := patrol_points[patrol_i]
	if _move_to(target, _patrol_speed(), delta):
		patrol_i = (patrol_i + 1) % patrol_points.size()
		wait_timer = _rng.randf_range(1.0, 2.6)
		look_base = facing


func _state_suspicious(delta: float) -> void:
	_face_towards(investigate_pos, delta)
	if react_timer > 0.0:
		react_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		return
	if look_timer > 0.0:
		look_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		facing = look_base + sin(anim_t * 2.0) * 1.1
		if look_timer <= 0.0:
			_return_to_patrol()
		return
	if _move_to(investigate_pos, _patrol_speed() * 0.9, delta, false):
		look_timer = 2.4
		look_base = facing
	elif awareness <= 0.0:
		_return_to_patrol()


func _state_chase(delta: float) -> void:
	var p := game.player
	if p == null or p.dead:
		_return_to_patrol()
		return

	if radio_timer > 0.0:
		radio_timer -= delta
		if radio_timer <= 0.0:
			radio_timer = -1.0
			game.alarm.raise_alarm(last_known, display_name)

	if sees_player:
		lost_timer = 0.0
		if radio_timer < 0.0:
			game.alarm.report_sighting(last_known)
		_face_towards(p.global_position, delta * 1.6)
		_combat_move(p, delta)
		_try_fire(p, delta)
	else:
		lost_timer += delta
		burst_left = 0
		var arrived := _move_to(last_known, chase_speed, delta)
		if arrived or lost_timer > 5.0:
			_enter_search(last_known)


## Default combat movement: keep preferred range and strafe.
func _combat_move(p: Player, delta: float) -> void:
	var to := p.global_position - global_position
	var d := to.length()
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = _rng.randf_range(0.8, 1.8)
		strafe_dir = -strafe_dir
	var desired := Vector2.ZERO
	if d > preferred_range * 1.2:
		_move_to(p.global_position, chase_speed, delta, false)
		return
	elif d < preferred_range * 0.6:
		desired = -to.normalized() * chase_speed * 0.8
	else:
		desired = to.normalized().orthogonal() * strafe_dir * chase_speed * 0.55
	velocity = velocity.move_toward(desired, 900.0 * delta)


func _try_fire(p: Player, delta: float) -> void:
	var d := global_position.distance_to(p.global_position)
	if burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			_shoot_at(p.global_position)
			burst_left -= 1
			burst_timer = burst_gap
		return
	if fire_timer <= 0.0 and d <= attack_range:
		var aim_err := absf(angle_difference(facing, (p.global_position - global_position).angle()))
		if aim_err < 0.3:
			burst_left = burst_count
			burst_timer = 0.0
			fire_timer = fire_interval + _rng.randf_range(0.0, 0.35)


func _shoot_at(target: Vector2) -> void:
	var base := (target - global_position).angle()
	var muzzle := global_position + Vector2.from_angle(base) * (body_radius + 8.0)
	for i in pellets:
		var a := base + _rng.randf_range(-spread, spread)
		if pellets > 1:
			a = base + lerpf(-spread, spread, float(i) / float(pellets - 1)) + _rng.randf_range(-0.03, 0.03)
		game.spawn_bullet(muzzle, Vector2.from_angle(a) * bullet_speed, bullet_damage, false, color)
	FX.flash(game.fx_layer, muzzle, color, 60.0, 0.08, 0.8)
	Sfx.play_at("enemy_shoot", global_position, -4.0)


func _state_search(delta: float) -> void:
	search_timer -= delta
	if game.alarm.level == AlarmSystem.Level.ALARM:
		search_timer = maxf(search_timer, 2.0)
		if game.alarm.last_known.distance_to(search_center) > 260.0:
			search_center = game.alarm.last_known
			search_points.clear()
	if search_timer <= 0.0:
		_return_to_patrol()
		return
	if search_points.is_empty():
		_build_search_points()
	if look_timer > 0.0:
		look_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		facing = look_base + sin(anim_t * 2.4) * 1.3
		return
	var spd := chase_speed * (0.85 if game.alarm.level == AlarmSystem.Level.ALARM else 0.6)
	if _move_to(search_points[0], spd, delta):
		search_points.remove_at(0)
		look_timer = _rng.randf_range(0.8, 1.6)
		look_base = facing


func _build_search_points() -> void:
	search_points.append(search_center)
	var center_cell := facility.cell_of(search_center)
	for i in 3:
		for attempt in 12:
			var c := center_cell + Vector2i(_rng.randi_range(-6, 6), _rng.randi_range(-5, 5))
			if facility.is_walkable(c):
				search_points.append(facility.cell_center(c))
				break


# --------------------------------------------------------------------------
# Movement helpers
# --------------------------------------------------------------------------

## Follows an A* path towards `target`. Returns true once arrived.
func _move_to(target: Vector2, spd: float, delta: float, face_movement := true) -> bool:
	if global_position.distance_to(target) < 14.0:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return true
	# Repath immediately for a genuinely new destination (next waypoint);
	# otherwise (moving or unreachable target, exhausted path) only when the
	# repath timer allows - unreachable targets used to repath every tick.
	var new_destination := _path_target == Vector2.INF or _path_target.distance_to(target) > 96.0
	var target_moved := _path_target.distance_to(target) > 28.0
	var exhausted := _path.is_empty() or _path_i >= _path.size()
	if new_destination or ((exhausted or target_moved) and _repath_timer <= 0.0):
		_path = facility.find_path(global_position, target)
		_path_i = 0
		_path_target = target
		_repath_timer = 0.45 + _rng.randf() * 0.15
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) < 12.0:
		_path_i += 1
	var waypoint := target
	if _path_i < _path.size():
		waypoint = _path[_path_i]
	elif not _path.is_empty():
		# Path exhausted but target not reached (partial path): give up on it.
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return global_position.distance_to(_path[_path.size() - 1]) < 20.0
	var dir := (waypoint - global_position).normalized()
	velocity = velocity.move_toward(dir * spd, 1400.0 * delta)
	if face_movement and velocity.length() > 15.0:
		facing = lerp_angle(facing, velocity.angle(), minf(1.0, delta * turn_rate))
	return false


func _face_towards(pos: Vector2, delta: float) -> void:
	facing = lerp_angle(facing, (pos - global_position).angle(), minf(1.0, delta * turn_rate))


func _apply_separation() -> void:
	var push := Vector2.ZERO
	for other in game.enemy_list:
		if other == self or not is_instance_valid(other):
			continue
		var d: Vector2 = global_position - other.global_position
		var l := d.length()
		if l > 0.01 and l < 28.0:
			push += d / l * (28.0 - l)
	velocity += push * 6.0


# --------------------------------------------------------------------------
# Damage
# --------------------------------------------------------------------------

func take_damage(amount: float, from_pos: Vector2, silent := false, knockback := 110.0) -> void:
	if state == State.DEAD:
		return
	amount = _absorb(amount, from_pos)
	hp -= amount
	hit_flash = 1.0
	velocity += (global_position - from_pos).normalized() * knockback * knockback_scale
	# Flinch: a short stagger interrupts bursts so hits feel impactful, but
	# with a cooldown so rapid fire can't stun-lock an enemy forever.
	if amount > 0.0 and anim_t - _last_flinch > 0.7:
		_last_flinch = anim_t
		burst_left = 0
		fire_timer = maxf(fire_timer, 0.18)
	Sfx.play_at("enemy_hit", global_position, -3.0)
	if amount > 0.0:
		FX.float_text(game.fx_layer, global_position + Vector2(_rng.randf_range(-8, 8), -22), str(int(round(minf(amount, max_hp)))), Palette.WHITE, 13)
	if hp <= 0.0:
		_die(silent)
		return
	if state != State.CHASE:
		if game.player != null:
			last_known = game.player.global_position
		facing = (from_pos - global_position).angle()
		_enter_chase()


## Hook for shields/armor. Returns the damage that gets through.
func _absorb(amount: float, _from_pos: Vector2) -> float:
	return amount


## Bosses and alert armored units can't be one-shot by the claw.
func can_be_taken_down() -> bool:
	return true


func _die(silent: bool) -> void:
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	cone = PackedVector2Array()
	_cone_node.queue_redraw()
	FX.burst(game.fx_layer, global_position, color, 22, 300.0, 0.6, 3.5)
	FX.burst(game.fx_layer, global_position, Palette.WHITE, 10, 200.0, 0.3, 2.0)
	FX.flash(game.fx_layer, global_position, color, 140.0, 0.3, 0.9)
	Sfx.play_at("explode", global_position, -4.0 if not silent else -10.0)
	z_index = -2
	modulate = Color(0.45, 0.45, 0.55, 0.8)
	# Corpses can be discovered by patrols unless they lie in shadow.
	if not facility.is_shadow(global_position):
		add_to_group("corpses")
	queue_redraw()
	died.emit(self)
	game.on_enemy_killed(self, silent)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _cone_color() -> Color:
	match state:
		State.CHASE:
			return Palette.RED
		State.SUSPICIOUS:
			return Palette.YELLOW
		State.SEARCH:
			return Palette.ORANGE
	return Color(0.75, 0.85, 1.0)


func _draw_cone() -> void:
	if state == State.DEAD or cone.size() < 3:
		return
	var c := _cone_color()
	var fill := Palette.with_alpha(c, 0.07 + 0.08 * awareness)
	_cone_node.draw_colored_polygon(cone, fill)
	var outline := cone.duplicate()
	outline.append(cone[0])
	_cone_node.draw_polyline(outline, Palette.with_alpha(c, 0.22), 1.0, true)


func _draw() -> void:
	if state == State.DEAD:
		_draw_wreck()
		return
	draw_circle(Vector2(0, 4), body_radius + 3.0, Color(0, 0, 0, 0.35))
	_draw_body()
	_draw_indicator()
	if hp < max_hp:
		var w := body_radius * 2.4
		var y := body_radius + 8.0
		draw_rect(Rect2(-w * 0.5, y, w, 3.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 3.0), color.lerp(Palette.WHITE, 0.3))


## Override in subclasses.
func _draw_body() -> void:
	draw_circle(Vector2.ZERO, body_radius, Color(0.12, 0.08, 0.1))
	draw_arc(Vector2.ZERO, body_radius, 0, TAU, 24, _line_color(), 2.0, true)


func _draw_wreck() -> void:
	draw_circle(Vector2.ZERO, body_radius * 0.9, Color(0.07, 0.06, 0.09))
	draw_arc(Vector2.ZERO, body_radius * 0.9, 0.3, 2.4, 8, Palette.with_alpha(color, 0.4), 1.5)
	draw_arc(Vector2.ZERO, body_radius * 0.9, 3.4, 5.4, 8, Palette.with_alpha(color, 0.4), 1.5)


func _line_color() -> Color:
	return color.lerp(Palette.WHITE, hit_flash)


func _draw_indicator() -> void:
	var top := Vector2(0, -body_radius - 18.0)
	var f := FX.font()
	match state:
		State.CHASE:
			draw_string(f, top + Vector2(-5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.RED)
			if radio_timer > 0.0:
				var k := 1.0 - radio_timer / radio_delay
				draw_arc(top, 13.0, -PI * 0.5, -PI * 0.5 + TAU * k, 20, Palette.RED, 2.5, true)
				draw_arc(top, 13.0, 0, TAU, 20, Palette.with_alpha(Palette.RED, 0.25), 1.0, true)
		State.SUSPICIOUS, State.SEARCH:
			var col := Palette.YELLOW if state == State.SUSPICIOUS else Palette.ORANGE
			draw_string(f, top + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
			draw_arc(top, 12.0, -PI * 0.5, -PI * 0.5 + TAU * awareness, 20, col, 2.0, true)
		State.PATROL:
			if awareness > 0.02:
				draw_arc(top, 10.0, -PI * 0.5, -PI * 0.5 + TAU * awareness, 20, Palette.YELLOW, 2.0, true)
