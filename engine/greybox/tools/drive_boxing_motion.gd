extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_boxing_motion.gd -- welcome
## Mechanical motion evidence, not boxing authenticity or player-fun acceptance.
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
var tests := Tests.new()
var scene: Node
var checks := 0
var failures := []
var trace := []
var keys := {}

func _initialize() -> void: _run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh() -> void:
	for code in keys.keys(): key(code, false)
	scene.combat_input.clear()
	scene.sim = tests.make_sim(0, 731); tests.quiet(scene.sim); tests.place(scene.sim, 1.35)
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

func snapshot() -> Array:
	var result := []
	for part in scene.player.get_children():
		if part is Node3D: result.append(part.transform)
	return result

func capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	var materials := {}
	if label.begins_with("side-"):
		scene.cam.position = scene.player.position + Vector3(3.7, 1.8, 1.1)
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
			for i in current.size(): jump = maxf(jump, current[i].origin.distance_to(last[i].origin))
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
		check(row + " connects the ground, hips, trunk, elbow and fist", foot_pivot > 0.15 and hip_turn > 0.05 and shoulder_roll > 0.03 and moving and fist_turn > 0.1)
		check(row + " visible contact matches the resolving tick", reached and pose_at_hit)
		if "HOOK" in row or "UPPER" in row: check(row + " keeps the elbow bent through delivery", delivery_angle > 70 and delivery_angle < 120)
		elif "STRAIGHT" in row: check(row + " extends the arm through delivery", delivery_angle > 145)
		check(row + " full rig holds through hitstop", stopped)
		check(row + " has no one-tick neutral snap", jump < 0.25)
	# Dodge entry, held pose, exit: inspect the actual rendered head and resolver.
	for dodge in ["SLIP_L", "SLIP_R", "DUCK", "WEAVE_L", "WEAVE_R", "LEAN"]:
		fresh(); var previous: Vector3 = scene.player.get_meta("head").position
		var max_jump := 0.0; var agreed := true; var peak := 0.0
		for tick in 70:
			step({"dodge": dodge} if tick == 0 else {})
			var head: Vector3 = scene.player.get_meta("head").position
			max_jump = maxf(max_jump, previous.distance_to(head)); previous = head
			var physical: Dictionary = scene.sim._head_world(scene.sim.P, scene.sim.B)
			var world: Vector3 = scene.player.position + head
			agreed = agreed and Vector2(world.x, world.z).distance_to(physical["p"]) < 0.0001 and absf(world.y - float(physical["h"])) < 0.0001
			peak = maxf(peak, head.distance_to(Vector3.UP * Sim.HEAD_H))
		check(dodge + " renders the same moving target used by collision", agreed and peak > 0.2)
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
	check("extra render frames neither advance motion nor alter combat", scene.sim.hash_state() == before and snapshot() == old_pose)
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
	print("SEQUENCE DETAIL guard ", covered, " rows ", rows, " hits ", hits)
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
