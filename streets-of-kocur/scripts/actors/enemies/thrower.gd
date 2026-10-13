extends Enemy
## White Thrower: keeps its distance, lines up on the player's depth and
## throws bottles that fly straight along the street. Step off the line or
## jump over them. Backs off when the player gets close.

const Projectile = preload("res://scripts/combat/projectile.gd")


func on_setup() -> void:
	moves = {
		"throw": {"windup": 0.5, "active": 0.05, "recovery": 0.45, "dmg": 1.0, "sound": "bottle"},
		"scratch": {"windup": 0.3, "active": 0.08, "recovery": 0.45, "dmg": 0.7, "x0": -4.0, "x1": 52.0,
			"depth": 16.0, "z0": 10.0, "z1": 90.0, "kb": 120.0, "stun": 0.3, "lunge": 20.0, "sound": "jab"},
	}


func wants_token() -> bool:
	return false


func think_goal(p: Fighter) -> Vector2:
	var side := 1.0 if position.x >= p.position.x else -1.0
	var dx := absf(p.position.x - position.x)
	if dx < 170.0:
		return p.position + Vector2(side * 380.0, p.position.y - position.y + hover.y * 0.3)
	return Vector2(p.position.x + side * 330.0, p.position.y)


func pick_attack(p: Fighter) -> String:
	var dx := absf(p.position.x - position.x)
	var dy := absf(p.position.y - position.y)
	if dx < 50.0 and dy < 10.0:
		return "scratch"
	if dy <= 14.0 and dx >= 150.0 and dx <= 600.0 and level.ranged_ready(self):
		return "throw"
	return ""


func on_attack_start() -> void:
	if move_name == "throw":
		var pr := Projectile.new()
		pr.setup_thrown(level, self, "bottle", dmg * float(move["dmg"]), facing)
		level.add_projectile(pr)


func pose() -> Dictionary:
	var p := super()
	if state == "windup" and move_name == "throw":
		p["arm_f"] = Vector2(-20, -26)
		p["lean"] = -0.3
	elif state == "attack" and move_name == "throw":
		p["arm_f"] = Vector2(30, -14)
	return p


func draw_body() -> void:
	super()
	# Bottle in the paw while winding up.
	if state == "windup" and move_name == "throw" and not dead:
		var hand := Vector2(-6, -98)
		draw_rect(Rect2(hand + Vector2(-4, -14), Vector2(8, 18)), Color("2f9a5a"))
		draw_rect(Rect2(hand + Vector2(-2, -20), Vector2(4, 7)), Color("2f9a5a"))
