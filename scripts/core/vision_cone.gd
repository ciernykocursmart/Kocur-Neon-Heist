class_name VisionCone
extends RefCounted
## Computes wall-clipped vision polygons via a fan of physics raycasts.

const WORLD_MASK := 1


## Returns polygon points relative to `origin`. For a full circle (fov >= TAU)
## the fan is closed without the origin vertex.
static func compute(space: PhysicsDirectSpaceState2D, origin: Vector2, angle: float, fov: float, radius: float, rays: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := fov >= TAU - 0.01
	if not full:
		pts.append(Vector2.ZERO)
	var count := rays if full else rays + 1
	for i in count:
		var a := angle - fov * 0.5 + fov * float(i) / float(rays)
		var end := origin + Vector2.from_angle(a) * radius
		var q := PhysicsRayQueryParameters2D.create(origin, end, WORLD_MASK)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			pts.append(end - origin)
		else:
			pts.append((hit["position"] as Vector2) - origin)
	return pts


static func angle_within(facing: float, target_angle: float, fov: float) -> bool:
	return absf(angle_difference(facing, target_angle)) <= fov * 0.5
