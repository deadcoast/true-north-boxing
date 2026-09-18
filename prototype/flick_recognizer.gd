extends RefCounted
## Engine-independent vector recognition; Godot Y points down.

const DIRECTIONS := ["RIGHT", "DOWN_RIGHT", "DOWN", "DOWN_LEFT", "LEFT", "UP_LEFT", "UP", "UP_RIGHT"]

var _reset_radius: float
var _activation_radius: float
var _max_flick_us: int
var _armed := false
var _excursion_us := -1
var _last_us := -1


static func valid_tuning(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["reset_radius", "activation_radius", "max_flick_ms"]:
		if not value.has(key) or not (value[key] is float or value[key] is int):
			return false
		if not is_finite(float(value[key])):
			return false
	return (value.reset_radius > 0 and value.reset_radius < value.activation_radius
		and value.activation_radius <= 1 and value.max_flick_ms > 0)


func _init(tuning: Dictionary) -> void:
	assert(valid_tuning(tuning), "Invalid flick tuning")
	_reset_radius = tuning.reset_radius
	_activation_radius = tuning.activation_radius
	_max_flick_us = int(tuning.max_flick_ms * 1000)


func reset() -> void:
	_armed = false
	_excursion_us = -1
	_last_us = -1


func sample(vector: Vector2, timestamp_us: int) -> String:
	if (not vector.is_finite() or absf(vector.x) > 1 or absf(vector.y) > 1
		or timestamp_us < 0 or timestamp_us < _last_us):
		reset()
		return ""
	_last_us = timestamp_us
	var magnitude := vector.length()
	if magnitude <= _reset_radius:
		_armed = true
		_excursion_us = -1
		return ""
	if not _armed:
		return ""
	if _excursion_us < 0:
		_excursion_us = timestamp_us
	if timestamp_us - _excursion_us > _max_flick_us:
		_armed = false
		return ""
	if magnitude < _activation_radius:
		return ""
	_armed = false
	var sector := posmod(int(floor((vector.angle() + PI / 8.0) / (PI / 4.0))), 8)
	return DIRECTIONS[sector]
