extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_foundation.gd -- welcome
## Targeted foundation checks. Passing this driver is NOT whole-model acceptance.
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
const Body := preload("res://sim/body_control.gd")
const Space := preload("res://presentation/rig_space.gd")
const Clock := preload("res://sim/clock.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
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

func pad_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new(); event.axis = axis; event.axis_value = value; event.device = 91
	root.push_input(event)

func advance(s, intent: Dictionary) -> Array:
	scene.sim = s
	scene.fight_view.capture(scene.player, s.P, s.B, s, "P")
	scene.fight_view.capture(scene.boss, s.B, s.P, s, "B")
	scene.fight_view.before_step(s)
	scene.prev_p = s.P["pos"]; scene.prev_b = s.B["pos"]
	s.step(intent)
	var emitted: Array = s.events.duplicate(true)
	scene._consume_events(); scene._render(1)
	return emitted

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
	key(KEY_D, false); key(KEY_D, true)
	check("keyboard neutral between fixed ticks rearms one step", scene._intent().has("pocket_step") and not scene._intent().has("pocket_step"))
	key(KEY_D, false); key(KEY_CTRL, false); scene.combat_input.clear()
	key(KEY_CTRL, true); pad_axis(JOY_AXIS_LEFT_Y, 1); scene._intent()
	pad_axis(JOY_AXIS_LEFT_Y, -1)
	check("controller rim reversal without neutral is not another step", not scene._intent().has("pocket_step"))
	pad_axis(JOY_AXIS_LEFT_Y, 0); pad_axis(JOY_AXIS_LEFT_Y, -1)
	check("controller neutral event between fixed ticks rearms one step", scene._intent().has("pocket_step") and not scene._intent().has("pocket_step"))
	pad_axis(JOY_AXIS_LEFT_Y, 0); key(KEY_CTRL, false); scene.combat_input.clear()
	key(KEY_D, true); scene._intent()
	scene.controls_menu.open(); scene.controls_menu.close(); key(KEY_D, true)
	check("pause/resume requires neutral before a held body stroke returns", scene._intent()["body_axis"] == Vector2.ZERO)
	key(KEY_D, false); scene._intent(); key(KEY_D, true)
	check("body control resumes after a deliberate neutral return", scene._intent()["body_axis"].x > 0.99)
	key(KEY_D, false); scene.combat_input.clear()
	pad_axis(JOY_AXIS_TRIGGER_LEFT, 1); pad_axis(JOY_AXIS_LEFT_X, 0.75); pad_axis(JOY_AXIS_LEFT_Y, -0.6)
	intent = scene._intent()
	check("controller body disk and body targeting coexist without a timed dodge", intent["body"] and intent["body_axis"].x > 0.6 and intent["body_axis"].y > 0.5 and not intent.has("dodge"))
	pad_axis(JOY_AXIS_TRIGGER_LEFT, 0); pad_axis(JOY_AXIS_LEFT_X, 0); pad_axis(JOY_AXIS_LEFT_Y, 0); scene.combat_input.clear()
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
	var rooted_punches := true; var rooted_opponent := true; var entry_distance := true; var return_distance := true
	for row in s.T["punch_matrix"]:
		s = fresh(2.5); s.step({"body_axis":Vector2.ZERO})
		var boss_origin: Vector2 = s.B["pos"]
		s._boss_act({"kind":"punch", "row":row, "mult":1.0, "body":false})
		rooted_opponent = rooted_opponent and s.B["pos"].distance_to(boss_origin) < 0.0001
		s = fresh(); origin = s.P["pos"]
		s.step({"body_axis":Vector2.ZERO, "punch":row})
		tests.clear_defense(s.B)
		for i in 120: s.step({"body_axis":Vector2.ZERO})
		rooted_punches = rooted_punches and s.P["pos"].distance_to(origin) < 0.0001
		for direction in [Vector2.UP, Vector2.DOWN]:
			s = fresh(2.0); origin = s.P["pos"]
			# Anatomical DOWN (+y) enters and UP (-y) retreats.
			s.step({"body_axis":Vector2.ZERO, "pocket_step":direction, "punch":row})
			var stepping: bool = s.P["pending"].get("stepping", false)
			tests.clear_defense(s.B)
			for i in 120: s.step({"body_axis":Vector2.ZERO})
			var bounded := absf(s.P["pos"].distance_to(origin) - Body.STEP_M) < 0.0001
			if direction.y > 0: entry_distance = entry_distance and bounded and stepping
			else: return_distance = return_distance and bounded and not stepping
	check("all native punch families stay rooted without a foot stroke", rooted_punches)
	check("opponent punch families cannot teleport into native player range", rooted_opponent)
	check("entry punches share one bounded step without extra lunge or reach", entry_distance)
	check("retreat punches keep their committed exit without forward teleport", return_distance)
	s = fresh(2.7); origin = s.P["pos"]
	s.step({"body_axis":Vector2(0,1), "punch":"R_STRAIGHT"})
	check("forward body compression cannot silently request a stepping punch", not s.P["pending"]["stepping"])
	for i in 100: s.step({"body_axis":Vector2(0,1)})
	check("out-of-range rooted punches cannot close distance automatically", s.P["pos"].distance_to(origin) < 0.0001)
	opponent_clock()
	s = fresh(1.7)
	for i in 16: advance(s, {"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"} if i == 0 else {"body_axis":Vector2.ZERO})
	var once: Dictionary = scene.player.get_meta("kinematics").duplicate(true)
	var repeated := once.duplicate(true)
	for i in 12: repeated = Motion.constrain(repeated)
	var repeat_stable := Vector3(once["chest"]).distance_to(repeated["chest"]) < 0.00001 and Vector3(once["pelvis"]).distance_to(repeated["pelvis"]) < 0.00001
	for i in 2:
		repeat_stable = repeat_stable and Vector3(once["wrists"][i]).distance_to(repeated["wrists"][i]) < 0.00001 and Vector3(once["knees"][i]).distance_to(repeated["knees"][i]) < 0.00001
	check("reapplying pose constraints cannot accumulate lean or lower the pelvis", repeat_stable)
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
	var sim_hash: int = s.hash_state()
	for i in 40: scene._render(float(i % 10) / 10.0)
	check("render interpolation never changes authoritative body or support", s.hash_state() == sim_hash)
	await capture("pov-angle")
	var camera_offset: Vector3 = scene.cam.position - scene.player.position
	check("player POV follows its eye instead of chase distance", Vector2(camera_offset.x, camera_offset.z).length() < 0.4 and not scene.player.get_meta("head").visible)
	s = fresh(); s.P["pos"] = Vector2(3.48, 0); s.B["pos"] = Vector2(3.48, -2)
	other_origin = s.B["pos"]
	for i in 100: s.step({"body_axis":Vector2.ZERO, "pocket_step":Vector2.RIGHT} if i == 0 else {"body_axis":Vector2.ZERO})
	check("blocked ring exit shortens step without moving opponent", s.P["pos"].x <= Sim.RING_HALF and s.B["pos"] == other_origin)
	s = fresh(0.71); origin = s.P["pos"]
	for i in 80: s.step({"body_axis":Vector2.ZERO,"pocket_step":Vector2(0,-1)} if i == 0 else {"body_axis":Vector2.ZERO})
	check("crowded entry can step outward instead of trapping the mover", s.P["pos"].distance_to(origin) > 0.45)
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
	var mirrored = fresh(); mirrored.P["stance"] = "southpaw"
	mirrored.step({"body_axis":Vector2.ZERO}); base = fresh(); base.step({"body_axis":Vector2.ZERO})
	var south: Dictionary = mirrored.P["body_control"]; var orthodox: Dictionary = base.P["body_control"]
	var fwd: Vector2 = orthodox["facing"]
	check("southpaw support mirrors lead/rear without mirroring anatomical input", Vector2(south["feet"][0]-mirrored.P["pos"]).dot(fwd) < 0 and Vector2(orthodox["feet"][0]-base.P["pos"]).dot(fwd) > 0)
	# A live opponent, native key edges and the actual match/view. This is
	# integration footage, not boxing authenticity or player-feel acceptance.
	s = tests.make_sim(0, 947); scene.sim = s; scene.combat_input.clear()
	var recording := "record" in OS.get_cmdline_user_args()
	var frames_saved := 0
	if recording:
		Engine.max_fps = 60
		DirAccess.make_dir_recursive_absolute("user://foundation-film")
	var held := {}; var thrown := 0; var opponent_thrown := 0; var finite := true
	var eye_clearance := INF; var close_glove_ticks := 0; var longest_close_run := 0; var close_run := 0
	var used_body := false; var moved_root := false; origin = s.P["pos"]
	for i in 2400:
		if recording: scene.fight_view.inspection_view = i >= 1200
		var wanted := []
		if i % 240 < 55: wanted.append(KEY_SPACE)
		if i % 240 >= 15 and i % 240 < 55: wanted.append(KEY_D if i % 480 < 240 else KEY_A)
		if i % 400 >= 120 and i % 400 < 124:
			wanted.append(KEY_CTRL); wanted.append(KEY_W if i % 800 < 400 else KEY_S)
		if i % 90 >= 60 and i % 90 < 75: wanted.append([KEY_J,KEY_K,KEY_U,KEY_O][int(i/90)%4])
		if s.mode == "EIGHT" and i % 30 == 0: wanted.append(KEY_ENTER)
		for code in [KEY_SPACE,KEY_D,KEY_A,KEY_CTRL,KEY_W,KEY_S,KEY_J,KEY_K,KEY_U,KEY_O,KEY_ENTER]:
			var on: bool = code in wanted
			if on != bool(held.get(code,false)): key(code,on); held[code] = on
		var emitted := advance(s,scene._intent())
		used_body = used_body or Vector2(s.P.get("body_control",{}).get("axis",Vector2.ZERO)).length() > 0.5
		moved_root = moved_root or s.P["pos"].distance_to(origin) > 0.2
		for event in emitted:
			if event.get("kind") == "punch": thrown += 1
			if event.get("kind") == "boss_act" and event.get("verb") == "punch": opponent_thrown += 1
		var rig: Dictionary = scene.player.get_meta("render_kinematics")
		finite = finite and Vector3(rig["head"]).is_finite() and scene.cam.position.is_finite()
		if not scene.fight_view.inspection_view:
			var nearest := INF
			for fighter in [scene.player, scene.boss]:
				for glove in fighter.get_meta("gloves"):
					nearest = minf(nearest, scene.cam.global_position.distance_to(glove.global_position) - Space.GLOVE_RADIUS)
			eye_clearance = minf(eye_clearance, nearest)
			# Describe close contact rather than hiding a threatening glove. This
			# 15 cm reporting band is an observation, not a boxing tuning limit.
			close_run = close_run + 1 if nearest < 0.15 else 0
			close_glove_ticks += 1 if nearest < 0.15 else 0
			longest_close_run = maxi(longest_close_run, close_run)
		if i == 177:
			var obstructors := []
			for fighter in [scene.player, scene.boss]:
				for part in fighter.get_children() + fighter.get_meta("cast_parts", []):
					if not part is MeshInstance3D or not part.is_visible_in_tree() or part.layers == 0: continue
					var local: Transform3D = part.global_transform.affine_inverse()
					var cross = part.get_aabb().intersects_ray(local * scene.cam.global_position, local.basis * -scene.cam.global_basis.z)
					if cross is Vector3:
						obstructors.append({"fighter":"P" if fighter == scene.player else "B", "anchor":part.get_meta("rig_anchor", str(part.name)), "index":part.get_meta("rig_index",-1), "distance":scene.cam.global_position.distance_to(part.global_transform * cross), "position":str(part.global_position)})
			obstructors.sort_custom(func(a,b): return a["distance"] < b["distance"])
			print("POV SIGHTLINE ", obstructors.slice(0,6), " camera=", scene.cam.global_position, " head=", rig["head"], " shoulders=", rig["shoulders"], " wrists=",rig["wrists"])
		if recording and i % 2 == 1:
			scene._hud()
			await process_frame; await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png("user://foundation-film/frame-%04d.png" % frames_saved) == OK: frames_saved += 1
		if i in [600,1800]:
			scene._hud(); await capture("live-pov-%d"%i)
			scene.fight_view.inspection_view = true; scene._render(1); await capture("live-observer-%d"%i)
			scene.fight_view.inspection_view = false; scene.fight_view.orbit = Vector3.ZERO
	for code in held:
		if held[code]: key(code,false)
	check("live native exchange exercises both fighters, body control and real root travel", thrown >= 5 and opponent_thrown >= 2 and used_body and moved_root)
	check("live exchange keeps finite embodied camera and anatomy", finite)
	check("embodied eye stays outside both fighters' glove volumes", eye_clearance > 0)
	if recording: check("normal-speed film contains every 60 Hz frame of the 20-second exchange", frames_saved == 1200)
	samples.append({"live_ticks":2400,"player_punches":thrown,"opponent_punches":opponent_thrown,"mode":s.mode,"minimum_eye_glove_clearance_m":eye_clearance,"close_glove_ticks":close_glove_ticks,"longest_close_glove_run_ticks":longest_close_run})
	var report := {"checks":checks,"failures":failures,"samples":samples,"scope":"native body/support/POV and committed-contact integration; whole-foundation and player-feel acceptance remain open"}
	var file := FileAccess.open("user://foundation.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FOUNDATION VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func opponent_clock() -> void:
	var committed := true; var timed := true; var charged := true
	var s = fresh(1.6)
	for row in s.T["punch_matrix"]:
		s = fresh(1.6); s.step({"body_axis":Vector2.ZERO})
		var stamina: float = s.B["stamina"]
		s.events.clear()
		s.btimer = s._boss_act({"kind":"punch", "row":row, "mult":1.0, "body":false})
		var startup: int = s.B["pending"].get("startup", 0)
		committed = committed and startup > 0 and tests.count_events(s.events,"boss_windup") == 1 and tests.count_events(s.events,"boss_act",{"verb":"punch"}) == 0
		charged = charged and is_equal_approx(stamina - float(s.B["stamina"]), float(s.T["punch_matrix"][row]["stamina"]))
		var delivered := -1
		for i in startup + 2:
			s.step({"body_axis":Vector2.ZERO})
			for e in s.events:
				if e.get("kind") == "boxing_contact" and e.get("by") == "B":
					delivered = i + 1
					var contact: Dictionary = e["contact"]
					var hand := 0 if str(row).begins_with("L_") else 1
					var world: Vector3 = s.B["boxing"]["origin"] + s.B["boxing"]["rig"]["wrists"][hand]
					timed = timed and float(contact["progress"]) >= 0.3 and world.distance_to(contact["point"]) < 0.001
			if delivered >= 0: break
		timed = timed and delivered > 0 and delivered <= startup and s.B["pending"].is_empty()
	check("every opponent family commits startup before contact", committed)
	check("opponent contact follows its active glove sweep within authored delivery", timed)
	check("native opponent commits the authored effort cost", charged)
	s = fresh(); s.step({"body_axis":Vector2.ZERO})
	s.btimer = s._boss_act({"kind":"punch", "row":"R_UPPERCUT", "mult":1.0, "body":false})
	var remaining: int = s.B["pending"]["t"]
	s.freeze_t = 5
	for i in 5: s.step({"body_axis":Vector2.ZERO})
	check("hitstop freezes the opponent commitment clock", s.B["pending"]["t"] == remaining)
	var restored = fresh()
	check("save restores the in-flight opponent punch", restored.restore(s.snapshot()).get("same",false))
	var same := true
	for i in 110:
		s.step({"body_axis":Vector2.ZERO}); restored.step({"body_axis":Vector2.ZERO})
		same = same and s.hash_state() == restored.hash_state() and s.events == restored.events
	check("opponent commitment replays identically after restore", same)
	for reason in ["drop", "clinch", "neutral reset"]:
		s = fresh(); s.step({"body_axis":Vector2.ZERO})
		s.btimer = s._boss_act({"kind":"punch", "row":"R_UPPERCUT", "mult":1.0, "body":false})
		if reason == "drop": s._drop(false)
		elif reason == "clinch": s._start_clinch("B")
		else:
			# The explicit VM neutral reset also terminates a prepared attack.
			s._neutral_reset(400)
		check(reason + " boundary cancels opponent startup", s.B["pending"].is_empty())
