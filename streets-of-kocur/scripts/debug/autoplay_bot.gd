extends RefCounted
## Scripted player used by the automated tests and the exported-build smoke
## test (never active in normal play). It walks right, lines up on the
## nearest gang cat's depth, mashes the combo, uses PAWQUAKE when crowded,
## eats food when hurt, sidesteps boss telegraphs and jumps shockwaves.
## Set Game.bot_input = AutoplayBot.new() to use it.

var frame := 0
var level: Node
var dodge_dir := 1.0
var use_special := true
var stats := {"attacks": 0, "specials": 0, "jumps": 0}


func poll(p: Node) -> Dictionary:
	frame += 1
	level = p.level
	var inp := {"move": Vector2.ZERO, "jump": false, "attack": false, "special": false, "grab": false, "run": false}
	if level == null:
		return inp
	var foes: Array = level.enemies().filter(func(e: Node) -> bool: return e.state != "enter" or absf(e.position.x - p.position.x) < 500.0)
	# Danger first: boss telegraphs and incoming projectiles.
	var danger := _danger(p)
	if danger != Vector2.ZERO:
		inp["move"] = danger
		if danger.y == 0.0 and frame % 2 == 0:
			inp["jump"] = true
			stats["jumps"] += 1
		return inp
	# Eat food when hurt.
	if p.hp < 65.0:
		var food: Node = _nearest_food(p)
		if food != null:
			inp["move"] = _toward(p, food.position, 0.0)
			return inp
	if foes.is_empty():
		var goal := Vector2(p.position.x + 300.0, (level.ymin + level.ymax) * 0.5)
		if level.flow == "play" and level.enc.next_index() < 0:
			goal.x = level.exit_x + 50.0
		inp["move"] = _toward(p, goal, 0.0)
		# Break props on the way.
		for pr: Node in level.props:
			if absf(pr.position.x - p.position.x) < 70.0 and absf(pr.position.y - p.position.y) < 20.0 and frame % 8 == 0:
				inp["attack"] = true
		return inp
	var t: Node = foes[0]
	var best := 1e9
	for e: Node in foes:
		var d: float = absf(e.position.x - p.position.x) + absf(e.position.y - p.position.y) * 2.0
		if d < best:
			best = d
			t = e
	var close := 0
	for e: Node in foes:
		if absf(e.position.x - p.position.x) < 120.0 and absf(e.position.y - p.position.y) < 40.0:
			close += 1
	if use_special and p.energy >= 50.0 and (close >= 2 or (t.get("is_boss") and t.vulnerable() and absf(t.position.x - p.position.x) < 140.0)) and frame % 10 == 0:
		inp["special"] = true
		stats["specials"] += 1
		return inp
	var side: float = 1.0 if p.position.x <= t.position.x else -1.0
	var reach: float = 46.0 + float(t.hurt_w)
	var want: Vector2 = t.position - Vector2(side * reach, 0)
	var dx: float = t.position.x - p.position.x
	var dy: float = t.position.y - p.position.y
	var boss_busy: bool = t.get("is_boss") and t.state == "move" and not t.vulnerable()
	if boss_busy:
		# Keep a safe distance from a boss that is mid-move.
		want = t.position - Vector2(side * (reach + 160.0), 0)
	inp["move"] = _toward(p, want, 0.0)
	if absf(dx) < reach + 26.0 and absf(dy) < 12.0 and not boss_busy:
		inp["move"] = Vector2(side * 0.3, signf(dy) * 0.5 if absf(dy) > 4.0 else 0.0)
		if frame % 7 == 0:
			inp["attack"] = true
			stats["attacks"] += 1
	return inp


func _toward(p: Node, goal: Vector2, _tol: float) -> Vector2:
	var d: Vector2 = goal - p.position
	var mv := Vector2.ZERO
	if absf(d.x) > 8.0:
		mv.x = signf(d.x)
	if absf(d.y) > 4.0:
		mv.y = signf(d.y)
	return mv


func _nearest_food(p: Node) -> Node:
	var best: Node = null
	var bd := 600.0
	for pk: Node in level.pickups:
		if pk.kind in ["fish", "chicken", "can"]:
			var d: float = absf(pk.position.x - p.position.x)
			if d < bd and absf(pk.position.x - level.cam_x) < level.HALF_W:
				bd = d
				best = pk
	return best


func _danger(p: Node) -> Vector2:
	for pr: Node in level.projectiles:
		if pr.spent:
			continue
		var dx: float = pr.position.x - p.position.x
		var approaching: bool = signf(pr.vel_x) == -signf(dx) or pr.kind == "can_fall"
		if pr.kind == "can_fall" and absf(dx) < 70.0 and absf(pr.position.y - p.position.y) < 40.0:
			return Vector2(-signf(dx) if dx != 0.0 else 1.0, 0.0001)
		if approaching and absf(dx) < 130.0 and absf(pr.position.y - p.position.y) < 26.0 and p.z < 1.0:
			if pr.kind == "shockwave":
				return Vector2(signf(pr.vel_x) * 0.5, 0.0)
			return Vector2(0, -1.0 if p.position.y > (level.ymin + level.ymax) * 0.5 else 1.0)
	for e: Node in level.enemies():
		if e.get("is_boss") and e.state == "move" and e.mv_phase == "tele":
			var dy: float = p.position.y - e.position.y
			var dxx: float = absf(p.position.x - e.position.x)
			if dxx < 420.0 and absf(dy) < 90.0:
				var dir := signf(dy) if dy != 0.0 else dodge_dir
				if (dir > 0.0 and p.position.y > level.ymax - 20.0) or (dir < 0.0 and p.position.y < level.ymin + 20.0):
					dir = -dir
				dodge_dir = dir
				return Vector2(signf(p.position.x - e.position.x) * 0.6, dir)
	return Vector2.ZERO
