extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_readiness.gd -- welcome
## PAC-202F: sustained native input through main._process, without demo/profile
## intents, quiet opponents, forced strings, health refills or tuning overrides.
## Add film for a 60 Hz GPU run; each recorded frame advances the real scene.
## Controlled GPU captures: set SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT to
## 0x0000/0x0000 for this process so a live controller cannot alter the journal.
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
const Clock := preload("res://sim/clock.gd")
var tests := Tests.new()
var scene: Node
var keys := {}
var failures: Array[String] = []
var checks := 0
var journal: Array = []
var film := false
var gpu := false
var caption: Label
var active_case := ""
var input_mismatches := 0
const CASES := [
	{"name": "rory-yuri", "fighter": 0, "boss": 1, "kind": "spar", "seconds": 100},
	{"name": "priya-marta", "fighter": 1, "boss": 18, "kind": "spar", "seconds": 100},
	{"name": "marcus-sam", "fighter": 2, "boss": 3, "kind": "spar", "seconds": 100},
	{"name": "june-dual", "fighter": 3, "boss": 1, "kind": "dual", "seconds": 110},
	{"name": "ep1-scrap", "fighter": 0, "boss": 0, "kind": "scrap", "seconds": 35},
	{"name": "fatigue-recovery", "fighter": 2, "boss": 3, "kind": "spar", "seconds": 65},
]

func _initialize() -> void: _run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _key(code: int, down: bool) -> void:
	if bool(keys.get(code, false)) == down: return
	keys[code] = down
	var event := InputEventKey.new(); event.keycode = code; event.pressed = down
	root.push_input(event)
	if "trace-input" in OS.get_cmdline_user_args() and scene != null and scene.sim.mode == "FIGHT":
		for action in scene.combat_input.KEYS:
			if scene.combat_input.KEYS[action] == code and scene.combat_input.down(action) != down and input_mismatches < 12:
				input_mismatches += 1
				print("INPUT DELIVERY ", scene.sim.tick, " ", action, " down=", down, " held=", scene.combat_input.held.get(action), " focus=", root.gui_get_focus_owner(), " handled=", root.is_input_handled(), " controls=", scene.controls_menu.opened, " club=", scene.club_flow.visible)

func _held(wanted: Array) -> void:
	for code in keys.keys():
		if not code in wanted: _key(code, false)
	for code in wanted: _key(code, true)

func _begin(rec: Dictionary) -> void:
	active_case = str(rec["name"])
	_held([]); scene.controls_menu.close(); scene.club_flow.close()
	scene.club_flow.enabled = false; scene.set_practice(false)
	var cards: Array = Sim.LINEUP_MILLBROOK.duplicate(true)
	var first: Dictionary = cards.pop_at(int(rec["fighter"]))
	first.erase("reserve"); cards.push_front(first)
	scene.sim = tests.make_sim(int(rec["boss"]), 731, cards)
	if rec["kind"] == "spar": scene.sim.start_spar(int(rec["boss"]))
	elif rec["kind"] == "scrap": scene.sim.start_ep1("scrap_1")
	scene.clock.acc = 0; scene.combat_input.clear(); scene.fx_counts.clear()
	scene.fight_view.clock_sim = null; scene.fight_view.orbit = Vector3.ZERO
	scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.fight_hud.dismiss_entry(); scene._consume_events(); scene._render(1); scene._hud()

func _policy(slice: int) -> Array:
	var s = scene.sim
	var timing: Dictionary = scene.fight_feedback.timing_state(s)
	if not timing.is_empty():
		if not timing["open"] or timing["locked"]: return []
		return [KEY_ENTER] if s.mode == "EIGHT" else [KEY_A if timing["label"] == "LEFT" else KEY_D]
	if s.mode in ["CARD", "CORNER"]: return [KEY_1] if slice % 2 == 0 else []
	if s.mode != "FIGHT": return []
	if active_case == "fatigue-recovery":
		# Price real heavy punches, repeated sprint-steps and leans; then spend
		# a sustained neutral interval recovering under the live opponent.
		if slice < 120:
			var heavy: Array = [KEY_SHIFT, KEY_S]
			if slice % 6 < 3: heavy.append(KEY_O if slice / 6 % 2 == 0 else KEY_Y)
			if slice % 2 == 0: heavy.append(KEY_CTRL); heavy.append(KEY_B)
			return heavy
		if slice < 210: return [KEY_S] if s.P["pos"].distance_to(s.B["pos"]) < 2.7 else []
	var wanted: Array = []
	var distance: float = s.P["pos"].distance_to(s.B["pos"])
	var cycle := slice % 180 # Thirty-second attack / recover / move journey.
	var tired: bool = float(s.P["stamina"]) < 25 or cycle >= 132
	if tired:
		if distance < 2.7: wanted.append(KEY_S)
		if s.zone(s.P["pos"]) in ["CORNER", "ROPES"]: wanted.append(KEY_A if slice / 60 % 2 == 0 else KEY_D)
	elif distance > 1.35: wanted.append(KEY_W)
	if cycle in [108, 114, 120, 126]: wanted.append([KEY_Q, KEY_E, KEY_V, KEY_B][(cycle - 108) / 6])
	if cycle >= 90 and cycle < 108:
		wanted.append(KEY_W)
		if distance < 1.25 and slice % 6 == 0: wanted.append(KEY_G)
	elif not tired:
		# Commit for >=166 ms; alternate head/body, hands and all five families.
		var beat := slice % 6
		if s.bstate in ["TELL", "HOLD", "ACTING"] and int(s.P["counter_t"]) == 0:
			wanted.append(KEY_SPACE)
		elif beat < 3:
			var row: String = scene.combat_input.ROWS[(slice / 6) % 10]
			wanted.append(scene.combat_input.KEYS[row])
			if slice / 6 % 3 == 1 or not s.bout.is_empty() and s.bout["kind"] == "scrap": wanted.append(KEY_C)
			if cycle < 60: wanted.append(KEY_SHIFT)
		elif s.bstate in ["TELL", "HOLD", "ACTING"]: wanted.append(KEY_SPACE)
	return wanted

func _rig_ok(actor: Node3D) -> bool:
	var rig: Dictionary = actor.get_meta("render_kinematics")
	for i in 2:
		for pair in [["shoulders", "elbows", Motion.UPPER_ARM], ["elbows", "wrists", Motion.FOREARM], ["hip_joints", "knees", Motion.THIGH], ["knees", "ankles", Motion.SHIN]]:
			if absf(rig[pair[0]][i].distance_to(rig[pair[1]][i]) - float(pair[2])) > 0.00001: return false
		if actor.get_meta("gloves")[i].position.distance_to(rig["wrists"][i]) > 0.00001: return false
	return true

func _camera_ok() -> bool:
	var top: Vector2 = scene.cam.unproject_position(scene.boss.position + Vector3.UP * 1.95)
	var bottom: Vector2 = scene.cam.unproject_position(scene.boss.position)
	var size := root.get_visible_rect().size
	return top.is_finite() and bottom.is_finite() and top.y > 90 and bottom.y < size.y - 100 and absf(top.x - size.x / 2) < size.x * 0.3

func _session(rec: Dictionary, hz: int) -> Dictionary:
	_begin(rec)
	var hashes: Array = []; var samples: Array = []; var commands: Array = []
	var rigid := true; var camera := true; var tells := true; var pure := true
	var min_stamina := 100.0; var recovered := 0.0; var fight_ticks := 0
	var zones := {}; var modes := {}; var previous_stamina := 100.0
	var first_bad := {}; var start_usec := Time.get_ticks_usec()
	var captured := {}
	for slice in int(rec["seconds"]) * 6:
		var wanted := _policy(slice); _held(wanted)
		commands.append(wanted.duplicate())
		for frame in hz / 6:
			var before: int = scene.sim.tick
			scene._process(1.0 / hz)
			if scene.sim.mode == "FIGHT": fight_ticks += scene.sim.tick - before
			rigid = _rig_ok(scene.player) and _rig_ok(scene.boss) and rigid
			if not _camera_ok():
				camera = false
				if first_bad.is_empty(): first_bad = {"tick": scene.sim.tick, "player": str(scene.player.position), "boss": str(scene.boss.position), "camera": str(scene.cam.position), "viewport": str(root.get_visible_rect()), "top": str(scene.cam.unproject_position(scene.boss.position + Vector3.UP * 1.95)), "feet": str(scene.cam.unproject_position(scene.boss.position))}
			if scene.sim.bstate in ["TELL", "HOLD"]:
				tells = tells and bool(scene.boss.get_meta("windup")) and scene.fight_hud.cue.text != ""
			if gpu:
				caption.text = "%s | %d Hz | %s | %.1fs" % [rec["name"], hz, scene.sim.mode, scene.sim.tick / 120.0]
				await process_frame; await RenderingServer.frame_post_draw
				var prefix := "readiness-%s" % rec["name"] if film else "readiness-%s-%dhz" % [rec["name"], hz]
				if slice % 60 == 0 and frame == 0: root.get_texture().get_image().save_png("user://%s-%03d.png" % [prefix, slice])
				var moment := ""
				if scene.sim.mode == "EIGHT" and scene.fight_feedback.timing.get("open", false): moment = "rise"
				elif not scene.sim.clinch.is_empty() and scene.fight_feedback.timing.get("open", false): moment = "clinch"
				elif float(scene.sim.P["stamina"]) < 15: moment = "gassed"
				elif int(scene.sim.P["counter_t"]) > 0: moment = "counter"
				if moment != "" and not captured.has(moment):
					captured[moment] = true; root.get_texture().get_image().save_png("user://%s-%s.png" % [prefix, moment])
		zones[scene.sim.zone(scene.sim.P["pos"])] = true; modes[scene.sim.mode] = true
		var stamina: float = scene.sim.P["stamina"]
		min_stamina = minf(min_stamina, stamina)
		if wanted.is_empty() or KEY_S in wanted: recovered += maxf(0, stamina - previous_stamina)
		previous_stamina = stamina
		var before_hash: int = scene.sim.hash_state()
		scene._render(scene.clock.alpha())
		pure = pure and before_hash == scene.sim.hash_state()
		hashes.append(str(before_hash))
		if slice % 6 == 0: samples.append({"tick": scene.sim.tick, "mode": scene.sim.mode, "stamina": stamina, "distance": scene.sim.P["pos"].distance_to(scene.sim.B["pos"]), "cue": scene.fight_hud.cue.text})
		if scene.sim.mode == "OVER": break
	_held([])
	var label := "%s / %d Hz" % [rec["name"], hz]
	_check(label + " fixed anatomy throughout", rigid)
	_check(label + " opponent stays clear of HUD", camera)
	_check(label + " authored tells remain visible", tells)
	_check(label + " repeated rendering is read-only", pure)
	_check(label + " exchanges include both offense and contact", int(scene.fx_counts.get("punch", 0)) >= 10 and int(scene.fx_counts.get("hit", 0)) >= 5 and int(scene.fx_counts.get("boss_act", 0)) >= 5)
	_check(label + " sustained fight time", fight_ticks >= (10 if rec["kind"] == "scrap" else 45) * 120)
	var released := true
	for action in scene.combat_input.KEYS:
		if scene.combat_input.down(action): print("HELD DETAIL ", action, " ", scene.combat_input.held.get(action), " keys=", keys, " focus=", root.gui_get_focus_owner(), " controls=", scene.controls_menu.opened, " club=", scene.club_flow.visible)
		released = released and not scene.combat_input.down(action)
	_check(label + " no input remains held", released)
	if rec["name"] == "fatigue-recovery": _check(label + " gassed through real costs then recovered", min_stamina < 15 and recovered > 40)
	if rec["kind"] == "dual": _check(label + " native corner send resumes next fighter", int(scene.sim.seg_idx) > 0 and int(scene.fx_counts.get("matchup", 0)) >= 2)
	var result := {"case": rec["name"], "hz": hz, "hashes": hashes, "commands": commands, "samples": samples, "events": scene.fx_counts.duplicate(), "fight_ticks": fight_ticks, "minimum_stamina": min_stamina, "recovered_stamina": recovered, "zones": zones.keys(), "modes": modes.keys(), "first_bad_camera": first_bad, "wall_seconds": (Time.get_ticks_usec() - start_usec) / 1000000.0}
	print("SESSION ", JSON.stringify(result.duplicate().merged({"hashes": hashes.size(), "commands": commands.size(), "samples": samples.size()}, true)))
	return result

func _run() -> void:
	film = "film" in OS.get_cmdline_user_args()
	gpu = film or "capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	print("HARDWARE INPUTS ", Input.get_connected_joypads())
	for device in Input.get_connected_joypads():
		var info := Input.get_joy_info(device)
		print("CONTROLLER vendor=%04x product=%04x" % [int(info.get("vendor_id", 0)), int(info.get("product_id", 0))])
	_check("controlled run has no external controller input", Input.get_connected_joypads().is_empty())
	if not Input.get_connected_joypads().is_empty(): quit(2); return
	for hz in [30, 60, 144]:
		var clock := Clock.new(); var ticks := 0; var aligned := true
		for slice in 600:
			for frame in hz / 6: ticks += clock.advance(1.0 / hz)
			aligned = aligned and ticks == (slice + 1) * 20
		_check("fixed clock aligns every 1/6 second boundary at %d Hz" % hz, aligned)
	var boundary := Clock.new()
	_check("clock does not round a genuinely short tick forward", boundary.advance(Sim.DT - 0.000001) == 0 and boundary.advance(0.000001) == 1)
	_check("clock retains hitch cap and rejects negative delta", boundary.advance(-1) == 0 and boundary.advance(2) == 30)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame
	scene.controls_menu.close(); scene.combat_input.reset_bindings()
	_check("normal launch pauses before the bell", scene.fight_hud.entry.visible)
	_key(KEY_ENTER, true); _key(KEY_ENTER, false); await process_frame
	_check("native Enter rings the first bell", not scene.fight_hud.entry.visible)
	if gpu:
		var layer := CanvasLayer.new(); layer.layer = 20; root.add_child(layer)
		caption = Label.new(); caption.position = Vector2(24, 148); layer.add_child(caption)
	for rec in CASES:
		var selected := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("case="): selected = arg.trim_prefix("case=")
		if selected != "" and selected != rec["name"]: continue
		var baseline: Dictionary = {}
		for hz in ([60] if film else ([30, 144] if gpu else [30, 60, 144])):
			var result: Dictionary = await _session(rec, hz)
			journal.append(result)
			var partial := FileAccess.open("user://readiness.json", FileAccess.WRITE)
			partial.store_string(JSON.stringify({"sessions": journal, "checks": checks, "failures": failures}, "\t")); partial.close()
			if baseline.is_empty(): baseline = result
			else: _check("%s identical state and native commands at %d Hz" % [rec["name"], hz], result["hashes"] == baseline["hashes"] and result["commands"] == baseline["commands"])
	var file := FileAccess.open("user://readiness.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"sessions": journal, "checks": checks, "failures": failures}, "\t")); file.close()
	print("READINESS VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
