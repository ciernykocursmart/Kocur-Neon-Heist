extends Node
## Game autoload: persistent progress (through SaveManager) and the state of
## the current run - difficulty, score, lives, continues, checkpoint and the
## pickups already consumed in this attempt (so restarts never duplicate food).

const Levels = preload("res://scripts/data/levels.gd")
const B = preload("res://scripts/data/balance.gd")

signal progress_changed

var data := {}

# --- current run ---
var difficulty := "normal"
var level_index := 0
var score := 0
var lives := 3
var continues_left := 3
var level_start_score := 0
var level_start_lives := 3
var checkpoint := 0  ## index of the first encounter that is not cleared yet
var consumed := {}  ## ids of pickups/props used up in this attempt
var continues_used := 0
var next_life_at := B.EXTRA_LIFE_EVERY
var attempt := {}  ## stats of the current level attempt (survive continues)
var bot_input = null  ## tests: an object with poll(player) used instead of the keyboard
var god_mode := false  ## tests only


func _ready() -> void:
	load_game()


# ------------------------------------------------------------------ saves
func defaults() -> Dictionary:
	return {
		"version": 1,
		"unlocked": 1,
		"completed": {},
		"best_scores": {},
		"best_ranks": {},
		"golden": {},
		"challenges": {},
		"campaign_complete": false,
		"completions": 0,
		"best_campaign_score": 0,
		"difficulty": "normal",
		"stats": {"enemies": 0, "food": 0, "deaths": 0, "bosses": 0, "play_time": 0.0, "levels_cleared": 0},
		"run": {"active": false, "level": 0, "difficulty": "normal", "score": 0, "lives": 3},
	}


func load_game() -> void:
	var raw: Dictionary = SaveManager.read()
	data = _sanitize(raw)
	difficulty = String(data["difficulty"])


## Merges whatever was read over the defaults and clamps every field, so a
## missing, partial or hand-edited save can never crash or unlock too much.
func _sanitize(raw: Dictionary) -> Dictionary:
	var d := defaults()
	if raw.is_empty():
		return d
	d["unlocked"] = clampi(int(raw.get("unlocked", 1)), 1, Levels.count())
	for key in ["completed", "best_scores", "best_ranks", "golden", "challenges"]:
		var src: Variant = raw.get(key, {})
		if typeof(src) == TYPE_DICTIONARY:
			for lv: Dictionary in Levels.LEVELS:
				if (src as Dictionary).has(lv["id"]):
					var v: Variant = src[lv["id"]]
					match key:
						"best_scores": d[key][lv["id"]] = maxi(0, int(v))
						"best_ranks": d[key][lv["id"]] = String(v) if String(v) in ["S", "A", "B", "C", "D"] else "D"
						_: d[key][lv["id"]] = bool(v)
	d["campaign_complete"] = bool(raw.get("campaign_complete", false))
	d["completions"] = maxi(0, int(raw.get("completions", 0)))
	d["best_campaign_score"] = maxi(0, int(raw.get("best_campaign_score", 0)))
	var df := String(raw.get("difficulty", "normal"))
	d["difficulty"] = df if df in B.DIFFICULTIES else "normal"
	var st: Variant = raw.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k: String in d["stats"]:
			if (st as Dictionary).has(k):
				d["stats"][k] = maxf(0.0, float(st[k])) if k == "play_time" else maxi(0, int(st[k]))
	var run: Variant = raw.get("run", {})
	if typeof(run) == TYPE_DICTIONARY:
		var r: Dictionary = run
		d["run"]["active"] = bool(r.get("active", false))
		d["run"]["level"] = clampi(int(r.get("level", 0)), 0, Levels.count() - 1)
		var rd := String(r.get("difficulty", "normal"))
		d["run"]["difficulty"] = rd if rd in B.DIFFICULTIES else "normal"
		d["run"]["score"] = maxi(0, int(r.get("score", 0)))
		d["run"]["lives"] = clampi(int(r.get("lives", 3)), 1, B.MAX_LIVES)
	# A level can only be in progress if it is unlocked.
	if int(d["run"]["level"]) >= int(d["unlocked"]):
		d["run"]["level"] = int(d["unlocked"]) - 1
	return d


func save_game() -> void:
	SaveManager.write(data)
	progress_changed.emit()


func reset_progress() -> void:
	data = defaults()
	data["difficulty"] = difficulty
	save_game()


func has_progress() -> bool:
	return bool(data["run"]["active"]) or int(data["unlocked"]) > 1 or not (data["completed"] as Dictionary).is_empty()


func is_unlocked(i: int) -> bool:
	return i >= 0 and i < int(data["unlocked"])


func is_completed(i: int) -> bool:
	return bool(data["completed"].get(Levels.get_level(i)["id"], false))


func best_score(i: int) -> int:
	return int(data["best_scores"].get(Levels.get_level(i)["id"], 0))


func best_rank(i: int) -> String:
	return String(data["best_ranks"].get(Levels.get_level(i)["id"], ""))


func has_golden(i: int) -> bool:
	return bool(data["golden"].get(Levels.get_level(i)["id"], false))


func has_challenge(i: int) -> bool:
	return bool(data["challenges"].get(Levels.get_level(i)["id"], false))


func set_difficulty(d: String) -> void:
	if d in B.DIFFICULTIES:
		difficulty = d
		data["difficulty"] = d
		save_game()


func diff() -> Dictionary:
	return B.diff(difficulty)


# ------------------------------------------------------------------ runs
func new_campaign(d: String) -> void:
	set_difficulty(d)
	score = 0
	lives = int(diff()["lives"])
	next_life_at = B.EXTRA_LIFE_EVERY
	begin_level(0)
	_store_run()


## Continue: the level saved in the current run, or the furthest unlocked level.
func continue_campaign() -> void:
	var run: Dictionary = data["run"]
	if bool(run["active"]):
		difficulty = String(run["difficulty"])
		score = int(run["score"])
		lives = int(run["lives"])
		next_life_at = (score / B.EXTRA_LIFE_EVERY + 1) * B.EXTRA_LIFE_EVERY
		begin_level(int(run["level"]))
	else:
		score = 0
		lives = int(diff()["lives"])
		next_life_at = B.EXTRA_LIFE_EVERY
		begin_level(continue_level())


func continue_level() -> int:
	if bool(data["run"]["active"]):
		return int(data["run"]["level"])
	for i in Levels.count():
		if is_unlocked(i) and not is_completed(i):
			return i
	return 0


## Level select: a single street with a fresh score.
func play_level(i: int) -> void:
	score = 0
	lives = int(diff()["lives"])
	next_life_at = B.EXTRA_LIFE_EVERY
	begin_level(i)


func begin_level(i: int) -> void:
	level_index = clampi(i, 0, Levels.count() - 1)
	checkpoint = 0
	consumed = {}
	continues_used = 0
	continues_left = int(diff()["continues"])
	level_start_score = score
	level_start_lives = lives
	attempt = {"enemies": 0, "food": 0, "damage": 0.0, "deaths": 0, "time": 0.0, "specials": 0, "best_combo": 0,
		"golden": false, "bosses": 0}


func restart_level() -> void:
	score = level_start_score
	lives = level_start_lives
	next_life_at = (score / B.EXTRA_LIFE_EVERY + 1) * B.EXTRA_LIFE_EVERY
	begin_level(level_index)


func can_continue() -> bool:
	return continues_left != 0


## Game over -> continue: full lives, back to the last checkpoint. Consumed
## pickups stay consumed and cleared encounters stay cleared.
func use_continue() -> bool:
	if not can_continue():
		return false
	if continues_left > 0:
		continues_left -= 1
	continues_used += 1
	lives = int(diff()["lives"])
	return true


func add_score(points: int) -> int:
	var p := int(round(points * float(diff()["score"])))
	score += p
	return p


## Returns true when the score crossed an extra-life threshold.
func check_extra_life() -> bool:
	if score >= next_life_at:
		next_life_at += B.EXTRA_LIFE_EVERY
		if lives < B.MAX_LIVES:
			lives += 1
			return true
	return false


func _store_run() -> void:
	data["run"] = {"active": true, "level": level_index, "difficulty": difficulty, "score": score, "lives": lives}
	save_game()


## Called when a level is cleared. Updates unlocks, bests, collectibles and
## stats exactly once per clear. Returns flags for the results screen.
func record_level_complete(stats: Dictionary) -> Dictionary:
	var lv := Levels.get_level(level_index)
	var id: String = lv["id"]
	var res := {"new_best": false, "unlocked_next": false, "first_clear": not is_completed(level_index)}
	data["completed"][id] = true
	if level_index + 1 < Levels.count() and int(data["unlocked"]) < level_index + 2:
		data["unlocked"] = level_index + 2
		res["unlocked_next"] = true
	var level_score := int(stats.get("level_score", 0))
	if level_score > best_score(level_index):
		data["best_scores"][id] = level_score
		res["new_best"] = true
	var rank := String(stats.get("rank", "D"))
	if best_rank(level_index) == "" or "SABCD".find(rank) < "SABCD".find(best_rank(level_index)):
		data["best_ranks"][id] = rank
	if bool(stats.get("golden", false)):
		data["golden"][id] = true
	if bool(stats.get("challenge", false)):
		data["challenges"][id] = true
	add_stats(stats)
	data["stats"]["levels_cleared"] = int(data["stats"]["levels_cleared"]) + 1
	if level_index + 1 < Levels.count():
		data["run"] = {"active": true, "level": level_index + 1, "difficulty": difficulty, "score": score, "lives": lives}
	else:
		data["run"]["active"] = false
	save_game()
	return res


func add_stats(stats: Dictionary) -> void:
	var st: Dictionary = data["stats"]
	st["enemies"] = int(st["enemies"]) + int(stats.get("enemies", 0))
	st["food"] = int(st["food"]) + int(stats.get("food", 0))
	st["deaths"] = int(st["deaths"]) + int(stats.get("deaths", 0))
	st["bosses"] = int(st["bosses"]) + int(stats.get("bosses", 0))
	st["play_time"] = float(st["play_time"]) + float(stats.get("time", 0.0))


func record_campaign_complete() -> void:
	data["campaign_complete"] = true
	data["completions"] = int(data["completions"]) + 1
	data["best_campaign_score"] = maxi(int(data["best_campaign_score"]), score)
	data["run"]["active"] = false
	save_game()


## Saves the run position so "Continue" in the main menu resumes this street.
func save_run_position() -> void:
	_store_run()


func level_data() -> Dictionary:
	return Levels.get_level(level_index)
