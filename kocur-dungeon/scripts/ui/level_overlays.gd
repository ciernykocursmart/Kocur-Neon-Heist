extends CanvasLayer
## Level overlays: the defeat screen, the results screen and the
## between-levels blessing choice.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")

const DEATH_TIPS := [
	"Tip: enemies flash before they strike - that is your cue to dodge.",
	"Tip: pouncing makes you briefly untouchable by enemies.",
	"Tip: swipe arrows and orbs out of the air with your claws.",
	"Tip: upgrades at camp make every life count.",
	"Tip: Assist difficulty halves incoming damage (Settings).",
	"Tip: rescued cats grant permanent perks.",
	"Tip: guardians are vulnerable right after a big attack.",
]

var level: Node
var root: Control
var _center: CenterContainer
var _busy := false
var state := ""  ## "", "death", "results", "blessing"


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = UI.root_control()
	root.visible = false
	add_child(root)
	root.add_child(UI.dim_rect(0.6))


func is_busy() -> bool:
	return _busy


func _open() -> void:
	_busy = true
	root.visible = true
	if _center:
		_center.queue_free()
		_center = null


func _close() -> void:
	_busy = false
	state = ""
	root.visible = false
	if _center:
		_center.queue_free()
		_center = null


# --------------------------------------------------------------------------
# Defeat
# --------------------------------------------------------------------------

func show_death() -> void:
	_open()
	state = "death"
	get_tree().paused = true
	var panel := UI.panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UI.label("YOU WERE CAUGHT!", 20, UI.C_BAD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("But a cat has nine lives...", 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var tip := UI.label(DEATH_TIPS[randi() % DEATH_TIPS.size()], 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.custom_minimum_size = Vector2(280, 0)
	box.add_child(tip)
	var retry := UI.button("Retry from Checkpoint", func() -> void:
		get_tree().paused = false
		_close()
		level.retry_from_checkpoint(), 200)
	box.add_child(retry)
	box.add_child(UI.button("Restart Level", func() -> void:
		get_tree().paused = false
		_close()
		level.restart_level(), 200))
	box.add_child(UI.button("Return to Camp", func() -> void:
		get_tree().paused = false
		Transition.go_camp(), 200))
	_center = UI.center(root, panel)
	await get_tree().process_frame
	retry.grab_focus()


# --------------------------------------------------------------------------
# Results
# --------------------------------------------------------------------------

func show_results(summary: Dictionary) -> void:
	_open()
	state = "results"
	var result: Dictionary = summary.get("result", {})
	var rec: Dictionary = Progress.record(level.level_id)
	var panel := UI.panel()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(330, 0)
	panel.add_child(box)
	box.add_child(UI.label("LEVEL COMPLETE!", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label(LevelCatalog.level_title(level.level_id), 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(HSeparator.new())
	_row(box, "clock", "Time", UI.fmt_time(level.level_time) + ("   (best %s)" % UI.fmt_time(rec["best_time"]) if rec["best_time"] > 0 else ""))
	_row(box, "coin", "Coins earned", "+%d   (total %d)" % [summary["coins"], Progress.coins()])
	_row(box, "star", "Secrets found", "%d / %d" % [rec["secrets"].size(), level.secrets_total])
	_row(box, "gem", "Shadow Gems", "%d / %d" % [rec["gems"].size(), level.gems_total])
	_row(box, "skull", "Deaths", str(level.deaths))
	for cat in summary["new_cats"]:
		_row(box, "cat", "Rescued " + GameData.CATS[cat]["name"], GameData.CATS[cat]["perk"], UI.C_GOOD)
	if summary["relic"] != "":
		_row(box, "relic", "Relic", level.meta.get("relic_name", "Relic"), UI.C_GOLD)
	box.add_child(HSeparator.new())
	box.add_child(UI.label("Optional challenges (+%d coins each, once)" % GameData.CHALLENGE_REWARD, 10, UI.C_DIM))
	var challenges := ["secrets", "gems", "deathless"]
	if level.meta.get("boss", "") != "":
		challenges.append("no_heal")
	for ch: String in challenges:
		if ch == "secrets" and level.secrets_total == 0:
			continue
		if ch == "gems" and level.gems_total == 0:
			continue
		var done: bool = rec["challenges"].has(ch)
		var fresh: bool = summary["challenges"].has(ch)
		_row(box, "check" if done else "lock", GameData.CHALLENGE_NAMES[ch], "NEW!" if fresh else ("done" if done else ""),
			UI.C_GOOD if done else UI.C_DIM)
	if summary["unlocked"] != "":
		box.add_child(UI.label("Unlocked: " + LevelCatalog.level_title(summary["unlocked"]), 10, UI.C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var nxt: String = level.next_level_id()
	var cont: Button
	if nxt == "":
		cont = UI.button("Continue", func() -> void: Transition.change_scene("res://scenes/ending.tscn"), 120)
	else:
		cont = UI.button("Continue", show_blessings, 120)
	row.add_child(cont)
	row.add_child(UI.button("Return to Camp", Transition.go_camp, 130))
	box.add_child(row)
	_center = UI.center(root, panel)
	await get_tree().process_frame
	cont.grab_focus()


func _row(box: VBoxContainer, icon: String, text: String, value: String, color := UI.C_TEXT) -> void:
	var r := HBoxContainer.new()
	r.add_child(UI.icon_rect(icon))
	var l := UI.label(text, 10, color)
	l.custom_minimum_size = Vector2(150, 0)
	r.add_child(l)
	var v := UI.label(value, 10, color)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.custom_minimum_size = Vector2(150, 0)
	r.add_child(v)
	box.add_child(r)


# --------------------------------------------------------------------------
# Blessing choice (temporary run rewards)
# --------------------------------------------------------------------------

func show_blessings() -> void:
	_open()
	state = "blessing"
	var offers := Progress.offer_blessings(3)
	var nxt: String = level.next_level_id()
	var panel := UI.panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UI.label("CHOOSE A BLESSING", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Blessings last until you return to camp.", 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var first: Button
	for id: String in offers:
		var b: Dictionary = GameData.BLESSINGS[id]
		var btn := UI.button("%s - %s" % [b["name"], b["desc"]], func() -> void:
			Progress.add_blessing(id)
			Transition.go_level(nxt), 320)
		btn.icon = UI.icon_tex(b["icon"])
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(btn)
		if first == null:
			first = btn
	if not Progress.run_blessings.is_empty():
		var names: PackedStringArray = []
		for id in Progress.run_blessings:
			names.append(GameData.BLESSINGS[id]["name"])
		var held := UI.label("Active: " + ", ".join(names), 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		held.autowrap_mode = TextServer.AUTOWRAP_WORD
		held.custom_minimum_size = Vector2(320, 0)
		box.add_child(held)
	box.add_child(UI.label("Next: " + LevelCatalog.level_title(nxt), 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.button("Return to Camp instead", Transition.go_camp, 320))
	_center = UI.center(root, panel)
	await get_tree().process_frame
	if first:
		first.grab_focus()
