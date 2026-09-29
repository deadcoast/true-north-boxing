extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_boxing_motion.gd -- welcome
## Mechanical motion evidence, not boxing authenticity or player-fun acceptance.
const Space := preload("res://presentation/rig_space.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
var tests := Tests.new()
var scene: Node
var checks := 0
var failures := []
var trace := []
var keys := {}
var anatomy_diagnostics := 0

func _initialize() -> void: _run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh(boss_index := 0) -> void:
	for code in keys.keys(): key(code, false)
	scene.combat_input.clear()
	scene.sim = tests.make_sim(boss_index, 731); tests.quiet(scene.sim); tests.place(scene.sim, 1.35)
	scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.fight_view.clock_sim = null; scene._render(1)

func key(code: int, pressed: bool) -> void:
	if bool(keys.get(code, false)) == pressed: return
	keys[code] = pressed
	var e := InputEventKey.new(); e.keycode = code; e.pressed = pressed; root.push_input(e)

func native_step() -> Array:
	return step(scene._intent())

func step(inp: Dictionary = {}) -> Array:
	scene.fight_view.capture(scene.player, scene.sim.P, scene.sim.B, scene.sim, "P")
	scene.fight_view.capture(scene.boss, scene.sim.B, scene.sim.P, scene.sim, "B")
	scene.fight_view.before_step(scene.sim)
	scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.sim.step(inp)
	var events: Array = scene.sim.events.duplicate(true)
	scene._consume_events(); scene._render(1); scene._hud()
	return events

func snapshot(fighter: Node3D = null) -> Array:
	var result := []
	if fighter == null: fighter = scene.player
	for part in fighter.get_children():
		if part is Node3D:
			var transform: Transform3D = part.transform
			# Measure visible world motion: root travel and local IK compensate
			# each other, for hands and knees as well as planted feet.
			transform.origin += fighter.position
			result.append(transform)
	return result

func capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	var materials := {}
	if label.begins_with("side-") or label.begins_with("front-"):
		scene.cam.position = scene.player.position + (Vector3(3.7, 1.8, 1.1) if label.begins_with("side-") else Vector3(1.1, 1.8, -3.7))
		scene.cam.look_at(scene.player.position + Vector3.UP * 0.9)
		# Inspection camera only: remove the chase camera's visibility mask so
		# the hips/trunk remain inspectable; restore every override afterward.
		for part in scene.player.get_children():
			if part is MeshInstance3D:
				materials[part] = part.material_override
				var opaque: StandardMaterial3D = part.mesh.material.duplicate()
				opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				part.material_override = opaque
	await process_frame; await RenderingServer.frame_post_draw
	check("GPU capture " + label, root.get_texture().get_image().save_png("user://motion-" + label + ".png") == OK)
	for part in materials: part.material_override = materials[part]

func _run() -> void:
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame
	scene.controls_menu.close(); scene.begin_fight(false)
	await planted_movement()
	if "footwork-only" in OS.get_cmdline_user_args():
		print("FOOTWORK VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
		scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1); return
	if "anatomy-only" in OS.get_cmdline_user_args():
		await anatomy()
		await contacts()
		await native_anatomy()
		print("ANATOMY VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
		scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1); return
	await anatomy()
	await contacts()
	await native_anatomy()
	await lifecycle()
	if "lifecycle-only" in OS.get_cmdline_user_args():
		print("LIFECYCLE VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
		scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1); return
	for row in scene.combat_input.ROWS:
		fresh()
		var first: Dictionary = scene.player.get_meta("kinematics").duplicate(true)
		step({"punch": row}); tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
		var hand := 0 if row.begins_with("L_") else 1
		var reached := false; var pose_at_hit := false; var stopped := true; var moving := false; var delivery_angle := 0.0
		var foot_pivot := 0.0; var hip_turn := 0.0; var shoulder_roll := 0.0; var fist_turn := 0.0
		var last := snapshot(); var jump := 0.0
		for tick in 150:
			var held: bool = scene.sim.freeze_t > 0
			var events := step()
			var rig: Dictionary = scene.player.get_meta("kinematics")
			var current := snapshot()
			if held:
				for i in current.size():
					if not (current[i] as Transform3D).is_equal_approx(last[i]):
						if stopped: print("HITSTOP DRIFT ", row, " tick ", tick, " part ", i, " from ", last[i], " to ", current[i])
						stopped = false
			for i in current.size():
				if current[i].origin.distance_to(last[i].origin) > 0.25: print("PART JUMP ", row, " tick=", tick, " index=", i, " from=", last[i].origin, " to=", current[i].origin)
				jump = maxf(jump, current[i].origin.distance_to(last[i].origin))
			last = current
			foot_pivot = maxf(foot_pivot, absf(float(rig["pivots"][hand]) - float(first["pivots"][hand])))
			hip_turn = maxf(hip_turn, absf(float(rig["hips_turn"]) - float(first["hips_turn"])))
			shoulder_roll = maxf(shoulder_roll, absf(float(rig["chest_turn"]) - float(rig["hips_turn"])))
			fist_turn = maxf(fist_turn, absf(float(rig["twists"][hand])))
			moving = moving or (rig["elbows"][hand] as Vector3).distance_to(first["elbows"][hand]) > 0.15
			for event in events:
				if event.get("kind") == "hit" and event.get("on") == "B":
					reached = true
					pose_at_hit = float(scene.player.get_meta("extension")) > 0.99
					delivery_angle = rad_to_deg((rig["shoulders"][hand] - rig["elbows"][hand]).angle_to(rig["wrists"][hand] - rig["elbows"][hand]))
					trace.append({"row": row, "tick": scene.sim.tick, "extension": scene.player.get_meta("extension"), "chain": rig["chain"], "joints": str(rig)})
			if row in ["R_STRAIGHT", "L_HOOK", "R_UPPERCUT"] and tick in [0, 3, 7, 12, 18, 24, 36, 48]:
				await capture(row.to_lower() + "-%02d" % tick)
				await capture("side-" + row.to_lower() + "-%02d" % tick)
			if row in ["L_HOOKERCUT", "R_HOOKERCUT"] and tick in [24, 28, 30, 32, 36]:
				await capture("side-" + row.to_lower() + "-%02d" % tick)
		check(row + " connects the ground, hips, trunk, elbow and fist", foot_pivot > 0.15 and hip_turn > 0.05 and shoulder_roll > 0.03 and moving and fist_turn > 0.1)
		check(row + " visible contact matches the resolving tick", reached and pose_at_hit)
		if "HOOK" in row or "UPPER" in row: check(row + " keeps the elbow bent through delivery", delivery_angle > 15 and delivery_angle < 120)
		elif "STRAIGHT" in row: check(row + " shortens inside without changing bone lengths", delivery_angle > 15 and delivery_angle < 145)
		check(row + " full rig holds through hitstop", stopped)
		check(row + " has no one-tick neutral snap", jump < 0.25)
	# Dodge entry, held pose, exit: inspect the actual rendered head and resolver.
	for dodge in ["SLIP_L", "SLIP_R", "DUCK", "WEAVE_L", "WEAVE_R", "LEAN"]:
		fresh(); var previous: Vector3 = scene.player.get_meta("head").position
		var max_jump := 0.0; var agreed := true; var peak := 0.0; var fixed := true
		for tick in 70:
			step({"dodge": dodge} if tick == 0 else {})
			scene._render(0.5); fixed = fixed and rigid_render(scene.player)
			scene._render(1.0); fixed = fixed and rigid_render(scene.player)
			var head: Vector3 = scene.player.get_meta("head").position
			max_jump = maxf(max_jump, previous.distance_to(head)); previous = head
			var physical: Dictionary = scene.sim._head_world(scene.sim.P, scene.sim.B)
			var world: Vector3 = scene.player.position + head
			agreed = agreed and (world - Space.ground(physical["p"]) - Vector3.UP * float(physical["h"])).length() < 0.0001 and absf(world.y - float(physical["h"])) < 0.0001
			peak = maxf(peak, head.distance_to(Vector3.UP * Sim.HEAD_H))
		check(dodge + " keeps limbs fixed and attached through entry and exit", fixed)
		check(dodge + " renders the same moving target used by collision", agreed and peak > 0.15)
		check(dodge + " enters and exits without teleporting", max_jump < 0.13 and previous.distance_to(Vector3.UP * Sim.HEAD_H) < 0.001)
	fresh(); var foot_slip := 0.0; var planted_ticks := 0; var last_world: Array = []
	for tick in 150:
		step({"move": Vector2(0.6, -0.3)})
		var feet: Array = scene.player.get_meta("kinematics")["feet"]
		var world: Array = [scene.player.position + feet[0], scene.player.position + feet[1]]
		if not last_world.is_empty():
			for i in 2:
				if absf(float(world[i].y)) < 0.0001 and absf(float(last_world[i].y)) < 0.0001:
					planted_ticks += 1; foot_slip = maxf(foot_slip, world[i].distance_to(last_world[i]))
		last_world = world
	check("stance feet plant while the other foot steps", planted_ticks > 50 and foot_slip < 0.001)
	var before: int = scene.sim.hash_state(); var old_pose := snapshot()
	for i in 20: scene._render(1)
	check("extra render frames neither advance motion nor alter combat", scene.sim.hash_state() == before and same_pose(snapshot(), old_pose))
	await transitions()
	var f := FileAccess.open("user://boxing-motion-trace.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "contact": trace}, "  ")); f.close()
	print("BOXING MOTION VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func transitions() -> void:
	# Real key edges go through the same adapter as play. The opponent's isolated
	# straight creates an observable evade/counter window; no counter flag is set.
	for pair in [[KEY_Q, "SLIP_L"], [KEY_E, "SLIP_R"], [KEY_DOWN, "DUCK"], [KEY_V, "WEAVE_R"], [KEY_B, "LEAN"]]:
		fresh()
		if pair[1] == "LEAN":
			tests.place(scene.sim, 2.2); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]; scene._render(1)
		key(pair[0], true)
		var last := snapshot(); var jump := 0.0
		for tick in 12:
			native_step()
			var now := snapshot()
			for i in now.size(): jump = maxf(jump, now[i].origin.distance_to(last[i].origin))
			last = now
		key(pair[0], false)
		scene.sim.bpending = {"row": "R_STRAIGHT", "body": false}; scene.sim._land_boss_punch(1.0)
		var earned: bool = scene.sim.P["counter_t"] > 0
		scene._consume_events(); key(KEY_W, pair[1] == "LEAN"); key(KEY_K, true)
		var landed := false
		for tick in 100:
			var events := native_step()
			if tick == 0: tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
			var now := snapshot()
			for i in now.size(): jump = maxf(jump, now[i].origin.distance_to(last[i].origin))
			last = now
			for event in events:
				if event.get("kind") == "hit" and event.get("on") == "B" and event.get("counter", false): landed = true
		key(KEY_K, false)
		if not (earned and landed): print("COUNTER DETAIL ", pair[1], " earned ", earned, " landed ", landed)
		check(pair[1] + " native defense earns and delivers a counter", earned and landed)
		check(pair[1] + " counter keeps the whole-body transition continuous", jump < 0.25)
	fresh(); key(KEY_SPACE, true)
	for tick in 12: native_step()
	var covered: float = scene.player.get_meta("kinematics")["guard"]
	var sequence := [KEY_J, KEY_K, KEY_U, KEY_O]
	var issued := 0; var hits := 0; var last := snapshot(); var jump := 0.0; var rows := []
	for tick in 420:
		if issued < sequence.size() and rows.size() == issued and scene.sim.P["busy_t"] <= 3 and scene.sim.P["pending"].is_empty():
			if issued > 0: key(sequence[issued - 1], false)
			key(KEY_C, issued == 3); key(sequence[issued], true); issued += 1
		var events := native_step()
		for event in events:
			if event.get("kind") == "punch":
				rows.append(event["row"]); tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
			if event.get("kind") == "hit" and event.get("on") == "B": hits += 1
		var now := snapshot()
		for i in now.size(): jump = maxf(jump, now[i].origin.distance_to(last[i].origin))
		last = now
	print("SEQUENCE DETAIL guard ", covered, " rows ", rows, " hits ", hits, " jump=", jump)
	check("native covered jab-cross-hook-body sequence preserves all four inputs", covered > 0.99 and rows == ["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_UPPERCUT"] and hits == 4)
	check("alternating hands and returning guard have no whole-body snap", jump < 0.25 and float(scene.player.get_meta("kinematics")["guard"]) > 0.99)
	fresh(); scene.sim.P["stamina"] = 10
	step({"punch": "R_STRAIGHT"}); tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
	var mid_recovery := false; var busy_at_contact := 0
	for tick in 160:
		for event in step():
			if event.get("kind") == "hit" and event.get("on") == "B": busy_at_contact = scene.sim.P["busy_t"]
		if busy_at_contact > 0 and scene.sim.freeze_t == 0 and scene.sim.P["busy_t"] == busy_at_contact / 2:
			mid_recovery = float(scene.player.get_meta("extension")) > 0.2
	check("tired hands visibly recover for the authored recovery duration", busy_at_contact > 40 and mid_recovery and float(scene.player.get_meta("extension")) == 0)
	# A live boss VM must show the punch which resolves, including string followups.
	fresh(); scene.sim = tests.make_sim(0, 731); tests.place(scene.sim, 1.35)
	scene.sim.P["comp"] = 10000; scene.sim.P["comp_max"] = 10000
	scene.fight_view.clock_sim = null; scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	var contacts := 0; var aligned := true
	for tick in 1000:
		for event in step():
			if event.get("kind") == "boss_act" and event.get("verb") == "punch":
				contacts += 1
				if scene.boss.get_meta("pose_row") != event["row"] or float(scene.boss.get_meta("extension")) < 0.99: print("BOSS CONTACT ", scene.sim.tick, " event ", event, " pose ", scene.boss.get_meta("pose_row"), " extension ", scene.boss.get_meta("extension"), " state ", scene.sim.bstate)
				aligned = aligned and scene.boss.get_meta("pose_row") == event["row"] and float(scene.boss.get_meta("extension")) > 0.99
	check("live boss strings show the resolving hand on every contact", contacts >= 3 and aligned)

func pose_jump(before: Array, after: Array) -> float:
	var largest := 0.0
	for i in before.size(): largest = maxf(largest, before[i].origin.distance_to(after[i].origin))
	return largest

func force_tell(string: String) -> void:
	scene.sim.events.clear(); scene.sim._force_string(string, 1.0, false)
	scene._consume_events(); scene._render(1)

func lifecycle() -> void:
	# Whiffing opponent keeps moving while a real native player key release
	# cancels the player's startup. Cancellation cannot own the other fighter.
	fresh(Sim.BOSSES.find("yuri_kowalchuk")); tests.place(scene.sim, 2.8)
	force_tell("S1"); scene.sim.btimer = 1
	step(); step()
	key(KEY_U, true)
	for i in 6: native_step()
	key(KEY_U, false)
	var events := native_step()
	check("native feint is emitted without a player contact", tests.count_events(events, "feint") == 1 and tests.count_events(events, "hit", {"on": "B"}) == 0)
	check("player feint preserves opponent recovery", scene.boss.get_meta("pose_row") == "R_HOOKERCUT" and float(scene.boss.get_meta("extension")) > 0.1)
	check("player feint retains the cancelled hand for retraction", scene.player.get_meta("pose_row") == "L_HOOK")
	var invented := 0
	for i in 22: invented += tests.count_events(native_step(), "hit", {"on": "B"})
	check("feint finishes its actual recovery without inventing a contact", invented == 0 and scene.player.get_meta("pose_row") == "" and scene.sim.P["busy_t"] == 0)
	for string in ["S1", "S2"]:
		fresh(Sim.BOSSES.find("yuri_kowalchuk")); force_tell(string)
		for i in (24 if string == "S1" else 0): step()
		key(KEY_J, true); var outcome := false; var held := true; var continuing := false
		for i in 55:
			tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
			var was_frozen: bool = scene.sim.freeze_t > 0
			var before := snapshot(scene.boss)
			events = native_step()
			if was_frozen:
				var current := snapshot(scene.boss)
				for part in current.size(): held = held and (before[part] as Transform3D).is_equal_approx(current[part])
			for event in events:
				if event.get("kind") == ("interrupt" if string == "S1" else "unbroken"):
					outcome = true
					continuing = scene.boss.get_meta("pose_row") != "" and float(scene.player.get_meta("extension")) > 0.99
		check(string + " native jab preserves both fighters' motion at " + ("interrupt" if string == "S1" else "unbroken hit"), outcome and continuing)
		check(string + " opponent windup and retraction hold through hitstop", held)
	# Moira's authored low uppercut must wind up below the head, too.
	fresh(Sim.BOSSES.find("moira_macisaac")); force_tell("S3"); var body_seen := false
	for i in 70:
		events = step()
		if scene.sim.bstate == "TELL" and float(scene.boss.get_meta("extension")) > 0.65:
			body_seen = (scene.boss.get_meta("kinematics")["wrists"][1] as Vector3).y < 1.3
		if tests.count_events(events, "boss_act", {"verb": "punch"}) > 0: break
	check("authored body uppercut winds up toward the body", body_seen)
	# Delayed and redirected variants use the actual VM, without modifying
	# source patterns. Setting the variant selects a deterministic remix branch.
	for variant in ["delay", "cancel"]:
		var boss_id := "yuri_kowalchuk" if variant == "delay" else "moira_macisaac"
		fresh(Sim.BOSSES.find(boss_id))
		scene.sim.set_remix(boss_id, boss_id + ".rematch"); scene.sim.new_dual()
		tests.quiet(scene.sim); tests.place(scene.sim, 1.35)
		var string := "S1" if variant == "delay" else "S2"
		force_tell(string); scene.sim.bfeint = variant
		var last := snapshot(scene.boss); var jump := 0.0; var contacts := 0; var aligned := true
		var max_hold_extension := 0.0
		for i in 170:
			events = step()
			var current := snapshot(scene.boss)
			if pose_jump(last, current) > 0.25:
				print("JUMP DETAIL ", variant, " tick ", i, " state ", scene.sim.bstate, " events ", events)
				for j in current.size():
					if current[j].origin.distance_to(last[j].origin) > 0.25: print("VARIANT PART ", j, " from=", last[j].origin, " to=", current[j].origin)
			jump = maxf(jump, pose_jump(last, current)); last = current
			if scene.sim.bstate == "HOLD" and scene.sim.btimer > 20: max_hold_extension = maxf(max_hold_extension, float(scene.boss.get_meta("extension")))
			for event in events:
				if event.get("kind") == "boss_act" and event.get("verb") == "punch":
					contacts += 1; aligned = aligned and scene.boss.get_meta("pose_row") == event["row"] and float(scene.boss.get_meta("extension")) > 0.99
			if i in [20, 40, 52, 58, 64, 72, 90]: await capture("lifecycle-" + variant + "-%02d" % i)
			if contacts >= 1 and scene.sim.freeze_t == 0: break
		print("VARIANT DETAIL ", variant, " max joint jump ", jump, " contacts ", contacts)
		check(variant + " feint has continuous whole-body transition", jump < 0.25)
		check(variant + " feint displays only the resolving hand at contact", contacts >= 1 and aligned)
		if variant == "delay": check("delayed feint does not hold a false contact pose", max_hold_extension < 0.5)
	# A false tell has no eventual hit; its loaded torso still needs recovery.
	fresh(Sim.BOSSES.find("tam_nguyen_roy")); force_tell("S1"); scene.sim.bstate = "FAKE"
	var last := snapshot(scene.boss); var fake_jump := 0.0; var fake_contacts := 0
	for i in 150:
		var was_fake: bool = scene.sim.bstate == "FAKE"
		events = step(); fake_contacts += tests.count_events(events, "boss_act", {"verb": "punch"})
		fake_jump = maxf(fake_jump, pose_jump(last, snapshot(scene.boss))); last = snapshot(scene.boss)
		if was_fake and scene.sim.bstate == "RECOVER": scene.sim.btimer = 1000
	check("false tell retracts its coil without a contact or neutral snap", fake_contacts == 0 and fake_jump < 0.25 and scene.boss.get_meta("pose_row") == "")
	var reference := []
	for hz in [30, 60, 144]:
		fresh(Sim.BOSSES.find("yuri_kowalchuk")); force_tell("S1")
		var replay := []; var render_time := 0.0
		for tick in 240:
			if tick == 2: key(KEY_U, true)
			if tick == 8: key(KEY_U, false)
			if tick == 45: key(KEY_J, true)
			if tick == 75: key(KEY_J, false)
			if tick == 110: key(KEY_Q, true)
			if tick == 130: key(KEY_Q, false)
			native_step()
			while render_time < float(tick + 1) / 120:
				scene._render(fposmod(render_time * 120, 1)); render_time += 1.0 / hz
			replay.append([scene.sim.hash_state(), scene.player.get_meta("kinematics").duplicate(true), scene.boss.get_meta("kinematics").duplicate(true)])
		if reference.is_empty(): reference = replay
		check("native lifecycle replay is identical with %d Hz renders" % hz, replay == reference)

func anatomy() -> void:
	for row in scene.combat_input.ROWS:
		fresh()
		var minimum := [INF, INF, INF, INF]; var maximum := [0.0, 0.0, 0.0, 0.0]
		for tick in 120:
			step({"punch": row} if tick == 0 else {})
			var rig: Dictionary = scene.player.get_meta("kinematics")
			for i in 2:
				var lengths := [(rig["shoulders"][i] as Vector3).distance_to(rig["elbows"][i]), (rig["elbows"][i] as Vector3).distance_to(rig["wrists"][i]), scene.player.get_meta("thighs")[i].scale.y, scene.player.get_meta("legs")[i].scale.y]
				for bone in 4: minimum[bone] = minf(minimum[bone], lengths[bone]); maximum[bone] = maxf(maximum[bone], lengths[bone])
		var fixed := true
		for bone in 4: fixed = fixed and maximum[bone] - minimum[bone] < 0.00001
		print("ANATOMY LENGTHS ", row, " min ", minimum, " max ", maximum)
		check(row + " preserves upper-arm forearm thigh and shin lengths", fixed)

func contacts() -> void:
	# Resolve at the same pose clock as the real contact. This matrix includes
	# both actors, every authored family, body/head, moving targets and the
	# range edges. Native startup travel is covered separately. It does not infer contact from extension == 1.
	for style in ["BOXERPUNCHER", "OUTBOXER", "SWARMER", "SLUGGER"]:
		for body in [false, true]:
			var cases := 0; var bad := []; var worst := 0.0
			for row in scene.combat_input.ROWS:
				for bonus in [0.0]:
					for range_case in ["inside", "edge", "outside"]:
						for dodge in ["", "SLIP", "DUCK", "LEAN", "WEAVE"]:
							for who in ["P", "B"]:
								fresh()
								var attacker: Dictionary = scene.sim.P if who == "P" else scene.sim.B
								var defender: Dictionary = scene.sim.B if who == "P" else scene.sim.P
								attacker["style"] = style
								attacker["pkg"]["reach_mult"] = 0.9 if style == "SWARMER" else 1.0
								attacker["pkg"]["straight_reach_mult"] = 1.12 if style == "OUTBOXER" else 1.0
								var region: Dictionary = scene.sim.contact_region(attacker, defender, row, body, bonus)
								var distance: float = region["reach"] + (-0.45 if range_case == "inside" else (-0.0001 if range_case == "edge" else 0.20))
								attacker["pos"] = Vector2.ZERO; defender["pos"] = Vector2(0, -distance)
								if dodge != "":
									defender["dodge"] = dodge; defender["dodge_t"] = 12; defender["dodge_dir"] = 1
								scene.fight_view.motion_solvers.clear()
								region = scene.sim.contact_region(attacker, defender, row, body, bonus)
								scene.fight_view.strikes[who] = {"tick": scene.sim.tick, "row": row, "body": body, "retract": 24, "range_bonus": bonus}
								var actor: Node3D = scene.player if who == "P" else scene.boss
								scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]; scene._render(1)
								var rig: Dictionary = actor.get_meta("kinematics")
								var hand: Vector3 = rig["wrists"][0 if row.begins_with("L_") else 1]
								var expected := Space.contact(region)
								var error := hand.distance_to(expected)
								worst = maxf(worst, error); cases += 1
								var target := Space.ground(region["target"] - attacker["pos"]) + Vector3.UP * float(region["h"])
								var surface_gap := hand.distance_to(target) - Space.GLOVE_RADIUS - (Space.BODY_RADIUS if body else Space.HEAD_RADIUS)
								var agrees := absf(surface_gap) < 0.001 if region["result"] == "HIT" else surface_gap > 0.00001
								if "capture" in OS.get_cmdline_user_args() and style == "BOXERPUNCHER" and who == "P" and dodge == "" and row in ["R_STRAIGHT", "L_HOOK"] and range_case == "edge":
									await capture("side-contact-" + row.to_lower() + ("-body" if body else "-head") + ("-step" if bonus > 0 else ""))
								if not agrees:
									bad.append([row, bonus, range_case, dodge, who, region["result"], error, surface_gap])
			print("CONTACT MATRIX ", style, " body=", body, " cases=", cases, " worst=", worst, " failures=", bad.size(), " examples=", bad.slice(0, 16))
			check(style + " " + ("body" if body else "head") + " fixed-arm contact matrix", bad.is_empty())

func same_pose(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if not (a[i] as Transform3D).is_equal_approx(b[i]): return false
	return true

func endpoints(part: Node3D, a: Vector3, b: Vector3) -> bool:
	var ok := (part.position - part.basis.y * 0.5).distance_to(a) < 0.0001 and (part.position + part.basis.y * 0.5).distance_to(b) < 0.0001
	if not ok and anatomy_diagnostics < 5:
		print("ATTACHMENT DETAIL ", part, " start=", (part.position - part.basis.y * 0.5).distance_to(a), " end=", (part.position + part.basis.y * 0.5).distance_to(b)); anatomy_diagnostics += 1
	return ok

func rigid_render(actor: Node3D) -> bool:
	var rig: Dictionary = actor.get_meta("render_kinematics")
	for i in 2:
		var lengths := [rig["shoulders"][i].distance_to(rig["elbows"][i]), rig["elbows"][i].distance_to(rig["wrists"][i]), rig["hip_joints"][i].distance_to(rig["knees"][i]), rig["knees"][i].distance_to(rig["ankles"][i])]
		var expected := [Motion.UPPER_ARM, Motion.FOREARM, Motion.THIGH, Motion.SHIN]
		for j in 4:
			if absf(lengths[j] - expected[j]) > 0.00001: return false
		if not endpoints(actor.get_meta("upper_arms")[i], rig["shoulders"][i], rig["elbows"][i]): return false
		if not endpoints(actor.get_meta("arms")[i], rig["elbows"][i], rig["wrists"][i]): return false
		if not endpoints(actor.get_meta("thighs")[i], rig["hip_joints"][i], rig["knees"][i]): return false
		if not endpoints(actor.get_meta("legs")[i], rig["knees"][i], rig["ankles"][i]): return false
		if actor.get_meta("gloves")[i].position.distance_to(rig["wrists"][i]) > 0.00001: return false
		if (actor.get_meta("boots")[i].position + Vector3.UP * 0.03).distance_to(rig["ankles"][i]) > 0.00001: return false
		var forefoot: Vector3 = rig["ankles"][i] - Vector3.UP * 0.095 + (rig["forward"] as Vector3).normalized().rotated(Vector3.UP, float(rig["pivots"][i])) * 0.08
		if forefoot.distance_to(rig["feet"][i]) > 0.00001: return false
	return endpoints(actor.get_meta("abdomen"), rig["pelvis"], actor.get_meta("mesh").position - actor.get_meta("mesh").basis.y * 0.285)

func native_anatomy() -> void:
	for stepping in [false, true]:
		for body in [false, true]:
			var contacts_ok := true; var travel_ok := true; var attached := true; var extended := true
			var landed := 0; var highest_gap := 0.0
			for row in scene.combat_input.ROWS:
				fresh()
				# IDLE still approaches above ENGAGE_DIST. Hold the native VM in
				# its empty ACTING queue so this fixture actually contacts at range.
				scene.sim.bstate = "ACTING"
				var reach: float = scene.sim.contact_region(scene.sim.P, scene.sim.B, row, body)["reach"]
				tests.place(scene.sim, reach + Sim.LUNGE_P + (0.5 if stepping else 0.0) - 0.025)
				scene.fight_view.motion_solvers.clear(); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]; scene._render(1)
				var origin: Vector2 = scene.sim.P["pos"]; var at_start := Vector2.ZERO; var final := Vector2.ZERO
				var start_pending := {}; var elapsed := 0
				for tick in 140:
					var events := step({"punch": row, "body": body, "move": Vector2(0, -1) if stepping else Vector2.ZERO} if tick == 0 else {})
					if tick == 0:
						at_start = scene.sim.P["pos"]; start_pending = scene.sim.P["pending"].duplicate(true)
					tests.clear_defense(scene.sim.B); scene.sim.B["guard_t"] = 0
					for alpha in [0.0, 0.25, 0.5, 0.75, 1.0]:
						scene._render(alpha); attached = attached and rigid_render(scene.player) and rigid_render(scene.boss)
					if stepping and not body and row == "R_STRAIGHT" and tick in [0, 4, 8, 12, 16, 20]:
						await capture("step-sequence-%02d" % tick)
						await capture("side-step-sequence-%02d" % tick)
						await capture("front-step-sequence-%02d" % tick)
					for event in events:
						if event.get("kind") == "hit" and event.get("on") == "B":
							landed += 1; final = scene.sim.P["pos"]; elapsed = tick + 1
							var rig: Dictionary = scene.player.get_meta("kinematics"); var i := 0 if row.begins_with("L_") else 1
							var region: Dictionary = scene.sim.contact_region(scene.sim.P, scene.sim.B, row, body)
							var target := Space.ground(region["target"] - scene.sim.P["pos"] - event.get("displacement", Vector2.ZERO)) + Vector3.UP * float(region["h"])
							var gap := (rig["wrists"][i] as Vector3).distance_to(target) - Space.GLOVE_RADIUS - (Space.BODY_RADIUS if body else Space.HEAD_RADIUS)
							if absf(gap) > 0.001: print("NATIVE GAP ", row, " body=", body, " region=", region, " view=", scene.player.get_meta("contact_region"), " hand=", rig["wrists"][i])
							highest_gap = maxf(highest_gap, absf(gap)); contacts_ok = contacts_ok and absf(gap) < 0.001
							if "STRAIGHT" in row and not body:
								var angle := rad_to_deg((rig["shoulders"][i] - rig["elbows"][i]).angle_to(rig["wrists"][i] - rig["elbows"][i]))
								print("EDGE STRAIGHT ", row, " step=", stepping, " angle=", angle)
								if angle <= 140: print("EDGE POSE shoulder=", rig["shoulders"][i], " wrist=", rig["wrists"][i], " pelvis=", rig["pelvis"], " support=", rig.get("support_shift"), " feet=", rig["feet"], " region=", region)
								extended = extended and angle > 140
							if row in ["R_STRAIGHT", "L_HOOK"]:
								await capture("native-" + row.to_lower() + ("-body" if body else "-head") + ("-step" if stepping else ""))
								await capture("side-native-" + row.to_lower() + ("-body" if body else "-head") + ("-step" if stepping else ""))
								await capture("front-native-" + row.to_lower() + ("-body" if body else "-head") + ("-step" if stepping else ""))
					if elapsed > 0: break
				if stepping:
					travel_ok = travel_ok and bool(start_pending.get("stepping", false)) and is_zero_approx(float(start_pending.get("range_bonus", -1))) and final.distance_to(at_start) > 0.45 and at_start.distance_to(origin) < 0.26
			print("NATIVE CONTACT step=", stepping, " body=", body, " landed=", landed, " gap=", highest_gap)
			check("native " + str([stepping, body]) + " every punch contacts at edge range", landed == 10 and contacts_ok)
			check("native " + str([stepping, body]) + " connected fixed bones at five interpolation phases", attached)
			check("native " + str([stepping, body]) + " step reach is gradual body travel", travel_ok)
			if not body: check("native " + str(stepping) + " edge straights extend while close straights fold", extended)

	fresh(); tests.place(scene.sim, 2.8)
	step({"punch": "L_STRAIGHT", "move": Vector2(0, -1)})
	for i in 3: step()
	var held: Vector2 = scene.sim.P["pos"]; var remaining: float = scene.sim.P["pending"]["step_remaining"]
	scene.sim.freeze_t = 6
	for i in 6: step()
	check("hitstop suspends step-in travel and its remaining distance", scene.sim.P["pos"] == held and scene.sim.P["pending"]["step_remaining"] == remaining)
	var events := step({"punch_release": true})
	var cancelled: Vector2 = scene.sim.P["pos"]
	for i in 12: step()
	check("feint cancels unspent step-in travel", tests.count_events(events, "feint") == 1 and scene.sim.P["pending"].is_empty() and scene.sim.P["pos"] == cancelled)

func planted_movement() -> void:
	# Native key input, actual clamping/separation, fixed-clock poses and the
	# visible interpolated rig. No fake root trajectory or animation-only pawn.
	for style in Motion.STANCES:
		for direction in [KEY_W, KEY_S, KEY_A, KEY_D]:
			fresh(); tests.place(scene.sim, 2.8); scene.sim.P["style"] = style
			scene.fight_view.motion_solvers.clear(); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]; scene._render(1)
			var first_foot := -1; var first_tick := -1; var slip := 0.0; var width := INF; var lead := INF
			var reach := 0.0; var jump := 0.0; var fixed := true; var weighted := false; var last_feet := []; var last_pose := snapshot()
			var opposite: int = {KEY_W: KEY_S, KEY_S: KEY_W, KEY_A: KEY_D, KEY_D: KEY_A}[direction]
			for tick in 180:
				if tick == 0: key(direction, true)
				if tick == 55: key(direction, false); key(opposite, true)
				if tick == 110: key(opposite, false)
				native_step()
				var rig: Dictionary = scene.player.get_meta("kinematics")
				var world := [scene.player.position + rig["feet"][0], scene.player.position + rig["feet"][1]]
				var fwd: Vector3 = rig["forward"]; var right := fwd.cross(Vector3.UP)
				width = minf(width, (world[1] - world[0]).dot(right)); lead = minf(lead, (world[0] - world[1]).dot(fwd))
				for i in 2:
					if first_foot < 0 and world[i].y > 0.002: first_foot = i; first_tick = tick
					if not last_feet.is_empty() and world[i].y < 0.00001 and last_feet[i].y < 0.00001:
						slip = maxf(slip, world[i].distance_to(last_feet[i]))
					reach = maxf(reach, (rig["feet"][i] as Vector3).length())
				last_feet = world
				jump = maxf(jump, pose_jump(last_pose, snapshot())); last_pose = snapshot()
				weighted = weighted or absf(float(rig.get("lead_weight", 0.5)) - 0.5) > 0.12
				for alpha in [0.0, 0.5, 1.0]: scene._render(alpha); fixed = fixed and rigid_render(scene.player)
				if style == "BOXERPUNCHER" and direction == KEY_D and tick in [12, 55, 61, 75, 120]:
					await capture("side-footwork-reversal-%03d" % tick)
			var expected := 0 if direction in [KEY_W, KEY_A] else 1
			var label := str(style) + " " + str({KEY_W: "forward", KEY_S: "retreat", KEY_A: "left", KEY_D: "right"}[direction])
			print("FOOTWORK DETAIL ", label, " first=", first_foot, " at=", first_tick, " width=", width, " lead=", lead, " slip=", slip, " reach=", reach, " jump=", jump)
			check(label + " leads with the travel-side foot promptly", first_foot == expected and first_tick < 12)
			check(label + " reverses and settles without sliding or crossing", slip < 0.0001 and width > 0.12 and lead > 0.035 and reach < 0.72)
			check(label + " transfers support through attached continuous anatomy", weighted and fixed and jump < 0.25)
	# Full circles and rope/corner stops keep the same support rules.
	for location in ["circle", "ropes", "corner"]:
		fresh()
		if location == "circle": tests.place(scene.sim, 1.9)
		else:
			scene.sim.P["pos"] = Vector2(0, 3.4) if location == "ropes" else Vector2(3.3, 3.3)
			scene.sim.B["pos"] = Vector2(0, 1.5) if location == "ropes" else Vector2(1.8, 1.8)
		scene.fight_view.motion_solvers.clear(); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]; scene._render(1)
		var width := INF; var lead := INF; var slip := 0.0; var last := []; var fixed := true; var jump := 0.0; var old := snapshot()
		for tick in 420:
			if tick == 0: key(KEY_D if location == "circle" else KEY_S, true); key(KEY_SPACE, true)
			if tick == 280: key(KEY_D, false); key(KEY_S, false)
			native_step()
			var rig: Dictionary = scene.player.get_meta("kinematics")
			var world := [scene.player.position + rig["feet"][0], scene.player.position + rig["feet"][1]]
			width = minf(width, (world[1] - world[0]).dot(rig["forward"].cross(Vector3.UP)))
			lead = minf(lead, (world[0] - world[1]).dot(rig["forward"]))
			for i in 2:
				if not last.is_empty() and world[i].y < 0.00001 and last[i].y < 0.00001: slip = maxf(slip, world[i].distance_to(last[i]))
			last = world; jump = maxf(jump, pose_jump(old, snapshot())); old = snapshot()
			scene._render(0.5); fixed = fixed and rigid_render(scene.player); scene._render(1)
			if tick in [36, 144, 288] : await capture("side-footwork-" + location + "-%03d" % tick)
		print("BOUNDARY DETAIL ", location, " width=", width, " lead=", lead, " slip=", slip, " jump=", jump)
		check(location + " maintains planted stance under guard", width > 0.12 and lead > 0.035 and slip < 0.0001 and float(scene.player.get_meta("kinematics")["guard"]) > 0.99)
		check(location + " keeps fixed continuous joints through the stop", fixed and jump < 0.25)
	for pair in [[KEY_Q, "SLIP_L"], [KEY_E, "SLIP_R"], [KEY_DOWN, "DUCK"], [KEY_V, "WEAVE"], [KEY_B, "LEAN"]]:
		fresh(); var before: Dictionary = scene.player.get_meta("kinematics").duplicate(true)
		# Head collision remains authoritative while the support carries the torso.
		var fixed := true; var head_agrees := true; var slip := 0.0; var prior := []; var jump := 0.0; var old := snapshot(); var hip_shift := 0.0
		for tick in 90:
			if tick == 0: key(pair[0], true)
			if tick == 1: key(pair[0], false)
			if tick == 55: key(KEY_D, true); key(KEY_SPACE, true)
			native_step()
			var rig: Dictionary = scene.player.get_meta("kinematics")
			var physical: Dictionary = scene.sim._head_world(scene.sim.P, scene.sim.B)
			head_agrees = head_agrees and (scene.player.position + rig["head"]).distance_to(Space.ground(physical["p"]) + Vector3.UP * float(physical["h"])) < 0.0001
			hip_shift = maxf(hip_shift, (rig["pelvis"] as Vector3).distance_to(before["pelvis"]))
			var world := [scene.player.position + rig["feet"][0], scene.player.position + rig["feet"][1]]
			for i in 2:
				if not prior.is_empty() and world[i].y < 0.00001 and prior[i].y < 0.00001: slip = maxf(slip, world[i].distance_to(prior[i]))
			prior = world; jump = maxf(jump, pose_jump(old, snapshot())); old = snapshot()
			for alpha in [0.0, 0.5, 1.0]: scene._render(alpha); fixed = fixed and rigid_render(scene.player)
			if tick in [6, 18, 36]: await capture("side-footwork-" + str(pair[1]).to_lower() + "-%03d" % tick)
		check(str(pair[1]) + " carries defense from planted support into guard and movement", fixed and head_agrees and slip < 0.0001 and hip_shift > 0.04 and jump < 0.25 and float(scene.player.get_meta("kinematics")["guard"]) > 0.99)
	# A single input journey is replayed with different render schedules,
	# including direction changes during a swing and movement into defense.
	var reference := []
	for hz in [30, 60, 144]:
		fresh(); tests.place(scene.sim, 1.9); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]; scene._render(1)
		var render_time := 0.0; var replay := []; var fixed := true; var clear := true; var body_agrees := true; var unchanged := true
		for tick in 360:
			if tick == 0: key(KEY_D, true)
			if tick == 25: key(KEY_D, false); key(KEY_A, true)
			if tick == 33: key(KEY_A, false); key(KEY_D, true)
			if tick == 55: key(KEY_Q, true)
			if tick == 56: key(KEY_Q, false)
			if tick == 100: key(KEY_DOWN, true)
			if tick == 101: key(KEY_DOWN, false)
			if tick == 145: key(KEY_V, true)
			if tick == 146: key(KEY_V, false)
			if tick == 200: key(KEY_B, true)
			if tick == 201: key(KEY_B, false)
			if tick == 250: key(KEY_D, false); key(KEY_SPACE, true)
			native_step()
			var hash_before: int = scene.sim.hash_state()
			while render_time < float(tick + 1) / 120:
				scene._render(fposmod(render_time * 120, 1)); render_time += 1.0 / hz
				fixed = fixed and rigid_render(scene.player)
				var body: Node3D = scene.player.get_meta("mesh")
				var top: Vector3 = body.position + body.basis.y * 0.285
				var head: Vector3 = scene.player.get_meta("head").position
				clear = clear and top.y <= head.y - Space.HEAD_RADIUS - 0.02
			scene._render(1)
			var region: Dictionary = scene.sim.contact_region(scene.sim.B, scene.sim.P, "L_STRAIGHT", true)
			var expected := Space.ground(region["target"] - scene.sim.P["pos"]) + Vector3.UP * float(region["h"])
			var body: Node3D = scene.player.get_meta("mesh")
			body_agrees = body_agrees and absf(body.position.x - expected.x) < 0.0001 and absf(body.position.z - expected.z) < 0.0001 and expected.y >= body.position.y - body.scale.y * 0.285 and expected.y <= body.position.y + body.scale.y * 0.285
			unchanged = unchanged and hash_before == scene.sim.hash_state()
			replay.append([hash_before, scene.player.get_meta("kinematics").duplicate(true), scene.boss.get_meta("kinematics").duplicate(true)])
		if reference.is_empty(): reference = replay
		check("movement-defense replay identical and read-only at %d Hz" % hz, replay == reference and unchanged)
		check("pivots remain anchored and head clears torso at %d Hz" % hz, fixed and clear)
		check("body aim remains on visible crouching torso at %d Hz" % hz, body_agrees)
