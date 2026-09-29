extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_club_journey.gd -- club
## PAC-203: normal scene, native GUI/key events, earned ledgers; no test sim,
## seeded wallet, forced outcomes, demo profile, or direct progression calls.
## -- club [capture] ; capture renders milestones, not a real-time movie.
var scene: Node
var club: CanvasLayer
var keys := {}
var checks := 0
var failures: Array[String] = []
var journeys: Array = []
var captures: Array = []
var gpu := false

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

func _activate(button: Button, mouse := false) -> void:
	button.grab_focus(); await process_frame; await process_frame
	if mouse:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT
		e.position = button.get_global_rect().get_center(); e.pressed = true; root.push_input(e)
		e = e.duplicate(); e.pressed = false; root.push_input(e)
	else:
		_key(KEY_ENTER, true); _key(KEY_ENTER, false)
	await process_frame

func _press(id: String, mouse := false) -> bool:
	var ok: bool = club.buttons.has(id) and is_instance_valid(club.buttons[id]) and not club.buttons[id].disabled
	_check("native action available: " + id, ok)
	if ok: await _activate(club.buttons[id], mouse)
	return ok

func _page(name: String) -> void:
	await _activate(club.navigation[name])
	_check("navigation reaches " + name, club.page == name)

func _capture(label: String) -> void:
	if not gpu: return
	await process_frame; await RenderingServer.frame_post_draw
	var path := "user://club-" + label + ".png"
	_check("rendered " + label, root.get_texture().get_image().save_png(path) == OK)
	captures.append(path)

func _roadwork() -> void:
	var before: int = scene.sim.training_used()
	if not await _press("roadwork"): return
	_check("training locks navigation and save until result", club.navigation["Bouts"].disabled and club.footer_buttons["save"].disabled)
	await _capture("roadwork")
	for beat in 12:
		while not club.training.is_empty() and float(club.training["time"]) < float(club.training["next"]) - 0.005: club._process(0.005)
		if club.training.is_empty(): break
		await _activate(club.buttons["step"])
		for frame in 65: club._process(0.005)
	_check("played rhythm commits one training slot", scene.sim.training_used() == before + 1)
	_check("training returns focus and unlocks navigation", club.training.is_empty() and not club.navigation["Bouts"].disabled and root.gui_get_focus_owner() != null)

func _policy(frame: int, body := false) -> Array:
	var s = scene.sim
	var timing: Dictionary = scene.fight_feedback.timing_state(s)
	if not timing.is_empty():
		if not timing["open"] or timing["locked"]: return []
		return [KEY_ENTER] if s.mode == "EIGHT" else [KEY_A if timing["label"] == "LEFT" else KEY_D]
	if s.mode == "CARD": return [KEY_1] if frame % 20 < 10 else []
	if s.mode != "FIGHT": return []
	var wanted: Array = []
	var distance: float = s.P["pos"].distance_to(s.B["pos"])
	if float(s.P["stamina"]) < 22: return [KEY_S] if distance < 2.6 else []
	if distance > 1.2: wanted.append(KEY_W)
	if body:
		wanted.append(KEY_C)
		if frame % 45 < 25: wanted.append(KEY_J)
		elif frame % 45 < 44: wanted.append(KEY_K)
	elif s.bstate in ["TELL", "HOLD", "ACTING"] and int(s.P["counter_t"]) == 0: wanted.append(KEY_SPACE)
	elif frame % 60 < 32:
		wanted.append(KEY_J if frame / 60 % 2 == 0 else KEY_K)
		wanted.append(KEY_SHIFT); wanted.append(KEY_C)
	return wanted

func _fight(label: String, max_seconds: int, body := false) -> void:
	var start_tick: int = scene.sim.tick
	var start_rewards: Dictionary = scene.sim.rewards.duplicate(true)
	var hashes: Array = []
	for frame in max_seconds * 60:
		if scene.sim.mode == "OVER": break
		if club.visible and club.page == "Corner":
			_held([]); await _press("send")
		_held(_policy(frame, body)); scene._process(1.0 / 60)
		if frame % 60 == 0: hashes.append(scene.sim.hash_state())
		if frame % 600 == 0: await process_frame
	_held([]); await process_frame
	_check(label + " ends through normal combat and returns to club", scene.sim.mode == "OVER" and club.visible and club.page == "Bouts")
	_check(label + " shows verdict and earned reward", club.result_text != "" and club.reward_text != "" and scene.sim.rewards != start_rewards)
	journeys.append({"name": label, "fighter": scene.sim.pname(), "tick_start": start_tick, "tick_end": scene.sim.tick, "result": club.result_text, "reward": club.reward_text, "hashes_each_second": hashes, "ledger": scene.sim.rewards.duplicate(true)})
	await _capture(label)

func _run() -> void:
	gpu = "capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene)
	scene.set_process(false); club = scene.club_flow; club.set_process(false)
	await process_frame; await process_frame
	_check("scripted capture has no external controller", Input.get_connected_joypads().is_empty())
	if not Input.get_connected_joypads().is_empty(): quit(1); return
	_check("normal entry opens the club before a simulation tick", club.visible and scene.sim.tick == 0 and scene.demo_log.is_empty())
	await _capture("entry")
	var tick: int = scene.sim.tick; scene._process(0.25)
	_check("club decisions pause combat", scene.sim.tick == tick)
	await _page("Recruit")
	var wallet: Dictionary = scene.sim.rewards.duplicate(true)
	_check("scouting names price and rejects empty wallet", club.buttons["scout"].disabled and club.buttons["scout"].text.contains("10 Prestige"))
	await _activate(club.buttons["scout"], true)
	_check("disabled native purchase cannot debit wallet", scene.sim.rewards == wallet)
	await _capture("recruit-locked")
	await _page("Training")
	await _press("partner:PRIYA")
	club._process(0) # Remember the focused club control before opening Controls.
	await _activate(club.footer_buttons["controls"])
	_check("controls pause owns focus", scene.controls_menu.opened)
	_key(KEY_ESCAPE, true); _key(KEY_ESCAPE, false); await process_frame
	_check("closing controls restores club focus", not scene.controls_menu.opened and root.gui_get_focus_owner() != null and club.surface.is_ancestor_of(root.gui_get_focus_owner()))
	var bond: int = scene.sim.kizuna_pts("RORY", "PRIYA")
	await _roadwork()
	_check("roadwork earns typed Beans and partner bond", scene.sim.beans_typed().get("STA", 0) > 0 and scene.sim.kizuna_pts("RORY", "PRIYA") > bond)
	await _roadwork() # A partner flavours part of the jar; two runs fund STA.
	await _page("Stable"); await _press("section:Bean jar")
	var stat_before: int = scene.sim.grown_stats(scene.sim._stable_card("RORY"))["STA"]
	var beans_before: int = scene.sim.rewards["beans"]
	await _press("raise:STA")
	_check("earned Beans buy a persistent stat raise at authored cost", scene.sim.grown_stats(scene.sim._stable_card("RORY"))["STA"] == stat_before + 1 and scene.sim.rewards["beans"] == beans_before - 5)
	_check("unaffordable next raise is disabled and explained", club.buttons["raise:STA"].disabled and club.buttons["raise:STA"].tooltip_text.contains("costs"))
	await _capture("bean-jar")
	await _press("section:Ability board")
	for id in club.buttons.keys():
		if str(id).begins_with("node:") and not club.buttons[id].disabled:
			var points: int = scene.sim.gpoints_free("RORY"); await _press(id)
			_check("ability node uses earned board points", scene.sim.gpoints_free("RORY") < points); break
	await _page("Training"); await _roadwork()
	_check("daily training cap is enforced through UI", scene.sim.training_used() == 3 and club.buttons["roadwork"].disabled)
	await _press("rest")
	_check("rest changes day and refreshes slots with explicit feedback", scene.sim.training_used() == 0 and club.status.text.contains("refreshed"))
	await _page("Bouts")
	for attempt in 8:
		if int(scene.sim.rewards["prestige"]) >= 10: break
		if not await _press("bout:scrap_1"): break
		await _fight("earned-scrap-%d" % attempt, 42, true)
	_check("repeated native scraps earn scouting currency", int(scene.sim.rewards["prestige"]) >= 10)
	await _page("Recruit")
	var prestige: int = scene.sim.rewards["prestige"]
	await _press("scout")
	_check("scout debits authored price and produces a lead", scene.sim.rewards["prestige"] == prestige - 10 and not scene.sim.open_mat().is_empty())
	await _capture("scout-lead")
	await _page("Training")
	for day in 8:
		if scene.sim.open_mat_day(): break
		await _press("rest")
	await _page("Recruit")
	var recruited := ""
	if not scene.sim.open_mat().is_empty(): recruited = str(scene.sim.open_mat()[0]["name"])
	await _press("sign:0")
	_check("open mat signs the earned recruit into the stable", recruited != "" and not scene.sim._stable_card(recruited).is_empty())
	await _page("Stable")
	if recruited != "": await _press("fighter:" + recruited)
	await _press("section:Roles"); await _press("role:SCOUT")
	_check("recruit works an existing bench role", scene.sim.stable_role(recruited) == "SCOUT")
	await _capture("stable-role")
	await _page("Bouts"); await _press("dual"); await _press("slot:0")
	if recruited != "": await _press("dress:" + recruited)
	_check("formation dresses recruited fighter and persists chosen starter", scene.sim.sealed_p[0] == recruited and scene.sim.board.get("dress", []).has(recruited))
	_check("dressed recruit's bench role pauses", not scene.sim.role_working(recruited))
	var chosen_staff: Array = scene.sim.staff_dressed().duplicate()
	for rec in scene.sim.STAFF.get("corps", []):
		if not str(rec["id"]) in chosen_staff:
			await _press("staff:" + str(rec["id"]))
			_check("overfull staff choice is refused without changing board", scene.sim.staff_dressed() == chosen_staff and club.status.text.contains("staff slots"))
			break
	for id in chosen_staff: await _press("staff:" + id)
	_check("formation can deliberately field no staff", scene.sim.staff_dressed().is_empty())
	await _capture("formation")
	var saved_hash: int = scene.sim.hash_state()
	await _activate(club.footer_buttons["save"])
	_check("save confirms the current board", club.status.text.begins_with("Club saved"))
	await _press("order:1")
	await _activate(club.footer_buttons["load"])
	_check("continue restores formation and complete ledger exactly", scene.sim.hash_state() == saved_hash and scene.sim.sealed_p[0] == recruited)
	# A valid JSON file with a foreign schema must not replace the live club.
	await _activate(club.footer_buttons["save"])
	var file_bad := FileAccess.open(scene.SAVE_PATH, FileAccess.WRITE); file_bad.store_string('{"schema":"foreign"}'); file_bad.close()
	await _activate(club.footer_buttons["load"])
	_check("rejected save preserves live state and offers previous save", scene.sim.hash_state() == saved_hash and club.footer_buttons["rollback"].visible and club.status.text.contains("intact"))
	await _capture("save-recovery")
	await _activate(club.footer_buttons["rollback"])
	_check("previous save recovers the exact board", scene.sim.hash_state() == saved_hash)
	await _page("Formation"); await _press("seal")
	_check("chosen recruit enters the live dual", not club.visible and scene.sim.pname() == recruited)
	scene._process(1.0 / 60)
	# The visible Club button remains the normal pause/return route.
	await _activate(scene.fight_hud.club_button)
	_check("in-flight bout blocks replacement", club.visible and club.buttons["dual"].disabled)
	await _page("Training")
	_check("in-flight bout blocks training and calendar changes", club.buttons["roadwork"].disabled and club.buttons["rest"].disabled)
	await _activate(club.footer_buttons["save"]); saved_hash = scene.sim.hash_state()
	var flight_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.SAVE_PATH))
	flight_save["dual"]["schema"] = "foreign-fight"
	var bad_flight := FileAccess.open(scene.SAVE_PATH, FileAccess.WRITE); bad_flight.store_string(JSON.stringify(flight_save)); bad_flight.close()
	await _activate(club.footer_buttons["load"])
	_check("incompatible fight snapshot cannot replace current simulation", scene.sim.hash_state() == saved_hash and club.status.text.contains("intact"))
	await _activate(club.footer_buttons["save"])
	await _activate(club.footer_buttons["return"]); scene._process(0.25)
	await _activate(scene.fight_hud.club_button); await _activate(club.footer_buttons["load"])
	_check("mid-fight continue restores exact simulation", scene.sim.hash_state() == saved_hash)
	await _activate(club.footer_buttons["return"])
	await _fight("full-dual", 450)
	await _page("Stable"); await _press("fighter:PRIYA"); await _press("use_fighter")
	await _press("opponent:MARCUS"); await _press("spar")
	_check("selected fighter faces selected stablemate with shared rules", scene.sim.pname() == "PRIYA" and scene.sim.bout.get("card", {}).get("name", "") == "MARCUS" and scene.sim.bout["kind"] == "spar")
	await _fight("stablemate-spar", 110)
	await _activate(club.footer_buttons["save"]); saved_hash = scene.sim.hash_state()
	var saved_rewards: Dictionary = scene.sim.rewards.duplicate(true)
	var saved_pi: Dictionary = scene.sim.pi.duplicate(true)
	# A new scene is a fresh launch, not an in-memory reload of the old scene.
	scene.queue_free(); await process_frame
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	club = scene.club_flow; club.set_process(false); await process_frame
	await _activate(club.footer_buttons["load"])
	_check("fresh launch restores completed journey and earned recruit", scene.sim.rewards == saved_rewards and scene.sim.pi == saved_pi and not scene.sim._stable_card(recruited).is_empty())
	_check("completed-bout save preserves deliberately empty staff", scene.sim.staff_dressed().is_empty())
	_check("restored result retains earned reward feedback", club.reward_text != "")
	await _capture("continued-club")
	for size in [Vector2i(960, 540), Vector2i(640, 480)]:
		root.size = size; await process_frame; await process_frame
		for name in ["Bouts", "Stable", "Recruit", "Formation", "Training", "Scout Book"]:
			await _page(name)
			var right: float = club.scroll.get_global_rect().end.x
			_check("layout contains " + name + " at " + str(size), right <= size.x and club.footer_buttons["return"].get_global_rect().end.y <= size.y and club.scroll.size.y > 40)
			await _capture("%d-%s" % [size.x, name.to_lower().replace(" ", "-")])
	var file := FileAccess.open("user://club-journey.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "journeys": journeys, "captures": captures}, "  ")); file.close()
	print("CLUB JOURNEY VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED", checks - failures.size(), checks])
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
