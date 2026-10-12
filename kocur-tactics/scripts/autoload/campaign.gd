extends Node
## Campaign autoload: persistent progress (missions, roster, upgrades,
## difficulty, records). Saved through SaveManager at safe points only:
## after a battle result, after buying an upgrade, after changing difficulty.

signal changed

const UD = preload("res://scripts/data/units_data.gd")
const Missions = preload("res://scripts/data/missions.gd")

const XP_BASE := 40
const XP_PER_KILL := 10
const XP_KILL_CAP := 30
const XP_RESERVE := 20

var data := {}


func _ready() -> void:
	load_game()


func defaults() -> Dictionary:
	var roster := {}
	for id: String in UD.HERO_ORDER:
		roster[id] = {"xp": 0, "upgrades": {}}
	var recruited := []
	for id: String in UD.HERO_ORDER:
		if bool(UD.HEROES[id]["start"]):
			recruited.append(id)
	return {
		"started": false, "difficulty": "normal", "missions": {}, "challenges": {}, "roster": roster,
		"recruited": recruited, "shards": 0, "shards_earned": 0, "campaign_complete": false, "battles_won": 0,
		"battles_lost": 0, "last_mission": "",
	}


func load_game() -> void:
	var raw: Dictionary = SaveManager.read()
	data = sanitize(raw)


## Merges a loaded (possibly malformed or old) save into a valid structure.
func sanitize(raw: Dictionary) -> Dictionary:
	var d := defaults()
	if raw.is_empty():
		return d
	d["started"] = bool(raw.get("started", false))
	var diff := str(raw.get("difficulty", "normal"))
	d["difficulty"] = diff if diff in UD.DIFFICULTIES else "normal"
	d["shards"] = maxi(0, int(raw.get("shards", 0)))
	d["shards_earned"] = maxi(0, int(raw.get("shards_earned", 0)))
	d["campaign_complete"] = bool(raw.get("campaign_complete", false))
	d["battles_won"] = maxi(0, int(raw.get("battles_won", 0)))
	d["battles_lost"] = maxi(0, int(raw.get("battles_lost", 0)))
	d["last_mission"] = str(raw.get("last_mission", ""))
	var rm: Variant = raw.get("missions", {})
	if rm is Dictionary:
		for id: String in Missions.mission_ids():
			if (rm as Dictionary).has(id) and rm[id] is Dictionary:
				var e: Dictionary = rm[id]
				var opt := []
				var raw_opt: Variant = e.get("optional", [])
				var n: int = (Missions.get_mission(id)["optional"] as Array).size()
				for i in n:
					opt.append(raw_opt is Array and i < (raw_opt as Array).size() and bool(raw_opt[i]))
				d["missions"][id] = {"completed": bool(e.get("completed", false)),
					"best_turns": maxi(0, int(e.get("best_turns", 0))), "medal": clampi(int(e.get("medal", 0)), 0, 3),
					"optional": opt, "plays": maxi(0, int(e.get("plays", 0)))}
	var rc: Variant = raw.get("challenges", {})
	if rc is Dictionary:
		for id: String in Missions.challenge_ids():
			if (rc as Dictionary).has(id) and rc[id] is Dictionary:
				d["challenges"][id] = {"completed": bool(rc[id].get("completed", false)),
					"best_turns": maxi(0, int(rc[id].get("best_turns", 0)))}
	var rr: Variant = raw.get("roster", {})
	if rr is Dictionary:
		for id: String in UD.HERO_ORDER:
			if (rr as Dictionary).has(id) and rr[id] is Dictionary:
				var hx: Dictionary = rr[id]
				var ups := {}
				var ru: Variant = hx.get("upgrades", {})
				if ru is Dictionary:
					for k: String in UD.UPGRADE_ORDER:
						var maxr: int = (UD.UPGRADES[k]["costs"] as Array).size()
						ups[k] = clampi(int((ru as Dictionary).get(k, 0)), 0, maxr)
				d["roster"][id] = {"xp": clampi(int(hx.get("xp", 0)), 0, 100000), "upgrades": ups}
	var rec: Variant = raw.get("recruited", [])
	if rec is Array:
		for id: Variant in rec:
			if str(id) in UD.HERO_ORDER and not (d["recruited"] as Array).has(str(id)):
				d["recruited"].append(str(id))
	return d


func save_game() -> bool:
	var ok: bool = SaveManager.write(data.duplicate(true))
	changed.emit()
	return ok


func has_progress() -> bool:
	return bool(data.get("started", false))


func new_campaign(diff := "normal") -> void:
	data = defaults()
	data["started"] = true
	data["difficulty"] = diff if diff in UD.DIFFICULTIES else "normal"
	save_game()


func reset_progress() -> void:
	data = defaults()
	SaveManager.delete_save()
	changed.emit()


func set_difficulty(diff: String) -> void:
	if diff in UD.DIFFICULTIES:
		data["difficulty"] = diff
		save_game()


func difficulty() -> String:
	return str(data.get("difficulty", "normal"))


# --------------------------------------------------------------------------
# Missions
# --------------------------------------------------------------------------

func mission_record(id: String) -> Dictionary:
	return data["missions"].get(id, {})


func is_completed(id: String) -> bool:
	if id.begins_with("c"):
		return bool(data["challenges"].get(id, {}).get("completed", false))
	return bool(mission_record(id).get("completed", false))


func is_unlocked(id: String) -> bool:
	var m := Missions.get_mission(id)
	if m.is_empty():
		return false
	if m.get("challenge", false):
		return is_completed(str(m["unlock"]))
	var i := Missions.index_of(id)
	return i == 0 or is_completed(Missions.MISSIONS[i - 1]["id"])


## The first unlocked mission that has not been completed (or the last one).
func next_mission() -> String:
	for m: Dictionary in Missions.MISSIONS:
		if not is_completed(m["id"]):
			return m["id"]
	return Missions.MISSIONS[Missions.MISSIONS.size() - 1]["id"]


func completed_count() -> int:
	var n := 0
	for id: String in Missions.mission_ids():
		if is_completed(id):
			n += 1
	return n


func medal_count() -> int:
	var n := 0
	for id: String in Missions.mission_ids():
		n += int(mission_record(id).get("medal", 0))
	return n


# --------------------------------------------------------------------------
# Roster
# --------------------------------------------------------------------------

func is_recruited(hero_id: String) -> bool:
	return (data["recruited"] as Array).has(hero_id)


func recruited() -> Array[String]:
	var out: Array[String] = []
	for id: String in UD.HERO_ORDER:
		if is_recruited(id):
			out.append(id)
	return out


func hero_xp(hero_id: String) -> int:
	return int(data["roster"][hero_id]["xp"])


func hero_level(hero_id: String) -> int:
	return UD.hero_level_for_xp(hero_xp(hero_id))


func hero_upgrades(hero_id: String) -> Dictionary:
	return data["roster"][hero_id]["upgrades"]


func hero_stats(hero_id: String) -> Dictionary:
	return UD.hero_stats(hero_id, hero_level(hero_id), hero_upgrades(hero_id))


## Heroes that may be deployed in a mission (captives of that mission excluded).
func available_heroes(mission_id: String) -> Array[String]:
	var m := Missions.get_mission(mission_id)
	var caps: Array = m.get("captives", [])
	var out: Array[String] = []
	for id in recruited():
		if not caps.has(id):
			out.append(id)
	return out


func default_squad(mission_id: String) -> Array[String]:
	var m := Missions.get_mission(mission_id)
	var out: Array[String] = []
	for id in available_heroes(mission_id):
		if out.size() < int(m.get("slots", 3)):
			out.append(id)
	return out


## Squad entries handed to the battle model.
func squad_entries(mission_id: String, ids: Array) -> Array:
	var m := Missions.get_mission(mission_id)
	var out := []
	if m.get("challenge", false):
		for pair: Array in m["squad"]:
			out.append({"hero_id": pair[0], "level": int(pair[1]), "upgrades": {}})
		return out
	for id: Variant in ids:
		out.append({"hero_id": str(id), "level": hero_level(str(id)), "upgrades": hero_upgrades(str(id)).duplicate()})
	return out


## Mission dictionary for a battle, with roster info for freeable heroes.
func battle_mission(mission_id: String) -> Dictionary:
	var m := Missions.get_mission(mission_id).duplicate(true)
	var rl := {}
	for cap: Variant in m.get("captives", []):
		var cid := str(cap)
		if UD.HEROES.has(cid) and is_recruited(cid):
			rl[cid] = {"level": hero_level(cid), "upgrades": hero_upgrades(cid).duplicate()}
	m["roster_levels"] = rl
	return m


func upgrade_rank(hero_id: String, up: String) -> int:
	return int(hero_upgrades(hero_id).get(up, 0))


func upgrade_cost(hero_id: String, up: String) -> int:
	var costs: Array = UD.UPGRADES[up]["costs"]
	var r := upgrade_rank(hero_id, up)
	return -1 if r >= costs.size() else int(costs[r])


func can_buy(hero_id: String, up: String) -> bool:
	var c := upgrade_cost(hero_id, up)
	return is_recruited(hero_id) and c > 0 and int(data["shards"]) >= c


func buy(hero_id: String, up: String) -> bool:
	if not can_buy(hero_id, up):
		return false
	data["shards"] = int(data["shards"]) - upgrade_cost(hero_id, up)
	data["roster"][hero_id]["upgrades"][up] = upgrade_rank(hero_id, up) + 1
	save_game()
	return true


# --------------------------------------------------------------------------
# Results
# --------------------------------------------------------------------------

## Applies a battle summary. Returns what changed (for the results screen).
## Rewards are only granted the first time (XP, shards, recruits); replays
## only improve records, medals and newly achieved optional objectives.
func record_result(mission_id: String, s: Dictionary) -> Dictionary:
	var m := Missions.get_mission(mission_id)
	var out := {"victory": s.get("result", "") == "victory", "first_clear": false, "xp": {}, "level_ups": [],
		"shards": 0, "recruits": [], "medal": 0, "new_optional": [], "campaign_complete": false}
	data["started"] = true
	data["last_mission"] = mission_id
	if m.get("challenge", false):
		if out["victory"]:
			var cr: Dictionary = data["challenges"].get(mission_id, {"completed": false, "best_turns": 0})
			out["first_clear"] = not bool(cr["completed"])
			cr["completed"] = true
			var bt := int(cr["best_turns"])
			cr["best_turns"] = int(s["turns"]) if bt == 0 else mini(bt, int(s["turns"]))
			data["challenges"][mission_id] = cr
			data["battles_won"] = int(data["battles_won"]) + 1
		else:
			data["battles_lost"] = int(data["battles_lost"]) + 1
		save_game()
		return out
	if not out["victory"]:
		data["battles_lost"] = int(data["battles_lost"]) + 1
		save_game()
		return out
	data["battles_won"] = int(data["battles_won"]) + 1
	var nopt: int = (m["optional"] as Array).size()
	var rec: Dictionary = data["missions"].get(mission_id, {"completed": false, "best_turns": 0, "medal": 0,
		"optional": [], "plays": 0})
	while (rec["optional"] as Array).size() < nopt:
		rec["optional"].append(false)
	var first := not bool(rec["completed"])
	out["first_clear"] = first
	rec["completed"] = true
	rec["plays"] = int(rec.get("plays", 0)) + 1
	var bt2 := int(rec["best_turns"])
	rec["best_turns"] = int(s["turns"]) if bt2 == 0 else mini(bt2, int(s["turns"]))
	var opt: Array = s.get("optional", [])
	var got := 0
	for i in nopt:
		var done := i < opt.size() and bool(opt[i])
		if done:
			got += 1
			if not bool(rec["optional"][i]):
				rec["optional"][i] = true
				out["new_optional"].append(i)
				out["shards"] += int(m["optional"][i].get("shards", 1))
	var medal := 1
	if got >= nopt and nopt > 0:
		medal = 3
	elif got > 0:
		medal = 2
	out["medal"] = medal
	rec["medal"] = maxi(int(rec["medal"]), medal)
	data["missions"][mission_id] = rec
	if first:
		out["shards"] += int(m.get("shards", 3))
		var deployed: Array = s.get("deployed", [])
		var kills: Dictionary = s.get("kills", {})
		for id in recruited():
			var gain := XP_RESERVE
			if deployed.has(id):
				gain = XP_BASE + mini(XP_KILL_CAP, XP_PER_KILL * int(kills.get(id, 0)))
			var before := hero_level(id)
			data["roster"][id]["xp"] = hero_xp(id) + gain
			out["xp"][id] = gain
			if hero_level(id) > before:
				out["level_ups"].append(id)
		for hid: String in UD.HERO_ORDER:
			if str(UD.HEROES[hid].get("joins", "")) == mission_id and not is_recruited(hid):
				data["recruited"].append(hid)
				out["recruits"].append(hid)
	data["shards"] = int(data["shards"]) + int(out["shards"])
	data["shards_earned"] = int(data["shards_earned"]) + int(out["shards"])
	if mission_id == "m12" and not bool(data["campaign_complete"]):
		data["campaign_complete"] = true
		out["campaign_complete"] = true
	save_game()
	return out
