extends Enemy
## White Street Punk: the basic brawler. Walks up, jabs, and sometimes
## follows the jab with a kick. Weak alone, dangerous in pairs.


func on_setup() -> void:
	moves = {
		"punch": {"windup": 0.38, "active": 0.08, "recovery": 0.36, "dmg": 1.0, "x0": -4.0, "x1": 58.0,
			"depth": 16.0, "z0": 10.0, "z1": 90.0, "kb": 90.0, "stun": 0.3, "lunge": 30.0, "sound": "jab"},
		"kick": {"windup": 0.22, "active": 0.1, "recovery": 0.45, "dmg": 1.15, "x0": -4.0, "x1": 64.0,
			"depth": 16.0, "z0": 0.0, "z1": 70.0, "kb": 160.0, "stun": 0.35, "lunge": 24.0, "sound": "swipe"},
	}


func pick_attack(p: Fighter) -> String:
	if has_token and in_melee_range(p, atk_range):
		queue_next = "kick" if rng.randf() < 0.35 else ""
		return "punch"
	return ""


func pose() -> Dictionary:
	var p := super()
	if state == "attack" and move_name == "kick":
		p["arm_f"] = Vector2(-6, 8)
		p["leg_f"] = 1.3
		p["lift_f"] = 26.0
		p["lean"] = -0.2
	return p
