extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_corner_calls.gd -- episode
## Bounded combat fixtures + native input; full episode traversal is drive_episode.
## Always use --audio-driver Dummy, including capture. Never an audible test.
const Tests := preload("res://sim/tests.gd")
const Calls := preload("res://presentation/corner_calls.gd")
const Locale := preload("res://episode/locale.gd")
const Campaign := preload("res://episode/campaign.gd")
var tests := Tests.new()
var scene: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition: failures.append(label)
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])

func _fresh():
	var sim = tests.make_sim(0, 731)
	tests.quiet(sim); tests.place(sim, 1.35); tests.clear_defense(sim.B)
	sim.P["pkg"] = {}; sim.B["pkg"] = {}
	scene.sim = sim; scene.prev_p = sim.P["pos"]; scene.prev_b = sim.B["pos"]
	scene.clock.acc = 0; scene.combat_input.clear(); scene.fight_view.clock_sim = null
	scene.fight_feedback.sync_audio(false)
	return sim

func _tell(string: String) -> void:
	scene.sim.events.clear(); scene.sim._force_string(string, 1.0, false); scene._consume_events(); scene._hud()

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = down; root.push_input(event)

func _capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	scene._render(1); scene._hud()
	await process_frame; await RenderingServer.frame_post_draw
	_check("combat caption is visible " + label, scene.cam.current and scene.fight_hud.cue.is_visible_in_tree())
	_check("rendered " + label, root.get_texture().get_image().save_png("user://calls-" + label + ".png") == OK)
	_check("caption fits viewport " + label, scene.fight_hud.cue.get_global_rect().end.x <= root.get_visible_rect().size.x + 1)

func _run() -> void:
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame
	scene.episode.active = false; scene.episode.hide()
	scene.episode.world.hide(); scene.get_meta("arena").show()
	scene.player.show(); scene.boss.show(); scene.cam.make_current(); scene.fight_hud.show()
	scene.controls_menu.close(); scene.begin_fight(false); scene.combat_input.reset_bindings()
	var calls = scene.fight_feedback.corner_calls
	_check("automation is silent at the output bus", AudioServer.is_bus_mute(0) and AudioServer.get_driver_name() == "Dummy")
	var assets := {}
	for language in ["en", "fr_CA"]:
		Locale.use(language)
		for index in 3:
			var sim = _fresh(); var string: String = ["S1", "S2", "S3"][index]
			var code: int = [1, 4, 7][index]
			var before: int = calls.starts
			_tell(string)
			_check("%s %s speaks code %d once" % [language, string, code], calls.starts == before + 1 and calls.voice.playing)
			var expected := ("fr" if language == "fr_CA" else "en") + "_" + str(code)
			_check("localized offline resource " + expected, calls.voice.stream == calls.streams[expected])
			var clip: AudioStreamWAV = calls.voice.stream
			_check("complete call fits original tell " + expected, clip.get_length() > 0.4 and clip.get_length() <= float(sim.pattern["strings"][string]["tell"]["ms"]) / 1000)
			var digest := clip.data.hex_encode().sha256_text()
			_check("distinct voiced waveform " + expected, not assets.has(digest)); assets[digest] = true
			var state_hash: int = sim.hash_state()
			scene._consume_events(); scene._hud()
			_check("duplicate observation neither restarts nor cancels " + expected, calls.starts == before + 1 and calls.voice.playing)
			_check("presentation leaves sim and RNG unchanged " + expected, state_hash == sim.hash_state())
			if language == "fr_CA": Locale.hud(scene, true, false, "")
			_check("readable localized code " + expected, str(code) in scene.fight_hud.cue.text and ("SÉQUENCE" if language == "fr_CA" else "SEQUENCE") in scene.fight_hud.cue.text and not "CALL S" in scene.fight_hud.cue.text)
			if index == 1: await _capture(language + "-four")
	Locale.use("en")
	var phase = _fresh(); phase.B["comp"] = phase.B["comp_max"] * 0.45; phase.step({}); _tell("S3")
	_check("phase two is 6dB quieter, with original 600ms tell", phase.bphase == 2 and calls.voice.volume_db == -14 and phase.pattern["strings"]["S3"]["tell"]["ms"] == 600)
	var gain: float = calls.voice.volume_db; phase.events.clear(); phase.step({}); _tell("S1")
	_check("phase directive applies once, retains 700ms tell", calls.voice.volume_db == gain and phase.pattern["strings"]["S1"]["tell"]["ms"] == 700)
	var saved: Dictionary = phase.snapshot(); var loaded = tests.make_sim(0, 731)
	_check("current quieter phase restores exact state", loaded.restore(saved).get("same", false) and loaded.bmods["corner_call_tier"] == -1)
	# Reproduce the prior save's actual dictionary and clocks; restore must not
	# silently migrate an in-flight bout or invalidate its hash.
	phase.bmods.erase("corner_call_tier"); phase.bmods["tier_shift"] = -1
	for id in ["S1", "S2", "S3"]: phase.pattern["strings"][id]["tell"]["ms"] -= 150
	saved = phase.snapshot(); loaded = tests.make_sim(0, 731)
	_check("legacy phase snapshot retains hash and old clocks", loaded.restore(saved).get("same", false) and loaded.pattern["strings"]["S1"]["tell"]["ms"] == 550 and not loaded.bmods.has("corner_call_tier"))
	scene.sim = loaded; calls.sync(loaded, false)
	_check("loading mid-tell does not replay stale speech", not calls.voice.playing)
	_tell("S1"); _check("legacy volume fallback is read-only", calls.voice.volume_db == -14 and not loaded.bmods.has("corner_call_tier"))
	for string in ["S1", "S2", "S3"]:
		_fresh(); _tell(string)
		var before: int = scene.fx_counts.get("interrupt", 0)
		var hits: int = scene.fx_counts.get("hit", 0)
		_key(KEY_J, true)
		for frame in 40:
			scene._process(1.0 / 120)
			if int(scene.fx_counts.get("hit", 0)) > hits: break
		_key(KEY_J, false)
		_check("native jab lands during " + string, int(scene.fx_counts.get("hit", 0)) > hits)
		_check("authored interrupt rule " + string, (int(scene.fx_counts.get("interrupt", 0)) > before) == (string != "S2"))
		_check("call cancels only on actual interrupt " + string, calls.voice.playing == (string == "S2"))
		if string != "S2":
			_check("full 800ms stagger " + string, scene.sim.bstate == "IDLE" and scene.sim.btimer == 96)
			_check("interrupt opens readable follow-up " + string, "INTERRUPTED" in scene.fight_hud.cue.text)
			Locale.hud(scene, true, false, "")
			_check("French interrupt feedback " + string, "INTERROMPU" in scene.fight_hud.cue.text)
			var cue_held := true
			for step in 150:
				if scene.sim.bstate != "IDLE" or scene.sim.btimer <= 0: break
				cue_held = cue_held and scene.fight_feedback.interrupt_active(scene.sim)
				scene._process(1.0 / 120)
			_check("follow-up cue survives hitstop and all recovery ticks " + string, cue_held and not scene.fight_feedback.interrupt_active(scene.sim))
	_fresh(); _tell("S1")
	var tick: int = scene.sim.tick; var starts: int = calls.starts
	_key(KEY_ESCAPE, true); _key(KEY_ESCAPE, false); scene._process(0.2)
	_check("native Escape pauses speech and simulation", scene.controls_menu.opened and calls.voice.stream_paused and scene.sim.tick == tick)
	_key(KEY_ESCAPE, true); _key(KEY_ESCAPE, false); scene._process(1.0 / 60)
	_check("resume continues call without replay", not calls.voice.stream_paused and calls.voice.playing and calls.starts == starts)
	scene.fight_feedback.play("heavy")
	_check("impacts duck under the spoken cue", scene.fight_feedback.voices[(scene.fight_feedback.voice_index + 7) % 8].volume_db == -24)
	scene.sim._drop(true, false); scene._consume_events()
	_check("standing eight stops obsolete call", not calls.voice.playing)
	_fresh(); _tell("S1"); scene.sim.states["P"]["tell_jam_audio"] = {"t": 120}; calls.sync(scene.sim, false)
	_check("new audio jam stops speech and masks its caption", not calls.voice.playing and Calls.caption(scene.sim, false) == "CORNER CALL MASKED")
	starts = calls.starts; _tell("S2")
	_check("jammed event cannot play or reveal code", calls.starts == starts and scene.fight_hud.cue.text == "CORNER CALL MASKED")
	_fresh(); scene.sim.states["P"]["tell_jam_visual"] = {"t": 120}; _tell("S2")
	_check("visual jam does not suppress an audio-channel tell", calls.voice.playing and "4" in Calls.caption(scene.sim, false))
	_fresh(); scene.sim.pattern["strings"]["S1"]["tell"]["motif"] = "shoulder_load"; _tell("S1")
	_check("another fighter's S1 never speaks Cassidy's code", not calls.voice.playing and Calls.caption(scene.sim, false) == "")
	_fresh(); _tell("S1"); scene.sim.tick -= 1; calls.sync(scene.sim, false)
	_check("rewind cancels obsolete speech", not calls.voice.playing)
	# Production Priya drill setup, copied exactly from the authored Vane data;
	# no mutation of the reusable generic assembler or of the source boss.
	scene.episode.active = true; scene.episode.show(); scene.episode.new_episode("fr_CA")
	scene.sim = Campaign.present(scene.content, scene.sim)
	# This bounded fixture starts after the introductory dialogue. The full
	# episode driver earns this position through its native conversation flow.
	scene.episode._ep()["dialogue"] = ""
	for index in 3:
		scene.episode._mockup(index)
		var string: String = ["S1", "S2", "S3"][index]
		_check("mockup teaches only its real sequence " + string, scene.sim.pattern["strings"].keys() == [string] and scene.sim.pattern["strings"][string]["actions"] == scene.sim.patterns["cassidy_vane"]["strings"][string]["actions"])
		_tell(string)
		_check("mockup uses same localized call " + string, calls.voice.playing and calls.voice.stream == calls.streams["fr_%d" % [1, 4, 7][index]] and scene.sim.bdialect == "cassidy_vane")
		_check("mockup preserves interrupt lesson " + string, (not scene.sim.pattern["interrupt"].is_empty()) == (index != 1))
		if index == 2:
			_check("save during a real queued call", not scene.episode.pending.is_empty() and scene.episode.save_episode())
			var exact_hash: int = scene.sim.hash_state(); var exact_tick: int = scene.sim.tick
			scene.episode.load_episode()
			_check("queued call survives native save format exactly", scene.sim.hash_state() == exact_hash and scene.sim.tick == exact_tick)
			_check("load stops old speech without replaying saved tell", not calls.voice.playing)
			root.size = Vector2i(960, 540); await _capture("fr-mockup-seven-960")
			_tell(string)
			scene.episode.state = "inspect"; scene._process(0.2)
			_check("leaving combat for a story page silences call", not calls.voice.playing or calls.voice.stream_paused)
	_check("source Cassidy pattern remains complete", scene.sim.patterns["cassidy_vane"]["strings"].size() == 3 and scene.sim.patterns["cassidy_vane"]["strings"]["S3"]["tags"] == ["phase>=2"])
	_check("output remains silent throughout", AudioServer.is_bus_mute(0))
	print("CORNER CALLS ", checks, " checks; ", failures.size(), " failures")
	print("DRIVE :: GREEN" if failures.is_empty() else "DRIVE :: RED")
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
