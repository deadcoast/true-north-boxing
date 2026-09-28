extends SceneTree
## PAC-005: actual viewport events -> scene adapter -> the real combat simulation.
## godot --headless --path engine/greybox -s tools/drive_input.gd -- dummy
const Adapter := preload("res://input/combat_input.gd")
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
var checks := 0
var failures: Array[String] = []
var scene: Node
var test := Tests.new()

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])

func _key(code: int, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = pressed; event.echo = echo
	root.push_input(event)

func _pad(button: int, pressed: bool = true, device: int = 3) -> void:
	var event := InputEventJoypadButton.new(); event.button_index = button; event.pressed = pressed; event.device = device
	root.push_input(event)

func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	root.push_input(event)

func _fresh(distance: float = 1.5):
	var sim = test.make_sim(0, 12345)
	test.quiet(sim); test.place(sim, distance)
	sim.P["pkg"] = {}; sim.B["pkg"] = {}; sim.P["stats"]["PWR"] = 50
	return sim

func _queue(sim, row: String, modifiers: Dictionary = {}) -> void:
	sim._queue_punch(row, modifiers); sim._try_execute_cmd(); test.clear_defense(sim.B)

func _damage(sim) -> float:
	var before: float = sim.B["comp"]
	if sim.P["pending"].get("stepping", false):
		while not sim.P["pending"].is_empty():
			test.clear_defense(sim.B); sim.step({})
	else: sim._land_player_punch()
	return before - float(sim.B["comp"])

func _run() -> void:
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	scene.controls_menu.close(); scene.combat_input.reset_bindings()
	var input = scene.combat_input
	for row in Adapter.ROWS:
		input.clear(); _key(Adapter.KEYS[row])
		var intent: Dictionary = scene._intent()
		_check("keyboard " + row, intent.get("punch", "") == row)
		var sim = _fresh(); sim.step(intent)
		_check("scene input executes " + row, sim.P["pending"].get("row", "") == row)
		_key(Adapter.KEYS[row], false)
	input.clear(); _key(KEY_SHIFT); _key(KEY_C); _key(KEY_J); _key(KEY_J, false); _key(KEY_C, false); _key(KEY_SHIFT, false)
	var captured: Dictionary = scene._intent()
	_check("press and release in one render frame preserve modifier snapshot", captured.get("punch") == "L_STRAIGHT" and captured.get("body", false) and captured.get("power", false))
	_check("release follows the same-frame press", scene._intent().get("punch_release", false))
	input.clear(); _key(KEY_J, true, true)
	_check("keyboard auto-repeat never repeats an attack", not scene._intent().has("punch"))
	input.clear(); _key(KEY_J); _key(KEY_K)
	_check("two presses retain event order", scene._intent().get("punch") == "L_STRAIGHT" and scene._intent().get("punch") == "R_STRAIGHT")
	var angles := [252.0, 216.0, 180.0, 144.0, 108.0, 72.0, 36.0, 0.0, -36.0, -72.0]
	for i in Adapter.ROWS.size():
		var vector := Vector2(cos(deg_to_rad(angles[i])), -sin(deg_to_rad(angles[i])))
		input.clear(); _mouse(true)
		var event := InputEventMouseMotion.new(); event.relative = vector * 90.0; root.push_input(event)
		_check("mouse gesture " + Adapter.ROWS[i], scene._intent().get("punch", "") == Adapter.ROWS[i])
		_mouse(false)
		input.clear(); input.stick_sample(7, Vector2.ZERO, 0); input.stick_sample(7, vector, 10000)
		input.stick_sample(7, vector, 55000); input.stick_sample(7, Vector2.ZERO, 70000)
		_check("stick gesture " + Adapter.ROWS[i], input.take_intent().get("punch", "") == Adapter.ROWS[i])
	input.clear(); input.stick_sample(2, Vector2.ZERO, 0); input.stick_sample(2, Vector2(0.9, -0.1), 1000); input.stick_sample(2, Vector2.ZERO, 2000)
	_check("subframe stick pulse survives", input.take_intent().get("punch", "") == "R_HOOK")
	input.clear(); input.stick_sample(2, Vector2.ZERO, 0); input.stick_sample(2, Vector2(0.3, 0), 20000); input.stick_sample(2, Vector2(0.5, 0), 140000); input.stick_sample(2, Vector2(0.8, 0), 200000)
	input.stick_sample(2, Vector2.ZERO, 250000)
	_check("slow stick drift is not a flick", not input.take_intent().has("punch"))
	input.clear(); input.stick_sample(2, Vector2.ZERO, 0); input.stick_sample(2, Vector2(0.7, 0), 1000); input.stick_sample(2, Vector2(0.7, -0.9), 3000); input.stick_sample(2, Vector2(0.7, -0.9), 40000)
	_check("staggered axis reports settle before classification", input.take_intent().get("punch", "") == "R_FLARED")
	input.clear(); input.stick_sample(2, Vector2(0.1, 1), 0); input.stick_sample(2, Vector2(0.1, 1), 150000); input.stick_sample(2, Vector2(0.1, -1), 160000)
	_check("150ms pull-back then forward is one haymaker", input.take_intent().get("haymaker", false) and input.queue.is_empty())
	input.preset = "chords"
	for left in [false, true]:
		for i in Adapter.FAMILIES.size():
			input.clear()
			if left: _pad(JOY_BUTTON_BACK)
			_pad(Adapter.CHORDS[i])
			var row: String = ("L_" if left else "R_") + Adapter.FAMILIES[i]
			_check("accessible chord " + row, scene._intent().get("punch", "") == row)
			_pad(Adapter.CHORDS[i], false); _pad(JOY_BUTTON_BACK, false)
	input.clear(); input.preset = "flick"
	var alt := InputEventKey.new(); alt.keycode = KEY_ALT; alt.pressed = true
	input.handle_event(alt, 0)
	var jab := InputEventKey.new(); jab.keycode = KEY_J; jab.pressed = true
	input.handle_event(jab, 149999); _check("haymaker charge cannot fire early", not input.take_intent().get("haymaker", false))
	input.handle_event(jab, 150000); _check("button haymaker uses the authored charge", input.take_intent().get("haymaker", false))
	var replacement := InputEventKey.new(); replacement.keycode = KEY_P
	_check("rebind supported", input.rebind("L_STRAIGHT", replacement))
	_key(KEY_P); _check("remapped punch reaches the live scene", scene._intent().get("punch", "") == "L_STRAIGHT")
	input.clear(); _key(KEY_J); _check("old binding is removed", not scene._intent().has("punch"))
	input.preset = "chords"
	_check("bindings persist", input.save_settings("user://input-drive.cfg") == OK)
	input.reset_bindings(); input.preset = "flick"
	_check("bindings and preset restore", input.load_settings("user://input-drive.cfg") == OK and input.preset == "chords")
	_key(KEY_P); _check("restored binding works", scene._intent().get("punch", "") == "L_STRAIGHT")
	input.reset_bindings(); input.preset = "flick"
	for row in Adapter.ROWS:
		var sim = _fresh(); _queue(sim, row)
		var data: Dictionary = sim.T["punch_matrix"][row]
		_check("authored frame data " + row, sim.P["pending"]["startup"] == Sim.ms(data["startup_ms"]) and sim.P["busy_t"] == Sim.ms(data["startup_ms"]) + Sim.ms(data["recovery_ms"]) and is_equal_approx(sim.P["pending"]["stamina_cost"], float(data["stamina"])))
	var base = _fresh(); _queue(base, "L_STRAIGHT"); var base_damage := _damage(base)
	var heavy = _fresh(); _queue(heavy, "L_STRAIGHT", {"body": true, "power": true, "haymaker": true, "block": true})
	_check("body power haymaker block-punch startup stacks", heavy.P["pending"]["startup"] == Sim.ms(160.0 * 1.4 * 1.9 * 1.15) and heavy.P["pending"]["mods"].size() == 4)
	_check("body power haymaker damage stacks", is_equal_approx(_damage(heavy), base_damage * 0.8 * 1.5 * 2.2))
	var stepping = _fresh(2.5); _queue(stepping, "L_STRAIGHT", {"move": Vector2(0, -1)})
	_check("moving toward out-of-range opponent activates step", stepping.P["pending"]["stepping"] and stepping.P["pending"]["startup"] == Sim.ms(160.0 * 1.3) and is_zero_approx(stepping.P["pending"]["range_bonus"]) and is_equal_approx(stepping.P["pending"]["step_remaining"], 0.5))
	_check("step reaches and multiplies damage", is_equal_approx(_damage(stepping), base_damage * 1.2))
	var still = _fresh(2.5); _queue(still, "L_STRAIGHT")
	_check("standing out of range does not invent a stepping punch", not still.P["pending"]["stepping"] and is_zero_approx(_damage(still)))
	var stack = _fresh(2.5); _queue(stack, "L_STRAIGHT", {"body": true, "power": true, "haymaker": true, "block": true, "move": Vector2(0, -1)})
	_check("all five modifiers stack", stack.P["pending"]["mods"].size() == 5 and stack.P["pending"]["startup"] == Sim.ms(160.0 * 1.4 * 1.9 * 1.15 * 1.3))
	var low = _fresh(); low.P["stamina"] = 3.0; _queue(low, "L_STRAIGHT", {"power": true})
	_check("unaffordable power preserves base punch", low.P["pending"]["row"] == "L_STRAIGHT" and not "POWER" in low.P["pending"]["mods"] and low.P["pending"]["stamina_cost"] == 2.0)
	var armed = _fresh(); armed.tension = 0; _queue(armed, "R_HOOK", {"lb": true})
	_check("unaffordable hissatsu preserves base punch", armed.cast.is_empty() and armed.P["pending"]["row"] == "R_HOOK")
	var guard = _fresh(); guard.P["blocking"] = true; _queue(guard, "R_STRAIGHT", {"block": true})
	_check("block-punch exits guard instantly", not guard.P["blocking"] and guard.P["pending"]["startup"] == Sim.ms(220.0 * 1.15))
	guard.step({"block": true}); _check("held guard stays down during punch startup", not guard.P["blocking"])
	var whiff = _fresh(4.0); _queue(whiff, "L_STRAIGHT", {"power": true}); _damage(whiff)
	_check("power whiff opens exactly authored vulnerability", whiff.P["guard_open_t"] == Sim.ms(300))
	var blocked = _fresh(); _queue(blocked, "L_STRAIGHT", {"power": true}); blocked.B["blocking"] = true; _damage(blocked)
	_check("blocked power opens authored vulnerability", blocked.P["guard_open_t"] == Sim.ms(300))
	var reload = _fresh(); reload.T = reload.T.duplicate(true); reload.T["modifiers"]["POWER"]["startup_mult"] = 2.0; reload.T["modifiers"]["POWER"]["stamina_mult"] = 3.0
	_queue(reload, "L_STRAIGHT", {"power": true})
	_check("modifiers read hot-reloaded data rather than literals", reload.P["pending"]["startup"] == Sim.ms(320) and reload.P["pending"]["stamina_cost"] == 6.0)
	var before: int = Time.get_ticks_usec(); scene.sim.T = scene.sim.T.duplicate(true); scene.sim.T["punch_matrix"]["L_STRAIGHT"]["startup_ms"] = 999
	_key(KEY_R)
	_check("scene hot reload restores authored values within one second", scene.sim.T["punch_matrix"]["L_STRAIGHT"]["startup_ms"] == 160 and Time.get_ticks_usec() - before < 1000000)
	input.clear(); _key(KEY_J); scene.controls_menu.open()
	_check("opening controls clears pending/held input", input.queue.is_empty() and not input.down("L_STRAIGHT"))
	scene.controls_menu.close()
	input.stick_sample(2, Vector2(1, 0), 0); input.stick_sample(2, Vector2(1, 0), 40000)
	_check("held stick cannot punch when resuming controls", not input.take_intent().has("punch"))
	input.stick_sample(2, Vector2.ZERO, 50000); input.stick_sample(2, Vector2(1, 0), 60000); input.stick_sample(2, Vector2(1, 0), 100000)
	_check("stick returns after neutral and a fresh flick", input.take_intent().get("punch", "") == "R_HOOK")
	# Capture latency must not turn a deliberately held uppercut into a feint.
	for duration in [50000, 100000]:
		input.clear(); input.stick_sample(2, Vector2(0.1, 1), 0); input.stick_sample(2, Vector2.ZERO, duration)
		var upper = _fresh(); upper.step(input.take_intent()); upper.step(input.take_intent())
		_check("down-flick release age %dus" % duration, upper.P["pending"].is_empty() == (duration < 80000))
	var hooks_before: bool = scene.sim.hooks_enabled
	var coach_before: bool = scene.sim.coach_on
	scene.set_practice(true); scene._hold_dummy()
	_check("dummy disables authored opponent decisions", not scene.sim.hooks_enabled and not scene.sim.coach_on and scene.sim.btimer > 100000)
	scene.set_practice(false)
	_check("leaving practice restores opponent behavior", scene.sim.hooks_enabled == hooks_before and scene.sim.coach_on == coach_before and scene.practice_restore.is_empty())
	var first = _fresh(); var second = _fresh()
	for tick in range(240):
		var command := {"punch": "R_HOOK", "power": true, "haymaker": true, "body": true} if tick % 80 == 0 else {}
		first.step(command); second.step(command)
	_check("modifier intent replay remains deterministic", first.hash_state() == second.hash_state())
	if "capture" in OS.get_cmdline_user_args():
		scene._render(1.0); scene._hud(); scene.controls_menu.open()
		for dimensions in [Vector2i(1280, 720), Vector2i(960, 600)]:
			root.size = dimensions
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var destination := "user://controls-%dx%d.png" % [dimensions.x, dimensions.y]
			_check("controls render " + str(dimensions), root.get_texture().get_image().save_png(destination) == OK)
			print("CAPTURE " + ProjectSettings.globalize_path(destination))
	print("INPUT DRIVE :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
