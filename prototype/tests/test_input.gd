extends SceneTree

const Flick = preload("res://flick_recognizer.gd")
const LabScene = preload("res://input_lab.tscn")
const EXPECTED := ["RIGHT", "DOWN_RIGHT", "DOWN", "DOWN_LEFT", "LEFT", "UP_LEFT", "UP", "UP_RIGHT"]
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)


func _joy(device: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _frames() -> void:
	await process_frame
	await process_frame


func _run() -> void:
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://input_tuning.json"))
	_check(Flick.valid_tuning(tuning), "Default tuning is valid")
	for invalid in [null, {}, {"reset_radius": true, "activation_radius": 0.8, "max_flick_ms": 120},
		{"reset_radius": 0.9, "activation_radius": 0.8, "max_flick_ms": 120},
		{"reset_radius": 0.2, "activation_radius": 0.8, "max_flick_ms": -1},
		{"reset_radius": 0.2, "activation_radius": INF, "max_flick_ms": 120}]:
		_check(not Flick.valid_tuning(invalid), "Reject invalid tuning")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260918
	for sector in range(8):
		for trial in range(100):
			var recognizer = Flick.new(tuning)
			recognizer.sample(Vector2.ZERO, 0)
			var angle := sector * PI / 4.0 + deg_to_rad(rng.randf_range(-15, 15))
			var vector := Vector2.from_angle(angle) * rng.randf_range(0.8, 1.0)
			_check(recognizer.sample(vector, 1000) == EXPECTED[sector], "Synthetic direction %s trial %s" % [sector, trial])
	var flick = Flick.new(tuning)
	_check(flick.sample(Vector2.RIGHT, 0).is_empty(), "Held at startup requires neutral")
	flick.sample(Vector2.ZERO, 100)
	_check(flick.sample(Vector2(0.1, 0.1), 200).is_empty(), "Drift in neutral is ignored")
	_check(flick.sample(Vector2.RIGHT, 1000) == "RIGHT", "Flick activates")
	_check(flick.sample(Vector2.RIGHT, 2000).is_empty(), "Held stick does not repeat")
	_check(flick.sample(Vector2.LEFT, 3000).is_empty(), "Opposite without neutral does not rearm")
	flick.sample(Vector2.ZERO, 4000)
	flick.sample(Vector2(0.4, 0), 5000)
	_check(flick.sample(Vector2.RIGHT, 126000).is_empty(), "Slow tilt rejected")
	_check(flick.sample(Vector2.RIGHT, 127000).is_empty(), "Timeout stays latched")
	flick.sample(Vector2.ZERO, 128000)
	_check(flick.sample(Vector2.LEFT, 129000) == "LEFT", "Neutral rearms after timeout")
	flick.sample(Vector2.ZERO, 130000)
	_check(flick.sample(Vector2(NAN, 0), 131000).is_empty(), "Reject NaN")
	_check(flick.sample(Vector2.RIGHT, 132000).is_empty(), "Bad samples require neutral reset")
	flick.sample(Vector2.ZERO, 133000)
	_check(flick.sample(Vector2(2, 0), 134000).is_empty(), "Reject out-of-range axes")
	flick.sample(Vector2.ZERO, 135000)
	_check(flick.sample(Vector2.RIGHT, 134999).is_empty(), "Reject backwards timestamps")
	flick.sample(Vector2.ZERO, 140000)
	flick.sample(Vector2(0.4, 0), 141000)
	_check(flick.sample(Vector2.RIGHT, 261000) == "RIGHT", "Exact time boundary accepted")
	flick.reset()
	_check(flick.sample(Vector2.RIGHT, 262000).is_empty(), "Explicit reset requires neutral")

	var lab = LabScene.instantiate()
	root.add_child(lab)
	await _frames()
	_check(not Input.use_accumulated_input, "Scene disables input accumulation")
	# Enter through the actual Godot event path, with separate X/Y events.
	_joy(8, JOY_AXIS_RIGHT_X, 0)
	_joy(8, JOY_AXIS_RIGHT_Y, 0)
	await _frames()
	_joy(8, JOY_AXIS_RIGHT_X, 0.9)
	_joy(8, JOY_AXIS_RIGHT_Y, -0.9)
	await _frames()
	_check(lab.records.size() == 1, "Paired axes emit one animation trigger")
	_check(lab.get_node("PunchMarker").position.z < 1.1, "Animation moves the glove property")
	if not lab.records.is_empty():
		_check(lab.records[-1].direction == "UP_RIGHT", "Paired axes resolve diagonal")
		_check(lab.records[-1].software_event_to_trigger_us >= 0, "Software timestamps are monotonic")
		_check(lab.records[-1].physical_to_visible_latency_ms == null, "Hardware latency remains unmeasured")
	await _frames()
	_check(lab.records.size() == 1, "Held controller cannot repeat on future frames")
	_joy(9, JOY_AXIS_RIGHT_X, 0)
	_joy(9, JOY_AXIS_RIGHT_Y, 0)
	await _frames()
	_joy(9, JOY_AXIS_RIGHT_X, -1)
	await _frames()
	_check(lab.records.size() == 2 and lab.records[-1].direction == "LEFT", "Second device is independent")
	Input.joy_connection_changed.emit(9, false)
	await _frames()
	_check(lab.records.size() == 2, "Disconnect drops held device state")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await _frames()
	_check(lab.records.size() == 3 and lab.records[-1].direction == "UP", "Keyboard event reaches animation trigger")
	key.echo = true
	Input.parse_input_event(key)
	await _frames()
	_check(lab.records.size() == 3, "Keyboard repeat is ignored")
	_check(lab.reload_tuning(), "Valid tuning reload succeeds")
	await _frames()
	_check(lab.records.size() == 3, "Reload does not create phantom input")
	_joy(10, JOY_AXIS_RIGHT_X, 0)
	_joy(10, JOY_AXIS_RIGHT_Y, 0)
	await _frames()
	lab.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_joy(10, JOY_AXIS_RIGHT_X, 1)
	await _frames()
	_check(lab.records.size() == 3, "Focus loss requires a fresh neutral before input")
	for frame in range(40):
		await process_frame
	_check(is_equal_approx(lab.get_node("PunchMarker").position.z, 1.1), "Animation returns to rest")
	lab.queue_free()
	await process_frame
	print(JSON.stringify({"suite": "northpaw_input", "checks": _checks, "failures": _failures,
		"synthetic_direction_samples": 800, "hardware_latency_measured": false,
		"scope": "Synthetic vectors and headless Godot event-to-animation wiring only"}))
	quit(0 if _failures.is_empty() else 1)
