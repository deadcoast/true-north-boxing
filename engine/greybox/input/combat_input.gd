extends RefCounted
## NP-03 2.1-2.5. Hardware events become the same intent used by replays/AI.
## Edges are queued, never inferred solely from the last rendered frame.

const PREFIX := "tnb_"
const BodyControl := preload("res://sim/body_control.gd")
const SETTINGS := "user://controls.cfg"
const ROWS := ["L_UPPERCUT", "L_HOOKERCUT", "L_HOOK", "L_FLARED", "L_STRAIGHT",
	"R_STRAIGHT", "R_FLARED", "R_HOOK", "R_HOOKERCUT", "R_UPPERCUT"]
const KEYS := {"L_STRAIGHT": KEY_J, "R_STRAIGHT": KEY_K, "L_HOOK": KEY_U,
	"R_HOOK": KEY_I, "L_FLARED": KEY_F, "R_FLARED": KEY_L,
	"L_HOOKERCUT": KEY_N, "R_HOOKERCUT": KEY_SEMICOLON, "L_UPPERCUT": KEY_Y, "R_UPPERCUT": KEY_O,
	"left": KEY_A, "right": KEY_D, "forward": KEY_W, "back": KEY_S,
	"block": KEY_SPACE, "body": KEY_C, "power": KEY_SHIFT, "lb": KEY_H,
	"windup": KEY_ALT, "rise": KEY_ENTER, "taunt": KEY_T, "sprint": KEY_CTRL, "clinch": KEY_G,
	"slip_left": KEY_Q, "slip_right": KEY_E, "weave": KEY_V, "lean": KEY_B, "duck": KEY_DOWN}
const FAMILIES := ["STRAIGHT", "FLARED", "HOOK", "HOOKERCUT", "UPPERCUT"]
const CHORDS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_DPAD_UP]

var preset := "flick"
var tuning: Dictionary = {}
var actions: Array[String] = []
var held: Dictionary = {}
var since: Dictionary = {}
var queue: Array[Dictionary] = []
var sticks: Dictionary = {}
var mouse_vector := Vector2.ZERO
var mouse_down := false
var mouse_fired := false
var require_neutral := false
var step_armed := true
var body_blocked := false

func _init() -> void:
	reset_bindings()

func reset_bindings() -> void:
	actions.clear()
	for key in KEYS:
		var e := InputEventKey.new(); e.keycode = KEYS[key]
		_define(str(key), [e])
	for i in FAMILIES.size():
		var e := InputEventJoypadButton.new(); e.button_index = CHORDS[i]; e.device = -1
		_define("chord_" + FAMILIES[i], [e])
	var left := InputEventJoypadButton.new(); left.button_index = JOY_BUTTON_BACK; left.device = -1
	_define("left_hand", [left])
	for pair in [["rise", JOY_BUTTON_A], ["power", JOY_BUTTON_RIGHT_SHOULDER], ["lb", JOY_BUTTON_LEFT_SHOULDER], ["windup", JOY_BUTTON_DPAD_DOWN]]:
		var e := InputEventJoypadButton.new(); e.button_index = pair[1]; e.device = -1
		InputMap.action_add_event(PREFIX + str(pair[0]), e)
	var footwork := InputEventJoypadButton.new(); footwork.button_index = JOY_BUTTON_LEFT_STICK; footwork.device = -1
	InputMap.action_add_event(PREFIX + "sprint", footwork)
	for pair in [["block", JOY_AXIS_TRIGGER_RIGHT], ["body", JOY_AXIS_TRIGGER_LEFT]]:
		var e := InputEventJoypadMotion.new(); e.axis = pair[1]; e.axis_value = 1.0; e.device = -1
		InputMap.action_add_event(PREFIX + str(pair[0]), e)
	clear()

func _define(action: String, events: Array) -> void:
	actions.append(action)
	if not InputMap.has_action(PREFIX + action): InputMap.add_action(PREFIX + action, 0.5)
	InputMap.action_erase_events(PREFIX + action)
	for e in events: InputMap.action_add_event(PREFIX + action, e)

func rebind(action: String, event: InputEvent) -> bool:
	if not action in actions or not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	var binding := event.duplicate() as InputEvent
	if binding is InputEventKey:
		binding.pressed = false; binding.echo = false
		binding.shift_pressed = false; binding.ctrl_pressed = false; binding.alt_pressed = false; binding.meta_pressed = false
	elif binding is InputEventJoypadButton: binding.pressed = false; binding.device = -1
	elif binding is InputEventJoypadMotion: binding.axis_value = signf(binding.axis_value); binding.device = -1
	elif binding is InputEventMouseButton: binding.pressed = false
	InputMap.action_erase_events(PREFIX + action)
	InputMap.action_add_event(PREFIX + action, binding)
	clear()
	return true

func save_settings(path: String = SETTINGS) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "preset", preset)
	for action in actions: cfg.set_value("bindings", action, InputMap.action_get_events(PREFIX + action))
	return cfg.save(path)

func load_settings(path: String = SETTINGS) -> Error:
	var cfg := ConfigFile.new(); var error := cfg.load(path)
	if error != OK: return error
	var selected := str(cfg.get_value("controls", "preset", "flick"))
	if selected in ["flick", "chords"]: preset = selected
	for action in actions:
		var saved = cfg.get_value("bindings", action, null)
		if not saved is Array or saved.is_empty(): continue
		if not saved.all(func(e): return e is InputEvent): continue
		InputMap.action_erase_events(PREFIX + action)
		for e in saved: InputMap.action_add_event(PREFIX + action, e)
	clear()
	return OK

func clear(wait_for_neutral: bool = false) -> void:
	require_neutral = wait_for_neutral
	body_blocked = wait_for_neutral; step_armed = not wait_for_neutral
	held.clear(); since.clear(); queue.clear(); sticks.clear()
	mouse_down = false; mouse_fired = false; mouse_vector = Vector2.ZERO

func down(action: String) -> bool:
	return held.get(action, {}).values().any(func(v): return bool(v))

func _mods(now: int) -> Dictionary:
	return {"body": down("body"), "power": down("power"), "block": down("block"), "lb": down("lb"),
		"haymaker": down("windup") and now - int(since.get("windup", now)) >= _pull_us()}

func _pull_us() -> int:
	return int(float(tuning.get("modifiers", {}).get("HAYMAKER", {}).get("pullback_min_ms", 150)) * 1000.0)

func _punch(row: String, now: int, extra: Dictionary = {}) -> void:
	var cmd := _mods(now); cmd.merge(extra, true); cmd["punch"] = row
	queue.append(cmd)

func handle_event(e: InputEvent, now: int, combat: bool = true) -> bool:
	if e is InputEventKey and e.echo: return false
	var consumed := false
	for action in actions:
		if not InputMap.event_is_action(e, PREFIX + action): continue
		var source := "%s:%d:%d" % [e.get_class(), e.device, e.axis if e is InputEventJoypadMotion else (e.button_index if e is InputEventJoypadButton or e is InputEventMouseButton else 0)]
		var was := down(action)
		var pressed := e.is_action_pressed(PREFIX + action)
		if not held.has(action): held[action] = {}
		held[action][source] = pressed
		if down(action) and not was: since[action] = now
		if not combat: continue
		if action in ROWS:
			if pressed: _punch(action, now)
			else: queue.append({"punch_release": true, "punch_release_age_ms": float(now - int(since.get(action, now))) / 1000.0})
			consumed = true
		elif action.begins_with("chord_") and preset == "chords":
			if pressed: _punch(("L_" if down("left_hand") else "R_") + action.trim_prefix("chord_"), now)
			else: queue.append({"punch_release": true, "punch_release_age_ms": float(now - int(since.get(action, now))) / 1000.0})
			consumed = true
		elif pressed and action in ["slip_left", "slip_right", "weave", "lean", "duck"]:
			queue.append({"dodge": {"slip_left": "SLIP_L", "slip_right": "SLIP_R", "weave": "WEAVE_R", "lean": "LEAN", "duck": "DUCK"}[action]}); consumed = true
		elif pressed and action in ["clinch", "taunt"]:
			queue.append({action: true}); consumed = true
		elif action == "sprint": consumed = true # held footwork modifier; no legacy burst edge
	if not combat: return false
	if e is InputEventJoypadMotion and e.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var v: Vector2 = sticks.get(e.device, {}).get("v", Vector2.ZERO)
		if e.axis == JOY_AXIS_RIGHT_X: v.x = e.axis_value
		else: v.y = e.axis_value
		stick_sample(e.device, v, now)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not consumed:
		mouse_down = e.pressed
		if e.pressed: mouse_vector = Vector2.ZERO; mouse_fired = false
		elif mouse_fired: queue.append({"punch_release": true})
		return true
	if e is InputEventMouseMotion and mouse_down:
		mouse_vector += e.relative
		if not mouse_fired and mouse_vector.length() >= 36.0:
			_punch(ROWS[sector(mouse_vector)], now); mouse_fired = true
		return true
	return consumed

static func sector(v: Vector2) -> int:
	var angle := rad_to_deg(atan2(-v.y, v.x))
	if angle > 90.0 or angle <= -90.0:
		var left := 180.0 - angle if angle > 0.0 else -180.0 - angle
		return clampi(int(floor((left + 90.0) / 36.0)), 0, 4)
	return 5 + 4 - clampi(int(floor((angle + 90.0) / 36.0)), 0, 4)

func stick_sample(device: int, v: Vector2, now: int) -> void:
	if preset != "flick": return
	if not sticks.has(device): sticks[device] = {"v": Vector2.ZERO, "armed": true, "start": now, "capture": -1, "best": Vector2.ZERO, "released": false, "pull": -1, "ready": -1, "mods": {}, "pressed_us": now, "blocked": require_neutral}
	var s: Dictionary = sticks[device]
	var off := float(tuning.get("flick_detection", {}).get("off_threshold", 0.25))
	var on := float(tuning.get("flick_detection", {}).get("on_threshold", 0.6))
	if bool(s.get("blocked", false)):
		if v.length() > off: return
		s["blocked"] = false
	var previous: Vector2 = s["v"]; s["v"] = v
	if previous.length() <= off and v.length() > off: s["start"] = now
	# A held pull-back is a windup. A short down-flick still throws an uppercut.
	if v.y >= on and absf(v.x) < 0.32:
		if int(s["pull"]) < 0: s["pull"] = now
		if now - int(s["pull"]) >= _pull_us(): s["ready"] = now; s["capture"] = -1
	elif int(s["pull"]) >= 0:
		if now - int(s["pull"]) >= _pull_us(): s["ready"] = now; s["capture"] = -1
		s["pull"] = -1
	if v.y <= -on and int(s["ready"]) >= 0 and now - int(s["ready"]) <= 250000:
		_punch(ROWS[sector(v)], now, {"haymaker": true}); s["ready"] = -1; s["capture"] = -1; s["armed"] = false; s["pressed_us"] = now
		return
	if int(s["capture"]) >= 0:
		if v.length() > Vector2(s["best"]).length(): s["best"] = v
		if v.length() <= off: s["released"] = true
	elif bool(s["armed"]) and v.length() >= on and int(s["ready"]) < 0:
		s["armed"] = false
		if now - int(s["start"]) <= 150000:
			s["capture"] = now; s["pressed_us"] = now; s["best"] = v; s["released"] = false; s["mods"] = _mods(now)
	elif v.length() <= off:
		if not bool(s["armed"]): queue.append({"punch_release": true, "punch_release_age_ms": float(now - int(s["pressed_us"])) / 1000.0})
		s["armed"] = true
	if int(s["capture"]) >= 0 and (bool(s["released"]) or now - int(s["capture"]) >= 33333) and int(s["pull"]) < 0:
		_punch(ROWS[sector(s["best"])], now, s["mods"])
		if bool(s["released"]): queue.append({"punch_release": true, "punch_release_age_ms": float(now - int(s["pressed_us"])) / 1000.0}); s["armed"] = true
		s["capture"] = -1

func poll_hardware(now: int) -> void:
	var connected := Input.get_connected_joypads()
	for device in sticks.keys():
		if device not in connected: sticks.erase(device)
	for device in connected:
		stick_sample(device, Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)), now)

func take_intent() -> Dictionary:
	var movement := Vector2(float(down("right")) - float(down("left")), float(down("back")) - float(down("forward")))
	for device in Input.get_connected_joypads():
		var pad := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if pad.length() > 0.2: movement += pad; break
	# The body disk is anatomical x/right and y/up, explicitly converted from
	# Godot's down-positive stick. Root travel has its own deliberate stroke.
	var axis := BodyControl.radial(Vector2(movement.x, -movement.y))
	if body_blocked:
		if movement.length() <= BodyControl.DEADZONE: body_blocked = false; step_armed = true
		axis = Vector2.ZERO
	var step_direction := Vector2.ZERO
	if axis.length() < 0.20: step_armed = true
	if down("sprint") and axis.length() >= 0.55 and step_armed:
		step_direction = axis; step_armed = false
	var result := {"body_axis": Vector2.ZERO if down("sprint") else axis, "block": down("block"), "body": down("body"), "power": down("power"), "lb": down("lb"), "rise": down("rise")}
	if step_direction != Vector2.ZERO: result["pocket_step"] = step_direction
	if not queue.is_empty(): result.merge(queue.pop_front(), true)
	return result
