extends Node2D
## A playable level: builds terrain, objects, enemies and the player from the
## level catalog, then runs checkpoints, death/retry, pickups, secrets,
## rescues, guardian fights and level completion.

signal pending_changed
signal boss_started(boss: Node)
signal boss_finished
signal completed(summary: Dictionary)

const LevelCatalog := preload("res://scripts/data/level_catalog.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const LevelGrid := preload("res://scripts/world/level_grid.gd")
const TileRenderer := preload("res://scripts/world/tile_renderer.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PauseScript := preload("res://scripts/ui/pause_menu.gd")
const OverlayScript := preload("res://scripts/ui/level_overlays.gd")

const OBJ := "res://scripts/objects/"
const ENEMY_SCRIPTS := {
	"s": preload("res://scripts/enemies/scout.gd"),
	"G": preload("res://scripts/enemies/guard.gd"),
	"A": preload("res://scripts/enemies/archer.gd"),
	"W": preload("res://scripts/enemies/mage.gd"),
	"B": preload("res://scripts/enemies/beast.gd"),
}
const BOSS_SCRIPTS := {
	"mouser": "res://scripts/bosses/iron_mouser.gd",
	"ember": "res://scripts/bosses/ember_guardian.gd",
	"frost": "res://scripts/bosses/frost_matron.gd",
	"stalker": "res://scripts/bosses/shadow_stalker.gd",
	"king": "res://scripts/bosses/pale_king.gd",
}
const RELIC_INDEX := {"mouser": 0, "ember": 1, "frost": 2, "stalker": 3, "king": 4}

var level_id := ""
var meta: Dictionary = {}
var grid: RefCounted
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var overlays: CanvasLayer
var region := 1

var objects: Node2D
var enemies_root: Node2D
var projectiles: Node2D
var fx_root: Node2D

var checkpoints: Array[Node] = []
var current_checkpoint: Node = null
var start_position := Vector2.ZERO
var exit_door: Node = null
var boss: Node = null
var boss_active := false
var boss_defeated := false
var boss_trigger_x := INF
var boss_gates: Array[Node] = []
var rising: Node = null
var _rising_trigger_y := INF

## Saved record for this level (what was banked on earlier runs).
var record: Dictionary = {}
## Things gathered on this attempt (survive deaths, discarded if the level is left).
var run_coins: Dictionary = {}
var run_items: Array[String] = []
var run_secrets: Array[String] = []
var run_gems: Array[String] = []
var run_cats: Array[String] = []
var run_relic := ""
var deaths := 0
var heals_used := 0
var boss_heals := 0
var level_time := 0.0
var secrets_total := 0
var gems_total := 0
var finished := false
var _shake := 0.0
var _shake_time := 0.0
var _dead_timer := -1.0
var _enemy_spawns: Array[Node] = []
var _crumbles: Array[Node] = []
var _icicles: Array[Node] = []


func _ready() -> void:
	if level_id == "":
		level_id = Transition.next_level_id if Transition.next_level_id != "" else "1-1"
	build(level_id)


func build(id: String) -> void:
	level_id = id
	meta = LevelCatalog.get_level(id)
	region = int(meta.get("region", 1))
	record = Progress.record(id)
	grid = LevelGrid.new()
	grid.parse(meta["map"])
	_build_background()
	var tiles := TileRenderer.new()
	tiles.name = "Tiles"
	tiles.z_index = -10
	add_child(tiles)
	tiles.setup(grid, region)
	_build_collision()
	objects = Node2D.new()
	objects.name = "Objects"
	add_child(objects)
	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	_build_player()
	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	fx_root = Node2D.new()
	fx_root.name = "FX"
	fx_root.z_index = 10
	add_child(fx_root)
	_spawn_entities()
	_build_camera()
	if meta.get("dark", false):
		var cm := CanvasModulate.new()
		cm.color = Color(0.2, 0.18, 0.3)
		add_child(cm)
		player.light.enabled = true
	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)
	pause_menu = PauseScript.new()
	pause_menu.name = "Pause"
	add_child(pause_menu)
	pause_menu.level = self
	overlays = OverlayScript.new()
	overlays.name = "Overlays"
	add_child(overlays)
	overlays.level = self
	Audio.play_music(meta.get("music", "r1"))
	hud.show_title("%s  %s" % [meta["id"].to_upper() if meta["id"] != "final" else "FINAL", meta["name"]],
		LevelCatalog.REGION_NAMES[region - 1])


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _build_background() -> void:
	var pb := ParallaxBackground.new()
	pb.name = "Parallax"
	add_child(pb)
	for i in 2:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(0.12, 0.05) if i == 0 else Vector2(0.35, 0.15)
		layer.motion_mirroring = Vector2(640, 0)
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/bg_r%d_%s.png" % [region, "far" if i == 0 else "mid"])
		s.centered = false
		s.scale = Vector2(2, 2)
		s.position = Vector2(0, -40)
		layer.add_child(s)
		pb.add_child(layer)


func _build_collision() -> void:
	var world := StaticBody2D.new()
	world.name = "World"
	world.collision_layer = 1
	world.collision_mask = 0
	add_child(world)
	for r: Rect2i in grid.merged_rects(func(x: int, y: int) -> bool: return grid.is_static_solid(x, y)):
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(r.size) * 16.0
		cs.shape = rs
		cs.position = Vector2(r.position) * 16.0 + rs.size / 2.0
		world.add_child(cs)
	var oneway := StaticBody2D.new()
	oneway.name = "OneWay"
	oneway.collision_layer = 64  # "oneway" layer: the player may drop through
	oneway.collision_mask = 0
	add_child(oneway)
	for r: Rect2i in grid.merged_rects(func(x: int, y: int) -> bool: return grid.is_oneway(x, y) and not grid.is_oneway(x, y - 1)):
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(r.size.x * 16.0, 6.0)
		cs.shape = rs
		cs.one_way_collision = true
		cs.position = Vector2(r.position.x * 16.0 + rs.size.x / 2.0, r.position.y * 16.0 + 3.0)
		oneway.add_child(cs)
	# Hazards: spikes (lower part of the tile) and pools.
	var haz := Area2D.new()
	haz.name = "Hazards"
	haz.collision_layer = 32
	haz.collision_mask = 2
	haz.monitorable = false
	add_child(haz)
	for y in grid.height:
		for x in grid.width:
			var c: String = grid.ch(x, y)
			if c == "^" or c == "v" or c == "L":
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				if c == "^":
					rs.size = Vector2(12, 7)
					cs.position = Vector2(x * 16 + 8, y * 16 + 12)
				elif c == "v":
					rs.size = Vector2(12, 7)
					cs.position = Vector2(x * 16 + 8, y * 16 + 4)
				else:
					var top: bool = grid.ch(x, y - 1) != "L"
					rs.size = Vector2(16, 10 if top else 16)
					cs.position = Vector2(x * 16 + 8, y * 16 + (11 if top else 8))
				cs.shape = rs
				haz.add_child(cs)
	haz.body_entered.connect(func(b: Node) -> void:
		if b == player:
			player.hazard_hit())


func _build_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.level = self
	add_child(player)
	start_position = grid.cell_floor(grid.start_cell)
	player.global_position = start_position
	player.safe_position = start_position
	player.light = PointLight2D.new()
	player.light.texture = Sprites.texture("light.png")
	player.light.texture_scale = 5.0
	player.light.energy = 1.05
	player.light.color = Color(0.85, 0.8, 1.0)
	player.light.position = Vector2(0, -10)
	player.light.enabled = false
	player.add_child(player.light)
	player.died.connect(_on_player_died)
	player.healed.connect(func(_a: int) -> void:
		heals_used += 1
		if boss_active:
			boss_heals += 1)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	var size: Vector2 = grid.pixel_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	add_child(camera)
	camera.global_position = player.global_position + Vector2(0, -30)
	camera.reset_smoothing()


func _obj(script_name: String) -> Node:
	return load(OBJ + script_name + ".gd").new()


func _spawn_entities() -> void:
	var sign_texts: Array = meta.get("signs", [])
	var sign_i := 0
	var cp_i := 0
	# Sign texts are listed left to right in the catalog.
	var sign_order: Dictionary = {}
	var sign_cells: Array = []
	for e in grid.entities_of("?"):
		sign_cells.append(e["cell"])
	sign_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in sign_cells.size():
		sign_order[sign_cells[i]] = i
	var whisper := Progress.has_cat("whisper")
	# Fake walls (secret passages) as one illusion node.
	var fake_cells: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			if grid.ch(x, y) == "%":
				fake_cells.append(Vector2i(x, y))
	if not fake_cells.is_empty():
		var fw := _obj("fake_wall")
		fw.cells = fake_cells
		fw.grid = grid
		fw.atlas = load("res://assets/sprites/tiles_r%d.png" % region)
		fw.shimmer = whisper
		fw.name = "FakeWalls"
		add_child(fw)
	# Secret zones ($ components).
	for comp in grid.components("$", true):
		var z := _obj("secret_zone")
		z.level = self
		z.cells.assign(comp)
		var first: Vector2i = comp[0]
		for c: Vector2i in comp:
			if c.y < first.y or (c.y == first.y and c.x < first.x):
				first = c
		z.key = "secret:%d,%d" % [first.x, first.y]
		objects.add_child(z)
		secrets_total += 1
	# Gates opened by levers, and boss gates.
	var lever_gates: Array[Node] = []
	for comp in grid.components("D"):
		var g := _obj("gate")
		g.cells.assign(comp)
		objects.add_child(g)
		lever_gates.append(g)
	for comp in grid.components("]"):
		var g := _obj("gate")
		g.cells.assign(comp)
		g.is_open = true
		objects.add_child(g)
		boss_gates.append(g)
	# Crumbling blocks.
	for y in grid.height:
		for x in grid.width:
			if grid.ch(x, y) == "~":
				var cb := _obj("crumble_block")
				cb.region = region
				cb.position = Vector2(x * 16, y * 16)
				objects.add_child(cb)
				_crumbles.append(cb)
	for e in grid.entities:
		var ch: String = e["ch"]
		var cell: Vector2i = e["cell"]
		var floor_pos: Vector2 = grid.cell_floor(cell)
		var center: Vector2 = grid.cell_center(cell)
		match ch:
			"X":
				exit_door = _obj("exit_door")
				exit_door.level = self
				exit_door.position = floor_pos
				exit_door.locked = meta.get("boss", "") != ""
				objects.add_child(exit_door)
			"K":
				var cp := _obj("checkpoint")
				cp.level = self
				cp.index = cp_i
				cp_i += 1
				cp.position = floor_pos
				objects.add_child(cp)
				checkpoints.append(cp)
			"o", "f", "g":
				var p := _obj("pickup")
				p.level = self
				p.kind = {"o": "coin", "f": "fish", "g": "gem"}[ch]
				p.key = "%s:%d,%d" % [p.kind, cell.x, cell.y]
				p.position = center
				if ch == "g":
					gems_total += 1
					p.ghost = record["gems"].has(p.key)
				elif ch == "o":
					p.ghost = record["items"].has(p.key)
				objects.add_child(p)
			"T":
				var t := _obj("chest")
				t.level = self
				t.key = "chest:%d,%d" % [cell.x, cell.y]
				t.opened = record["items"].has(t.key)
				t.position = floor_pos
				objects.add_child(t)
			"R":
				var cage := _obj("cage")
				cage.level = self
				cage.cat_id = meta.get("cat", "pip")
				cage.already_rescued = Progress.has_cat(cage.cat_id)
				cage.position = floor_pos
				objects.add_child(cage)
			"s", "G", "A", "W", "B":
				var en: Node = ENEMY_SCRIPTS[ch].new()
				en.level = self
				en.position = floor_pos
				en.facing = -1 if (cell.x % 2 == 0) else 1
				enemies_root.add_child(en)
				_enemy_spawns.append(en)
			"H", "V":
				var mp := _obj("moving_platform")
				var dir := Vector2i.RIGHT if ch == "H" else Vector2i.UP
				var n: int = grid.path_length(cell, dir, 4)
				mp.travel = Vector2(dir) * n * 16.0
				mp.position = center + Vector2(0, -4)
				objects.add_child(mp)
			"l":
				var lv := _obj("lever")
				lv.level = self
				lv.position = floor_pos
				var best: Node = null
				var best_d := INF
				for g in lever_gates:
					var gc: Vector2i = g.cells[0]
					var d := Vector2(gc).distance_to(Vector2(cell))
					if d < best_d:
						best_d = d
						best = g
				if best:
					lv.gates.append(best)
				objects.add_child(lv)
			"F":
				var fj := _obj("flame_jet")
				fj.position = floor_pos
				fj.offset = float(cell.x % 4) * 0.8
				objects.add_child(fj)
			"O":
				var sw := _obj("saw")
				sw.level = self
				sw.position = center
				sw.dir = 1.0 if cell.x % 2 == 0 else -1.0
				objects.add_child(sw)
			"Y":
				var ic := _obj("icicle")
				ic.level = self
				ic.position = Vector2(cell.x * 16 + 8, cell.y * 16)
				objects.add_child(ic)
				_icicles.append(ic)
			"J":
				var sp := _obj("spring")
				sp.position = floor_pos
				objects.add_child(sp)
			"t":
				var tc := _obj("torch")
				tc.position = center
				objects.add_child(tc)
			"?":
				var sg := _obj("sign")
				sign_i = sign_order.get(cell, 0)
				sg.text = sign_texts[sign_i] if sign_i < sign_texts.size() else "..."
				sg.position = floor_pos
				objects.add_child(sg)
			"!":
				boss_trigger_x = minf(boss_trigger_x, cell.x * 16.0)
			"r":
				rising = _obj("rising_hazard")
				rising.level = self
				rising.width = grid.pixel_size().x
				rising.start_y = (grid.height + 2) * 16.0
				rising.speed = float(meta.get("rise_speed", 18.0))
				add_child(rising)
				_rising_trigger_y = floor_pos.y
			"1", "2", "3", "4", "5":
				var bid: String = meta.get("boss", "mouser")
				boss = load(BOSS_SCRIPTS[bid]).new()
				boss.level = self
				boss.position = floor_pos
				boss.boss_defeated.connect(_on_boss_defeated)
				enemies_root.add_child(boss)


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not finished and not player.is_dead():
		level_time += delta
	# Camera follows with a little look-ahead.
	var look := Vector2(player.facing * 28.0, -24.0)
	camera.global_position = player.global_position + look
	if _shake_time > 0.0:
		_shake_time -= delta
		var amt := _shake if Settings.screen_shake else 0.0
		camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	else:
		camera.offset = Vector2.ZERO
	if boss and not boss_active and not boss_defeated and player.global_position.x >= boss_trigger_x and not player.is_dead():
		start_boss_fight()
	if rising and not rising.active and player.global_position.y < _rising_trigger_y - 8:
		rising.start()
		toast("The pale fire is rising - climb!")
	if _dead_timer >= 0.0:
		_dead_timer -= delta
		if _dead_timer < 0.0:
			overlays.show_death()


func shake(amount: float, time: float) -> void:
	_shake = maxf(_shake if _shake_time > 0 else 0.0, amount)
	_shake_time = maxf(_shake_time, time)


func hitstop(time: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(time, true, false, true).timeout
	Engine.time_scale = 1.0


func toast(text: String, color := Color.WHITE) -> void:
	if hud:
		hud.toast(text, color)


# --------------------------------------------------------------------------
# Queries used by the player, enemies and objects
# --------------------------------------------------------------------------

func is_ice_below(pos: Vector2) -> bool:
	var c: Vector2i = grid.cell_of(pos + Vector2(0, 2))
	return grid.is_ice(c.x, c.y)


func is_safe_ground(pos: Vector2) -> bool:
	for dx in [-5.0, 5.0]:
		var c: Vector2i = grid.cell_of(pos + Vector2(dx, 2))
		if not grid.is_static_solid(c.x, c.y):
			return false
	var me: Vector2i = grid.cell_of(pos + Vector2(0, -2))
	for x in range(me.x - 1, me.x + 2):
		if grid.is_hazard(x, me.y) or grid.is_hazard(x, me.y + 1):
			return false
	return true


func is_below_map(pos: Vector2) -> bool:
	return pos.y > grid.pixel_size().y + 24.0


func floor_below(pos: Vector2) -> Vector2:
	var c: Vector2i = grid.cell_of(pos + Vector2(0, -4))
	for y in range(c.y, mini(c.y + 12, grid.height + 1)):
		if grid.is_solid(c.x, y) or grid.is_oneway(c.x, y):
			return Vector2(pos.x, y * 16)
	return pos


func add_projectile(p: Node) -> void:
	projectiles.add_child(p)


func clear_projectiles() -> void:
	for p in projectiles.get_children():
		p.queue_free()


# --------------------------------------------------------------------------
# Events from objects
# --------------------------------------------------------------------------

func pending_coins() -> int:
	var t := 0.0
	for k in run_coins:
		t += float(run_coins[k])
	return int(round(t))


func on_pickup(p: Node, by: Node) -> void:
	match p.kind:
		"coin":
			if p.ghost:
				Audio.play("coin", -12.0)
				return
			run_coins[p.key] = 1.0 * Progress.coin_multiplier()
			Audio.play("coin", -4.0)
			pending_changed.emit()
		"fish":
			by.heal(Progress.heal_amount())
			Audio.play("heal")
			Fx.float_text(self, p.global_position, "+%s" % _hearts_text(Progress.heal_amount()), Color(1, 0.6, 0.6))
		"gem":
			if not p.ghost and not run_gems.has(p.key):
				run_gems.append(p.key)
				toast("Shadow Gem found!", Color(0.8, 0.6, 1.0))
			Audio.play("gem")
			Fx.burst(self, p.global_position, Color(0.7, 0.4, 1.0), 16)
			pending_changed.emit()
		"relic":
			run_relic = meta.get("boss", "")
			Audio.play("gem")
			Audio.play("secret")
			Fx.burst(self, p.global_position, Color(1, 0.9, 0.5), 24)
			toast("Relic recovered: %s" % meta.get("relic_name", "Ancient Relic"), Color(1, 0.9, 0.5))


func _hearts_text(halves: int) -> String:
	return "%s hearts" % (str(halves / 2) + (".5" if halves % 2 else "")) if halves != 2 else "1 heart"


func on_checkpoint(cp: Node, by: Node) -> void:
	current_checkpoint = cp
	Audio.play("checkpoint")
	if Progress.has_cat("flurry"):
		by.heal(by.max_hp)
	else:
		by.heal(2)
	heals_used = maxi(heals_used - 1, 0)  # checkpoint healing does not count as eating fish
	if boss_active:
		boss_heals = maxi(boss_heals - 1, 0)
	toast("Checkpoint lit")


func on_chest(chest: Node) -> void:
	if record["items"].has(chest.key):
		return
	run_coins[chest.key] = chest.VALUE * Progress.coin_multiplier()
	Fx.burst(self, chest.global_position + Vector2(0, -10), Color(1, 0.85, 0.3), 24, 120)
	Fx.float_text(self, chest.global_position + Vector2(0, -16), "+%d" % int(round(chest.VALUE * Progress.coin_multiplier())), Color(1, 0.9, 0.4))
	toast("Treasure!", Color(1, 0.9, 0.4))
	pending_changed.emit()


func on_secret(zone: Node) -> void:
	if not run_secrets.has(zone.key):
		run_secrets.append(zone.key)
	Audio.play("secret")
	var already: bool = record["secrets"].has(zone.key)
	toast("Secret found!" if not already else "Secret (found before)", Color(0.7, 1.0, 0.8))
	pending_changed.emit()


func on_rescue(cat_id: String, pos: Vector2) -> void:
	if not run_cats.has(cat_id):
		run_cats.append(cat_id)
	Audio.play("rescue")
	var cat: Dictionary = GameData.CATS.get(cat_id, {"name": "a friend", "perk": ""})
	toast("Rescued %s! (%s)" % [cat["name"], cat["perk"]], Color(1, 0.75, 0.85))
	Fx.float_text(self, pos + Vector2(0, -36), "Thank you!", Color(1, 0.8, 0.9))
	pending_changed.emit()


func on_enemy_defeated(enemy: Node) -> void:
	if Progress.has_cat("inkblot") and randf() < 0.18:
		var p := _obj("pickup")
		p.level = self
		p.kind = "fish"
		p.key = ""
		p.position = enemy.global_position + Vector2(0, -10)
		objects.call_deferred("add_child", p)


func on_player_hazard_reset() -> void:
	camera.reset_smoothing()


# --------------------------------------------------------------------------
# Guardian fights
# --------------------------------------------------------------------------

func start_boss_fight() -> void:
	if boss == null or boss_active or boss_defeated:
		return
	boss_active = true
	boss_heals = 0
	for g in boss_gates:
		g.close()
	boss.start_fight()
	boss_started.emit(boss)
	Audio.play_music("final" if meta.get("boss", "") == "king" else "boss")
	Audio.play("boss_roar")
	shake(4.0, 0.5)


func _on_boss_defeated() -> void:
	boss_active = false
	boss_defeated = true
	boss_finished.emit()
	for g in boss_gates:
		g.open()
	if exit_door:
		exit_door.set_locked(false)
	clear_projectiles()
	Audio.play_music(meta.get("music", "r1"))
	toast("%s defeated!" % boss.display_name, Color(1, 0.9, 0.5))
	# Drop the region relic.
	var bid: String = meta.get("boss", "")
	if bid != "":
		var p := _obj("pickup")
		p.level = self
		p.kind = "relic"
		p.relic_index = RELIC_INDEX.get(bid, 0)
		p.key = "relic:" + bid
		p.position = floor_below(boss.global_position) + Vector2(0, -12)
		objects.call_deferred("add_child", p)


# --------------------------------------------------------------------------
# Death and retry
# --------------------------------------------------------------------------

func _on_player_died() -> void:
	deaths += 1
	Progress.add_stat("deaths")
	_dead_timer = 1.3
	shake(3.0, 0.3)


func respawn_point() -> Vector2:
	if current_checkpoint:
		return current_checkpoint.respawn_position()
	return start_position


## Retry from the last checkpoint: local state resets, gathered items stay.
func retry_from_checkpoint() -> void:
	_dead_timer = -1.0
	clear_projectiles()
	for e in _enemy_spawns:
		if is_instance_valid(e) and e.has_method("reset_to_spawn"):
			e.reset_to_spawn()
	if boss and is_instance_valid(boss) and not boss_defeated:
		boss.reset_fight()
		boss_active = false
		for g in boss_gates:
			g.open()
		boss_finished.emit()
		Audio.play_music(meta.get("music", "r1"))
	for c in _crumbles:
		c.reset()
	for i in _icicles:
		i.reset()
	if rising:
		rising.active = false
		rising.top_y = respawn_point().y + 16 * 7
	player.shield = Progress.start_shields() if current_checkpoint == null else player.shield
	player.respawn_at(respawn_point())
	camera.global_position = player.global_position
	camera.reset_smoothing()
	if rising:
		rising.active = current_checkpoint != null and player.global_position.y < _rising_trigger_y - 8


func restart_level() -> void:
	Transition.go_level(level_id)


# --------------------------------------------------------------------------
# Completion
# --------------------------------------------------------------------------

func complete_level() -> void:
	if finished:
		return
	finished = true
	player.input_enabled = false
	player.velocity = Vector2.ZERO
	Audio.play("complete")
	Audio.stop_music(0.5)
	var result := {
		"coins": run_coins, "items": run_items, "secrets": run_secrets, "gems": run_gems, "cats": run_cats,
		"relic": run_relic, "deaths": deaths, "heals": boss_heals if meta.get("boss", "") != "" else heals_used,
		"time": level_time, "boss": meta.get("boss", "") != "",
		"secrets_total": secrets_total, "gems_total": gems_total,
	}
	Progress.add_stat("play_time", level_time)
	Progress.add_stat("pounces", player.stats["pounces"])
	var summary := Progress.commit_level(level_id, result)
	summary["result"] = result
	completed.emit(summary)
	var tw := create_tween()
	tw.tween_property(player.sprite, "modulate:a", 0.0, 0.4)
	await tw.finished
	overlays.show_results(summary)


func next_level_id() -> String:
	var i := LevelCatalog.index_of(level_id)
	if i + 1 < LevelCatalog.count():
		return LevelCatalog.LEVELS[i + 1]["id"]
	return ""
