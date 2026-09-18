extends Node3D
## Timing starts at software event delivery, never at physical stick movement.

const Flick = preload("res://flick_recognizer.gd")
const KEY_VECTORS := {
	KEY_Q: Vector2(-1, -1), KEY_W: Vector2(0, -1), KEY_E: Vector2(1, -1),
	KEY_A: Vector2(-1, 0), KEY_D: Vector2(1, 0),
	KEY_Z: Vector2(-1, 1), KEY_X: Vector2(0, 1), KEY_C: Vector2(1, 1),
}

signal punch_triggered(record: Dictionary)

var records: Array[Dictionary] = []
var _tuning: Dictionary
var _devices: Dictionary = {}
var _vectors: Dictionary = {}
var _pending_us: Dictionary = {}
var _glove: MeshInstance3D
var _motion: Tween
var _status: Label3D


func _ready() -> void:
	Input.use_accumulated_input = false
	if not reload_tuning():
		push_error("Input lab requires valid input_tuning.json")
		get_tree().quit(1)
		return
	_build_stage()
	Input.joy_connection_changed.connect(_connection_changed)
	print("INPUT LAB: right stick or QWE / A D / ZXC. Return stick to neutral before each flick. F5 reloads tuning.")


func reload_tuning() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://input_tuning.json"))
	if not Flick.valid_tuning(parsed):
		return false
	_tuning = parsed
	_devices.clear()
	_vectors.clear()
	_pending_us.clear()
	return true


func _connection_changed(device: int, _connected: bool) -> void:
	_devices.erase(device)
	_vectors.erase(device)
	_pending_us.erase(device)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_devices.clear()
		_vectors.clear()
		_pending_us.clear()


func _input(event: InputEvent) -> void:
	var now := Time.get_ticks_usec()
	if event is InputEventJoypadMotion:
		if event.axis not in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			return
		var vector: Vector2 = _vectors.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_RIGHT_X:
			vector.x = event.axis_value
		else:
			vector.y = event.axis_value
		_vectors[event.device] = vector
		if not _pending_us.has(event.device):
			_pending_us[event.device] = now
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F5:
			print("Tuning reload: ", reload_tuning())
		elif KEY_VECTORS.has(event.physical_keycode):
			feed_vector(-1, Vector2.ZERO, now)
			feed_vector(-1, KEY_VECTORS[event.physical_keycode], now)


func _process(_delta: float) -> void:
	# Sample after both axis events in this frame; don't classify the first axis
	# of a diagonal as a cardinal direction. Added delay is part of telemetry.
	var now := Time.get_ticks_usec()
	for device in _vectors:
		feed_vector(device, _vectors[device], now, _pending_us.get(device, now))
	_pending_us.clear()


func feed_vector(device: int, vector: Vector2, timestamp_us: int, event_us: int = -1) -> String:
	if not _devices.has(device):
		_devices[device] = Flick.new(_tuning)
	var direction: String = _devices[device].sample(vector, timestamp_us)
	if not direction.is_empty():
		_trigger(direction, device, timestamp_us if event_us < 0 else event_us)
	return direction


func _trigger(direction: String, device: int, event_us: int) -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	_glove.position = Vector3(0.45, 1.1, 1.0)
	_motion = create_tween()
	_motion.tween_property(_glove, "position:z", -0.1, 0.10)
	_motion.tween_property(_glove, "position:z", 1.1, 0.18)
	var trigger_us := Time.get_ticks_usec()
	var record := {
		"direction": direction, "device": device,
		"event_delivered_us": event_us, "animation_trigger_us": trigger_us,
		"software_event_to_trigger_us": trigger_us - event_us,
		"physical_to_visible_latency_ms": null,
	}
	records.append(record)
	if records.size() > 256:
		records.pop_front()
	_status.text = "PAC-002 INPUT LAB\n%s  |  event to trigger: %.2f ms\nHardware-to-visible latency: UNMEASURED\nQWE / A D / ZXC or right stick - F5 reload" % [direction, (trigger_us - event_us) / 1000.0]
	print(JSON.stringify(record))
	punch_triggered.emit(record)


func _build_stage() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.4, 4.2)
	camera.rotation_degrees.x = -12
	camera.fov = 55
	add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -20, 0)
	add_child(light)
	var dummy := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	dummy.mesh = capsule
	dummy.position = Vector3(0, 0.85, -1)
	add_child(dummy)
	_glove = MeshInstance3D.new()
	_glove.name = "PunchMarker"
	var glove_mesh := SphereMesh.new()
	glove_mesh.radius = 0.18
	glove_mesh.height = 0.36
	_glove.mesh = glove_mesh
	_glove.position = Vector3(0.45, 1.1, 1.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.2, 0.12)
	_glove.material_override = material
	add_child(_glove)
	_status = Label3D.new()
	_status.position = Vector3(0, 2.7, -1)
	_status.font_size = 28
	_status.text = "PAC-002 INPUT LAB\nRight stick or QWE / A D / ZXC\nHardware-to-visible latency: UNMEASURED"
	add_child(_status)
