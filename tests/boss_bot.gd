extends RefCounted
## Combat bot used by the test-suite to validate WARDEN balance. It strafes
## around the boss, dashes away from incoming bullets, uses the SMG at range
## and the shotgun up close, reloads, and grabs nearby supplies. It is
## deliberately simpler than a human (no prediction, no cover use).

static func fight(tree: SceneTree, game, max_seconds: float) -> Dictionary:
	var p = game.player
	var boss = game.boss
	var t := 0.0
	var orbit := 1.0
	var dash_cd := 0.0
	var hits_taken := 0.0
	var hp_start: float = p.hp
	while t < max_seconds:
		await tree.physics_frame
		var dt := 1.0 / 60.0
		t += dt
		dash_cd -= dt
		if p.dead or boss.is_dead() or game.mission_over:
			break
		var to: Vector2 = boss.global_position - p.global_position
		var d := to.length()
		# Weapon choice.
		var want := "smg" if d > 170.0 else "shotgun"
		if p.mag == 0 and p.reserve == 0:
			for w in ["smg", "shotgun", "pistol"]:
				if w != p.weapon_id and int(p.ammo[w]["reserve"]) + int(p.ammo[w]["mag"]) > 0:
					want = w
					break
		if want != p.weapon_id and (int(p.ammo[want]["mag"]) + int(p.ammo[want]["reserve"])) > 0:
			p.switch_weapon(want)
		# Aim and fire.
		p.aim_angle = to.angle()
		p._try_fire()
		# Movement: orbit at ~230 px, flip direction on collision.
		var radial := to.normalized() * (d - 230.0) * 0.02
		var tangent := to.normalized().orthogonal() * orbit
		var move: Vector2 = (tangent + radial).normalized() * float(p.speed) * dt
		# Dodge: dash perpendicular to the nearest incoming bullet.
		if dash_cd <= 0.0 and p.dash_timer <= 0.0:
			for b in game.bullets.get_children():
				if b.from_player:
					continue
				var rel: Vector2 = p.global_position - b.global_position
				if rel.length() < 70.0 and rel.dot(b.velocity) > 0.0:
					p._dash(b.velocity.normalized().orthogonal() * orbit)
					dash_cd = 0.6
					break
		var col = p.move_and_collide(move)
		if col != null:
			orbit = -orbit
	return {
		"won": boss.is_dead(),
		"dead": p.dead,
		"time": t,
		"hp_left": p.hp,
		"hp_start": hp_start,
		"boss_hp": boss.hp,
		"phase": boss.phase,
	}
