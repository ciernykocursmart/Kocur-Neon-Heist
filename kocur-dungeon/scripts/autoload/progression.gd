extends Node
## Progress autoload: permanent campaign progression (saved) and the
## temporary run state (blessings - never saved). Gameplay systems ask this
## node for derived values such as max health or claw damage.

signal coins_changed(total: int)
signal progress_changed

const GameData := preload("res://scripts/data/game_data.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")

var data: Dictionary = {}
## Temporary run state - cleared on returning to camp, never written to disk.
var run_blessings: Array[String] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_game()


# --------------------------------------------------------------------------
# Save data
# --------------------------------------------------------------------------

static func defaults() -> Dictionary:
	return {
		"version": 1,
		"started": false,
		"coins": 0,
		"unlocked": 0,
		"levels": {},
		"upgrades": {},
		"rescued": [],
		"relics": [],
		"game_complete": false,
		"intro_seen": false,
		"stats": {"deaths": 0, "enemies": 0, "play_time": 0.0, "coins_earned": 0, "bosses": 0, "levels_done": 0,
			"secrets": 0, "pounces": 0},
	}


func load_game() -> void:
	data = sanitize(SaveManager.read())


## Merges loaded data over defaults and coerces every field to a safe type,
## so a hand-edited or partially written save can never crash the game.
static func sanitize(raw: Dictionary) -> Dictionary:
	var d := defaults()
	if raw.is_empty():
		return d
	d["started"] = bool(raw.get("started", false))
	d["coins"] = maxi(0, int(raw.get("coins", 0)))
	d["unlocked"] = clampi(int(raw.get("unlocked", 0)), 0, LevelCatalog.count() - 1)
	d["game_complete"] = bool(raw.get("game_complete", false))
	d["intro_seen"] = bool(raw.get("intro_seen", false))
	var lv: Variant = raw.get("levels", {})
	if typeof(lv) == TYPE_DICTIONARY:
		for id in lv:
			if LevelCatalog.index_of(str(id)) >= 0 and typeof(lv[id]) == TYPE_DICTIONARY:
				d["levels"][str(id)] = _sanitize_record(lv[id])
	var up: Variant = raw.get("upgrades", {})
	if typeof(up) == TYPE_DICTIONARY:
		for id in up:
			if GameData.UPGRADES.has(str(id)):
				d["upgrades"][str(id)] = clampi(int(up[id]), 0, GameData.UPGRADES[str(id)]["costs"].size())
	for key in ["rescued", "relics"]:
		var arr: Variant = raw.get(key, [])
		if typeof(arr) == TYPE_ARRAY:
			for v in arr:
				if not d[key].has(str(v)):
					d[key].append(str(v))
	d["rescued"] = d["rescued"].filter(func(c): return GameData.CATS.has(c))
	var st: Variant = raw.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in d["stats"]:
			if st.has(k) and (typeof(st[k]) == TYPE_INT or typeof(st[k]) == TYPE_FLOAT):
				d["stats"][k] = st[k] if k == "play_time" else int(st[k])
	return d


static func _sanitize_record(r: Dictionary) -> Dictionary:
	var rec := new_record()
	rec["completed"] = bool(r.get("completed", false))
	rec["best_time"] = float(r.get("best_time", 0.0))
	for key in ["items", "secrets", "gems", "challenges"]:
		var arr: Variant = r.get(key, [])
		if typeof(arr) == TYPE_ARRAY:
			for v in arr:
				if not rec[key].has(str(v)):
					rec[key].append(str(v))
	return rec


static func new_record() -> Dictionary:
	return {"completed": false, "best_time": 0.0, "items": [], "secrets": [], "gems": [], "challenges": []}


func save_game() -> void:
	SaveManager.write(data)
	progress_changed.emit()


func has_progress() -> bool:
	return bool(data.get("started", false))


func new_game() -> void:
	data = defaults()
	data["started"] = true
	run_blessings.clear()
	save_game()
	coins_changed.emit(coins())


func reset_progress() -> void:
	SaveManager.delete_save()
	data = defaults()
	run_blessings.clear()
	progress_changed.emit()
	coins_changed.emit(0)


# --------------------------------------------------------------------------
# Queries
# --------------------------------------------------------------------------

func coins() -> int:
	return int(data["coins"])


func record(level_id: String) -> Dictionary:
	if not data["levels"].has(level_id):
		return new_record()
	return data["levels"][level_id]


func is_unlocked(level_id: String) -> bool:
	var i := LevelCatalog.index_of(level_id)
	return i >= 0 and i <= int(data["unlocked"])


func is_completed(level_id: String) -> bool:
	return bool(record(level_id)["completed"])


## The level "Continue" should start: first unlocked level not yet completed.
func next_level_id() -> String:
	for i in range(int(data["unlocked"]) + 1):
		var id: String = LevelCatalog.LEVELS[i]["id"]
		if not is_completed(id):
			return id
	return LevelCatalog.LEVELS[mini(int(data["unlocked"]), LevelCatalog.count() - 1)]["id"]


func has_cat(cat_id: String) -> bool:
	return data["rescued"].has(cat_id)


func total_gems() -> int:
	var n := 0
	for id in data["levels"]:
		n += data["levels"][id]["gems"].size()
	return n


func total_secrets() -> int:
	var n := 0
	for id in data["levels"]:
		n += data["levels"][id]["secrets"].size()
	return n


func upgrade_level(id: String) -> int:
	return int(data["upgrades"].get(id, 0))


func upgrade_max(id: String) -> int:
	return GameData.UPGRADES[id]["costs"].size()


func upgrade_cost(id: String) -> int:
	var lvl := upgrade_level(id)
	if lvl >= upgrade_max(id):
		return -1
	var base: int = GameData.UPGRADES[id]["costs"][lvl]
	if has_cat("bramble"):
		base = int(round(base * 0.85))
	return base


## Shadow Gems required (in addition to coins) for the next level of an upgrade.
func upgrade_gem_req(id: String) -> int:
	var lvl := upgrade_level(id)
	match id:
		"heavy": return 3
		"fur": return 5
		"heart": return 8 if lvl == 2 else 0
	return 0


func can_buy(id: String) -> bool:
	var cost := upgrade_cost(id)
	return cost >= 0 and coins() >= cost and total_gems() >= upgrade_gem_req(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	data["coins"] = coins() - upgrade_cost(id)
	data["upgrades"][id] = upgrade_level(id) + 1
	save_game()
	coins_changed.emit(coins())
	return true


# --------------------------------------------------------------------------
# Derived gameplay values
# --------------------------------------------------------------------------

func has_blessing(id: String) -> bool:
	return run_blessings.has(id)


func max_hp() -> int:
	var hearts := 5 + upgrade_level("heart")
	if has_cat("pip"):
		hearts += 1
	if has_cat("moonpaw"):
		hearts += 1
	return hearts * 2


func claw_damage() -> int:
	return 2 + upgrade_level("claws") + (1 if has_blessing("sharp") else 0)


func pounce_damage() -> int:
	return 3 + 2 * upgrade_level("heavy")


func pounce_cooldown() -> float:
	var cd := 1.0 - 0.2 * upgrade_level("pounce")
	if has_cat("nibbles"):
		cd -= 0.15
	if has_blessing("quick"):
		cd *= 0.75
	return maxf(cd, 0.3)


func heal_amount() -> int:
	return 2 + upgrade_level("remedy") + (1 if has_blessing("tonic") else 0)


func coin_multiplier() -> float:
	var m := 1.0
	if has_cat("soot"):
		m += 0.15
	if has_blessing("lucky"):
		m += 0.5
	return m


func start_shields() -> int:
	var n := upgrade_level("fur")
	if has_cat("old_tom"):
		n += 1
	if has_blessing("bubble"):
		n += 1
	return n


func speed_multiplier() -> float:
	return 1.12 if has_blessing("swift") else 1.0


func jump_multiplier() -> float:
	return 1.08 if has_blessing("spring") else 1.0


func hazard_damage() -> int:
	return 1 if has_cat("cinder") else 2


func magnet_radius() -> float:
	return 56.0 if upgrade_level("whiskers") > 0 else 18.0


# --------------------------------------------------------------------------
# Run blessings (temporary)
# --------------------------------------------------------------------------

func offer_blessings(count := 3) -> Array[String]:
	var pool: Array[String] = []
	for id: String in GameData.BLESSINGS:
		if not run_blessings.has(id) or id == "tonic":
			pool.append(id)
	var out: Array[String] = []
	while out.size() < count and pool.size() > 0:
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


func add_blessing(id: String) -> void:
	if not GameData.BLESSINGS.has(id):
		return
	if not run_blessings.has(id):
		run_blessings.append(id)


func clear_run() -> void:
	run_blessings.clear()


# --------------------------------------------------------------------------
# Level completion
# --------------------------------------------------------------------------

## Commits the results of a finished level. `result` keys:
##   items: Array of item keys picked up this run (coins, fish ignored)
##   coins: Dictionary item_key -> coin value (only for not-yet-saved items)
##   secrets, gems: Arrays of keys; cats: Array of cat ids; relic: String
##   deaths: int, heals: int, time: float, boss: bool, secrets_total, gems_total
## Returns a summary of what was newly awarded (no reward is ever granted twice).
func commit_level(level_id: String, result: Dictionary) -> Dictionary:
	var rec: Dictionary = record(level_id).duplicate(true)
	var first_clear := not bool(rec["completed"])
	var summary := {"coins": 0, "new_secrets": 0, "new_gems": 0, "new_cats": [], "first_clear": first_clear,
		"challenges": [], "unlocked": "", "relic": ""}
	var coin_total := 0.0
	var coin_map: Dictionary = result.get("coins", {})
	for key in coin_map:
		if not rec["items"].has(key):
			rec["items"].append(key)
			coin_total += float(coin_map[key])
	for key in result.get("items", []):
		if not rec["items"].has(key):
			rec["items"].append(key)
	for key in result.get("secrets", []):
		if not rec["secrets"].has(key):
			rec["secrets"].append(key)
			summary["new_secrets"] += 1
			data["stats"]["secrets"] += 1
	for key in result.get("gems", []):
		if not rec["gems"].has(key):
			rec["gems"].append(key)
			summary["new_gems"] += 1
	for cat in result.get("cats", []):
		if GameData.CATS.has(cat) and not data["rescued"].has(cat):
			data["rescued"].append(cat)
			summary["new_cats"].append(cat)
	var relic: String = result.get("relic", "")
	if relic != "" and not data["relics"].has(relic):
		data["relics"].append(relic)
		summary["relic"] = relic
	if first_clear:
		coin_total += 20.0
		if result.get("boss", false):
			coin_total += 50.0
			data["stats"]["bosses"] += 1
		data["stats"]["levels_done"] += 1
	# Optional challenges - each pays out once.
	var earned: Array = []
	if int(result.get("secrets_total", 0)) > 0 and rec["secrets"].size() >= int(result["secrets_total"]):
		earned.append("secrets")
	if int(result.get("gems_total", 0)) > 0 and rec["gems"].size() >= int(result["gems_total"]):
		earned.append("gems")
	if int(result.get("deaths", 1)) == 0:
		earned.append("deathless")
	if result.get("boss", false) and int(result.get("heals", 1)) == 0:
		earned.append("no_heal")
	for ch in earned:
		if not rec["challenges"].has(ch):
			rec["challenges"].append(ch)
			summary["challenges"].append(ch)
			coin_total += GameData.CHALLENGE_REWARD
	rec["completed"] = true
	var t := float(result.get("time", 0.0))
	if t > 0.0 and (rec["best_time"] <= 0.0 or t < rec["best_time"]):
		rec["best_time"] = t
	data["levels"][level_id] = rec
	var gained := int(round(coin_total))
	data["coins"] = coins() + gained
	data["stats"]["coins_earned"] += gained
	summary["coins"] = gained
	var idx := LevelCatalog.index_of(level_id)
	if idx + 1 < LevelCatalog.count() and int(data["unlocked"]) < idx + 1:
		data["unlocked"] = idx + 1
		summary["unlocked"] = LevelCatalog.LEVELS[idx + 1]["id"]
	if idx == LevelCatalog.count() - 1:
		data["game_complete"] = true
	data["started"] = true
	save_game()
	coins_changed.emit(coins())
	return summary


func add_stat(key: String, amount: Variant = 1) -> void:
	if data["stats"].has(key):
		data["stats"][key] += amount
