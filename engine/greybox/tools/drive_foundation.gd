extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_foundation.gd -- welcome
## Targeted foundation checks. Passing this driver is NOT whole-model acceptance.
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
const Body := preload("res://sim/body_control.gd")
const Space := preload("res://presentation/rig_space.gd")
const Clock := preload("res://sim/clock.gd")
var tests := Tests.new()
var scene: Node
var checks := 0
var failures: Array[String] = []
var samples := []

func _initialize() -> void: _run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh(spacing := 1.6):
	var s = tests.make_sim(0, 947)
	tests.quiet(s); tests.place(s, spacing)
	s.bstate = "ACTING"; s.bqueue = []; s.btimer = 100000
	return s

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = pressed
	root.push_input(event)

func advance(s, intent: Dictionary) -> void:
	scene.sim = s
	scene.fight_view.capture(scene.player, s.P, s.B, s, "P")
	scene.fight_view.capture(scene.boss, s.B, s.P, s, "B")
	scene.fight_view.before_step(s)
	scene.prev_p = s.P["pos"]; scene.prev_b = s.B["pos"]
	s.step(intent); scene._consume_events(); scene._render(1)

func capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	await process_frame; await RenderingServer.frame_post_draw
	check("rendered " + label, root.get_texture().get_image().save_png("user://foundation-" + label + ".png") == OK)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame; await process_frame
	scene.controls_menu.close(); scene.fight_hud.entry.hide(); scene.combat_input.reset_bindings()
	scene.sim = fresh()
	key(KEY_D, true)
	var intent: Dictionary = scene._intent()
	check("native right intent is body control, with no free root move", intent.has("body_axis") and intent["body_axis"].x > 0.99 and not intent.has("move"))
	key(KEY_SPACE, true); key(KEY_C, true); key(KEY_SHIFT, true); key(KEY_J, true)
	intent = scene._intent()
	check("body, guard, target and punch remain independently expressible", intent["body_axis"].x > 0.99 and intent["block"] and intent["body"] and intent["power"] and intent.get("punch") == "L_STRAIGHT")
	for code in [KEY_D, KEY_SPACE, KEY_C, KEY_SHIFT, KEY_J]: key(code, false)
	scene.combat_input.clear()
	key(KEY_CTRL, true); key(KEY_D, true)
	var steps := 0; var burst := false
	for i in 90:
		intent = scene._intent(); steps += 1 if intent.has("pocket_step") else 0
		burst = burst or intent.get("sprint", false)
	check("held step strokes once without legacy teleport burst", steps == 1 and not burst)
	key(KEY_CTRL, false); key(KEY_CTRL, true)
	check("repressing modifier at held rim does not manufacture a step", not scene._intent().has("pocket_step"))
	key(KEY_D, false); scene._intent(); key(KEY_D, true)
	check("neutral return rearms the next deliberate step", scene._intent().has("pocket_step"))
	key(KEY_D, false); key(KEY_CTRL, false); scene.combat_input.clear()
	key(KEY_D, true); scene._intent()
	scene.controls_menu.open(); scene.controls_menu.close(); key(KEY_D, true)
	check("pause/resume requires neutral before a held body stroke returns", scene._intent()["body_axis"] == Vector2.ZERO)
	key(KEY_D, false); scene._intent(); key(KEY_D, true)
	check("body control resumes after a deliberate neutral return", scene._intent()["body_axis"].x > 0.99)
	key(KEY_D, false); scene.combat_input.clear()
	check("radial deadzone preserves diagonal angle and uniform radius", Body.radial(Vector2.ONE).is_equal_approx(Vector2.ONE.normalized()) and Body.radial(Vector2(0.1,0.1)) == Vector2.ZERO)
	var s = fresh()
	var origin: Vector2 = s.P["pos"]
	var previous: Vector3 = Vector3.ZERO
	var max_jump := 0.0; var correspondence := true; var lengths := true
	for i in 720:
		var axis := Vector2.from_angle(TAU * i / 360.0)
		advance(s, {"body_axis": axis, "block": true})
		var head: Dictionary = s._head_world(s.P, s.B)
		var local := Space.ground(head["p"] - s.P["pos"]) + Vector3.UP * float(head["h"])
		var rig: Dictionary = scene.player.get_meta("render_kinematics")
		correspondence = correspondence and local.distance_to(rig["head"]) < 0.0001
		if i > 0: max_jump = maxf(max_jump, local.distance_to(previous))
		previous = local
		for hand in 2:
			lengths = lengths and absf(rig["shoulders"][hand].distance_to(rig["elbows"][hand]) - 0.38) < 0.0001 and absf(rig["elbows"][hand].distance_to(rig["wrists"][hand]) - 0.36) < 0.0001
		if i % 90 == 0: samples.append({"tick": s.tick, "axis": str(axis), "head": str(local), "support": s.P["body_control"]["support"]})
	check("continuous circular body sweep stays rooted", s.P["pos"].distance_to(origin) < 0.0001)
	check("full body sweep has bounded continuous motion", max_jump < 0.06)
	check("visible head and canonical head coincide throughout sweep", correspondence)
	check("fixed arm lengths survive the continuous body surface", lengths)
	check("guard remains active during live continuous body movement", s.P["blocking"])
	await capture("pov-body")
	scene.fight_view.inspection_view = true; scene.fight_view.orbit = Vector3.ZERO; scene._render(1)
	await capture("observer-body")
	scene.fight_view.inspection_view = false; scene.fight_view.orbit = Vector3.ZERO
	s = fresh(); var normal := s.resolve_geometry(s.B, s.P, "R_STRAIGHT", false)
	for i in 35: s.step({"body_axis": Vector2.RIGHT})
	check("continuous slip changes actual straight-punch geometry", normal == "HIT" and s.resolve_geometry(s.B, s.P, "R_STRAIGHT", false) == "MISS_LATERAL")
	s.bpending = {"row":"R_STRAIGHT", "body":false}; s._land_boss_punch(1.0)
	check("threatened neutral-to-slip miss opens a real counter", s.P["counter_t"] > 0)
	s = fresh(3.0)
	for i in 35: s.step({"body_axis": Vector2.RIGHT})
	s.bpending = {"row":"R_STRAIGHT", "body":false}; s._land_boss_punch(1.0)
	check("unthreatened out-of-range body movement earns no counter", s.P["counter_t"] == 0)
	s = fresh(); origin = s.P["pos"]; var other_origin: Vector2 = s.B["pos"]
	var maximum_tick := 0.0; var last: Vector2 = origin
	for i in 100:
		advance(s, {"body_axis":Vector2.ZERO, "pocket_step":Vector2.RIGHT} if i == 0 else {"body_axis":Vector2.ZERO})
		maximum_tick = maxf(maximum_tick, last.distance_to(s.P["pos"])); last = s.P["pos"]
	check("bounded footwork moves real root by authored step length", absf(origin.distance_to(s.P["pos"]) - Body.STEP_M) < 0.0001)
	check("step travels over time and never drags opponent", maximum_tick < 0.04 and s.B["pos"].is_equal_approx(other_origin))
	check("step finishes with no active or stale queued travel", s.P["body_control"]["step"].is_empty() and s.P["body_control"]["queued"].is_empty())
	var foot_match := true; var planted_stable := true; var legs_fixed := true; var one_support := true
	s = fresh(); s.step({"body_axis":Vector2.ZERO})
	var prior: Dictionary = s.P["body_control"].duplicate(true)
	for i in 140:
		advance(s, {"body_axis":Vector2(0.25,0.2), "pocket_step":Vector2.RIGHT} if i == 0 else {"body_axis":Vector2(0.25,0.2)})
		var state: Dictionary = s.P["body_control"]
		var rig: Dictionary = scene.player.get_meta("render_kinematics")
		one_support = one_support and (state["planted"][0] or state["planted"][1])
		for j in 2:
			var sole: Vector3 = Space.ground(state["feet"][j] - s.P["pos"]) + Vector3.UP * float(state["foot_lift"][j])
			foot_match = foot_match and sole.distance_to(rig["feet"][j]) < 0.0001
			if state["planted"][j] and prior["planted"][j]:
				planted_stable = planted_stable and Vector2(state["feet"][j]).distance_to(prior["feet"][j]) < 0.0001
			legs_fixed = legs_fixed and absf(rig["hip_joints"][j].distance_to(rig["knees"][j])-0.43) < 0.0001 and absf(rig["knees"][j].distance_to(rig["ankles"][j])-0.42) < 0.0001
		prior = state.duplicate(true)
	check("rendered soles follow authoritative support feet", foot_match)
	check("grounded support never slides or leaves both feet airborne", planted_stable and one_support)
	check("canonical footwork preserves both leg lengths", legs_fixed)
	check("completed step gathers and restores settled support", s.P["body_control"]["gait"].is_empty() and s.P["body_control"]["support"] > 0.90)
	await capture("pov-angle")
	var camera_offset: Vector3 = scene.cam.position - scene.player.position
	check("player POV follows its eye instead of chase distance", Vector2(camera_offset.x, camera_offset.z).length() < 0.4 and not scene.player.get_meta("head").visible)
	s = fresh(); s.P["pos"] = Vector2(3.48, 0); s.B["pos"] = Vector2(3.48, -2)
	other_origin = s.B["pos"]
	for i in 100: s.step({"body_axis":Vector2.ZERO, "pocket_step":Vector2.RIGHT} if i == 0 else {"body_axis":Vector2.ZERO})
	check("blocked ring exit shortens step without moving opponent", s.P["pos"].x <= Sim.RING_HALF and s.B["pos"] == other_origin)
	s = fresh(); s.P["busy_t"] = 120
	s.step({"body_axis":Vector2.ZERO,"pocket_step":Vector2.RIGHT})
	check("committed action buffers at most one step", not s.P["body_control"]["queued"].is_empty() and s.P["body_control"]["step"].is_empty())
	for i in 30: s.step({"body_axis":Vector2.ZERO})
	check("blocked step expires rather than executing later", s.P["body_control"]["queued"].is_empty() and s.P["body_control"]["step"].is_empty())
	s = fresh(); s.step({"body_axis":Vector2(0.4,0.6),"pocket_step":Vector2.LEFT})
	var frozen: Dictionary = s.P["body_control"].duplicate(true)
	s.freeze_t = 6
	for i in 6: s.step({"body_axis":Vector2(-1,-1)})
	check("hitstop freezes canonical body and step clock", s.P["body_control"] == frozen)
	s.freeze_t = 2; s.step({"pocket_step":Vector2.RIGHT})
	check("new step during hitstop survives without advancing support", s.P.has("frozen_step") and s.P["body_control"] == frozen)
	var saved: Dictionary = s.snapshot(); var restored = fresh()
	check("typed save restores in-flight body and footwork exactly", restored.restore(saved).get("same", false))
	for i in 80:
		var follow := {"body_axis":Vector2.from_angle(float(i)/13.0)}
		s.step(follow); restored.step(follow)
	check("restored body exchange has exact replay continuation", s.hash_state() == restored.hash_state())
	s = fresh(); s.step({"body_axis":Vector2.ZERO,"pocket_step":Vector2.LEFT})
	s._drop(true); s.step({})
	check("knockdown cancels old body travel and buffered steps", not s.P.has("body_control") and not s.P.has("frozen_step"))
	s = fresh(); s.P["stamina"] = 0; s.step({"body_axis":Vector2.ZERO,"pocket_step":Vector2.LEFT})
	check("exhausted footwork refuses travel instead of borrowing effort", s.P["body_control"]["step"].is_empty())
	var hashes := []
	for hz in [30,60,144]:
		s = fresh(); var clock := Clock.new(); var count := 0
		for frame in hz * 3:
			for t in clock.advance(1.0/hz):
				var cmd := {"body_axis":Vector2.from_angle(float(count)/25.0)}
				if count == 100: cmd["pocket_step"] = Vector2(-1,-1)
				s.step(cmd); count += 1
		hashes.append(s.hash_state())
	check("30/60/144 Hz partitioning preserves body/step outcomes", hashes[0] == hashes[1] and hashes[1] == hashes[2])
	var base = fresh(); var rotated = fresh(); var rotation := 1.19; var translation := Vector2(0.2,-0.3)
	rotated.P["pos"] = Vector2(base.P["pos"]).rotated(rotation) + translation
	rotated.B["pos"] = Vector2(base.B["pos"]).rotated(rotation) + translation
	var invariant := true
	for i in 120:
		var cmd := {"body_axis":Vector2.from_angle(float(i)/23.0)}
		if i == 50: cmd["pocket_step"] = Vector2(0.5,-1)
		base.step(cmd); rotated.step(cmd)
		var a: Dictionary = base._head_world(base.P,base.B); var b: Dictionary = rotated._head_world(rotated.P,rotated.B)
		invariant = invariant and Vector2(b["p"]).distance_to(Vector2(a["p"]).rotated(rotation)+translation) < 0.0001 and absf(a["h"]-b["h"]) < 0.0001
		invariant = invariant and base.resolve_geometry(base.B,base.P,"L_STRAIGHT",false) == rotated.resolve_geometry(rotated.B,rotated.P,"L_STRAIGHT",false)
	check("interior transformed encounter preserves body/step and current contact result", invariant)
	var report := {"checks":checks,"failures":failures,"samples":samples,"scope":"continuous body/pocket stepping/POV only; swept punch/guard and whole-foundation acceptance remain open"}
	var file := FileAccess.open("user://foundation.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FOUNDATION VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
