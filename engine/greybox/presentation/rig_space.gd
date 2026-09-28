extends RefCounted
## Tactical ground coordinates are converted once; body height is in model units.
## Keep this mapping uniform in x/z, including exhibition engagements.
const GROUND_SCALE := 0.65
const GLOVE_RADIUS := 0.14
const HEAD_RADIUS := 0.18
const BODY_RADIUS := 0.21

static func ground(point: Vector2) -> Vector3:
	return Vector3(point.x, 0, point.y) * GROUND_SCALE

static func contact(region: Dictionary) -> Vector3:
	# The region tests target centres. Place the glove on the corresponding
	# surface, tangent at each lateral/height boundary. Outside the region the
	# same surface continues away from the target, rather than homing onto it.
	var lateral := float(region["l"])
	var height := float(region["h"])
	var low := float(region["lat"][0]); var high := float(region["lat"][1])
	var side := -1.0 if region["left"] else 1.0
	var x := clampf(lateral / (high if lateral >= 0 else -low), -1, 1)
	var y := 0.0
	if not region["body"]:
		var middle := 1.55
		var span := float(region["heights"][1]) - middle if height >= middle else middle - float(region["heights"][0])
		y = clampf((height - middle) / maxf(span, 0.001), -1, 1)
	var across := Vector2(x, y).limit_length(1.0)
	var forward := ground(region["forward"]).normalized()
	var right := ground(region["right"]).normalized() * side
	var normal := -right * across.x - Vector3.UP * across.y - forward * sqrt(maxf(0, 1.0 - across.length_squared()))
	var point := forward * minf(float(region["d"]), float(region["reach"])) * GROUND_SCALE
	point += right * clampf(lateral, low, high) * GROUND_SCALE
	point.y = height if region["body"] else clampf(height, float(region["heights"][0]), float(region["heights"][1]))
	return point + normal * (GLOVE_RADIUS + (BODY_RADIUS if region["body"] else HEAD_RADIUS))
