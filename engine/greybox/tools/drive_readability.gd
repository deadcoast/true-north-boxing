extends SceneTree
## PAC-201: real scene entry/input and presentation geometry, no sim tuning changes.
## godot --headless --path engine/greybox -s tools/drive_readability.gd -- welcome
## Omit --headless and add capture to retain actual GPU-rendered frames.
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
var scene: Node
var checks := 0
var failures: Array[String] = []
var tests := Tests.new()
var camera_samples: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = pressed; root.push_input(event)

func capture(name: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	await process_frame; await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png("user://" + name + ".png")
	check("render saved " + name, err == OK)

func frame_at(distance: float, angle: float, center := Vector2.ZERO) -> bool:
	var forward := Vector2(sin(angle), cos(angle))
	scene.sim.P["pos"] = center + forward * distance * 0.5
	scene.sim.B["pos"] = center - forward * distance * 0.5
	scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.fight_view.orbit = Vector3.ZERO; scene.fight_view.last_tick = -1
	scene._render(1.0); scene._hud()
	var head: Vector2 = scene.cam.unproject_position(scene.boss.position + Vector3.UP * 1.9)
	var feet: Vector2 = scene.cam.unproject_position(scene.boss.position)
	var size := root.get_visible_rect().size
	var player_head: Vector2 = scene.cam.unproject_position(scene.player.global_position + scene.player.get_meta("head").position + Vector3.UP * .18)
	var player_feet: Vector2 = scene.cam.unproject_position(scene.player.global_position)
	camera_samples.append({"viewport":str(size),"distance_m":distance,"angle_rad":angle,"center":str(center),"pitch_deg":rad_to_deg(-scene.cam.rotation.x),"fov_deg":scene.cam.fov,"chase_m":Vector2(scene.cam.position.x-scene.player.position.x,scene.cam.position.z-scene.player.position.z).length(),"player_projected_height_pct":absf(player_feet.y-player_head.y)/size.y*100,"player_visible_height_pct":(clampf(player_feet.y,0,size.y)-clampf(player_head.y,0,size.y))/size.y*100})
	# The center scorebug ends at y=90; side resource panels do not cross it.
	var clear: bool = head.y > 100 and feet.y < size.y - 112 and absf(head.x - size.x * 0.5) < 1.0
	if not clear: print("PROJECTION head=%s feet=%s viewport=%s" % [head, feet, size])
	return clear

func _run() -> void:
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	# These full-body/framing/clearance assertions specify the retained chase
	# observer. drive_foundation exercises the default embodied camera.
	scene.fight_view.observer_view = true
	await process_frame
	scene.controls_menu.close()
	check("launch waits for a deliberate first bell", scene.fight_hud.entry.visible)
	var before: int = scene.sim.hash_state()
	scene._process(5.0)
	check("entry does not advance sim or clock", scene.sim.hash_state() == before and scene.clock.acc == 0)
	check("entry has keyboard focus", scene.fight_hud.start_button.has_focus())
	await capture("entry-1280x720")
	key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
	check("controls can open before the bell", scene.controls_menu.opened)
	scene.controls_menu.close()
	check("closing controls restores entry focus", scene.fight_hud.start_button.has_focus())
	scene.fight_hud.controls_button.grab_focus(); key(KEY_TAB, true); key(KEY_TAB, false)
	check("entry focus stays in its controls", scene.fight_hud.start_button.has_focus())
	# Real native UI activation, then verify the same key did not leak into combat.
	key(KEY_ENTER, true); key(KEY_ENTER, false); await process_frame
	check("Enter activates focused Fight button", not scene.fight_hud.entry.visible)
	check("bell input does not become a punch", not scene._intent().has("punch"))
	scene._process(1.0 / 60.0)
	check("fight advances after explicit start", scene.sim.tick == 2)
	key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
	before = scene.sim.hash_state(); scene._process(5.0)
	check("controls pause live fight", scene.controls_menu.opened and scene.sim.hash_state() == before)
	scene.controls_menu.close()
	scene.fight_hud.show_entry(); scene.fight_hud.practice_button.grab_focus()
	key(KEY_ENTER, true); key(KEY_ENTER, false); await process_frame
	check("Practice is accessible by keyboard", scene.practice_dummy and not scene.fight_hud.entry.visible)
	check("practice setting and menu agree", scene.controls_menu.practice.button_pressed)
	scene._process(0.1)
	check("dummy does not attack", scene.sim.bpending.is_empty() and scene.sim.bstate == "IDLE")
	scene.set_practice(false)
	check("leaving practice restores live opponent", not scene.practice_dummy and scene.practice_restore.is_empty())
	for viewport in [Vector2i(1280, 720), Vector2i(960, 600)]:
		root.size = viewport; await process_frame
		for distance in [0.7, 1.0, 1.5, 2.0, 4.0, 7.0]:
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				check("full body %s distance %.1f angle %.1f" % [viewport, distance, angle], frame_at(distance, angle))
		check("corner full body %s" % viewport, frame_at(0.7, PI * 0.25, Vector2(3, 3)))
		var boundaries := 0
		for boundary in scene.ring_boundaries:
			if boundary.material_override != null and boundary.material_override.get_shader_parameter("foreground_only"): boundaries += 1
		check("all corner boundaries use per-fragment foreground clearance %s" % viewport, boundaries == 16)
		if viewport.x == 1280: await capture("close-corner-1280x720")
		scene.sim = tests.make_sim(1, 12345); frame_at(1.5, 0)
		scene.sim._force_string("S1", 1, true); scene._consume_events(); scene._render(1); scene._hud()
		check("neutral HUD leaves details closed", not scene.fight_hud.details.visible)
		await capture("windup-%dx%d" % [viewport.x, viewport.y])
		root.size = viewport; scene.fight_hud.show_entry(); await process_frame
		check("entry stays inside viewport %s" % viewport, Rect2(Vector2.ZERO, Vector2(viewport)).encloses(scene.fight_hud.entry.get_global_rect()))
		if viewport.x == 960: await capture("entry-960x600")
		scene.fight_hud.dismiss_entry()
	root.size = Vector2i(1280, 720); await process_frame
	for row in scene.sim.T["punch_matrix"]:
		scene.sim.P["pending"] = {"row": row, "t": 1, "startup": 60, "mods": []}
		before = scene.sim.hash_state(); scene._render(1)
		var hand := 0 if str(row).begins_with("L_") else 1
		var direction: Vector2 = (scene.sim.B["pos"] - scene.sim.P["pos"]).normalized()
		var forward := Vector3(direction.x, 0, direction.y)
		var gloves: Array = scene.player.get_meta("gloves")
		check("correct attacking hand " + str(row), gloves[hand].position.dot(forward) > gloves[1 - hand].position.dot(forward) + 0.4 and before == scene.sim.hash_state())
	scene.sim.P["pending"] = {}
	scene.fight_view.orbit = Vector3(0, 0, 1); scene.fight_view.last_tick = scene.sim.tick
	var orbit_ok := true
	for index in 120:
		var previous: Vector3 = scene.fight_view.orbit
		var angle := deg_to_rad(float(index) * 0.375)
		scene.sim.P["pos"] = Vector2(sin(angle), cos(angle)) * 2
		scene.sim.B["pos"] = Vector2.ZERO
		scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
		scene.sim.tick += 1; scene._render(1)
		orbit_ok = orbit_ok and previous.angle_to(scene.fight_view.orbit) <= deg_to_rad(70.0 / 120.0) + 0.0001
	check("ordinary orbit respects its presentation cap", orbit_ok)
	for boss in Sim.BOSSES.size():
		scene.sim = tests.make_sim(boss, 12345); frame_at(1.5, 0)
		var all_ok := true
		for string in scene.sim.pattern["strings"]:
			scene.sim._force_string(string, 1.0, false)
			before = scene.sim.hash_state(); scene._render(1.0)
			all_ok = all_ok and scene.boss.get_meta("windup") and scene.sim.hash_state() == before
			var row: String = scene.boss.get_meta("pose_row")
			all_ok = all_ok and (row == "" or row in scene.sim.T["punch_matrix"])
		check("every string poses without changing sim: " + scene.sim.boss_name, all_ok)
	scene.sim = tests.make_sim(1, 12345); frame_at(1.5, 0)
	scene.sim._force_string("S1", 1.0, true); scene._consume_events(); scene._render(1)
	var loaded: Vector3 = scene.boss.get_meta("gloves")[1].position
	scene.sim.bstate = "SEQ"
	scene.fight_view.observe({"kind": "boss_act", "verb": "punch", "row": "R_STRAIGHT"}, scene.sim.tick)
	scene._render(1)
	check("contact pose differs from windup", scene.boss.get_meta("gloves")[1].position.distance_to(loaded) > 0.4)
	check("contact is visibly extended", scene.boss.get_meta("extension") == 1.0)
	scene._hud(); await capture("contact-1280x720")
	scene.sim.tick += 30; scene._render(1)
	check("glove recovers on sim time", scene.boss.get_meta("extension") == 0.0)
	scene.sim._end_segment("presentation check")
	for tick in 600:
		if scene.sim.mode == "CORNER": break
		scene.sim.step({})
	scene._hud()
	check("existing corner actions stay accessible", scene.fight_hud.details.visible and scene.hud.text.contains("CORNER"))
	scene.fight_hud.detail_button.pressed.emit(); scene._hud()
	check("Hide details works during a corner", not scene.fight_hud.details.visible)
	scene.fight_hud.detail_button.pressed.emit(); scene._hud()
	check("corner details reopen without losing actions", scene.fight_hud.details.visible)
	scene.sim.mode = "FIGHT"; scene._hud()
	check("details close when fighting resumes", not scene.fight_hud.details.visible)
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss pauses fight", scene.controls_menu.opened)
	var report := FileAccess.open("user://camera-observations.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"samples":camera_samples,"scope":"Measurements of production projection; existing framing checks establish opponent/HUD containment, not NP-03 fixed pitch, chase or compact-player compliance."},"  ")); report.close()
	print("VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
