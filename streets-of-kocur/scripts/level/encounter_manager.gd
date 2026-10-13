extends RefCounted
## Encounter and wave progression for one level.
##  - An encounter starts once, when the player walks up to its arena.
##  - The camera locks to the arena; waves spawn just off-screen in small,
##    staggered groups and never above the simultaneous-enemy cap.
##  - The next wave comes when the current one is (almost) beaten.
##  - The encounter clears only when every wave has spawned and every enemy
##    (and the boss) is defeated. Cleared encounters never restart.
##  - A watchdog pulls back any enemy that ends up outside the arena, so a
##    level can never get stuck on an unreachable enemy.

const MAX_ALIVE := 5
const STAGGER := 0.45

var level: Node
var list: Array = []  ## [{x, waves, boss, final, label, state}]
var current := -1
var wave_i := -1
var pending: Array = []  ## [{kind, side, t}]
var alive: Array = []
var boss: Node = null
var boss_pending := ""
var boss_t := 0.0
var spawned_total := 0
var seed_base := 1000


func setup(lvl: Node, encounters: Array, checkpoint: int) -> void:
	level = lvl
	list = []
	for i in encounters.size():
		var e: Dictionary = (encounters[i] as Dictionary).duplicate(true)
		e["state"] = "cleared" if i < checkpoint else "idle"
		list.append(e)


func active() -> bool:
	return current >= 0


func next_index() -> int:
	for i in list.size():
		if list[i]["state"] != "cleared":
			return i
	return -1


func all_cleared() -> bool:
	return next_index() == -1


func tick(dt: float) -> void:
	if current < 0:
		var n := next_index()
		if n >= 0 and level.player.position.x >= float(list[n]["x"]) - 140.0:
			start(n)
		return
	_tick_active(dt)


func start(i: int) -> void:
	if list[i]["state"] != "idle":
		return  # never start an encounter twice
	list[i]["state"] = "active"
	current = i
	wave_i = -1
	pending = []
	alive = []
	boss = null
	boss_pending = String(list[i].get("boss", ""))
	boss_t = 0.0
	level.lock_arena(float(list[i]["x"]))
	if list[i].has("label"):
		level.show_banner(String(list[i]["label"]), "", 1.6)
	_next_wave()


func _next_wave() -> void:
	var waves: Array = list[current]["waves"]
	wave_i += 1
	if wave_i >= waves.size():
		return
	var t := 0.0
	for k: String in waves[wave_i]:
		var side := 1
		var kd := k
		if k.ends_with("<"):
			side = -1
			kd = k.substr(0, k.length() - 1)
		pending.append({"kind": kd, "side": side, "t": t})
		t += STAGGER


func _tick_active(dt: float) -> void:
	alive = alive.filter(func(e: Node) -> bool: return is_instance_valid(e) and not e.dead)
	# Boss walks in shortly after the arena locks.
	if boss_pending != "":
		boss_t += dt
		if boss_t >= 0.6:
			boss = level.spawn_boss(boss_pending)
			boss_pending = ""
	# Staggered spawns, respecting the cap.
	for p: Dictionary in pending:
		p["t"] = float(p["t"]) - dt
	var still: Array = []
	for p: Dictionary in pending:
		if float(p["t"]) <= 0.0 and alive.size() < MAX_ALIVE:
			alive.append(level.spawn_enemy(String(p["kind"]), int(p["side"]), seed_base + spawned_total))
			spawned_total += 1
		else:
			still.append(p)
	pending = still
	_watchdog(dt)
	var waves: Array = list[current]["waves"]
	var last_wave := wave_i >= waves.size() - 1
	if pending.is_empty() and not last_wave and alive.size() <= 1:
		_next_wave()
		return
	var boss_done: bool = boss_pending == "" and (boss == null or not is_instance_valid(boss) or boss.dead)
	if pending.is_empty() and last_wave and alive.is_empty() and boss_done:
		_clear()


## Reinforcements summoned by a boss join the current encounter.
func summon(kinds: Array) -> void:
	if current < 0:
		return
	for k: String in kinds:
		var side := -1 if k.ends_with("<") else 1
		pending.append({"kind": k.trim_suffix("<"), "side": side, "t": 0.2 * pending.size()})


func _watchdog(dt: float) -> void:
	var r: Rect2 = level.arena_rect()
	for e: Node in alive:
		if e.state == "enter":
			continue
		var out: bool = e.position.x < r.position.x - 30.0 or e.position.x > r.end.x + 30.0 \
			or e.position.y < r.position.y - 5.0 or e.position.y > r.end.y + 5.0
		e.outside_t = e.outside_t + dt if out else 0.0
		if e.outside_t > 2.5:
			e.outside_t = 0.0
			e.position = level.clamp_to_arena(e.position)


func kill_all() -> void:
	pending = []
	boss_pending = ""
	for e: Node in alive:
		if is_instance_valid(e) and not e.dead:
			e.die(1 if e.position.x >= level.player.position.x else -1, {"kb": 300.0, "launch": 320.0})


## The boss fell: the encounter counts as cleared without the usual
## "street clear" flow (the level runs its K.O. sequence instead).
func finish_with_boss() -> void:
	if current < 0:
		return
	list[current]["state"] = "cleared"
	Game.checkpoint = current + 1
	current = -1
	alive = []
	pending = []


func _clear() -> void:
	var i := current
	list[i]["state"] = "cleared"
	current = -1
	alive = []
	level.on_encounter_cleared(i, bool(list[i].get("final", false)))
