extends Node2D
## The level scene: builds a street from scripts/data/levels.gd and runs the
## fixed-step game loop. Owns the camera, hit resolution, hit-stop, the attack
## token budget, pickups, props, hazards and the level flow:
##   intro -> play -> (exit walk | boss K.O.) -> results     or  -> gameover

const Levels = preload("res://scripts/data/levels.gd")
const B = preload("res://scripts/data/balance.gd")
const EncounterManager = preload("res://scripts/level/encounter_manager.gd")
const StagePainter = preload("res://scripts/gfx/stage_painter.gd")
const FxLayer = preload("res://scripts/gfx/fx.gd")
const PickupNode = preload("res://scripts/level/pickup.gd")
const PropNode = preload("res://scripts/level/prop.gd")
const HazardNode = preload("res://scripts/level/hazard.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const Overlays = preload("res://scripts/ui/level_overlays.gd")
const ENEMY_SCRIPTS := {
	"punk": preload("res://scripts/actors/enemies/punk.gd"),
	"brawler": preload("res://scripts/actors/enemies/brawler.gd"),
	"runner": preload("res://scripts/actors/enemies/runner.gd"),
	"thrower": preload("res://scripts/actors/enemies/thrower.gd"),
	"enforcer": preload("res://scripts/actors/enemies/enforcer.gd"),
}
const BOSS_SCRIPTS := {
	"slick": preload("res://scripts/bosses/slick.gd"),
	"bruno": preload("res://scripts/bosses/bruno.gd"),
	"snowmane": preload("res://scripts/bosses/snowmane.gd"),
	"lardpaw": preload("res://scripts/bosses/lardpaw.gd"),
}
const ZOOM := 1.35
const HALF_W := 640.0 / ZOOM
const CAM_Y := 720.0 - 360.0 / ZOOM
const COMIC := ["POW!", "WHAM!", "BONK!", "THWACK!", "SMACK!", "KAPOW!"]

signal level_finished(result: Dictionary)

var data := {}
var length := 4000.0
var ymin := 450.0
var ymax := 670.0
var player: Player
var world: Node2D
var stage: Node2D
var fx: Node2D
var cam: Camera2D
var hud: Node
var overlays: Node
var enemies_list: Array = []
var projectiles: Array = []
var props: Array = []
var pickups: Array = []
var hazards: Array = []
var obstacles: Array = []  ## Rect2 footprints of solid scenery
var enc: EncounterManager
var locked := false
var arena_cx := 640.0
var cam_x := 640.0
var shake_amt := 0.0
var shake_t := 0.0
var hitstop := 0
var tokens: Array = []
var ranged_cd := 0.0
var flow := "intro"
var flow_t := 0.0
var boss: Node = null
var boss_level := false
var hint_i := 0
var exit_x := 0.0
var drop_n := 0
var result := {}
var slowmo_until := 0
var comic_i := 0
var respawn_t := -1.0


func _ready() -> void:
	data = Game.level_data()
	length = float(data["length"])
	ymin = float(data["depth"][0])
	ymax = float(data["depth"][1])
	boss_level = Levels.has_boss(Game.level_index)
	exit_x = length - 220.0
	stage = StagePainter.new()
	stage.setup(String(data["theme"]), length)
	stage.exit_x = exit_x
	add_child(stage)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	fx = FxLayer.new()
	add_child(fx)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(ZOOM, ZOOM)
	for o: Dictionary in data["obstacles"]:
		obstacles.append(Rect2(float(o["x0"]), float(o["y0"]), float(o["x1"]) - float(o["x0"]), float(o["y1"]) - float(o["y0"])))
		var deco := ObstacleNode.new()
		deco.setup(String(o["kind"]), obstacles.back())
		world.add_child(deco)
	_build_props_and_pickups()
	for hz: Dictionary in data["hazards"]:
		var h := HazardNode.new()
		h.setup(hz)
		world.add_child(h)
		hazards.append(h)
	enc = EncounterManager.new()
	enc.setup(self, data["encounters"], Game.checkpoint)
	enc.seed_base = 1000 + Game.level_index * 100 + Game.checkpoint * 10
	player = Player.new()
	player.level = self
	player.position = Vector2(_spawn_x(), (ymin + ymax) * 0.5)
	world.add_child(player)
	cam_x = clampf(player.position.x + 200.0, HALF_W, length - HALF_W)
	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	overlays = Overlays.new()
	add_child(overlays)
	overlays.setup(self)
	if Game.checkpoint == 0:
		Game.save_run_position()
	Audio.play_music(String(data["music"]))
	player.control_locked = true
	var sub := String(data["name"]).to_upper()
	show_banner("STREET %d" % int(data["num"]), sub, 2.4)
	if Game.checkpoint > 0:
		hud.show_hint("Back at the checkpoint - go get 'em!", 2.5)
	_update_camera(1.0)


func _spawn_x() -> float:
	if Game.checkpoint <= 0:
		return 160.0
	var ci := mini(Game.checkpoint, (data["encounters"] as Array).size())
	var prev: Dictionary = data["encounters"][ci - 1]
	return minf(float(prev["x"]) + 200.0, length - 300.0)


func _build_props_and_pickups() -> void:
	for i in (data["pickups"] as Array).size():
		var pd: Dictionary = data["pickups"][i]
		var uid := "pk%d" % i
		if not Game.consumed.has(uid):
			_add_pickup(String(pd["kind"]), uid, Vector2(float(pd["x"]), float(pd["y"])), false)
	for i in (data["props"] as Array).size():
		var d: Dictionary = data["props"][i]
		var uid := "pr%d" % i
		var pos := Vector2(float(d["x"]), float(d["y"]))
		if Game.consumed.has(uid):
			# Prop already broken earlier in this attempt: its drop may still lie there.
			var drop := String(d.get("drop", ""))
			if drop != "" and not Game.consumed.has(uid + "d"):
				_add_pickup(drop, uid + "d", pos, false)
			continue
		var p := PropNode.new()
		p.setup(String(d["kind"]), uid, pos, String(d.get("drop", "")))
		world.add_child(p)
		props.append(p)


func _add_pickup(kind: String, uid: String, pos: Vector2, popped: bool) -> Node2D:
	var pk := PickupNode.new()
	pk.setup(kind, uid, pos, popped)
	world.add_child(pk)
	pickups.append(pk)
	return pk


# ================================================================== loop
func _physics_process(dt: float) -> void:
	if slowmo_until > 0 and Time.get_ticks_msec() >= slowmo_until:
		slowmo_until = 0
		Engine.time_scale = 1.0
	flow_t += dt
	fx.tick(dt)
	if hitstop > 0:
		hitstop -= 1
		_update_camera(dt)
		return
	if flow in ["play", "exit"]:
		Game.attempt["time"] = float(Game.attempt["time"]) + dt
	player.tick(dt)
	for e: Node in enemies_list.duplicate():
		if is_instance_valid(e):
			e.tick(dt)
	for p: Node in projectiles.duplicate():
		if is_instance_valid(p):
			p.tick(dt)
	for h: Node in hazards:
		h.tick(dt, self)
	for pk: Node in pickups.duplicate():
		pk.tick(dt, self)
		_check_pickup(pk)
	if flow == "play":
		enc.tick(dt)
	ranged_cd -= dt
	_flow_tick(dt)
	_update_camera(dt)
	_check_hints()
	if respawn_t >= 0.0:
		respawn_t -= dt
		if respawn_t < 0.0:
			_respawn_player()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and flow in ["play", "exit", "intro"] and not get_tree().paused:
		overlays.open_pause()


func _flow_tick(_dt: float) -> void:
	match flow:
		"intro":
			if flow_t >= 1.1:
				player.control_locked = false
				flow = "play"
				flow_t = 0.0
		"exit":
			if player.position.x >= exit_x - 40.0 and not player.dead:
				_finish_level()
		"boss_ko":
			if flow_t >= 1.2 and player.state in ["idle", "walk", "run"]:
				player.set_state("victory")
				player.control_locked = true
			if flow_t >= 3.6:
				_finish_level()


# ================================================================== camera
func _update_camera(dt: float) -> void:
	var target: float
	if locked:
		target = arena_cx
	else:
		target = clampf(player.position.x + player.facing * 60.0, HALF_W, length - HALF_W)
		target = maxf(target, cam_x)
	cam_x = lerpf(cam_x, target, 1.0 - exp(-6.0 * dt))
	cam.position = Vector2(cam_x, CAM_Y)
	if shake_t > 0.0 and Settings.screen_shake:
		shake_t -= dt
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt * clampf(shake_t * 6.0, 0.0, 1.0)
	else:
		cam.offset = Vector2.ZERO
	stage.cam_x = cam_x


func shake(amount: float, time: float) -> void:
	shake_amt = maxf(shake_amt if shake_t > 0.0 else 0.0, amount)
	shake_t = maxf(shake_t, time)


func lock_arena(x: float) -> void:
	arena_cx = clampf(x, HALF_W, length - HALF_W)
	locked = true
	tokens.clear()


func unlock_arena() -> void:
	locked = false


func arena_rect() -> Rect2:
	var cx := arena_cx if locked else cam_x
	return Rect2(cx - HALF_W + 30.0, ymin, HALF_W * 2.0 - 60.0, ymax - ymin)


func view_rect() -> Rect2:
	return Rect2(cam_x - HALF_W, CAM_Y - 360.0 / ZOOM, HALF_W * 2.0, 720.0 / ZOOM)


func clamp_to_arena(p: Vector2) -> Vector2:
	var r := arena_rect()
	var q := Vector2(clampf(p.x, r.position.x + 20.0, r.end.x - 20.0), clampf(p.y, r.position.y, r.end.y))
	for o: Rect2 in solid_rects():
		if o.grow(4.0).has_point(q):
			q.y = o.end.y + 6.0 if o.end.y + 6.0 <= ymax else o.position.y - 6.0
	return q


# ================================================================== world rules
func solid_rects() -> Array:
	var out: Array = obstacles.duplicate()
	for p: Node in props:
		if not p.broken:
			out.append(p.footprint())
	return out


## Keeps characters on the street: level/arena bounds, depth band and solid
## obstacles (pushed out on the side they came from).
func constrain(f, old: Vector2, p: Vector2) -> Vector2:
	var x0 := 20.0
	var x1 := length - 20.0
	if f != null and f is Enemy and f.state == "enter":
		x0 = -400.0
		x1 = length + 400.0
	elif f != null:
		if locked:
			x0 = arena_cx - HALF_W + 24.0
			x1 = arena_cx + HALF_W - 24.0
		elif f == player:
			x0 = maxf(x0, cam_x - HALF_W + 24.0)
	p.x = clampf(p.x, x0, x1)
	p.y = clampf(p.y, ymin, ymax)
	if f == null:
		return p
	var hw: float = minf(float(f.hurt_w) * 0.6, 24.0)
	for r: Rect2 in solid_rects():
		var g := r.grow_individual(hw, 3.0, hw, 3.0)
		if not g.has_point(p):
			continue
		if old.x <= g.position.x:
			p.x = g.position.x - 0.01
		elif old.x >= g.end.x:
			p.x = g.end.x + 0.01
		elif old.y <= g.position.y and g.position.y - 0.01 >= ymin:
			p.y = g.position.y - 0.01
		elif old.y >= g.end.y and g.end.y + 0.01 <= ymax:
			p.y = g.end.y + 0.01
		else:
			p.x = g.position.x - 0.01 if p.x - g.position.x < g.end.x - p.x else g.end.x + 0.01
	return p


func enemies() -> Array:
	return enemies_list.filter(func(e: Node) -> bool: return is_instance_valid(e) and not e.dead)


func all_fighters() -> Array:
	var out: Array = [player]
	out.append_array(enemies())
	return out


func player_unavailable() -> bool:
	return player.dead or player.state in ["dead_wait", "victory"]


# ================================================================== combat
## Resolves one frame of an active attack against the opposing side.
func resolve_attack(attacker: Node2D, atk: Dictionary, target_team := "", exclude: Node = null) -> bool:
	if atk.is_empty():
		return false
	var team: String = target_team
	if team == "":
		team = "enemy" if attacker.get("team") == "player" else "player"
	var targets: Array = [player] if team == "player" else enemies()
	var landed := false
	var az: float = float(attacker.get("z"))
	var af: int = int(attacker.get("facing"))
	for t: Node in targets:
		if t == attacker or t == exclude or t in atk["hit"] or not t.can_be_hit():
			continue
		if Fighter.overlaps(attacker.position, az, af, atk, t):
			atk["hit"].append(t)
			if t.receive_hit(atk, attacker):
				landed = true
				_on_hit(attacker, t, atk)
	if team == "enemy" and atk.get("owner") == player:
		for pr: Node in props:
			if pr.broken or pr in atk["hit"]:
				continue
			if Fighter.overlaps(attacker.position, az, af, atk, pr):
				atk["hit"].append(pr)
				pr.receive_hit(atk, attacker)
				play_sfx("crate", -4.0, 0.15)
				fx.spark(pr.position + Vector2(0, -30), 0.6, Color(1, 0.8, 0.5))
				hitstop = maxi(hitstop, 2)
				if pr.hits_left <= 0:
					_break_prop(pr)
	return landed


func _on_hit(attacker: Node2D, t: Node, atk: Dictionary) -> void:
	var typ := String(atk.get("type", "light"))
	var heavy := typ != "light"
	hitstop = maxi(hitstop, 5 if heavy else 3)
	var hp_pos: Vector2 = t.position + Vector2(0, -float(t.z) - float(t.body_h) * 0.55)
	fx.spark(hp_pos, 1.3 if heavy else 0.8, Color(1, 0.95, 0.5) if t != player else Color(1, 0.5, 0.4))
	if heavy:
		shake(6.0 if t != player else 4.0, 0.15)
	var owner: Node = atk.get("owner")
	if owner == player and t != player:
		register_hit(player, t, float(atk.get("dmg", 0.0)))
		if heavy and comic_i % 2 == 0:
			fx.comic(hp_pos + Vector2(0, -40), COMIC[comic_i / 2 % COMIC.size()], Color("ffd23a"))
		comic_i += 1
	elif t == player:
		Game.attempt["damage"] = float(Game.attempt["damage"]) + float(atk.get("dmg", 0.0))


## Credits the player for a hit (combo counter, energy, damage number).
func register_hit(_by: Node, t: Node, dmg: float) -> void:
	player.on_hit_landed(t, dmg)
	Game.attempt["best_combo"] = maxi(int(Game.attempt["best_combo"]), player.hit_count)
	fx.text(t.position + Vector2(randf_range(-12, 12), -float(t.z) - float(t.body_h) - 10.0), str(int(round(dmg))), Color.WHITE, 18, 0.5, 70.0)
	Game.add_score(10)


func combo_bonus(n: int) -> void:
	var pts := Game.add_score(n * n * 5)
	fx.text(player.position + Vector2(0, -150), "%d HIT COMBO  +%d" % [n, pts], Color("7ab8ff"), 22, 1.2)
	play_sfx("combo", -2.0)
	_check_life()


func request_token(e: Node) -> bool:
	tokens = tokens.filter(func(x: Node) -> bool: return is_instance_valid(x) and not x.dead and x.has_token)
	if e in tokens:
		return true
	if tokens.size() < int(Game.diff()["attackers"]):
		tokens.append(e)
		return true
	return false


func release_token(e: Node) -> void:
	tokens.erase(e)


func ranged_ready(_e: Node) -> bool:
	if ranged_cd <= 0.0:
		ranged_cd = 1.3 / float(Game.diff()["aggro"])
		return true
	return false


func hazard_hit(hz: Node, f: Node) -> void:
	var a: Dictionary = hz.attack_data()
	var atk: Dictionary = player.make_attack(a, 1.5 if f != player else 1.0)
	atk["owner"] = hz
	if f.receive_hit(atk, hz):
		fx.spark(f.position + Vector2(0, -40), 1.0, Color(0.6, 0.9, 1.0) if hz.kind == "puddle" else Color(1, 0.8, 0.3))
		play_sfx("electric" if hz.kind == "puddle" else "hit_heavy", -2.0)
		hitstop = maxi(hitstop, 3)
		if f == player:
			Game.attempt["damage"] = float(Game.attempt["damage"]) + float(atk["dmg"])
		else:
			fx.text(f.position + Vector2(0, -float(f.body_h) - 20.0), "ZAP!" if hz.kind == "puddle" else "CRUNCH!", Color("7ad8ff"), 20)


# ================================================================== spawning
func spawn_enemy(kind: String, side: int, seed_value: int) -> Node:
	var e: Enemy = ENEMY_SCRIPTS[kind].new()
	e.setup(kind, self, seed_value)
	var r := arena_rect()
	var x := r.end.x + 90.0 if side > 0 else r.position.x - 90.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := rng.randf_range(ymin + 12.0, ymax - 12.0)
	for i in 6:
		var ok := true
		for o: Rect2 in solid_rects():
			if y >= o.position.y - 8.0 and y <= o.end.y + 8.0 and absf(o.get_center().x - x) < 400.0:
				ok = false
		if ok:
			break
		y = rng.randf_range(ymin + 12.0, ymax - 12.0)
	e.position = Vector2(x, y)
	e.facing = -side
	e.set_state("enter")
	world.add_child(e)
	enemies_list.append(e)
	return e


func spawn_boss(id: String) -> Node:
	var b: Boss = BOSS_SCRIPTS[id].new()
	b.setup_boss(id, self, 7000 + Game.level_index)
	var r := arena_rect()
	b.position = Vector2(r.end.x + 160.0, (ymin + ymax) * 0.5)
	world.add_child(b)
	enemies_list.append(b)
	boss = b
	hud.show_boss(b)
	Audio.play_music(String(data.get("boss_music", "boss")))
	return b


func boss_intro(b: Node) -> void:
	show_banner(String(b.display_name), String(b.title), 2.0)
	play_sfx("boss_roar", 2.0)
	shake(8.0, 0.4)


func summon(kinds: Array) -> void:
	enc.summon(kinds)
	fx.comic(boss.position + Vector2(0, -200) if boss else player.position, "GET HIM, BOYS!", Color("ff6a6a"))


func add_projectile(p: Node) -> void:
	world.add_child(p)
	projectiles.append(p)


func remove_actor(n: Node) -> void:
	enemies_list.erase(n)
	projectiles.erase(n)
	tokens.erase(n)
	if is_instance_valid(n):
		n.queue_free()


func spawn_drop(kind: String, pos: Vector2) -> void:
	drop_n += 1
	_add_pickup(kind, "drop%d" % drop_n, clamp_to_arena(pos) if locked else pos, true)


func _break_prop(pr: Node) -> void:
	pr.broken = true
	props.erase(pr)
	Game.consumed[pr.uid] = true
	play_sfx("crate", 0.0)
	fx.debris(pr.position, Color("b07a3a") if pr.kind in ["crate", "stall"] else Color("8a94a0"))
	Game.add_score(50)
	if pr.drop != "":
		_add_pickup(pr.drop, pr.uid + "d", pr.position + Vector2(0, 2), true)
	pr.queue_free()


func _check_pickup(pk: Node) -> void:
	if not pk.can_collect() or player.dead:
		return
	if absf(pk.position.x - player.position.x) > 36.0 or absf(pk.position.y - player.position.y) > 22.0 or player.z > 30.0:
		return
	pk.collected = true
	Game.consumed[pk.uid] = true
	var info: Dictionary = B.PICKUPS[pk.kind]
	var top: Vector2 = player.position + Vector2(0, -130)
	if float(info["heal"]) > 0.0:
		Game.attempt["food"] = int(Game.attempt["food"]) + 1
		var healed: float = player.heal(float(info["heal"]))
		if healed > 0.0:
			fx.text(top, "+%d HP" % int(round(healed)), Color("8aff7a"), 24, 1.0)
		else:
			Game.add_score(200)
			fx.text(top, "FULL! +200", Color("ffd23a"), 22, 1.0)
		play_sfx("food", 0.0)
	else:
		if pk.kind == "golden":
			Game.attempt["golden"] = true
			player.add_energy(float(info.get("energy", 0.0)))
			fx.text(top + Vector2(0, -26), "GOLDEN FISH!", Color("ffd23a"), 26, 1.4)
		play_sfx("score", 0.0)
	var pts := Game.add_score(int(info["score"]))
	fx.text(top + Vector2(0, 26), "+%d" % pts, Color.WHITE, 18, 0.8)
	fx.sparkle(pk.position + Vector2(0, -16))
	_check_life()
	pickups.erase(pk)
	pk.queue_free()


func _check_life() -> void:
	if Game.check_extra_life():
		play_sfx("life", 0.0)
		fx.text(player.position + Vector2(0, -180), "EXTRA LIFE!", Color("ff6aa0"), 28, 1.6)


# ================================================================== events
func on_enemy_defeated(e: Node) -> void:
	Game.attempt["enemies"] = int(Game.attempt["enemies"]) + 1
	var pts := Game.add_score(int(e.score_value))
	if not e.is_boss:
		fx.text(e.position + Vector2(0, -float(e.body_h) - 30.0), "+%d" % pts, Color("ffd23a"), 20, 0.9)
		play_sfx("enemy_ko", -2.0, 0.1)
		if int(Game.attempt["enemies"]) % 3 == 0:
			play_sfx("meow", -6.0, 0.2)
	_check_life()


func on_boss_defeated(b: Node) -> void:
	Game.attempt["bosses"] = int(Game.attempt["bosses"]) + 1
	enc.kill_all()
	enc.finish_with_boss()
	for p: Node in projectiles.duplicate():
		remove_actor(p)
	flow = "boss_ko"
	flow_t = 0.0
	player.invuln = 99.0
	Engine.time_scale = 0.3
	slowmo_until = Time.get_ticks_msec() + 1100
	Audio.stop_music(0.3)
	play_sfx("victory", 2.0)
	shake(14.0, 0.6)
	fx.comic(b.position + Vector2(0, -float(b.body_h) - 40.0), "K.O.!", Color("ff4a4a"))
	show_banner("K.O.!", "%s is down!" % String(b.display_name), 2.6)
	hud.hide_boss()


func on_encounter_cleared(i: int, final: bool) -> void:
	Game.checkpoint = i + 1
	unlock_arena()
	tokens.clear()
	if final:
		if not boss_level:
			flow = "exit"
			flow_t = 0.0
			stage.exit_open = true
			show_banner("STREET CLEAR!", "Head for the next street  -->", 2.0)
			play_sfx("level_clear", 0.0)
	else:
		play_sfx("checkpoint", -2.0)
		hud.show_go()


func on_player_down() -> void:
	Game.attempt["deaths"] = int(Game.attempt["deaths"]) + 1
	Game.lives -= 1
	if Game.lives > 0:
		respawn_t = 0.6
	else:
		Game.lives = 0
		flow = "gameover"
		flow_t = 0.0
		Audio.stop_music(0.4)
		play_sfx("gameover", 0.0)
		overlays.open_game_over()


func _respawn_player() -> void:
	player.position = clamp_to_arena(player.position) if locked else player.position
	player.respawn()
	play_sfx("life", -2.0)
	fx.ring(player.position, 160.0, Color(1, 0.9, 0.5))
	# Clear some room: push nearby gang members over (no damage).
	var push := player.make_attack({"dmg": 0.0, "radial": true, "rx": 170.0, "depth": 60.0, "z0": -20.0, "z1": 200.0,
		"kb": 380.0, "launch": 300.0, "knockdown": true, "type": "special"})
	for e: Node in enemies():
		if e.is_boss:
			continue
		if Fighter.overlaps(player.position, 0.0, player.facing, push, e) and e.can_be_hit():
			e.knock_down(1 if e.position.x >= player.position.x else -1, 380.0, 300.0)
	hud.show_hint("Lives left: %d" % Game.lives, 1.6)


func _finish_level() -> void:
	if flow == "results":
		return
	flow = "results"
	player.control_locked = true
	Engine.time_scale = 1.0
	result = compute_result()
	result["record"] = Game.record_level_complete(result)
	if Game.level_index == Levels.count() - 1:
		Game.record_campaign_complete()
	Audio.stop_music(0.3)
	play_sfx("level_clear", 0.0)
	overlays.open_results(result)
	level_finished.emit(result)


## Score bonuses and rank for the results screen. Called exactly once.
func compute_result() -> Dictionary:
	var a: Dictionary = Game.attempt
	var par: float = float(data["par_time"])
	var time_bonus := Game.add_score(int(maxf(0.0, par - float(a["time"])) * 10.0))
	var hp_bonus := Game.add_score(int(player.hp) * 20)
	var nodmg_bonus := Game.add_score(5000) if float(a["damage"]) <= 0.0 else 0
	var pts := 100.0 - float(a["damage"]) * 0.2 - Game.continues_used * 20.0 - int(a["deaths"]) * 10.0
	if float(a["time"]) <= par:
		pts += 10.0
	var rank := "D"
	if pts >= 90.0:
		rank = "S"
	elif pts >= 75.0:
		rank = "A"
	elif pts >= 55.0:
		rank = "B"
	elif pts >= 35.0:
		rank = "C"
	var ch: Dictionary = data["challenge"]
	var ch_ok := false
	match String(ch["type"]):
		"combo": ch_ok = int(a["best_combo"]) >= int(ch["value"])
		"damage": ch_ok = float(a["damage"]) <= float(ch["value"])
		"no_special": ch_ok = player.specials_used == 0 and int(a["specials"]) == 0
		"no_death": ch_ok = int(a["deaths"]) == 0
	return {
		"level_score": Game.score - Game.level_start_score, "total_score": Game.score,
		"enemies": int(a["enemies"]), "damage": int(round(float(a["damage"]))), "food": int(a["food"]),
		"food_total": Levels.food_total(Game.level_index), "golden": bool(a["golden"]), "time": float(a["time"]),
		"deaths": int(a["deaths"]), "continues": Game.continues_used, "best_combo": int(a["best_combo"]),
		"time_bonus": time_bonus, "hp_bonus": hp_bonus, "nodmg_bonus": nodmg_bonus, "rank": rank,
		"challenge": ch_ok, "challenge_text": String(ch["text"]), "bosses": int(a["bosses"]),
	}


# ================================================================== presentation
func play_sfx(n: String, db := 0.0, pitch_var := 0.05) -> void:
	Audio.play(n, db, pitch_var)


func show_banner(title: String, sub: String, time: float) -> void:
	if hud:
		hud.show_banner(title, sub, time)


func _check_hints() -> void:
	var hints: Array = data["hints"]
	while hint_i < hints.size() and player.position.x >= float(hints[hint_i]["x"]):
		hud.show_hint(String(hints[hint_i]["text"]), 5.0)
		hint_i += 1


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Solid scenery (traffic barriers, crate walls, pillars): drawn, never breaks.
class ObstacleNode extends Node2D:
	var kind := "barrier"
	var rect := Rect2()

	func setup(k: String, r: Rect2) -> void:
		kind = k
		rect = r
		position = Vector2(r.get_center().x, r.end.y)

	func _draw() -> void:
		var w := rect.size.x
		var d := rect.size.y
		var ol := Color("2a2235")
		draw_rect(Rect2(-w * 0.5, -d, w, d), Color(0, 0, 0, 0.25))
		match kind:
			"barrier":
				for i in 2:
					var y := -d * (0.25 + 0.5 * i)
					var base := Rect2(-w * 0.5, y - 46, w, 30)
					draw_rect(base.grow(3.0), ol)
					draw_rect(base, Color("f4f0e6"))
					for k in 5:
						var x := -w * 0.5 + k * w / 5.0
						draw_colored_polygon(PackedVector2Array([Vector2(x, y - 46), Vector2(x + w / 10.0, y - 46), Vector2(x + w / 5.0, y - 16), Vector2(x + w / 10.0, y - 16)]), Color("e8413c"))
					draw_rect(Rect2(-w * 0.45, y - 16, 6, 16), ol)
					draw_rect(Rect2(w * 0.45 - 6, y - 16, 6, 16), ol)
				draw_circle(Vector2(-w * 0.4, -d * 0.75 - 54), 5, Color(1, 0.6, 0.1) if int(Time.get_ticks_msec() / 400) % 2 == 0 else Color(0.4, 0.2, 0.1))
			"crates":
				var n := int(w / 50.0)
				for row in 2:
					for i in n:
						var r2 := Rect2(-w * 0.5 + i * (w / n), -d * 0.35 - 56 - row * 50 - (d * 0.4 if i % 2 == 0 else 0.0), w / n - 4, 50)
						draw_rect(r2.grow(2.0), ol)
						draw_rect(r2, Color("a8703a") if (i + row) % 2 == 0 else Color("b8803a"))
						draw_line(r2.position, r2.end, Color("7a4a20"), 3.0)
			"pillar":
				draw_rect(Rect2(-w * 0.5, -d * 0.5 - 260, w, 260).grow(3.0), ol)
				draw_rect(Rect2(-w * 0.5, -d * 0.5 - 260, w, 260), Color("d8d4cc"))
				for k in 4:
					draw_line(Vector2(-w * 0.5 + 10 + k * (w - 20) / 3.0, -d * 0.5 - 250), Vector2(-w * 0.5 + 10 + k * (w - 20) / 3.0, -d * 0.5 - 10), Color("b0aaa0"), 3.0)
				draw_rect(Rect2(-w * 0.5 - 8, -d * 0.5 - 20, w + 16, 20), Color("bcb6ac"))
				draw_rect(Rect2(-w * 0.5 - 8, -d * 0.5 - 270, w + 16, 16), Color("bcb6ac"))
