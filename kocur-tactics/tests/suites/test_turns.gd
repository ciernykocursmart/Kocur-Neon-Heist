extends "res://tests/test_case.gd"
## Turn structure, cooldowns, statuses, objectives and interactions.


func test_move_then_act_once() -> void:
	var b := make_battle(["1..r", "...."], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	check(b.is_player_turn(), "battle starts on the player turn")
	eq(b.turn, 1, "turn 1")
	check(b.cmd_move(nox, Vector2i(2, 0)), "move")
	check(not b.cmd_move(nox, Vector2i(2, 1)), "cannot move twice")
	check(b.cmd_ability(nox, "claw", Vector2i(3, 0)), "act after moving")
	check(not b.cmd_ability(nox, "claw", Vector2i(3, 0)), "cannot act twice")
	check(not b.cmd_wait(nox), "cannot wait after acting")
	check(not b.cmd_undo_move(nox), "cannot undo a move after acting")
	eq(b.heroes_left_to_act(), 0, "no heroes left to act")


func test_undo_move() -> void:
	var b := make_battle(["1...", "...r"], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	check(b.cmd_move(nox, Vector2i(2, 0)), "move")
	check(b.cmd_undo_move(nox), "undo before acting")
	eq(nox.pos, Vector2i(0, 0), "back on the start tile")
	check(not nox.moved, "movement restored")
	check(b.cmd_move(nox, Vector2i(1, 1)), "can move again after undo")


func test_wait_and_act_without_moving() -> void:
	var b := make_battle(["1r..", "2..."], [["nox", 1], ["bramble", 1]])
	var nox = unit_named(b, "shadowblade")
	var br = unit_named(b, "guardian")
	check(b.cmd_ability(nox, "claw", Vector2i(1, 0)), "attack without moving")
	check(not b.cmd_move(nox, Vector2i(0, 2)), "cannot move after acting")
	check(b.cmd_wait(br), "wait")
	check(not b.cmd_move(br, Vector2i(1, 1)), "cannot move after waiting")


func test_enemy_phase_and_reset() -> void:
	var b := make_battle(["1....r", "......"], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	check(b.cmd_move(nox, Vector2i(2, 0)), "move")
	check(b.cmd_end_phase(), "end turn")
	eq(b.turn, 2, "turn advanced")
	check(b.is_player_turn(), "back to the player after the enemy phase")
	check(not nox.moved and not nox.acted, "hero actions reset")
	var r = unit_named(b, "recruit")
	check(r.pos != Vector2i(5, 0), "enemy moved during its phase")
	check(not b.enemy_order_log.is_empty(), "enemy acted")
	check(not b.cmd_end_phase() == false, "end phase allowed again on turn 2")


func test_enemy_turn_order() -> void:
	var b := make_battle([
		"1.........",
		"..........",
		".....rams.",
		"......g...",
	], [["nox", 1]])
	b.cmd_end_phase()
	var kinds := []
	for uid: int in b.enemy_order_log:
		kinds.append(b.unit_by_uid(uid).kind)
	eq(kinds, ["mage", "archer", "guard", "recruit", "stalker"], "casters, ranged, guards, melee, flankers")


func test_cooldowns_tick() -> void:
	var b := make_battle(["1.......", "........", ".......r"], [["willow", 1]])
	var w = unit_named(b, "ranger")
	w.pos = Vector2i(4, 0)
	var r = unit_named(b, "recruit")
	r.pos = Vector2i(5, 2)
	r.hp = 100
	r.max_hp = 100
	check(b.cmd_ability(w, "volley", r.pos) or b.cmd_ability(w, "volley", Vector2i(4, 2)), "volley used")
	check(not w.ability_ready("volley"), "volley on cooldown right after use")
	b.cmd_end_phase()
	check(not w.ability_ready("volley"), "volley still on cooldown on the next turn (cd 2)")
	b.cmd_end_phase()
	check(not w.ability_ready("volley"), "cooldown 2: still waiting on the second turn")
	b.cmd_end_phase()
	check(w.ability_ready("volley") or not w.alive, "volley ready after waiting 2 full turns")


func test_status_durations() -> void:
	var b := make_battle(["2......", "1.....r"], [["bramble", 1], ["nox", 1]])
	var br = unit_named(b, "guardian")
	check(b.cmd_ability(br, "stance", br.pos), "stance")
	check(br.has_status("stance"), "stance active")
	b.cmd_end_phase()
	check(not br.has_status("stance"), "stance lasts until the start of the Guardian's next turn")
	var nox = unit_named(b, "shadowblade")
	nox.status["chilled"] = 2
	var m: int = nox.effective_move()
	b.cmd_end_phase()
	check(nox.has_status("chilled"), "chilled lasts 2 turns")
	b.cmd_end_phase()
	check(not nox.has_status("chilled"), "chill wears off")
	check(nox.effective_move() > m or not nox.alive, "movement restored")


func test_threat_display() -> void:
	var b := make_battle(["1.....", "......", "....r."], [["nox", 1]])
	var r = unit_named(b, "recruit")
	var th: Dictionary = b.threat_cells(r)
	check(th.has(Vector2i(4, 1)), "adjacent tile is threatened")
	check(th.has(Vector2i(0, 2)), "tile at move 4 + reach 1 is threatened")
	check(not th.has(Vector2i(0, 0)), "tile far away is not threatened")


func test_turn_limit_defeat() -> void:
	var b := make_battle(["1.#", "..#", "##r"], [["nox", 1]], {"type": "eliminate", "text": ""}, {"turn_limit": 2})
	b.cmd_end_phase()
	eq(b.result, "", "still going after turn 1")
	b.cmd_end_phase()
	eq(b.result, "defeat", "turn limit reached -> defeat")
	eq(b.defeat_reason, "Out of time.", "reason given")
	check(not b.cmd_end_phase(), "no more turns once the battle ended")


func test_survive_victory() -> void:
	var b := make_battle(["1.#", "..#", "##r"], [["nox", 1]], {"type": "survive", "turns": 3, "text": "Survive"})
	b.cmd_end_phase()
	b.cmd_end_phase()
	eq(b.result, "", "not yet")
	b.cmd_end_phase()
	eq(b.result, "victory", "survived 3 turns")


func test_defend_overrun() -> void:
	var b := make_battle(["1#...", "##...", "..rD."], [["nox", 1]], {"type": "defend", "turns": 5, "text": "Defend"})
	b.cmd_end_phase()
	eq(b.result, "defeat", "an enemy on the shrine at round end -> defeat")


func test_eliminate_and_ko_defeat() -> void:
	var b := make_battle(["1r", ".."], [["nox", 1]])
	var r = unit_named(b, "recruit")
	r.hp = 1
	b.cmd_ability(unit_named(b, "shadowblade"), "claw", r.pos)
	eq(b.result, "victory", "last enemy defeated -> victory")
	var b2 := make_battle(["1r", ".."], [["willow", 1]])
	var w = unit_named(b2, "ranger")
	b2.apply_damage(w, 100)
	b2._check_end()
	eq(b2.result, "defeat", "all heroes down -> defeat")


func test_rescue_and_escape() -> void:
	var b := make_battle(["1C.E", "....", "...r"], [["nox", 1]],
		{"type": "rescue_escape", "tag": "moss", "text": "Rescue"}, {"captives": ["moss"]})
	var nox = unit_named(b, "shadowblade")
	var its: Array = b.interactions(nox)
	eq(its.size(), 1, "one interaction next to the cage")
	check(b.cmd_interact(nox, "free", Vector2i(1, 0)), "free the captive")
	var moss = unit_named(b, "mender")
	check(moss != null and moss.tag == "moss", "Moss joins on the cage tile")
	check(not moss.can_act(), "a freed hero acts next turn")
	check(b.freed.has("moss"), "freed recorded")
	b.cmd_end_phase()
	if moss.alive:
		moss.pos = Vector2i(3, 0)
		check(b.can_escape(moss), "Moss can escape")
		check(not b.can_escape(nox), "Nox is not the escape target")
		check(b.cmd_interact(moss, "escape", Vector2i(3, 0)), "escape")
		eq(b.result, "victory", "Moss escaped -> victory")


func test_claim_relics() -> void:
	var b := make_battle(["1R.R", "2...", "...r"], [["nox", 1], ["bramble", 1]],
		{"type": "claim", "text": "Claim"})
	var nox = unit_named(b, "shadowblade")
	check(b.cmd_move(nox, Vector2i(1, 0)), "step on a relic")
	check(b.cmd_interact(nox, "claim", Vector2i(1, 0)), "claim it")
	eq(b.claimed.size(), 1, "1 of 2")
	eq(b.result, "", "not yet won")
	var br = unit_named(b, "guardian")
	br.pos = Vector2i(3, 0)
	check(b.cmd_interact(br, "claim", Vector2i(3, 0)), "claim the second")
	eq(b.result, "victory", "all relics -> victory")


func test_escape_all() -> void:
	var b := make_battle(["1E", "2E", "..", "#r"], [["nox", 1], ["bramble", 1]], {"type": "escape", "text": "Escape"})
	var nox = unit_named(b, "shadowblade")
	var br = unit_named(b, "guardian")
	check(b.cmd_move(nox, Vector2i(1, 0)), "move to exit")
	check(b.cmd_interact(nox, "escape", Vector2i(1, 0)), "Nox escapes")
	check(b.unit_at(Vector2i(1, 0)) == null, "escaped hero leaves the map")
	eq(b.result, "", "Bramble still on the map")
	check(b.cmd_move(br, Vector2i(1, 1)), "move")
	check(b.cmd_interact(br, "escape", Vector2i(1, 1)), "Bramble escapes")
	eq(b.result, "victory", "everyone out -> victory")


func test_alert_and_wake() -> void:
	var b := make_battle([
		"1...........",
		"............",
		"..........r.",
		"...........r",
	], [["nox", 1]], {"type": "eliminate", "text": ""}, {"alert": 4})
	var r1 = b.unit_at(Vector2i(10, 2))
	var r2 = b.unit_at(Vector2i(11, 3))
	check(not r1.awake and not r2.awake, "enemies start dormant")
	b.cmd_end_phase()
	eq(r1.pos, Vector2i(10, 2), "dormant enemies do not move")
	var nox = unit_named(b, "shadowblade")
	nox.pos = Vector2i(6, 2)
	b.cmd_end_phase()
	check(r1.awake and r2.awake, "a hero within the alert radius wakes the group")


func test_reinforcements_announced() -> void:
	var b := make_battle(["1.......", "........", "......r."], [["nox", 1]], {"type": "eliminate", "text": ""},
		{"reinforcements": [{"turn": 2, "units": [["r", 7, 0], ["a", 7, 1]]}]})
	eq(b.incoming_cells().size(), 0, "nothing announced on turn 1")
	b.cmd_end_phase()
	eq(b.incoming_cells(), [Vector2i(7, 0), Vector2i(7, 1)] as Array[Vector2i], "turn 2: incoming tiles marked")
	var n_before: int = b.side_units("enemy").size()
	b.cmd_end_phase()
	check(b.side_units("enemy").size() >= n_before + 1, "reinforcements arrived")
	eq(b.incoming_cells().size(), 0, "markers cleared")


func test_optional_objectives() -> void:
	var b := make_battle(["1r", ".."], [["nox", 1]], {"type": "eliminate", "text": ""},
		{"optional": [{"type": "turns", "turns": 3, "text": "fast"}, {"type": "no_ko", "text": "no ko"}]})
	eq(b.optional_status()[0]["state"], "open", "open during battle")
	var r = unit_named(b, "recruit")
	r.hp = 1
	b.cmd_ability(unit_named(b, "shadowblade"), "claw", r.pos)
	eq(b.optional_status()[0]["state"], "done", "won in time")
	eq(b.optional_status()[1]["state"], "done", "no KO")
	var s: Dictionary = b.summary()
	eq(s["optional"], [true, true], "summary carries optional results")
	eq(s["result"], "victory", "summary result")
	eq(s["kills"]["nox"], 1, "summary kills")


func test_commands_rejected_outside_player_turn() -> void:
	var b := make_battle(["1r", ".."], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	var r = unit_named(b, "recruit")
	check(not b.cmd_move(r, Vector2i(1, 1)), "player cannot command enemies")
	r.hp = 1
	b.cmd_ability(nox, "claw", r.pos)
	check(not b.cmd_move(nox, Vector2i(0, 1)), "no commands after the battle ended")
