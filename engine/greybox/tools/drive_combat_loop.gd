extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_combat_loop.gd -- welcome
## NP-03 integration: directions are screen-relative, resources shape the hands,
## and the rendered exchange follows the same clock as its hit resolution.
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
var tests := Tests.new()
var scene: Node
var checks := 0
var failures: Array[String] = []
var keys := {}

func capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	await process_frame; await RenderingServer.frame_post_draw
	check("GPU frame: " + label, root.get_texture().get_image().save_png("user://combat-" + label + ".png") == OK)

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh():
	var s = tests.make_sim(0, 731)
	tests.quiet(s); tests.place(s, 1.5)
	s.P["pkg"] = {}; s.B["pkg"] = {}
	return s

func key(code: int, pressed: bool) -> void:
	if bool(keys.get(code, false)) == pressed: return
	keys[code] = pressed
	var e := InputEventKey.new(); e.keycode = code; e.pressed = pressed; root.push_input(e)

func _run() -> void:
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame
	scene.controls_menu.close(); scene.begin_fight(false); scene.combat_input.reset_bindings()
	for angle in [0.0, PI / 2, PI, PI * 1.5]:
		for direction in [-1.0, 1.0]:
			scene.sim = fresh()
			var away := Vector2(sin(angle), cos(angle))
			scene.sim.P["pos"] = away; scene.sim.B["pos"] = -away
			scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
			scene.fight_view.orbit = Vector3.ZERO; scene._render(1)
			var camera_right := Vector2(scene.cam.global_basis.x.x, scene.cam.global_basis.x.z)
			var before: Vector2 = scene.sim.P["pos"]
			scene.combat_input.clear(); key(KEY_A if direction < 0 else KEY_D, true)
			scene.sim.step(scene._intent()); key(KEY_A if direction < 0 else KEY_D, false)
			check("screen lateral %s / %s" % [angle, direction], (scene.sim.P["pos"] - before).dot(camera_right) * direction > 0)
			var f = fresh(); f.P["pos"] = away; f.B["pos"] = -away
			f._set_dodge(f.P, "SLIP", int(direction))
			check("screen slip %s / %s" % [angle, direction], (f._head_world(f.P, f.B)["p"] - f.P["pos"]).dot(camera_right) * direction > 0)
	var fast = fresh(); var tired = fresh()
	tired.P["stamina"] = 10
	fast._queue_punch("L_STRAIGHT", {}); fast._try_execute_cmd()
	tired._queue_punch("L_STRAIGHT", {}); tired._try_execute_cmd()
	check("gassed hands use authored speed curve", int(tired.P["pending"]["startup"]) == Sim.ms(160.0 / 0.55))
	check("gassed recovery uses authored speed curve", int(tired.P["busy_t"]) - int(tired.P["pending"]["startup"]) == Sim.ms(220.0 / 0.55))
	for stamina in [90.0, 55.0, 25.0, 10.0]:
		var s = fresh(); s.P["stamina"] = stamina; s.P["comp"] = 20
		var scale: float = s._gassed(s.P)["composure_regen"]
		s.step({})
		check("composure recovery band %s" % stamina, is_equal_approx(float(s.P["comp"]), 20.0 + 3.0 / 120 * scale))
	var guarded = fresh(); guarded.P["stamina"] = 50
	guarded.staff_fx = {}
	guarded.step({"block": true})
	check("holding guard uses active stamina recovery", is_equal_approx(float(guarded.P["stamina"]), 50.0 + 1.0 / 120))
	var punching = fresh(); punching.P["guard"] = 40; punching.P["busy_t"] = 30
	punching.step({})
	check("guard cannot refill through punch recovery", is_equal_approx(float(punching.P["guard"]), 40.0))
	# The contact pose and the sim both hold during hitstop.
	scene.sim = fresh(); scene.fight_view.before_step(scene.sim)
	scene.sim.step({"punch": "L_STRAIGHT"}); scene._consume_events()
	tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
	for i in 80:
		if scene.sim.freeze_t > 0: break
		scene.fight_view.before_step(scene.sim); scene.sim.step({}); scene._consume_events()
	scene.fight_view.pose(scene.player, scene.sim.P, scene.sim.B, scene.sim, "P")
	var hand: Vector3 = scene.player.get_meta("gloves")[0].position
	var frozen: int = scene.sim.freeze_t
	for i in frozen:
		scene.fight_view.before_step(scene.sim); scene.sim.step({}); scene._consume_events()
		scene.fight_view.pose(scene.player, scene.sim.P, scene.sim.B, scene.sim, "P")
	check("hitstop holds the glove on contact for every frozen tick (%d ticks, %s → %s)" % [frozen, hand, scene.player.get_meta("gloves")[0].position], frozen > 0 and hand.is_equal_approx(scene.player.get_meta("gloves")[0].position))
	for hz in [30, 60, 144]:
		scene.sim = fresh(); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
		scene.clock.acc = 0; scene.combat_input.clear(); scene.fight_view.clock_sim = null
		var before_punches: int = scene.fx_counts.get("punch", 0)
		var before_hits: int = scene.fx_counts.get("hit", 0)
		for row in scene.combat_input.ROWS:
			var code: int = scene.combat_input.KEYS[row]
			key(code, true)
			for frame in int(hz * 1.4):
				scene._process(1.0 / hz)
				if hz == 60 and row == "R_HOOK" and frame in [0, 5, 10, 14, 18, 24]: await capture("hook-%02d" % frame)
			key(code, false)
			for frame in int(hz * 0.2): scene._process(1.0 / hz)
		check("all ten native punch keys commit at %d Hz" % hz, int(scene.fx_counts.get("punch", 0)) - before_punches == 10)
		check("sustained exchange resolves hits at %d Hz" % hz, int(scene.fx_counts.get("hit", 0)) - before_hits >= 6)
	# Follow the visible timing state, using native key edges, not forced beats.
	scene.sim = fresh(); scene.sim._drop(true, false); scene._consume_events()
	for frame in 400:
		var timing: Dictionary = scene.fight_feedback.timing_state(scene.sim)
		key(KEY_ENTER, not timing.is_empty() and timing["open"] and not timing["locked"])
		scene._process(1.0 / 60)
		if scene.sim.mode != "EIGHT": break
	key(KEY_ENTER, false)
	check("visible standing-eight cue lets native taps recover", scene.sim.mode == "FIGHT" and scene.fx_counts.get("eight_up", 0) == 1)
	scene.sim = fresh(); scene.sim._start_clinch("B"); scene._consume_events()
	for frame in 220:
		var timing: Dictionary = scene.fight_feedback.timing_state(scene.sim)
		key(KEY_A, not timing.is_empty() and timing["label"] == "LEFT" and timing["open"] and not timing["locked"])
		key(KEY_D, not timing.is_empty() and timing["label"] == "RIGHT" and timing["open"] and not timing["locked"])
		scene._process(1.0 / 60)
		if scene.sim.clinch.is_empty(): break
	key(KEY_A, false); key(KEY_D, false)
	check("visible clinch cues accept all four native alternating taps", scene.fx_counts.get("clinch_beat", 0) == 4)
	check("contact, tell and timing cues reach audio feedback", scene.fight_feedback.played.get("jab", 0) > 0 and scene.fight_feedback.played.get("beat", 0) > 0)
	await _club_journey()
	print("COMBAT LOOP VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func press(id: String) -> void:
	var club = scene.club_flow
	check("club action available: " + id, club.buttons.has(id) and not club.buttons[id].disabled)
	if club.buttons.has(id) and not club.buttons[id].disabled: club.buttons[id].pressed.emit()

func _club_journey() -> void:
	scene.sim = tests.make_sim(0, 731); scene.clock.acc = 0; scene.combat_input.clear()
	var club = scene.club_flow; club.page = "Training"; club.open(); club.set_process(false)
	var start_tick: int = scene.sim.tick
	scene._process(0.1)
	check("club pauses the fight clock", scene.sim.tick == start_tick)
	var beans: int = scene.sim.rewards.get("beans", 0)
	press("roadwork")
	await capture("roadwork")
	for step in 12:
		while not club.training.is_empty() and float(club.training["time"]) < float(club.training["next"]) - 0.01: club._process(0.01)
		press("step")
		for frame in 35: club._process(0.01)
	check("played roadwork consumes a daily slot and earns Beans", scene.sim.training_used() == 1 and int(scene.sim.rewards.get("beans", 0)) > beans)
	for page in ["Stable", "Recruit", "Formation", "Scout Book", "Bouts"]:
		club.page = page; club.rebuild(); await process_frame
		if page in ["Stable", "Bouts"]: await capture(page.to_lower())
		check("club page builds: " + page, club.body.get_child_count() > 0)
	club.save_club(); club.save_club(); club.save_club()
	var saved_hash: int = scene.sim.hash_state()
	var saved_ledger: Dictionary = scene.sim.rewards.duplicate(true)
	check("repeated save retains a rollback file", FileAccess.file_exists(scene.SAVE_PATH + ".bak") and club.status.text.begins_with("Club saved"))
	scene.sim.new_day(); club.load_club()
	check("continue restores the club ledger and exact sim state", scene.sim.hash_state() == saved_hash and scene.sim.rewards == saved_ledger)
	club.page = "Bouts"; club.rebuild(); press("bout:scrap_1")
	check("scrap starts through the club with its real objective", not club.visible and scene.sim.bout["kind"] == "scrap" and scene.sim.obj["id"] == "SCR-01")
	# Simple body-shot policy over native input; no health/objective edits.
	for frame in 60 * 40:
		if scene.sim.mode == "OVER": break
		key(KEY_C, true); key(KEY_W, scene.sim.P["pos"].distance_to(scene.sim.B["pos"]) > 1.25)
		key(KEY_J, frame % 45 < 25); key(KEY_K, frame % 45 >= 26 and frame % 45 < 44)
		var timing: Dictionary = scene.fight_feedback.timing_state(scene.sim)
		key(KEY_ENTER, not timing.is_empty() and timing["open"] and not timing["locked"])
		scene._process(1.0 / 60)
	for code in [KEY_C, KEY_W, KEY_J, KEY_K, KEY_ENTER]: key(code, false)
	check("scrap returns to club with verdict and reward", scene.sim.mode == "OVER" and club.visible and club.result_text != "" and club.reward_text != "")
	await capture("scrap-result")
	check("body-shot objective was earned through input", scene.sim.obj["met"] and int(scene.sim.pi["dialects"].get("school", {}).get("scraps", 0)) >= 1)
	var earned: Dictionary = scene.sim.rewards.duplicate(true)
	press("dual"); press("order:1"); var planned: Array = club.order.duplicate(); press("seal")
	check("formation rings the bell in chosen order and retains earnings", not club.visible and scene.sim.sealed_p.slice(0, planned.size()) == planned and scene.sim.rewards == earned)
	scene._process(1.0 / 60); club.page = "Bouts"; club.open()
	check("live bout cannot be replaced through club buttons", club.buttons["bout:scrap_1"].disabled and club.buttons["dual"].disabled)
	club.page = "Training"; club.rebuild()
	check("live bout prevents training", club.buttons["roadwork"].disabled)
	club.save_club(); var mid_hash: int = scene.sim.hash_state(); club.close()
	scene._process(0.1); club.open(); club.load_club()
	check("mid-bout save resumes exact state", scene.sim.hash_state() == mid_hash)
