extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_broadcast.gd -- episode
## Silent presentation fixtures; drive_episode verifies the earned full journey.
const Campaign := preload("res://episode/campaign.gd")
var scene: Node
var ep: Node
var radio: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition: failures.append(label)
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])

func _press_next() -> void:
	await process_frame
	ep.buttons["next"].grab_focus(); await process_frame
	var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = true; root.push_input(event)
	event = InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = false; root.push_input(event)
	await process_frame

func _fixture(language: String) -> void:
	ep.new_episode(language)
	var old = Campaign.present(scene.content, scene.sim)
	for flag in ["letter", "scrap_1", "priya_trial", "scrap_2", "scrap_3"]: Campaign.mark(old, flag)
	for name in ["PRIYA", "MARCUS", "JUNE"]: Campaign.join(old, name)
	scene.sim = Campaign.prepare(scene.content, old)
	ep.pending.clear(); ep._fight(); ep.transition_t = 0; radio.reset()
	scene.sim.events.clear(); ep.pending.clear()

func _capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	scene._render(1); scene._hud()
	await process_frame; await RenderingServer.frame_post_draw
	_check("capture " + label, root.get_texture().get_image().save_png("user://broadcast-" + label + ".png") == OK)
	if radio.caption.visible:
		_check("caption fits " + label, radio.caption.get_global_rect().end.x <= root.size.x and radio.caption.get_global_rect().end.y < root.size.y - 112)
		if ep.state == "fight": _check("objective stays below caption " + label, ep.quest.position.y >= radio.caption.get_global_rect().end.y)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	ep = scene.episode; radio = ep.broadcast; scene.club_flow.set_process(false)
	await process_frame
	_check("Dummy driver and muted Master protect speakers", AudioServer.get_driver_name() == "Dummy" and AudioServer.is_bus_mute(0))
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://episode/broadcast.v1.json"))
	for key in radio.catalog:
		for language in ["en", "fr_CA"]:
			var clip: Dictionary = radio.catalog[key]["clips"][language]
			var cue: Dictionary = authored["cues"][key]
			var expected: String = ep.data["scenes"][cue["scene"]][cue["line"]][1 if language == "en" else 2] if cue.has("scene") else cue[language]
			_check("authored wording " + key + ":" + language, clip["text"] == expected)
			_check("complete offline clip " + key + ":" + language, is_equal_approx(radio.streams[key + ":" + language].get_length(), float(clip["seconds"])) and float(clip["peak"]) > 0 and float(clip["peak"]) < 1)
	for key in ["survival_charter", "marcus_loss"]:
		_check("Danielle remains authored French in both locales " + key, radio.catalog[key]["clips"]["en"]["file"] == radio.catalog[key]["clips"]["fr_CA"]["file"])
	ep.new_episode("en")
	_check("Gord begins with the real archive page", radio.current == "archive_open" and radio.voice.playing and not radio.caption.visible)
	var tick: int = scene.sim.tick
	scene.controls_menu.open(); scene._process(0.5)
	_check("controls pause narration and tape together", radio.voice.stream_paused and ep.staging.ambience.stream_paused and scene.sim.tick == tick)
	scene.controls_menu.close(); scene._process(0)
	_check("closing controls resumes the same line", radio.voice.playing and not radio.voice.stream_paused and radio.current == "archive_open")
	# Exercise the real audio completion signal, not a simulated finished call.
	var deadline := Time.get_ticks_msec() + 12000
	while radio.current == "archive_open" and Time.get_ticks_msec() < deadline: await process_frame
	_check("completed opening naturally reaches the missing-name hole", ep.staging.shot == "archive:1" and ep.freeze_t == 1 and radio.current == "")
	scene._process(0.5)
	_check("hole keeps all tape channels silent and hides the name", ep.staging.sound_hole and ep.staging.ambience.stream_paused and (ep.staging.foley.stream_paused or not ep.staging.foley.playing) and not radio.voice.playing and not ep.panel.visible and scene.sim.tick == tick)
	scene.controls_menu.open(); scene._process(4)
	_check("controls cannot consume the missing-name second", ep.freeze_t == 0.5)
	scene.controls_menu.close(); scene._process(0.49)
	_check("name is still absent at 990ms", ep.staging.sound_hole and radio.current == "")
	scene._process(0.011)
	_check("Gord resumes after one second, without a revealed name", radio.current == "archive_believes" and is_equal_approx(ep.staging.sound_hole_seconds, 1))
	await _capture("archive-return")
	await _press_next()
	_check("native Continue can skip narration cleanly into boxing", ep.state == "fight" and not radio.voice.playing)
	for language in ["en", "fr_CA"]:
		_fixture(language)
		# Explicit fixture boundary: real core segment closure, seeded score.
		scene.sim.ep_p = 0; scene.sim.ep_b = 100; scene.sim._end_segment("clock")
		scene._consume_events(); ep.advance(0)
		_check("actual R1 loss selects Danielle " + language, radio.current == "marcus_loss" and "jauge" in radio.caption.text)
		var starts: int = radio.starts; var before: int = scene.sim.hash_state()
		radio.observe({"kind":"seg_card", "seg":1, "won":false}, "survival"); radio.sync(false)
		_check("duplicate loss does not replay or alter combat " + language, radio.starts == starts and before == scene.sim.hash_state())
		await _capture(language + "-loss")
		scene.sim._open_corner(); scene._consume_events(); ep.advance(0); radio.sync(false)
		_check("corner page carries the subtitle without overlay overlap " + language, ep.state == "corner" and not radio.caption.visible and radio.current == "marcus_loss")
		ep.save_episode(); before = scene.sim.hash_state(); ep.load_episode(); radio.sync(false)
		_check("resolved corner reload is exact and does not repeat commentary " + language, not radio.voice.playing and scene.sim.hash_state() == before)
		_fixture(language)
		radio.observe({"kind":"seg_card", "seg":1, "won":true}, "survival")
		radio.observe({"kind":"seg_card", "seg":2, "won":false}, "survival")
		radio.observe({"kind":"seg_card", "seg":1, "won":false}, "archive")
		_check("no invented loss or wrong-round commentary " + language, radio.current == "")
		scene.sim.seg_idx = 2; scene.sim._load_segment(); scene.sim.events.clear(); ep.pending.clear()
		scene.sim.boss_name = "cal_mason"; radio.observe({"kind":"drop", "who":"B"}, "survival")
		_check("another opponent cannot trigger Vane's line " + language, radio.current == "")
		scene.sim.boss_name = "cassidy_vane"
		radio.observe({"kind":"drop", "who":"P"}, "survival")
		_check("Rory drop cannot trigger Vane's line " + language, radio.current == "")
		scene.sim._drop(false); scene._consume_events(); ep.advance(0); radio.sync(false)
		_check("actual Vane knockdown speaks Gord " + language, radio.current == "vane_down" and "VANE" in radio.caption.text)
		await _capture(language + "-vane")
		root.size = Vector2i(960, 540); await _capture(language + "-vane-small"); root.size = Vector2i(1280, 720)
		# Readability tests hold combat states as bounded presentation fixtures.
		for mode in ["EIGHT", "CLINCH", "CLASH"]:
			scene.sim.mode = mode; radio.sync(false)
			_check("rhythm/exchange priority " + language + ":" + mode, radio.held and not radio.caption.visible)
		scene.sim.mode = "FIGHT"; scene.sim.bstate = "TELL"; radio.sync(false)
		_check("tell priority pauses broadcast " + language, radio.held and radio.voice.stream_paused)
		scene.sim.bstate = "IDLE"; scene.sim.P["counter_t"] = 0; scene.sim.btimer = 0; radio.sync(false)
		_check("clear exchange resumes the same utterance " + language, not radio.held and radio.voice.playing)
		scene.sim._force_string("S1", 1.0, false); scene._consume_events()
		_check("real Cassidy code takes priority in the same event frame " + language, scene.fight_feedback.corner_calls.voice.playing and radio.voice.stream_paused and not radio.caption.visible)
		scene.sim.bstate = "IDLE"; scene.fight_feedback.sync_audio(false); radio.sync(false)
		before = scene.sim.hash_state(); radio.sync(true); radio.sync(false)
		_check("presentation pause never changes simulation/RNG " + language, scene.sim.hash_state() == before)
		ep._dialogue("tag"); _check("Gord finishes over the immediate victory shot " + language, radio.current == "vane_down")
		while ep.freeze_t > 0: ep.advance(0.1)
		ep.next_line(); _check("next authored conversation cancels obsolete call " + language, not radio.voice.playing)
		ep._dialogue("survival"); _check("localized survival opening " + language, radio.voice.stream == radio.streams["survival_stakes:" + language])
		await _press_next(); _check("native dialogue hands Gord off to Danielle " + language, radio.current == "survival_charter")
		ep.language = "fr_CA" if language == "en" else "en"; ep._language()
		_check("locale switch cancels the previous spoken language " + language, not radio.voice.playing)
		ep._title(); _check("title cancels every broadcast channel " + language, radio.current == "" and not radio.voice.playing and not radio.caption.visible)
	_check("automation never unmutes Master", AudioServer.is_bus_mute(0))
	var report := {"checks":checks, "failures":failures, "scope":"Silent real AudioStream completion, native Continue and bounded core event fixtures. Full earned journey is drive_episode. Provisional synthetic performances; no listening/casting acceptance."}
	var file := FileAccess.open("user://broadcast-report.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ")); file.close()
	print("BROADCAST ", checks, " checks; ", failures.size(), " failures")
	print("DRIVE :: GREEN" if failures.is_empty() else "DRIVE :: RED")
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
