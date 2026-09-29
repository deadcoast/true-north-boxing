extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_episode.gd -- episode
## Native input through the production episode. No planted story flags, forced
## verdicts, seeded wallets or direct progression calls. Simulated time is explicit.
var scene: Node
var episode: CanvasLayer
var keys := {}
var checks := 0
var failures: Array[String] = []
var journal: Array = []
var captures: Array = []
var gpu := false
var frame := 0
var started := 0
var saved_in_fight := false
var performance_samples: Array = []
var saved_at_verdict := false
var saved_at_glove := false

func _initialize() -> void: _run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _key(code: int, down: bool) -> void:
	if bool(keys.get(code, false)) == down: return
	keys[code] = down
	var e := InputEventKey.new(); e.keycode = code; e.pressed = down; root.push_input(e)

func _held(wanted: Array) -> void:
	for code in keys.keys():
		if not code in wanted: _key(code, false)
	for code in wanted: _key(code, true)

func _tick() -> void:
	scene._process(1.0 / 60.0); frame += 1

func _press(id: String) -> bool:
	_held([])
	# Let page construction's deferred default focus finish before selecting.
	await process_frame
	var available: bool = episode.buttons.has(id) and is_instance_valid(episode.buttons[id]) and not episode.buttons[id].disabled
	_check("native episode action: " + id, available)
	if not available: return false
	episode.buttons[id].grab_focus(); await process_frame
	_key(KEY_ENTER, true); _key(KEY_ENTER, false); await process_frame
	return true

func _capture(label: String) -> void:
	if episode.state == "world": _tick()
	journal.append({"label":label, "state":episode.state, "phase":episode._ep().get("phase", ""), "tick":scene.sim.tick, "position":episode.world.point(), "flags":episode._ep().get("flags", {}).duplicate(), "stable":scene.sim.stable.map(func(c): return c["name"]), "ledger":scene.sim.rewards.duplicate(true)})
	if not gpu: return
	await process_frame; await RenderingServer.frame_post_draw
	var path := "user://episode-" + label + ".png"
	_check("rendered " + label, root.get_texture().get_image().save_png(path) == OK); captures.append(path)

func _render_sample(label: String) -> void:
	if not gpu: return
	var frames: Array[float] = []; var cpu: Array[float] = []
	var previous := Time.get_ticks_usec()
	# Continuous real renderer frames, separate from the accelerated journey.
	# Warm up scene upload before measuring; no supplied 1/60 delta is a sample.
	for i in 210:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - previous) / 1000.0
		previous = now
		var work := Time.get_ticks_usec()
		_held(_policy() if episode.state == "fight" else [])
		scene._process(minf(elapsed / 1000.0, 0.1)); frame += 1
		if i >= 30: frames.append(elapsed); cpu.append((Time.get_ticks_usec() - work) / 1000.0)
	_held([]); frames.sort(); cpu.sort()
	performance_samples.append({"scene":label, "frames":frames.size(), "render_interval_ms_p50":frames[90], "render_interval_ms_p95":frames[171], "render_interval_ms_max":frames[-1], "main_process_ms_p95":cpu[171], "adapter":RenderingServer.get_video_adapter_name(), "viewport":str(root.size), "method":"Continuous process_frame wall clock after 30 warm-up frames; 180 measured frames. Not physical input-to-photon."})

func _dialogue() -> void:
	for safety in 60:
		if episode.state != "dialogue": return
		var shot: String = episode.staging.shot
		var before_tick: int = scene.sim.tick
		if shot == "archive:1":
			_check("the missing name mutes a real tape audio stream", episode.staging.ambience.stream_paused and episode.staging.sound_hole)
		if shot in ["letter:3", "letter:11", "tag:0", "tag:2"]:
			var first: Vector3 = episode.staging.paper.position
			for i in 45: _tick()
			_check("authored shot pauses combat: " + shot, scene.sim.tick == before_tick)
			if shot.begins_with("letter:"):
				_check("letter is physically moved: " + shot, episode.staging.paper.position != first)
			await _capture("shot-" + shot.replace(":", "-"))
			if shot == "tag:2":
				for i in 310: _tick()
				_check("Priya carries the carbon copy to its permanent wall position", episode.staging.paper.position.distance_to(Vector3(-4.7, 1.6, -5.18)) < 0.01)
				_check("June straightens her own persistent card", absf(episode.world.cards.get_node("card_JUNE").rotation.z) < 0.001)
				await _capture("carbon-pinned")
		if shot == "present:0":
			_check("present glove matches the archive camera", episode.world.camera.global_transform.is_equal_approx(episode.staging.archive_camera) and episode.world.camera.fov == 40)
			_check("present holds the same raised glove", episode.world.actor.get_meta("gloves")[1].position.y > 2.0)
			await _capture("match-cut")
		while episode.freeze_t > 0: _tick()
		if shot == "letter:11": _check("Whitlock folds the sheet before pinning it", is_equal_approx(episode.staging.fold.rotation.z, PI))
		if shot == "letter:11": await _capture("letter-pinned")
		if shot == "tag:0":
			_check("observer signs the original and separates the handed-over carbon", episode.staging.signature.scale.x == 1 and episode.staging.paper.position.distance_to(episode.staging.form.position) > 0.5)
		if shot == "present:0":
			_check("match cut transfers automatically to live shadow boxing", episode.state == "training" and episode.handoff_t >= 0 and not episode.panel.visible)
			_check("shadow boxing keeps the gym visible without a competition overlay", not scene.get_meta("arena").visible and not scene.fight_hud.visible and not scene.boss.visible)
			var t: float = episode.handoff_t; var tick: int = scene.sim.tick
			_key(KEY_ESCAPE, true); _key(KEY_ESCAPE, false)
			for i in 15: _tick()
			_check("controls pause both handoff and combat", scene.controls_menu.opened and episode.handoff_t == t and scene.sim.tick == tick)
			_key(KEY_ESCAPE, true); _key(KEY_ESCAPE, false)
			for i in 3: _tick()
			_check("idle handoff grants no punches or lesson credit", episode.training["accepted"] == 0 and not episode._ep()["flags"].get("shadow", false))
			_held([KEY_J])
			for i in 6: _tick()
			_held([])
			_check("a real jab is accepted while the camera is still blending", episode.handoff_t >= 0 and episode.training["accepted"] > 0)
			_check("live shadow boxer retains Rory's opaque world identity", episode.world.actor.visible and not scene.player.visible and episode.world.actor.global_transform.is_equal_approx(scene.player.global_transform))
			await _capture("live-shadow-handoff")
			_key(KEY_F10, true); _key(KEY_F10, false)
			var accepted: int = episode.training["accepted"]
			episode.load_episode()
			_check("continue restores earned shadow punches without replaying the handoff", episode.state == "training" and episode.training["accepted"] == accepted and episode.handoff_t < 0)
			return
		if shot == "archive:1": _check("tape sound hole lasts exactly a second", is_equal_approx(episode.staging.sound_hole_seconds, 1.0) and not episode.staging.ambience.stream_paused)
		if not await _press("next"): return
	_check("dialogue has a finite authored end", false)

func _walk(to: Vector2) -> void:
	var before: Vector3 = episode.world.actor.position
	var fight_tick: int = scene.sim.tick
	for step in 2400:
		if episode.state != "world": break
		if episode.transition_t > 0: _held([]); _tick(); continue
		var at := Vector2(episode.world.actor.position.x, episode.world.actor.position.z)
		var diff := to - at
		if diff.length() < 0.3: break
		var wanted: Array = [KEY_SHIFT]
		if absf(diff.x) > 0.16: wanted.append(KEY_D if diff.x > 0 else KEY_A)
		if absf(diff.y) > 0.16: wanted.append(KEY_S if diff.y > 0 else KEY_W)
		_held(wanted); _tick()
		if step % 180 == 0: await process_frame
	_held([])
	for i in 12: _tick()
	_check("walk reaches %s using native movement" % str(to), Vector2(episode.world.actor.position.x, episode.world.actor.position.z).distance_to(to) < 0.75)
	_check("walking never steps the fight clock", scene.sim.tick == fight_tick and (episode.world.actor.position != before or Vector2(before.x, before.z).distance_to(to) < 0.75))

func _interact(id: String) -> void:
	_held([]); _tick(); await process_frame
	_check("physical interaction target " + id, episode.world.nearest == id)
	_key(KEY_E, true); _key(KEY_E, false); _tick(); await process_frame

func _policy() -> Array:
	var s = scene.sim
	var timing: Dictionary = scene.fight_feedback.timing_state(s)
	if not timing.is_empty():
		if not timing["open"] or timing["locked"]: return []
		return [KEY_ENTER] if s.mode == "EIGHT" else [KEY_A if timing["label"] == "LEFT" else KEY_D]
	if s.mode == "CARD": return [KEY_1] if frame % 20 < 10 else []
	if s.mode != "FIGHT": return []
	var wanted: Array = []
	var distance: float = s.P["pos"].distance_to(s.B["pos"])
	var fight: String = episode._ep().get("fight", "")
	var threat: bool = s.bstate in ["TELL", "HOLD"] and s.btimer <= 10 or (s.bstate == "ACTING" and not s.bqueue.is_empty() and s.bqueue[0].get("kind") == "punch" and s.btimer <= 10)
	if distance > 1.2: wanted.append(KEY_W)
	if fight == "archive":
		var lesson: int = episode._ep().get("lesson", 0)
		if lesson == 0:
			if frame % 50 < 30: wanted.append(KEY_J)
		elif lesson == 1:
			if s.P["counter_t"] > 0: wanted.append(KEY_J if frame % 16 < 8 else KEY_K)
			elif not s.P["pending"].is_empty(): wanted.append(KEY_J if s.P["pending"].get("row") == "L_STRAIGHT" else KEY_K)
			elif threat: wanted.append(KEY_Q if frame % 24 < 12 else KEY_E)
		elif lesson == 2:
			if threat: wanted.append(KEY_SPACE)
		elif lesson >= 3 and s.tension >= 100:
			wanted.append(KEY_H); wanted.append(KEY_ALT)
			if frame % 60 > 20: wanted.append(KEY_N if frame % 120 < 60 else KEY_SEMICOLON)
		else:
			if frame % 50 < 25: wanted.append(KEY_J)
			elif frame % 50 < 48: wanted.append(KEY_K)
		return wanted
	if float(s.P["stamina"]) < 25: return [KEY_S] if distance < 2.8 else []
	if fight == "scrap_1":
		wanted.append(KEY_C)
		if frame % 50 < 25: wanted.append(KEY_J)
		elif frame % 50 < 48: wanted.append(KEY_K)
	elif threat: wanted.append(KEY_SPACE)
	elif frame % 55 < 28:
		wanted.append(KEY_J if frame / 55 % 2 == 0 else KEY_K)
		wanted.append(KEY_SHIFT); wanted.append(KEY_C)
	return wanted

func _fight(max_seconds: int) -> void:
	var label: String = episode._ep().get("fight", "")
	var last_lesson := -1
	for i in max_seconds * 60:
		if episode.state == "dialogue" and episode._ep().get("dialogue") == "vane": await _capture("vane-introduction"); await _dialogue()
		if not episode.state in ["fight", "corner", "freeze"]: break
		if episode.state == "freeze" and not saved_at_glove:
			saved_at_glove = true; _held([])
			_key(KEY_F10, true); _key(KEY_F10, false)
			# Invoke the same public Continue handler for this precise save boundary.
			episode.load_episode()
			while episode.transition_t > 0: _tick()
			_tick()
			_check("Continue during the raised glove retains the earned DROP transition", episode.state == "freeze" and not episode.archive_drop.is_empty())
		if episode.transition_t > 0: _held([]); _tick(); continue
		if label == "priya_trial" and scene.sim.mode == "OVER" and not saved_at_verdict:
			saved_at_verdict = true; _held([])
			_key(KEY_TAB, true); _key(KEY_TAB, false); await process_frame
			await _press("save"); await _press("load")
			_check("save at the final bell retains unconsumed story events", not episode.pending.is_empty())
		if episode.state == "corner":
			await _capture("corner-" + str(scene.sim.seg_idx))
			if int(scene.sim.corner["actions_left"]) > 0: await _press("talk:plan" if scene.sim.seg_idx == 0 else "talk:fire")
			else: _check("locked corner explains the real crowd rule", scene.sim.corner.get("locked", false))
			await _press("send")
		if label == "survival" and i > 100 and not saved_in_fight and episode.state == "fight" and scene.sim.mode == "FIGHT":
			saved_in_fight = true; _held([])
			_key(KEY_TAB, true); _key(KEY_TAB, false); await process_frame
			await _press("save")
			var hash_before: int = scene.sim.hash_state(); var tick_before: int = scene.sim.tick
			var state_before := {}
			for name in scene.sim.state_vars(): state_before[name] = var_to_bytes(scene.sim.get(name))
			await _press("load")
			_check("in-flight save restores exact simulation hash and tick", scene.sim.hash_state() == hash_before and scene.sim.tick == tick_before)
			if scene.sim.hash_state() != hash_before:
				for name in state_before:
					if state_before[name] != var_to_bytes(scene.sim.get(name)):
						print("SAVE DIFF ", name, " before bytes hash ", hash(state_before[name]), " after bytes hash ", hash(var_to_bytes(scene.sim.get(name))))
		_held(_policy()); _tick()
		if label == "archive" and episode._ep().get("lesson", 0) == 0:
			for event in episode.pending:
				if event.get("kind") == "hit" and event.get("on") == "B": print("ARCHIVE HIT ", event.get("row"), " frame ", frame)
		if label == "archive" and int(episode._ep().get("lesson", 0)) != last_lesson:
			last_lesson = int(episode._ep().get("lesson", 0)); print("ARCHIVE LESSON ", last_lesson, " tick ", scene.sim.tick, " tension ", scene.sim.tension)
		if label == "archive" and episode._ep().get("lesson", 0) >= 3 and frame % 60 == 20: await create_timer(0.17).timeout
		if i % 600 == 0: await process_frame
	_held([]); _tick(); await process_frame
	await _capture(label + "-result")

func _lose_survival() -> void:
	for i in 400 * 60:
		if episode.state == "dialogue" and episode._ep().get("dialogue") == "vane": await _dialogue()
		if not episode.state in ["fight", "corner"]: break
		if episode.state == "corner": await _press("send")
		_held([KEY_1] if scene.sim.mode == "CARD" and i % 20 < 10 else [])
		_tick()
		if i % 600 == 0: await process_frame
	_held([]); _tick()
	_check("losing the actual dual cannot award the charter or tag", scene.sim.seg_wins_p < 2 and not episode._ep()["flags"].get("survival", false) and episode.state == "inspect")
	await _capture("survival-loss")
	await _press("retry_survival"); await _dialogue()
	_check("failure offers a real retry with the recruited squad preserved", episode.state == "board" and scene.sim.stable.size() == 4 and not episode._ep()["flags"].get("survival", false))

func _training() -> void:
	for step in 2400:
		if episode.state != "training": break
		var key: int = [KEY_J, KEY_K, KEY_U, KEY_I, KEY_Y, KEY_O][int(episode.training["index"]) % 6]
		_held([key] if step % 30 < 20 else []); _tick()
		if step % 300 == 0: await process_frame
	_held([])
	_check("shadow drill requires and records twelve accepted punches", episode.state == "dialogue" and episode._ep().get("flags", {}).get("shadow", false))

func _roundtrip_world() -> void:
	_held([]); _key(KEY_TAB, true); _key(KEY_TAB, false); await process_frame
	await _press("save")
	var before: Dictionary = scene.sim.rewards.duplicate(true); var position: Array = episode.world.point()
	await _press("load")
	_check("world save preserves earned ledgers and location", scene.sim.rewards == before and episode.world.point() == position)
	await _capture("continued-world")

func _harbour_training() -> void:
	await _walk(Vector2(0, 12)); await _walk(Vector2(0, 25)); await _walk(Vector2(-4, 29)); await _interact("roadwork"); await _press("train")
	var before: int = scene.sim.training_used()
	for beat in 12:
		while episode.state == "training" and float(episode.training["t"]) < beat + 0.5: _tick()
		if episode.state != "training": break
		await _press("step")
		_tick()
	while episode.state == "training": _tick()
	_check("Harbour roadwork books a real paid training slot", scene.sim.training_used() == before + 1 and int(scene.sim.rewards.get("beans", 0)) > 0)
	await _capture("harbour-training"); await _press("back")
	await _interact("roadwork"); await _press("train"); await _press("cancel")
	_check("cancelled roadwork cannot survive in the episode save", not episode._ep().has("training") and scene.sim.training_used() == before + 1)
	await _roundtrip_world()
	await _walk(Vector2(0, 25)); await _walk(Vector2(0, 12)); await _walk(Vector2(0, 6)); await _walk(Vector2(-5, -1)); await _interact("mitts"); await _press("train")
	for beat in 12:
		while episode.state == "training" and float(episode.training["t"]) < beat * 1.3 + 0.65: _tick()
		if episode.state != "training": break
		var code: int = [KEY_J, KEY_K, KEY_U, KEY_I, KEY_Y, KEY_O][beat % 6]
		_held([code])
		for i in 22: _tick()
		_held([])
	while episode.state == "training": _tick()
	var records: Array = episode._ep()["metrics"]["training"]
	_check("Mitts scores actual called punches under tempo", records[-1]["game"] == "mitts" and float(records[-1]["grade"]) > 0)
	await _capture("mitts-result"); await _press("back")
	await _walk(Vector2(0, 4)); await _walk(Vector2(5, -5)); await _interact("locker")
	var beans: int = scene.sim.rewards.get("beans", 0)
	if episode.buttons["raise:STA"].disabled:
		_check("unaffordable growth keeps its price gate", beans < scene.sim.raise_cost("RORY", "STA"))
	else:
		await _press("raise:STA"); _check("earned Beans purchase a persistent stat raise", scene.sim.rewards.get("beans", 0) == beans - 5)
	if episode.buttons.has("node:sp1") and not episode.buttons["node:sp1"].disabled:
		var points: int = scene.sim.gpoints_free("RORY"); await _press("node:sp1")
		_check("ability board spends earned points", scene.sim.gpoints_free("RORY") < points)
	await _capture("growth"); await _press("back")

func _scouting_spars() -> void:
	await _walk(Vector2(5, 4)); await _interact("film")
	for i in 3:
		await _press("mockup:" + str(i)); await _fight(110)
		_check("optional scouting spar %d reaches its real segment verdict" % (i + 1), episode.state == "inspect" and episode._ep()["metrics"]["bouts"][-1]["fight"] == "mockup")
		await _press("back"); await _interact("film")
	_check("all three mockups earn Vane Pattern Intel", scene.sim.pi_level("cassidy_vane") >= 2)
	await _capture("scouting-binders"); await _press("back")

func _localization_and_recovery() -> void:
	var malformed: Dictionary = episode._ep().duplicate(true)
	malformed["flags"]["survival"] = true
	_check("unearned charter save is rejected", episode.Campaign.validate(malformed) != "")
	malformed = episode._ep().duplicate(true); malformed["metrics"]["bouts"].append({"fight":"survival", "won":true, "segment_wins":{}})
	_check("malformed segment evidence is rejected without coercion", episode.Campaign.validate(malformed) != "")
	_key(KEY_TAB, true); _key(KEY_TAB, false); await process_frame
	await _press("language"); await _press("back")
	_check("Canadian French is an in-game language choice", episode.language == "fr_CA" and TranslationServer.get_locale() == "fr_CA")
	root.size = Vector2i(960, 600); await process_frame
	await _capture("fr-960-world")
	await _roundtrip_world()
	for id in episode.data["scenes"]:
		for line in episode.data["scenes"][id]: _check("EN/FR authored line " + id, line.size() == 3 and str(line[1]) != "" and str(line[2]) != "")
	var original: String = FileAccess.get_file_as_string(episode.SAVE_PATH)
	var file := FileAccess.open(episode.SAVE_PATH, FileAccess.WRITE); file.store_string("{interrupted-write"); file.close()
	var live = scene.sim
	_key(KEY_TAB, true); _key(KEY_TAB, false); await process_frame; await _press("load")
	_check("invalid save leaves the live simulation intact and reports failure", scene.sim == live and episode.state == "title" and episode.status != "")
	await _press("backup")
	_check("native backup recovery restores the episode", episode.state == "world" and episode.language == "fr_CA")
	_check("recovery preserves readable backup and retains damaged primary", FileAccess.get_file_as_string(episode.SAVE_PATH + ".rejected") == "{interrupted-write" and episode.Save.read_file(episode.SAVE_PATH + ".bak").get("ok", false))
	_check("legacy club save remains separate", not FileAccess.file_exists("user://tnb_save.json"))
	await _capture("fr-recovered")
	root.size = Vector2i(1280, 720); await process_frame

func _run() -> void:
	gpu = "capture" in OS.get_cmdline_user_args(); started = Time.get_ticks_msec()
	root.size = Vector2i(1280, 720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	episode = scene.episode; scene.club_flow.set_process(false)
	_check("automated episode output is muted before playback", AudioServer.is_bus_mute(0))
	await process_frame; await process_frame
	_check("normal episode entry pauses simulation", episode != null and episode.state == "title" and scene.sim.tick == 0)
	await _capture("title")
	await _press("new"); await _dialogue()
	_check("archive gives authored legend build and 80 initial tension", scene.sim.P["stats"]["PWR"] >= 90 and scene.sim.tension == 80)
	while episode.transition_t > 0: _tick()
	await _render_sample("archive-boxing")
	await _capture("1976")
	await _fight(110)
	if episode.state != "dialogue":
		print("ARCHIVE DEBUG ", JSON.stringify({"pattern":scene.sim.pattern, "P":scene.sim.P, "B":scene.sim.B, "fx":scene.fx_counts, "mode":scene.sim.mode, "state":episode.state, "lesson":episode._ep().get("lesson")}))
		_check("archive sequence completed through actual boxing", false); _finish(); return
	await _dialogue(); await _training(); await _dialogue()
	_check("Rory starts alone after the letter", scene.sim.stable.size() == 1 and scene.sim.stable[0]["name"] == "RORY" and scene.sim.stable[0]["stats"]["HRT"] == 99)
	_check("Scout Book shelf stays empty before Priya joins", not episode.world.binders.visible)
	await _capture("letter-gym")
	await _render_sample("gym-world")
	await _walk(Vector2(0, -5)); await _interact("board")
	_check("unrecruited squad cannot seal Saturday's order", episode.state == "inspect" and not episode.buttons.has("bell"))
	await _press("back"); await _walk(Vector2(0, 6))
	await _roundtrip_world()
	await _walk(Vector2(0, 12)); await _walk(Vector2(-30, 12)); await _walk(Vector2(-30, -18)); await _walk(Vector2(-26, -18)); await _interact("scrap_1")
	await _press("glove_up"); await _fight(38)
	_check("body shots earn the first lesson", episode._ep()["flags"].get("scrap_1", false)); await _press("back")
	await _walk(Vector2(-30, -18)); await _walk(Vector2(-34, -25)); await _interact("priya"); await _dialogue(); await _fight(105); await _dialogue()
	_check("fought trial recruits Priya", scene.sim.stable.size() == 2 and episode._ep()["flags"].get("joined_PRIYA", false))
	_check("final-bell save was exercised before recruitment", saved_at_verdict)
	_check("Priya's binders appear through the real recruitment event", episode.world.binders.visible)
	await _walk(Vector2(-30, -18)); await _walk(Vector2(-30, -13)); await _walk(Vector2(30, -13)); await _walk(Vector2(30, -20)); await _walk(Vector2(25, -22)); await _interact("scrap_2")
	await _press("glove_up"); await _fight(38); await _dialogue()
	_check("survival lesson recruits Marcus", episode._ep()["flags"].get("joined_MARCUS", false))
	await _walk(Vector2(35, -22)); await _interact("scrap_3"); await _press("glove_up"); await _fight(38); await _dialogue()
	_check("centre exchange recruits June", episode._ep()["flags"].get("joined_JUNE", false))
	await _capture("four-dressed")
	await _walk(Vector2(30, -20)); await _walk(Vector2(30, -13)); await _walk(Vector2(12, -13)); await _walk(Vector2(12, 12)); await _walk(Vector2(0, 12)); await _walk(Vector2(0, 6)); await _walk(Vector2(5, 4)); await _interact("film"); await _dialogue()
	await _scouting_spars()
	await _walk(Vector2(0, 6)); await _harbour_training(); await _localization_and_recovery()
	await _walk(Vector2(0, 4)); await _walk(Vector2(0, -5)); await _interact("board"); await _dialogue()
	_check("Survival Dual preserves sealed authored opponents", scene.sim.blineup == ["ascendant_seed", "ascendant_r2", "cassidy_vane"])
	await _capture("board"); await _press("bell"); await _lose_survival(); await _press("bell"); await _fight(350)
	_check("Survival qualification matches actual segment wins", episode._ep()["flags"].get("survival", false) == (scene.sim.seg_wins_p >= 2))
	_check("hands-on retry actually qualifies for the authored tag", scene.sim.seg_wins_p >= 2 and episode.state == "dialogue")
	var right_leads: Array = episode._ep()["metrics"].get("r2_tells", [])
	_check("R2 tape fact actually occurs in combat", "TAPE_RIGHT" in right_leads)
	for cycle in episode._ep()["metrics"].get("r2_cycles", []):
		for i in cycle.size(): _check("R2 third-exchange right lead at opener %d" % (i + 1), (cycle[i] == "TAPE_RIGHT") == (i % 3 == 2))
	if episode.state == "dialogue": await _dialogue()
	await _capture("survival-verdict")
	for shot in ["archive:1", "freeze:0", "present:0", "letter:3", "letter:11", "tag:0", "tag:2"]:
		_check("authored audiovisual action reached " + shot, episode.staging.visited.has(shot))
	_finish()

func _finish() -> void:
	_check("automated episode cannot leave its output unmuted", AudioServer.is_bus_mute(0))
	var report := {"checks":checks, "failures":failures, "journal":journal, "captures":captures, "frames":frame, "accelerated_frames_nominal_seconds":frame / 60.0, "episode_metrics":episode._ep().get("metrics", {}), "performance":performance_samples, "wall_ms":Time.get_ticks_msec() - started, "population":"One automated native-input implementer journey. Not new-player or physical input-to-photon evidence."}
	var file := FileAccess.open("user://episode-journey.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ")); file.close()
	print("EPISODE JOURNEY ", checks, " checks; ", failures.size(), " failures; ", ProjectSettings.globalize_path("user://episode-journey.json"))
	print("DRIVE :: GREEN" if failures.is_empty() else "DRIVE :: RED")
	quit(0 if failures.is_empty() else 1)
