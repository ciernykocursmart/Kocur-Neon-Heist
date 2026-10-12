extends SceneTree
## Autoplays missions with the AI controlling the heroes and prints results.
##   godot --headless --path . -s res://tests/sim.gd -- [mission ids] [--diff=normal] [--verbose]

const Battle = preload("res://scripts/core/battle.gd")
const AI = preload("res://scripts/core/ai.gd")
const Missions = preload("res://scripts/data/missions.gd")
const UD = preload("res://scripts/data/units_data.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var diff := "normal"
	var verbose := false
	var ids: Array[String] = []
	var lvl := -1
	for a in args:
		if a.begins_with("--diff="):
			diff = a.substr(7)
		elif a == "--verbose":
			verbose = true
		elif a.begins_with("--level="):
			lvl = int(a.substr(8))
		else:
			ids.append(a)
	if ids.is_empty():
		ids = Missions.mission_ids()
		ids.append_array(Missions.challenge_ids())
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var r := run(id, diff, verbose, lvl)
		print("%s  %-8s turns=%2d ko=%d  opt=%s  heroes_left=%s  (%d ms) %s" % [id, r["result"], r["turns"], r["ko"],
			str(r["optional"]), r["left"], Time.get_ticks_msec() - t0, r["reason"]])
	quit()


static func default_squad(m: Dictionary, lvl: int) -> Array:
	if m.get("challenge", false):
		var out := []
		for p: Array in m["squad"]:
			out.append({"hero_id": p[0], "level": p[1], "upgrades": {}})
		return out
	var idx := Missions.index_of(m["id"])
	var heroes := ["nox", "bramble", "willow"]
	if idx >= 3:
		heroes.append("moss")
	if idx >= 6:
		heroes = ["nox", "bramble", "willow", "moss"]
	var level := lvl if lvl > 0 else clampi(1 + idx / 2, 1, 6)
	var out := []
	var caps: Array = m.get("captives", [])
	for h in heroes:
		if out.size() < int(m["slots"]) and not caps.has(h):
			out.append({"hero_id": h, "level": level, "upgrades": {}})
	return out


static func run(id: String, diff: String, verbose: bool, lvl := -1) -> Dictionary:
	var m := Missions.get_mission(id)
	var b := Battle.new()
	b.setup(m, default_squad(m, lvl), diff)
	var hero_ai := AI.new()
	var guard := 0
	while b.result == "" and guard < 40:
		guard += 1
		hero_ai.play_hero_phase(b)
		if verbose:
			for e: Dictionary in b.take_events():
				if e["t"] == "log":
					print("   [T%d] %s" % [b.turn, e["text"]])
		else:
			b.take_events()
	var left := []
	for u in b.side_units("hero"):
		left.append("%s:%d" % [u.name, u.hp])
	return {"result": b.result if b.result != "" else "timeout", "turns": b.turn, "ko": b.ko_count,
		"optional": b.summary()["optional"], "left": ",".join(left), "reason": b.defeat_reason}
