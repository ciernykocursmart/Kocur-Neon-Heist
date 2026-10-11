class_name Progression
extends RefCounted
## Rules for points, trophies, medals, unlocks and records. Pure functions on
## the save dictionary so they are easy to test.

## Grand Prix points for 1st..6th.
const POINTS := [10, 7, 5, 3, 2, 1]
const TROPHY_NAMES := ["None", "Bronze", "Silver", "Gold"]
const MEDAL_NAMES := ["None", "Bronze", "Silver", "Gold"]


static func points_for(position: int) -> int:
	return POINTS[position - 1] if position >= 1 and position <= POINTS.size() else 0


## Trophy for an overall cup standing: 1st gold (3), 2nd silver (2), 3rd bronze (1).
static func trophy_for(standing: int) -> int:
	return clampi(4 - standing, 0, 3)


static func cup_unlocked(save: Dictionary, cup_id: String) -> bool:
	var idx := -1
	for i in TrackCatalog.CUPS.size():
		if TrackCatalog.CUPS[i]["id"] == cup_id:
			idx = i
	if idx <= 0:
		return idx == 0
	var prev: String = TrackCatalog.CUPS[idx - 1]["id"]
	return int(save["cups"][prev]["trophy"]) > 0


static func track_unlocked(save: Dictionary, track_id: String) -> bool:
	return cup_unlocked(save, TrackCatalog.cup_of_track(track_id))


static func cup_unlock_text(cup_id: String) -> String:
	for i in TrackCatalog.CUPS.size():
		if TrackCatalog.CUPS[i]["id"] == cup_id and i > 0:
			return "Earn a trophy in the %s" % TrackCatalog.CUPS[i - 1]["name"]
	return ""


static func champion(save: Dictionary, difficulty := "") -> bool:
	for c in TrackCatalog.CUPS:
		var key := "trophy" if difficulty == "" else "trophy_" + difficulty
		if int(save["cups"][c["id"]][key]) <= 0:
			return false
	return true


static func gold_medals(save: Dictionary) -> int:
	var n := 0
	for t in save["records"]:
		if int(save["records"][t]["tt_medal"]) >= 3:
			n += 1
	return n


static func is_unlocked(save: Dictionary, rule: String) -> bool:
	if rule == "":
		return true
	var parts := rule.split(":")
	match parts[0]:
		"cup":
			return int(save["cups"].get(parts[1], {}).get("trophy", 0)) > 0
		"cup_gold":
			return int(save["cups"].get(parts[1], {}).get("trophy", 0)) >= 3
		"medal":
			var tier := MEDAL_NAMES.find(parts[2].capitalize())
			return int(save["records"].get(parts[1], {}).get("tt_medal", 0)) >= tier
		"golds":
			return gold_medals(save) >= int(parts[1])
		"champion":
			return champion(save)
		"hard_champion":
			return champion(save, "hard")
	return false


## Every unlockable as {id, kind, name, rule}.
static func all_unlockables() -> Array:
	var out := []
	for id in Catalog.PLAYABLE:
		out.append({"id": "racer:" + id, "kind": "Racer", "name": Catalog.RACERS[id]["name"], "rule": Catalog.RACERS[id]["unlock"]})
	for id in Catalog.KART_ORDER:
		out.append({"id": "kart:" + id, "kind": "Kart", "name": Catalog.KARTS[id]["name"], "rule": Catalog.KARTS[id]["unlock"]})
	for id in Catalog.PAINT_ORDER:
		out.append({"id": "paint:" + id, "kind": "Paint", "name": Catalog.PAINTS[id]["name"], "rule": Catalog.PAINTS[id]["unlock"]})
	for id in Catalog.WHEEL_ORDER:
		out.append({"id": "wheels:" + id, "kind": "Wheels", "name": Catalog.WHEELS[id]["name"], "rule": Catalog.WHEELS[id]["unlock"]})
	for id in Catalog.ACCESSORY_ORDER:
		out.append({"id": "accessory:" + id, "kind": "Accessory", "name": Catalog.ACCESSORIES[id]["name"], "rule": Catalog.ACCESSORIES[id]["unlock"]})
	for c in TrackCatalog.CUPS:
		out.append({"id": "cup:" + c["id"], "kind": "Cup", "name": c["name"], "rule": "" if c == TrackCatalog.CUPS[0] else "cup:" + TrackCatalog.CUPS[TrackCatalog.CUPS.find(c) - 1]["id"]})
	return out


## Unlockables that are unlocked now but were not marked seen. Marks them.
static func collect_new_unlocks(save: Dictionary) -> Array:
	var fresh := []
	var seen: Array = save["seen_unlocks"]
	for u in all_unlockables():
		if u["rule"] == "":
			continue
		if is_unlocked(save, u["rule"]) and not (u["id"] in seen):
			seen.append(u["id"])
			fresh.append(u)
	return fresh


static func medal_for(track_id: String, total_time: float) -> int:
	var m: Array = TrackCatalog.TRACKS[track_id]["medals"]
	if total_time <= 0.0:
		return 0
	if total_time <= m[0]:
		return 3
	if total_time <= m[1]:
		return 2
	if total_time <= m[2]:
		return 1
	return 0


## Applies a valid race result to records and stats. Returns flags for the UI.
static func record_race(save: Dictionary, res: Dictionary) -> Dictionary:
	var out := {"new_best_time": false, "new_best_lap": false, "medal": 0, "medal_improved": false}
	var tid: String = res["track"]
	if not save["records"].has(tid) or not res.get("valid", false):
		return out
	var r: Dictionary = save["records"][tid]
	var time: float = res["player_time"]
	var lap: float = res["player_best_lap"]
	var full_laps := int(res.get("laps", 3)) == 3
	if res["mode"] == "time_trial":
		save["stats"]["time_trials"] += 1
		if full_laps and (r["tt_time"] <= 0.0 or time < r["tt_time"]):
			r["tt_time"] = time
			out["new_best_time"] = true
		if r["tt_lap"] <= 0.0 or lap < r["tt_lap"]:
			r["tt_lap"] = lap
			out["new_best_lap"] = true
		if full_laps:
			var medal := medal_for(tid, time)
			out["medal"] = medal
			if medal > int(r["tt_medal"]):
				r["tt_medal"] = medal
				out["medal_improved"] = true
	else:
		if full_laps and (r["race_time"] <= 0.0 or time < r["race_time"]):
			r["race_time"] = time
			out["new_best_time"] = true
		if r["race_lap"] <= 0.0 or lap < r["race_lap"]:
			r["race_lap"] = lap
			out["new_best_lap"] = true
		var pos: int = res["player_position"]
		save["stats"]["races"] += 1
		if pos == 1:
			save["stats"]["wins"] += 1
			r["wins"] += 1
		if pos <= 3:
			save["stats"]["podiums"] += 1
	return out


static func add_recent(save: Dictionary, res: Dictionary) -> void:
	var entry := {"track": res["track"], "mode": res["mode"], "position": res.get("player_position", 1),
		"time": res.get("player_time", 0.0), "difficulty": res.get("difficulty", "normal"),
		"date": Time.get_date_string_from_system()}
	var recent: Array = save["recent"]
	recent.push_front(entry)
	save["recent"] = recent.slice(0, 12)


## Stores a finished cup. Returns true if the trophy improved.
static func record_cup(save: Dictionary, cup_id: String, standing: int, points: int, difficulty: String) -> bool:
	var c: Dictionary = save["cups"][cup_id]
	var trophy := trophy_for(standing)
	var improved := trophy > int(c["trophy"])
	if trophy > 0 and int(c["trophy"]) == 0:
		save["stats"]["cups_finished"] += 1
	c["trophy"] = maxi(int(c["trophy"]), trophy)
	var key := "trophy_" + difficulty
	if c.has(key):
		c[key] = maxi(int(c[key]), trophy)
	c["best_points"] = maxi(int(c["best_points"]), points)
	return improved
