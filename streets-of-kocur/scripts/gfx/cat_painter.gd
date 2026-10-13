class_name CatPainter
extends RefCounted
## Draws every cat in the game from a "look" (fur, outfit, proportions) and a
## "pose" (limb positions, expression) with plain 2D primitives and outlines.
## Local space: feet at (0, 0), facing +x. The caller flips/scales with
## draw_set_transform, so shapes, shadows and hitboxes share one origin.

const OUTLINE_W := 3.0


static func default_pose() -> Dictionary:
	return {
		"lean": 0.0, "crouch": 0.0, "leg_f": 0.0, "leg_b": 0.0, "lift_f": 0.0, "lift_b": 0.0,
		"arm_f": Vector2(6, 22), "arm_b": Vector2(-4, 22), "tail": 0.0, "eyes": "open", "mouth": "none",
		"flash": Color(1, 1, 1, 0), "squash": Vector2.ONE, "head_tilt": 0.0, "head_dy": 0.0, "belly": 0.0,
		"curl": 0.0, "item_angle": 0.0,
	}


static func _ellipse(c: Vector2, rx: float, ry: float, rot := 0.0, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color, ow := OUTLINE_W) -> void:
	ci.draw_colored_polygon(pts, fill)
	if ow > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, ow)


static func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, w: float, fill: Color, outline: Color, ow := OUTLINE_W) -> void:
	if ow > 0.0:
		ci.draw_line(a, b, outline, w + ow * 2.0)
		ci.draw_circle(a, w * 0.5 + ow, outline)
		ci.draw_circle(b, w * 0.5 + ow, outline)
	ci.draw_line(a, b, fill, w)
	ci.draw_circle(a, w * 0.5, fill)
	ci.draw_circle(b, w * 0.5, fill)


static func _circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, outline: Color, ow := OUTLINE_W) -> void:
	if ow > 0.0:
		ci.draw_circle(c, r + ow, outline)
	ci.draw_circle(c, r, fill)


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, fill: Color, outline: Color, ow := OUTLINE_W) -> void:
	_poly(ci, PackedVector2Array([a, b, c]), fill, outline, ow)


static func _fl(c: Color, flash: Color) -> Color:
	if flash.a <= 0.0:
		return c
	return c.lerp(Color(flash.r, flash.g, flash.b, c.a), flash.a)


## Shadow on the ground under a character. Shrinks while it is in the air.
static func draw_shadow(ci: CanvasItem, rx: float, height: float) -> void:
	var k := clampf(1.0 - height / 320.0, 0.45, 1.0)
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, rx * k, rx * 0.28 * k), Color(0, 0, 0, 0.32))


static func draw_cat(ci: CanvasItem, look: Dictionary, pose_in: Dictionary) -> void:
	var pose := default_pose()
	pose.merge(pose_in, true)
	var fl: Color = pose["flash"]
	var ol: Color = look.get("outline", Color("2a2235"))
	var fur: Color = _fl(look.get("fur", Color.WHITE), fl)
	var fur_back: Color = _fl(look.get("fur_back", (look.get("fur", Color.WHITE) as Color).darkened(0.16)), fl)
	var belly: Color = _fl(look.get("belly", Color.WHITE), fl)
	var acc: Array = look.get("acc", [])
	var accent: Color = _fl(look.get("accent", Color("e8413c")), fl)
	var accent2: Color = _fl(look.get("accent2", Color("6b6b80")), fl)
	var bw: float = 19.0 * float(look.get("bw", 1.0))
	var bh: float = 22.0 * float(look.get("bh", 1.0))
	var hr: float = 19.0 * float(look.get("hr", 1.0))
	var leg_l: float = 28.0 * float(look.get("legs", 1.0))
	var arm_s: float = float(look.get("arms", 1.0))
	var limb_w: float = 10.0 * float(look.get("limb_w", 1.0))
	var sq: Vector2 = pose["squash"]
	var lean: float = pose["lean"]
	var crouch: float = pose["crouch"]
	var curl: float = pose["curl"]

	# Body anchor points.
	var hip := Vector2(0, -leg_l * (1.0 - 0.38 * crouch))
	var torso_c := hip + Vector2(2, -bh * 0.78).rotated(lean)
	var shoulder_f := torso_c + Vector2(bw * 0.45, -bh * 0.5).rotated(lean)
	var shoulder_b := torso_c + Vector2(-bw * 0.05, -bh * 0.55).rotated(lean)
	var neck := torso_c + Vector2(bw * 0.3, -bh * 0.92).rotated(lean)
	var head_c := neck + Vector2(5, -hr * 0.82 + float(pose["head_dy"])).rotated(lean * 0.5)
	var hip_f := hip + Vector2(bw * 0.38, 0).rotated(lean)
	var hip_b := hip + Vector2(-bw * 0.42, 0).rotated(lean)
	var foot_f := Vector2(hip_f.x + sin(pose["leg_f"]) * leg_l * 0.9, -float(pose["lift_f"]))
	var foot_b := Vector2(hip_b.x + sin(pose["leg_b"]) * leg_l * 0.9, -float(pose["lift_b"]))

	# Rolled into a ball (Lardpaw's rolling charge, knock-down tumbles).
	if curl > 0.5:
		var r := (bw + hr) * 0.95
		var c := Vector2(0, -r)
		_circle(ci, c, r, fur, ol)
		var spin: float = pose["item_angle"]
		for i in 3:
			var a := spin + TAU * i / 3.0
			ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.25, c + Vector2(cos(a), sin(a)) * r * 0.85, fur_back, 4.0)
		ci.draw_colored_polygon(_ellipse(c + Vector2(r * 0.2, -r * 0.1), r * 0.45, r * 0.35), belly)
		if "crown" in acc:
			_crown(ci, c + Vector2(0, -r * 0.95).rotated(spin * 0.2), hr * 0.8, _fl(Color("ffcf3a"), fl), ol)
		return

	# Tail.
	var tail_base := torso_c + Vector2(-bw * 0.85, bh * 0.25).rotated(lean)
	var tl: float = 34.0 * float(look.get("tail", 1.0))
	var tp := PackedVector2Array()
	var ph: float = pose["tail"]
	for i in 8:
		var t := i / 7.0
		tp.append(tail_base + Vector2(-t * tl * 0.7 - sin(ph) * 4.0 * t, -sin(t * PI * 0.85) * tl * 0.9 - t * 6.0 + sin(ph + t * 3.0) * 5.0 * t))
	ci.draw_polyline(tp, ol, 9.0 * float(look.get("limb_w", 1.0)) + OUTLINE_W * 2.0)
	ci.draw_circle(tp[7], (9.0 * float(look.get("limb_w", 1.0))) * 0.5 + OUTLINE_W, ol)
	ci.draw_polyline(tp, fur_back, 9.0 * float(look.get("limb_w", 1.0)))
	ci.draw_circle(tp[7], 4.5 * float(look.get("limb_w", 1.0)), fur_back)

	# Back leg and back arm.
	_capsule(ci, hip_b, foot_b + Vector2(0, -limb_w * 0.5), limb_w * 1.1, fur_back, ol)
	_poly(ci, _ellipse(foot_b + Vector2(4, -limb_w * 0.35), limb_w * 0.85, limb_w * 0.5), fur_back, ol)
	var paw_b: Vector2 = shoulder_b + (pose["arm_b"] as Vector2) * arm_s
	_capsule(ci, shoulder_b, paw_b, limb_w * 0.95, fur_back, ol)
	_circle(ci, paw_b, limb_w * 0.62, accent2 if "wraps" in acc else fur_back, ol)

	# Torso.
	var torso := _ellipse(torso_c, bw * sq.x, bh * sq.y, lean)
	_poly(ci, torso, fur, ol)
	var belly_k: float = 1.0 + float(pose["belly"])
	ci.draw_colored_polygon(_ellipse(torso_c + Vector2(bw * 0.3, bh * 0.15).rotated(lean), bw * 0.55 * sq.x * belly_k, bh * 0.68 * sq.y * belly_k, lean), belly)
	_outfit(ci, acc, torso_c, bw * sq.x, bh * sq.y, lean, accent, accent2, ol, fl)

	# Front leg.
	_capsule(ci, hip_f, foot_f + Vector2(0, -limb_w * 0.5), limb_w * 1.15, fur, ol)
	_poly(ci, _ellipse(foot_f + Vector2(5, -limb_w * 0.35), limb_w * 0.9, limb_w * 0.52), _fl(Color("f2f2f2"), fl) if "sneakers" in acc else fur, ol)

	# Head.
	_head(ci, look, pose, head_c, hr, fur, belly, ol, accent, accent2, acc, fl)

	# Front arm (drawn last so punches read clearly in front of the body).
	var paw_f: Vector2 = shoulder_f + (pose["arm_f"] as Vector2) * arm_s
	if "wrench" in acc:
		_wrench(ci, paw_f, float(pose["item_angle"]), hr, _fl(Color("9aa3ad"), fl), ol)
	if "spear" in acc:
		_spear(ci, paw_f, float(pose["item_angle"]), hr, accent, ol, fl)
	_capsule(ci, shoulder_f, paw_f, limb_w * 1.0, fur, ol)
	_circle(ci, paw_f, limb_w * 0.7, accent2 if "wraps" in acc else fur, ol)
	if "drumstick" in acc:
		_drumstick(ci, paw_f + Vector2(4, -6), hr * 0.9, fl, ol)


static func _outfit(ci: CanvasItem, acc: Array, c: Vector2, rx: float, ry: float, lean: float, accent: Color, accent2: Color, ol: Color, fl: Color) -> void:
	if "vest" in acc:
		var pts := PackedVector2Array()
		for i in 11:
			var a := -PI * 0.5 + PI * i / 10.0 - PI * 0.5
			pts.append(c + Vector2(cos(a) * rx * 0.98, sin(a) * ry * 0.98).rotated(lean))
		pts.append(c + Vector2(-rx * 0.1, ry * 0.6).rotated(lean))
		_poly(ci, pts, accent, ol, 2.0)
	if "tank" in acc or "hood" in acc or "jacket" in acc or "track" in acc:
		var shirt := _ellipse(c + Vector2(0, -ry * 0.12).rotated(lean), rx * 0.99, ry * 0.86, lean)
		_poly(ci, shirt, accent, ol, 2.0)
		if "track" in acc:
			ci.draw_line(c + Vector2(-rx * 0.6, -ry * 0.5).rotated(lean), c + Vector2(rx * 0.4, ry * 0.6).rotated(lean), Color.WHITE, 3.0)
		if "jacket" in acc:
			_tri(ci, c + Vector2(rx * 0.1, -ry * 0.85).rotated(lean), c + Vector2(rx * 0.7, -ry * 0.6).rotated(lean), c + Vector2(rx * 0.35, -ry * 0.1).rotated(lean), accent.lightened(0.25), ol, 2.0)
		if "tank" in acc:
			ci.draw_colored_polygon(_ellipse(c + Vector2(rx * 0.3, ry * 0.05).rotated(lean), rx * 0.42, ry * 0.5, lean), accent.lightened(0.18))
	if "armor" in acc:
		var plate := _ellipse(c + Vector2(rx * 0.12, -ry * 0.05).rotated(lean), rx * 0.9, ry * 0.78, lean, 8)
		_poly(ci, plate, accent2, ol, 2.5)
		for v in [Vector2(-0.4, -0.4), Vector2(0.5, -0.4), Vector2(-0.4, 0.4), Vector2(0.5, 0.4)]:
			ci.draw_circle(c + Vector2(v.x * rx, v.y * ry).rotated(lean), 2.5, accent2.lightened(0.4))
	if "belt" in acc:
		ci.draw_line(c + Vector2(-rx * 0.95, ry * 0.45).rotated(lean), c + Vector2(rx * 0.95, ry * 0.45).rotated(lean), Color("3a2a20"), 6.0)
		ci.draw_rect(Rect2(c + Vector2(rx * 0.25, ry * 0.45 - 4).rotated(lean), Vector2(8, 8)), _fl(Color("ffcf3a"), fl))
	if "chain" in acc:
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(c + Vector2(lerpf(-rx * 0.4, rx * 0.75, t), -ry * 0.55 + sin(t * PI) * ry * 0.55).rotated(lean))
		ci.draw_polyline(pts, _fl(Color("ffcf3a"), fl), 4.0)
		ci.draw_circle(pts[4] + Vector2(0, 5), 6, _fl(Color("ffcf3a"), fl))


static func _head(ci: CanvasItem, look: Dictionary, pose: Dictionary, hc: Vector2, hr: float, fur: Color, belly: Color, ol: Color, accent: Color, accent2: Color, acc: Array, fl: Color) -> void:
	var tilt: float = pose["head_tilt"]
	var R := func(v: Vector2) -> Vector2: return hc + v.rotated(tilt)
	if "mane" in acc:
		var mane := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			var r := hr * (1.55 if i % 2 == 0 else 1.25)
			mane.append(hc + Vector2(cos(a) * r - hr * 0.2, sin(a) * r))
		_poly(ci, mane, _fl(Color("f7efd8"), fl), ol)
	if "hood" in acc:
		_circle(ci, R.call(Vector2(-hr * 0.15, -hr * 0.05)), hr * 1.22, accent.darkened(0.15), ol)
	# Ears.
	var ear_in: Color = _fl(look.get("ear_inner", Color("f2a0b4")), fl)
	_tri(ci, R.call(Vector2(-hr * 0.85, -hr * 0.35)), R.call(Vector2(-hr * 0.55, -hr * 1.45)), R.call(Vector2(-hr * 0.05, -hr * 0.75)), fur, ol)
	_tri(ci, R.call(Vector2(-hr * 0.1, -hr * 0.75)), R.call(Vector2(hr * 0.35, -hr * 1.5)), R.call(Vector2(hr * 0.75, -hr * 0.55)), fur, ol)
	_tri(ci, R.call(Vector2(-hr * 0.62, -hr * 0.55)), R.call(Vector2(-hr * 0.52, -hr * 1.15)), R.call(Vector2(-hr * 0.22, -hr * 0.78)), ear_in, ol, 0.0)
	_tri(ci, R.call(Vector2(hr * 0.08, -hr * 0.8)), R.call(Vector2(hr * 0.35, -hr * 1.2)), R.call(Vector2(hr * 0.55, -hr * 0.65)), ear_in, ol, 0.0)
	# Skull + muzzle.
	_poly(ci, _ellipse(hc, hr * 1.08, hr * 0.95, tilt), fur, ol)
	ci.draw_colored_polygon(_ellipse(R.call(Vector2(hr * 0.62, hr * 0.38)), hr * 0.42, hr * 0.3, tilt), belly)
	# Eyes.
	var eyes: String = pose["eyes"]
	var eye_col: Color = look.get("eye", Color("ffd23a"))
	var e1: Vector2 = R.call(Vector2(hr * 0.12, -hr * 0.12))
	var e2: Vector2 = R.call(Vector2(hr * 0.66, -hr * 0.12))
	var ew := hr * 0.2
	var eh := hr * 0.27
	match eyes:
		"closed", "happy":
			for e in [e1, e2]:
				ci.draw_arc(e + Vector2(0, eh * 0.3), ew, PI * 1.1, PI * 1.9, 6, ol, 2.5)
		"x":
			for e in [e1, e2]:
				ci.draw_line(e + Vector2(-ew, -ew), e + Vector2(ew, ew), ol, 2.5)
				ci.draw_line(e + Vector2(-ew, ew), e + Vector2(ew, -ew), ol, 2.5)
		"dizzy":
			for e in [e1, e2]:
				ci.draw_arc(e, ew, 0, TAU * 0.8, 8, ol, 2.0)
				ci.draw_arc(e, ew * 0.45, 0, TAU * 0.8, 6, ol, 2.0)
		"hurt":
			for e in [e1, e2]:
				ci.draw_line(e + Vector2(-ew, -eh * 0.4), e + Vector2(ew, 0), ol, 2.5)
				ci.draw_line(e + Vector2(-ew, eh * 0.4), e + Vector2(ew, 0), ol, 2.5)
		_:
			var wide := eyes == "wide"
			for e in [e1, e2]:
				ci.draw_colored_polygon(_ellipse(e, ew * (1.25 if wide else 1.0), eh * (1.25 if wide else 1.0)), ol)
				ci.draw_colored_polygon(_ellipse(e, ew * 0.78 * (1.25 if wide else 1.0), eh * 0.8 * (1.25 if wide else 1.0)), _fl(eye_col, fl))
				ci.draw_colored_polygon(_ellipse(e + Vector2(ew * 0.25, 0), ew * 0.22, eh * 0.62), Color("140f18"))
				ci.draw_circle(e + Vector2(-ew * 0.2, -eh * 0.35), 1.4, Color.WHITE)
			if look.get("brows", false) or eyes == "angry":
				ci.draw_line(e1 + Vector2(-ew * 1.3, -eh * 1.5), e1 + Vector2(ew * 1.2, -eh * 0.8), ol, 3.0)
				ci.draw_line(e2 + Vector2(-ew * 1.0, -eh * 0.8), e2 + Vector2(ew * 1.3, -eh * 1.5), ol, 3.0)
	if "shades" in acc:
		ci.draw_line(e1 + Vector2(-ew * 1.4, -1), e2 + Vector2(ew * 1.5, -1), Color("101018"), eh * 1.9)
		ci.draw_line(e1 + Vector2(-ew * 0.8, -eh * 0.5), e1 + Vector2(ew * 0.2, -eh * 0.5), Color(1, 1, 1, 0.6), 2.0)
	if "eyepatch" in acc:
		ci.draw_circle(e1, ew * 1.35, Color("101018"))
		ci.draw_line(e1 + Vector2(-hr * 0.5, -hr * 0.6), e1 + Vector2(hr * 0.6, -hr * 0.1), Color("101018"), 2.0)
	# Nose, mouth, whiskers.
	var nose: Vector2 = R.call(Vector2(hr * 0.98, hr * 0.18))
	_tri(ci, nose + Vector2(-4, -3), nose + Vector2(3, -3), nose + Vector2(-0.5, 2), _fl(Color("f07890"), fl), ol, 1.5)
	var m: Vector2 = R.call(Vector2(hr * 0.78, hr * 0.5))
	match String(pose["mouth"]):
		"open", "yell":
			ci.draw_colored_polygon(_ellipse(m + Vector2(0, 3), hr * 0.2, hr * 0.17), Color("3a1020"))
			ci.draw_colored_polygon(_ellipse(m + Vector2(0, 6), hr * 0.12, hr * 0.07), Color("e05a78"))
		"o":
			ci.draw_colored_polygon(_ellipse(m + Vector2(0, 3), hr * 0.1, hr * 0.13), Color("3a1020"))
		"grin", "teeth":
			ci.draw_line(m + Vector2(-hr * 0.25, 0), m + Vector2(hr * 0.22, 1), ol, 2.0)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-hr * 0.2, 0), m + Vector2(hr * 0.18, 1), m + Vector2(0, hr * 0.2)]), Color.WHITE)
		_:
			ci.draw_line(m + Vector2(-hr * 0.12, 1), m, ol, 1.5)
			ci.draw_line(m, m + Vector2(hr * 0.12, 2), ol, 1.5)
	var wk: Vector2 = R.call(Vector2(hr * 0.8, hr * 0.35))
	for k in [-1, 0, 1]:
		ci.draw_line(wk, wk + Vector2(hr * 0.75, k * hr * 0.2 - 2), Color(ol.r, ol.g, ol.b, 0.7) if look.get("whisker", null) == null else look["whisker"], 1.2)
	# Headwear.
	if "mohawk" in acc:
		for i in 4:
			var b: Vector2 = R.call(Vector2(-hr * 0.6 + i * hr * 0.38, -hr * 0.85))
			_tri(ci, b + Vector2(-hr * 0.2, 2), b + Vector2(-hr * 0.05, -hr * 0.6 - (i % 2) * 4), b + Vector2(hr * 0.2, 2), accent, ol, 2.0)
	if "headband" in acc:
		ci.draw_line(R.call(Vector2(-hr * 1.0, -hr * 0.45)), R.call(Vector2(hr * 1.0, -hr * 0.45)), accent, hr * 0.28)
		ci.draw_line(R.call(Vector2(-hr * 1.0, -hr * 0.45)), R.call(Vector2(-hr * 1.6, -hr * 0.1 + sin(float(pose["tail"]) * 2.0) * 3.0)), accent, 4.0)
		ci.draw_line(R.call(Vector2(-hr * 1.0, -hr * 0.45)), R.call(Vector2(-hr * 1.5, -hr * 0.5)), accent, 4.0)
	if "cap" in acc:
		var cap := PackedVector2Array()
		for i in 11:
			var a := PI + PI * i / 10.0
			cap.append(hc + Vector2(cos(a) * hr * 1.05, sin(a) * hr * 0.75 - hr * 0.35))
		_poly(ci, cap, accent, ol, 2.0)
		ci.draw_line(R.call(Vector2(-hr * 1.0, -hr * 0.4)), R.call(Vector2(-hr * 1.75, -hr * 0.3)), accent.darkened(0.2), 6.0)
	if "helmet" in acc:
		var hel := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			hel.append(hc + Vector2(cos(a) * hr * 1.18, sin(a) * hr * 1.0 - hr * 0.2))
		_poly(ci, hel, accent2, ol, 2.5)
		ci.draw_line(R.call(Vector2(-hr * 1.15, -hr * 0.22)), R.call(Vector2(hr * 1.15, -hr * 0.22)), accent2.darkened(0.3), 4.0)
		ci.draw_line(R.call(Vector2(0, -hr * 1.2)), R.call(Vector2(0, -hr * 0.3)), accent, 4.0)
	if "crown" in acc:
		_crown(ci, R.call(Vector2(-hr * 0.05, -hr * 0.95)), hr * 0.85, _fl(Color("ffcf3a"), fl), ol)
	if "scarf" in acc:
		var nk: Vector2 = hc + Vector2(-hr * 0.15, hr * 0.92)
		ci.draw_colored_polygon(_ellipse(nk, hr * 0.95, hr * 0.28, 0.1), accent)
		ci.draw_polyline(_ellipse(nk, hr * 0.95, hr * 0.28, 0.1), ol, 2.0)
		var ph: float = pose["tail"]
		var tip1 := nk + Vector2(-hr * 1.9, hr * 0.1 + sin(ph * 2.2) * 6.0)
		var tip2 := nk + Vector2(-hr * 1.6, hr * 0.55 + sin(ph * 2.2 + 1.0) * 6.0)
		_poly(ci, PackedVector2Array([nk + Vector2(-hr * 0.6, -hr * 0.15), tip1, tip1 + Vector2(4, 8), nk + Vector2(-hr * 0.5, hr * 0.2)]), accent, ol, 2.0)
		_poly(ci, PackedVector2Array([nk + Vector2(-hr * 0.5, hr * 0.05), tip2, tip2 + Vector2(5, 7), nk + Vector2(-hr * 0.3, hr * 0.3)]), accent.darkened(0.15), ol, 2.0)


static func _crown(ci: CanvasItem, base: Vector2, w: float, col: Color, ol: Color) -> void:
	var pts := PackedVector2Array([
		base + Vector2(-w * 0.6, 0), base + Vector2(-w * 0.7, -w * 0.7), base + Vector2(-w * 0.35, -w * 0.35),
		base + Vector2(0, -w * 0.85), base + Vector2(w * 0.35, -w * 0.35), base + Vector2(w * 0.7, -w * 0.7),
		base + Vector2(w * 0.6, 0)])
	_poly(ci, pts, col, ol, 2.5)
	ci.draw_circle(base + Vector2(0, -w * 0.2), w * 0.1, Color("e8413c"))


static func _wrench(ci: CanvasItem, p: Vector2, ang: float, hr: float, col: Color, ol: Color) -> void:
	var dir := Vector2.UP.rotated(ang)
	var tip := p + dir * hr * 2.4
	_capsule(ci, p - dir * hr * 0.3, tip, hr * 0.32, col, ol)
	var side := dir.orthogonal()
	_poly(ci, PackedVector2Array([tip + side * hr * 0.55, tip + side * hr * 0.55 + dir * hr * 0.7, tip + side * hr * 0.15 + dir * hr * 0.35,
		tip - side * hr * 0.15 + dir * hr * 0.35, tip - side * hr * 0.55 + dir * hr * 0.7, tip - side * hr * 0.55]), col, ol, 2.5)


static func _spear(ci: CanvasItem, p: Vector2, ang: float, hr: float, accent: Color, ol: Color, fl: Color) -> void:
	var dir := Vector2.UP.rotated(ang)
	var tip := p + dir * hr * 3.4
	var tail := p - dir * hr * 1.4
	ci.draw_line(tail, tip, ol, 7.0)
	ci.draw_line(tail, tip, _fl(Color("8a5a30"), fl), 4.0)
	var side := dir.orthogonal()
	_tri(ci, tip + side * hr * 0.25, tip + dir * hr * 0.9, tip - side * hr * 0.25, _fl(Color("d8dde6"), fl), ol, 2.0)
	# Little white-crown pennant.
	var f0 := tip - dir * hr * 0.3
	_poly(ci, PackedVector2Array([f0, f0 - dir * hr * 0.9, f0 - dir * hr * 0.45 - side * hr * 1.1]), accent, ol, 2.0)


static func _drumstick(ci: CanvasItem, p: Vector2, s: float, fl: Color, ol: Color) -> void:
	_capsule(ci, p, p + Vector2(s * 0.9, -s * 0.9), s * 0.22, _fl(Color("f4ecd8"), fl), ol, 2.0)
	_poly(ci, _ellipse(p + Vector2(-s * 0.1, s * 0.1), s * 0.6, s * 0.45, -0.7), _fl(Color("c06a2a"), fl), ol, 2.5)
