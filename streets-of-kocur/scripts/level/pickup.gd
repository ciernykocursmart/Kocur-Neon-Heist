extends Node2D
## A food or score item lying on the street. Collected by walking over it;
## removed on collection and remembered by id so restarts never respawn it.

const B = preload("res://scripts/data/balance.gd")

var kind := "fish"
var uid := ""
var z := 0.0
var vz := 0.0
var t := 0.0
var collected := false
var drop_vx := 0.0


func setup(k: String, id: String, pos: Vector2, popped := false) -> void:
	kind = k
	uid = id
	position = pos
	if popped:
		z = 20.0
		vz = 320.0
		drop_vx = 0.0


func tick(dt: float, level: Node) -> void:
	t += dt
	if z > 0.0 or vz > 0.0:
		z += vz * dt
		vz -= 1400.0 * dt
		if z <= 0.0:
			z = 0.0
			vz = 0.0
	position = level.constrain(null, position, position)


func can_collect() -> bool:
	return not collected and z <= 4.0 and t > 0.25


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	CatPainter.draw_shadow(self, 16.0, z)
	var bob := 3.0 + sin(t * 4.0) * 3.0 if z <= 0.0 else 0.0
	if kind in ["fish", "chicken", "can"] or kind == "golden":
		# soft glow so food reads clearly on busy floors
		draw_colored_polygon(CatPainter._ellipse(Vector2(0, -12 - bob - z), 26, 20), Color(1, 1, 0.8, 0.12 + 0.06 * sin(t * 5.0)))
	PickupArt.draw_item(self, kind, Vector2(0, -bob - z), 1.0, t)
