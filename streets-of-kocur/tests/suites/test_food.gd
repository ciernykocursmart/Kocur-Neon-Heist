extends "res://tests/test_case.gd"
## Food, score items, breakable props and the "never respawn" rule.


func _place(lv: Node, kind: String, uid: String, pos: Vector2) -> Node:
	var pk: Node = lv._add_pickup(kind, uid, pos, false)
	pk.t = 1.0
	return pk


func test_food_heal_amounts() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	for kind: String in ["fish", "chicken", "can"]:
		p.hp = 10.0
		var pk := _place(lv, kind, "t_" + kind, p.position)
		step(lv, 1)
		near(p.hp, 10.0 + float(B.PICKUPS[kind]["heal"]), 0.01, "%s heals %d" % [kind, int(B.PICKUPS[kind]["heal"])])
		check(not is_instance_valid(pk) or pk.collected, "%s removed after eating" % kind)
	eq(int(game().attempt["food"]), 3, "food counted")


func test_heal_capped_at_max() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	p.hp = 90.0
	_place(lv, "can", "cap1", p.position)
	step(lv, 1)
	eq(p.hp, p.max_hp, "healing stops at max health")
	var s0: int = game().score
	_place(lv, "fish", "cap2", p.position)
	step(lv, 1)
	eq(p.hp, p.max_hp, "still max")
	check(game().score > s0, "eating at full health gives points instead")


func test_no_double_collect() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	p.hp = 10.0
	var pk := _place(lv, "chicken", "dbl", p.position)
	step(lv, 1)
	near(p.hp, 50.0, 0.01, "healed once")
	lv._check_pickup(pk)
	step(lv, 5)
	near(p.hp, 50.0, 0.01, "same item never heals twice")
	check(game().consumed.has("dbl"), "remembered as consumed")


func test_pickup_needs_contact() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	p.hp = 10.0
	_place(lv, "fish", "far", p.position + Vector2(80, 0))
	_place(lv, "fish", "deep", p.position + Vector2(0, 40))
	step(lv, 3)
	eq(p.hp, 10.0, "items out of reach (side or depth) are not collected")


func test_golden_fish_and_yarn() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	p.energy = 0.0
	var s0: int = game().score
	_place(lv, "golden", "g", p.position)
	step(lv, 1)
	check(p.energy >= 99.0, "golden fish fills the special meter")
	check(bool(game().attempt["golden"]), "golden fish recorded")
	check(game().score - s0 >= 3000, "golden fish worth 3000")
	var s1: int = game().score
	_place(lv, "yarn", "y", p.position)
	step(lv, 1)
	eq(game().score - s1, 500, "yarn ball worth 500")


func test_level_food_collected_once_after_restart() -> void:
	# Eat the first food item of street 1, then reload from a continue: it must stay gone.
	var lv: Node = await start_level(0, 0)
	var pd: Dictionary = lv.data["pickups"][0]
	var n_pickups: int = (lv.data["pickups"] as Array).size()
	var p: Node = lv.player
	var pk: Node = null
	for x: Node in lv.pickups:
		if x.uid == "pk0":
			pk = x
	check(pk != null, "first pickup exists")
	p.position = pk.position
	p.hp = 20.0
	pk.t = 1.0
	step(lv, 1)
	check(game().consumed.has("pk0"), "eaten")
	var lv2: Node = await start_level_keep(0)
	var again := false
	for x: Node in lv2.pickups:
		if x.uid == "pk0":
			again = true
	check(not again, "eaten food is not respawned after a continue (%s)" % str(pd))
	var others := 0
	for x: Node in lv2.pickups:
		if x.uid.begins_with("pk"):
			others += 1
	eq(others, n_pickups - 1, "other food still there")


## Reloads the level scene WITHOUT resetting the attempt (like a continue).
func start_level_keep(_idx: int) -> Node:
	var lv: Node = await spawn_scene("res://scenes/level.tscn")
	lv.set_physics_process(false)
	lv.flow = "play"
	lv.player.control_locked = false
	return lv


func test_prop_breaks_and_drops_once() -> void:
	var lv: Node = await start_level(0, 0)
	var pr: Node = null
	for x: Node in lv.props:
		if x.drop != "":
			pr = x
			break
	check(pr != null, "street 1 has a prop with food inside")
	var p: Node = lv.player
	p.position = pr.position + Vector2(-50, 0)
	p.facing = 1
	var uid: String = pr.uid
	var n0: int = lv.pickups.size()
	for i in 5:
		lv.resolve_attack(p, p.make_attack(B.MOVES["finisher"]))
	check(not (pr in lv.props), "prop broken")
	eq(lv.pickups.size(), n0 + 1, "exactly one drop")
	check(game().consumed.has(uid), "broken prop remembered")
	for i in 5:
		lv.resolve_attack(p, p.make_attack(B.MOVES["finisher"]))
	eq(lv.pickups.size(), n0 + 1, "hitting the spot again drops nothing more")
	# Reload: the prop stays broken and its uneaten drop lies there once.
	var lv2: Node = await start_level_keep(0)
	var props_again: Array = lv2.props.filter(func(x: Node) -> bool: return x.uid == uid)
	eq(props_again.size(), 0, "broken prop not rebuilt after a continue")
	var drops: Array = lv2.pickups.filter(func(x: Node) -> bool: return x.uid == uid + "d")
	eq(drops.size(), 1, "its uneaten drop is still there (once)")
	var d: Node = drops[0]
	lv2.player.position = d.position
	lv2.player.hp = 10.0
	d.t = 1.0
	step(lv2, 1)
	var lv3: Node = await start_level_keep(0)
	eq(lv3.pickups.filter(func(x: Node) -> bool: return x.uid == uid + "d").size(), 0, "eaten drop gone for good")


func test_extra_life_threshold() -> void:
	var lv: Node = await arena()
	game().lives = 3
	game().score = B.EXTRA_LIFE_EVERY - 100
	game().next_life_at = B.EXTRA_LIFE_EVERY
	_place(lv, "yarn", "ly", lv.player.position)
	step(lv, 1)
	eq(game().lives, 4, "extra life at %d points" % B.EXTRA_LIFE_EVERY)
	_place(lv, "yarn", "ly2", lv.player.position)
	step(lv, 1)
	eq(game().lives, 4, "only one extra life per threshold")
	eq(game().next_life_at, 2 * B.EXTRA_LIFE_EVERY, "next threshold")


func test_food_budget_per_street() -> void:
	for i in Levels.count():
		var total := 0.0
		for pd: Dictionary in Levels.get_level(i)["pickups"]:
			total += float(B.PICKUPS[pd["kind"]]["heal"])
		for pd: Dictionary in Levels.get_level(i)["props"]:
			if String(pd.get("drop", "")) != "":
				total += float(B.PICKUPS[pd["drop"]]["heal"])
		check(total >= 60.0 and total <= 400.0, "street %d total healing %d is limited" % [i + 1, int(total)])
