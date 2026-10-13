extends Enemy
## White Brawler: big, slow, tough. Shrugs off single light hits (poise),
## throws a slow haymaker followed by an uppercut that knocks the player down.


func on_setup() -> void:
	moves = {
		"haymaker": {"windup": 0.5, "active": 0.1, "recovery": 0.25, "dmg": 1.0, "x0": -6.0, "x1": 70.0,
			"depth": 18.0, "z0": 10.0, "z1": 100.0, "kb": 140.0, "stun": 0.42, "lunge": 40.0, "sound": "heavy"},
		"uppercut": {"windup": 0.26, "active": 0.1, "recovery": 0.65, "dmg": 1.2, "x0": -6.0, "x1": 66.0,
			"depth": 18.0, "z0": 0.0, "z1": 110.0, "kb": 260.0, "launch": 320.0, "knockdown": true, "stun": 0.5,
			"lunge": 30.0, "sound": "heavy"},
	}


func pick_attack(p: Fighter) -> String:
	if has_token and in_melee_range(p, atk_range):
		queue_next = "uppercut"
		return "haymaker"
	return ""


func pose() -> Dictionary:
	var p := super()
	if state == "windup":
		p["arm_f"] = Vector2(-22, -6)
		p["lean"] = -0.35
	elif state == "attack" and move_name == "uppercut":
		p["arm_f"] = Vector2(22, -38)
		p["lean"] = 0.1
	return p
