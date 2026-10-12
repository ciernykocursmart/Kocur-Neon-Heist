extends "res://tests/test_case.gd"
## Guardians: they fight (several telegraphed moves), change phases, can be
## defeated, unlock the exit, drop their relic and reset on retry.

const LevelCatalog := preload("res://scripts/data/level_catalog.gd")


func _boss_levels() -> Array[String]:
	var out: Array[String] = []
	for lv: Dictionary in LevelCatalog.LEVELS:
		if lv.has("boss"):
			out.append(lv["id"])
	return out


func _enter_arena(lvl: Node) -> void:
	var p: CharacterBody2D = lvl.player
	p.invuln = 99999.0
	p.global_position = Vector2(lvl.boss_trigger_x + 40, lvl.boss.floor_y - 1)
	await frames(5)


func test_at_least_three_guardians_including_final() -> void:
	var ids := _boss_levels()
	gt(ids.size(), 2, "three or more guardian levels")
	check(ids.has("1-3") and ids.has("2-3") and ids.has("final"), "Iron Mouser, Ember Guardian and the Pale King")


func test_guardians_fight_with_varied_telegraphed_moves() -> void:
	for id in _boss_levels():
		var lvl := await spawn_level(id)
		await _enter_arena(lvl)
		var b: Node = lvl.boss
		check(lvl.boss_active and b.fighting, "%s: fight started" % id)
		var actions := {}
		var max_proj := 0
		var in_bounds := true
		var p: CharacterBody2D = lvl.player
		for i in 60 * 40:
			# Keep the cat moving (near / far) so every pattern gets used.
			if i % 150 == 0:
				var near_side := (i / 150) % 2 == 0
				var off := 50.0 if near_side else 220.0
				var tx: float = b.global_position.x + (off if b.global_position.x < (b.arena_left + b.arena_right) / 2 else -off)
				p.global_position.x = clampf(tx, b.arena_left + 20, b.arena_right - 20)
			await frames(1)
			actions[b.action] = true
			max_proj = maxi(max_proj, lvl.projectiles.get_child_count())
			if b.global_position.x < b.arena_left - 1 or b.global_position.x > b.arena_right + 1:
				in_bounds = false
		actions.erase("intro")
		actions.erase("idle")
		gt(actions.size(), 2, "%s: %s uses several moves (%s)" % [id, b.display_name, ", ".join(actions.keys())])
		gt(b.telegraphs, 3, "%s: attacks are announced with warnings (%d)" % [id, b.telegraphs])
		check(in_bounds, "%s: guardian stays inside its arena" % id)
		lt(max_proj, 60, "%s: projectiles are cleaned up (peak %d)" % [id, max_proj])
		note("%s %s: hp %d, moves %s" % [id, b.display_name, b.max_hp, actions.keys()])


func test_phases_defeat_unlock_and_relic() -> void:
	Progress.new_game()
	for id in _boss_levels():
		var lvl := await spawn_level(id)
		await _enter_arena(lvl)
		var b: Node = lvl.boss
		var phases_expected: int = b.phase_thresholds.size() + 1
		var phase_events := [0]
		b.phase_changed.connect(func(_p: int) -> void: phase_events[0] += 1)
		var hits := 0
		var blocked_during_transition := false
		while b.state != b.S.DEAD and hits < 400:
			var landed: bool = b.take_hit(Progress.claw_damage(), b.global_position + Vector2(-20, 0), "claw")
			if not landed and b._transition_t > 0.0:
				blocked_during_transition = true
			hits += 1
			await frames(4)
		eq(b.state, b.S.DEAD, "%s: guardian can be defeated" % id)
		eq(phase_events[0], phases_expected - 1, "%s: went through all %d phases" % [id, phases_expected])
		if phases_expected > 1:
			check(blocked_during_transition, "%s: brief invulnerability between phases" % id)
		await frames(10)
		check(lvl.boss_defeated, "%s: level registers the win" % id)
		check(not lvl.exit_door.locked, "%s: exit unlocked" % id)
		for gate in lvl.boss_gates:
			check(gate.is_open, "%s: arena gates reopen" % id)
		var relic: Node = null
		for o in lvl.objects.get_children():
			if o.get("kind") == "relic":
				relic = o
		check(relic != null, "%s: relic dropped" % id)
		eq(lvl.projectiles.get_child_count(), 0, "%s: projectiles cleared on defeat" % id)
		note("%s: defeated with %d base claw hits at %d damage" % [id, hits, Progress.claw_damage()])


func test_retry_resets_the_fight() -> void:
	for id in ["1-3", "final"]:
		var lvl := await spawn_level(id)
		await _enter_arena(lvl)
		var b: Node = lvl.boss
		for i in 10:
			b.take_hit(3, b.global_position + Vector2(-20, 0), "pounce")
			await frames(3)
		lt(b.hp, b.max_hp, "%s: guardian damaged" % id)
		var p: CharacterBody2D = lvl.player
		p.invuln = 0.0
		p.hurt(999, p.global_position, true)
		await frames(100)
		lvl.overlays._close()
		tree.paused = false
		lvl.retry_from_checkpoint()
		await frames(5)
		eq(b.hp, b.max_hp, "%s: guardian health restored on retry" % id)
		eq(b.phase, 1, "%s: back to phase 1" % id)
		check(not lvl.boss_active and not b.fighting, "%s: fight waits for the cat to re-enter" % id)
		for gate in lvl.boss_gates:
			check(gate.is_open, "%s: gates open again after retry" % id)
		eq(lvl.projectiles.get_child_count(), 0, "%s: no leftover projectiles" % id)
		lt(p.global_position.x, lvl.boss_trigger_x, "%s: respawn is outside the arena" % id)


func test_king_summons_are_cleaned_up() -> void:
	var lvl := await spawn_level("final")
	await _enter_arena(lvl)
	var b: Node = lvl.boss
	var base_enemies: int = lvl.enemies_root.get_child_count()
	var max_enemies := base_enemies
	for i in 60 * 40:
		await frames(1)
		max_enemies = maxi(max_enemies, lvl.enemies_root.get_child_count())
		if i == 60 * 10:
			while b.phase < 3 and b.hp > 1:
				b.take_hit(4, b.global_position + Vector2(-20, 0), "pounce")
				await frames(3)
	gt(max_enemies, base_enemies, "the Pale King summons his guard in later phases")
	b.die()
	await frames(120)
	eq(lvl.enemies_root.get_child_count(), 1, "summoned minions vanish with the king (only his body remains)")
