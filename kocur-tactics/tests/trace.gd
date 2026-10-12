extends SceneTree
## Debug helper: AI autoplay of one mission, printing hero positions each turn.
##   godot --headless --path . -s res://tests/trace.gd -- m10

const Battle = preload("res://scripts/core/battle.gd")
const AI = preload("res://scripts/core/ai.gd")
const Missions = preload("res://scripts/data/missions.gd")
const Sim = preload("res://tests/sim.gd")


func _initialize() -> void:
	var id: String = OS.get_cmdline_user_args()[0]
	var m := Missions.get_mission(id)
	var b := Battle.new()
	b.setup(m, Sim.default_squad(m, -1), "normal")
	var ai := AI.new()
	for i in 20:
		if b.result != "":
			break
		var line := "T%d " % b.turn
		for u in b.side_units("hero", true):
			line += "%s%s:%d " % [u.name.substr(0, 4), str(u.pos), u.hp]
		print(line)
		ai.play_hero_phase(b)
		for e in b.take_events():
			if e["t"] == "log":
				print("     ", e["text"])
	print(b.result, " ", b.defeat_reason)
	quit()
