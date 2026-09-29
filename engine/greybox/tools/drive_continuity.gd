extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_continuity.gd -- episode
## Bounded scene fixtures; drive_episode independently earns the complete journey.
const Campaign := preload("res://episode/campaign.gd")
var scene: Node
var ep: Node
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition: failures.append(label)
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = down; root.push_input(event)

func _ticks(count: int) -> void:
	for i in count: scene._process(1.0 / 60.0)

func _next() -> void:
	await process_frame
	ep.buttons["next"].grab_focus(); await process_frame
	_key(KEY_ENTER, true); _key(KEY_ENTER, false); await process_frame

func _capture(label: String, black := false) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	await process_frame; await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := "user://continuity-" + label + ".png"
	_check("capture " + label, picture.save_png(path) == OK); captures.append(path)
	if black:
		var dark := true
		for x in range(0, picture.get_width(), 16):
			for y in range(0, picture.get_height(), 16):
				var pixel := picture.get_pixel(x, y)
				dark = dark and maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.01
		_check("entire rendered cut is black " + label, dark)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	ep = scene.episode; scene.club_flow.set_process(false); await process_frame
	_check("automated output uses Dummy and muted Master", AudioServer.get_driver_name() == "Dummy" and AudioServer.is_bus_mute(0))
	for language in ["en", "fr_CA"]:
		root.size = Vector2i(1280, 720) if language == "en" else Vector2i(960, 600)
		ep.new_episode(language)
		scene.sim = Campaign.present(scene.content, scene.sim)
		ep._ep()["dialogue"] = ""; ep._ep()["line"] = 0; ep.pending.clear()
		ep._training("shadow", true); ep.transition_t = 0
		_ticks(18)
		var breath = ep.staging.breath
		var coach: Node3D = ep.world.cast["WHITLOCK"]
		_check("entrance begins during live shadow boxing " + language, ep.state == "training" and coach.visible and not ep.staging.coach_entered and not ep.panel.visible)
		_check("breath is emitted beside Rory's mouth " + language, breath.puffs[0].visible and breath.puffs[0].global_position.distance_to(ep.world.actor.get_meta("head").global_position) < 0.65)
		_ticks(72); await _capture(language + "-entrance")
		var at: Vector3 = coach.position; var age: float = breath.ages[0]; var tick: int = scene.sim.tick
		scene.controls_menu.open(); _ticks(90)
		_check("controls freeze entrance, breath and boxing " + language, coach.position == at and breath.ages[0] == age and scene.sim.tick == tick)
		scene.controls_menu.close()
		_ticks(130)
		_check("coach arrives holding an opened envelope " + language, ep.staging.coach_entered and coach.position.distance_to(Vector3(-1.5, 0, 2.8)) < 0.001 and ep.staging.envelope.is_visible_in_tree() and ep.staging.envelope.get_child(0).rotation.x > 0)
		_check("entrance grants no shadow credit " + language, ep.training["accepted"] == 0 and ep.staging.coach_watched == 0 and not Campaign.has(scene.sim, "shadow"))
		ep.save_episode(); var before: int = scene.sim.hash_state(); ep.load_episode()
		_check("live shadow save restores exact simulation " + language, scene.sim.hash_state() == before and ep.state == "training")
		_ticks(1)
		_check("loaded entrance keeps the coach at his arrived position " + language, ep.staging.coach_entered and coach.position.distance_to(Vector3(-1.5, 0, 2.8)) < 0.001)
		while ep.transition_t > 0: _ticks(1)
		# Actual accepted inputs, not forged punch events or training credits.
		for attempt in 30:
			if int(ep.training["accepted"]) >= 6: break
			var code: int = [KEY_J, KEY_K, KEY_U, KEY_I, KEY_Y, KEY_O][int(ep.training["index"]) % 6]
			_key(code, true); _ticks(20); _key(code, false); _ticks(10)
		_check("coach watches a complete native combination " + language, ep.staging.coach_watched > 0 and ep.training["accepted"] == 6 and scene.sim.tick > tick)
		_check("watching does not skip the shadow round " + language, ep.state == "training" and not Campaign.has(scene.sim, "shadow"))
		# Wait for a natural visible exhalation in the moving, live scene.
		for safety in 150:
			if breath.ages[(breath.cursor - 3) % 12] < 0.2: break
			_ticks(1)
		_ticks(30); await _capture(language + "-watching")
		var puff: MeshInstance3D = breath.puffs[(breath.cursor - 3) % 12]
		at = puff.global_position; var emitted: int = breath.emitted
		_ticks(12)
		_check("breath drifts independently after emission " + language, puff.global_position != at and breath.emitted == emitted)
		ep._dialogue("archive"); _ticks(1)
		_check("archive has no present-day breath " + language, breath.puffs.all(func(p): return not p.visible))
		ep._training("shadow", true); _ticks(20); ep._title(); _ticks(1)
		_check("title clears scene atmosphere and envelope " + language, breath.puffs.all(func(p): return not p.visible) and not ep.staging.envelope.is_visible_in_tree())
		# Explicit earned-state fixture, separate from the unseeded full journey.
		ep.new_episode(language); scene.sim = Campaign.present(scene.content, scene.sim)
		_check("new episode clears the previous coaching session " + language, ep.training.is_empty() and ep.pending.is_empty() and not ep._ep().has("training"))
		ep._closing_wall()
		_check("an unearned charter cannot enter the closing shot " + language, ep.state != "outro" and not ep._ep().has("closing_wall"))
		for flag in ["letter", "scrap_1", "priya_trial", "scrap_2", "scrap_3", "survival"]: Campaign.mark(scene.sim, flag)
		for name in ["PRIYA", "MARCUS", "JUNE"]: Campaign.join(scene.sim, name)
		ep._ep()["metrics"]["bouts"].append({"fight":"survival", "won":true, "segment_wins":2})
		ep._show_world(); ep.world.sync(scene.sim); ep._dialogue("tag")
		for i in 10:
			if ep.state != "dialogue": break
			while ep.freeze_t > 0: _ticks(1)
			await _next()
		_check("last authored native Continue reaches wall composition " + language, ep.state == "outro" and not ep.panel.visible and not ep.quest.visible and ep.transition_t == 0)
		_check("wall carries letter, carbon and all four earned cards " + language, ep.world.cards.get_children().filter(func(c): return c.name.begins_with("card_")).size() == 4 and ep.world.cards.has_node("charter") and ep.world.cards.has_node("letter"))
		_check("closing save validates " + language, Campaign.validate(ep._ep()) == "")
		await _capture(language + "-wall")
		tick = scene.sim.tick; _ticks(40)
		_check("wall remains visible before cut " + language, not ep.staging.black.visible and ep.state == "outro")
		ep.save_episode(); before = scene.sim.hash_state(); ep.load_episode()
		_check("closing reload preserves exact sim and safely restarts composition " + language, scene.sim.hash_state() == before and ep.state == "outro" and ep.transition_t == 0 and ep.freeze_t == 1.2)
		_ticks(54)
		_check("black precedes the end card " + language, ep.staging.black.visible and not ep.panel.visible and ep.state == "outro" and scene.sim.tick == tick)
		await _capture(language + "-black", true)
		var remaining: float = ep.freeze_t
		scene.controls_menu.open(); _ticks(90)
		_check("controls pause the closing cut " + language, ep.freeze_t == remaining and scene.sim.tick == tick)
		scene.controls_menu.close(); _ticks(30)
		_check("end card remains on black without moving boxing " + language, ep.state == "complete" and ep.panel.visible and ep.staging.black.visible and scene.sim.tick == tick and not ep._ep().has("closing_wall"))
		await _capture(language + "-end-card")
		ep.load_episode()
		_check("completed save restores black end card " + language, ep.state == "complete" and ep.staging.black.visible)
		var bad: Dictionary = ep._ep().duplicate(true); bad["closing_wall"] = "true"
		_check("reject malformed closing marker " + language, Campaign.validate(bad) != "")
		bad["closing_wall"] = true
		_check("reject marker on wrong scene " + language, Campaign.validate(bad) != "")
		ep._world(); _ticks(15)
		_check("return to gym clears black and restores breathing " + language, not ep.staging.black.visible and ep.state == "world" and breath.puffs.any(func(p): return p.visible))
	_check("Master stays muted", AudioServer.is_bus_mute(0))
	var file := FileAccess.open("user://continuity-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "captures":captures, "scope":"Native punch/Continue input within explicit scene fixtures. Earned progression is separately checked by drive_episode. No physical input-to-photon or final art/animation acceptance."}, "  ")); file.close()
	print("CONTINUITY ", checks, " checks; ", failures.size(), " failures")
	print("DRIVE :: GREEN" if failures.is_empty() else "DRIVE :: RED")
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
