extends Node2D
## Breakable street prop (crate, barrel, oil drum, trash can, fruit stall).
## Solid until broken; takes a few hits; drops at most one item, once.

const SIZES := {
	"crate": Vector2(30, 14), "barrel": Vector2(26, 13), "drum": Vector2(26, 13), "trashcan": Vector2(24, 12),
	"stall": Vector2(72, 16),
}
const HITS := {"crate": 2, "barrel": 2, "drum": 3, "trashcan": 1, "stall": 3}

var kind := "crate"
var uid := ""
var drop := ""
var hits_left := 2
var broken := false
var shake_t := 0.0
var t := 0.0
var z := 0.0
var hurt_w := 30.0
var depth_r := 14.0
var body_h := 60.0


func setup(k: String, id: String, pos: Vector2, drop_kind: String) -> void:
	kind = k
	uid = id
	position = pos
	drop = drop_kind
	hits_left = HITS.get(k, 2)
	var s: Vector2 = SIZES.get(k, Vector2(30, 14))
	hurt_w = s.x
	depth_r = s.y
	body_h = 110.0 if k == "stall" else 60.0


func footprint() -> Rect2:
	var s: Vector2 = SIZES.get(kind, Vector2(30, 14))
	return Rect2(position.x - s.x, position.y - s.y, s.x * 2.0, s.y * 2.0)


## Props react to player attacks only; one hit per attack activation.
func receive_hit(atk: Dictionary, _from: Node2D) -> bool:
	if broken:
		return false
	hits_left -= 2 if String(atk.get("type", "light")) in ["heavy", "special", "throw"] else 1
	shake_t = 0.2
	return true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if broken:
		return
	var sx := sin(shake_t * 80.0) * 3.0 if shake_t > 0.0 else 0.0
	draw_colored_polygon(CatPainter._ellipse(Vector2(0, 2), hurt_w * 1.1, depth_r * 0.9), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(sx, 0), 0.0, Vector2.ONE)
	var maxh: int = HITS.get(kind, 2)
	PickupArt.draw_prop(self, kind, 1.0 - float(hits_left) / float(maxh), t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
